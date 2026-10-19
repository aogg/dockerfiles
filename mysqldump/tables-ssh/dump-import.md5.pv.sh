#!/bin/bash
set +x

# ai要求
# 变量table不用规则时，需要后面加个空格"$table "
# ai要求

# ========== env 文件加载 ==========
# 优先级: 已导出的环境变量(docker run -e等) > env文件 > 脚本内默认值
# 用法: ENV_FILE=/path/to/.env 显式指定; 未指定时自动加载脚本同目录的 .env
# env文件格式: 每行 KEY=VALUE, 支持 # 注释/空行/export前缀/成对引号
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null 2>&1 && pwd)
load_env_file() {
        local env_file=$1
        if [[ ! -f "$env_file" ]]; then
                return 0
        fi
        echo "加载env文件: $env_file"
        local line key value
        while IFS= read -r line || [[ -n "$line" ]]; do
                line="${line#"${line%%[![:space:]]*}"}"
                line="${line%"${line##*[![:space:]]}"}"
                [[ -z "$line" || "$line" == \#* ]] && continue
                [[ "$line" == export\ * ]] && line="${line#export }"
                [[ "$line" != *=* ]] && continue
                key="${line%%=*}"
                value="${line#*=}"
                key="${key%"${key##*[![:space:]]}"}"
                value="${value#"${value%%[![:space:]]*}"}"
                value="${value%"${value##*[![:space:]]}"}"
                if [[ ${#value} -ge 2 && "$value" == \"*\" ]]; then
                        value="${value:1:${#value}-2}"
                elif [[ ${#value} -ge 2 && "$value" == \'*\' ]]; then
                        value="${value:1:${#value}-2}"
                fi
                [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || { echo "env文件忽略非法变量名: $key"; continue; }
                # 只填充未设置或为空的变量(真实环境变量优先)
                if [[ -z "${!key:-}" ]]; then
                        printf -v "$key" '%s' "$value"
                        export "$key"
                fi
        done < "$env_file"
}
ENV_FILE_PATH=${ENV_FILE:-}
if [[ -z "$ENV_FILE_PATH" && -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/.env" ]]; then
        ENV_FILE_PATH="$SCRIPT_DIR/.env"
fi
if [[ -n "$ENV_FILE_PATH" ]]; then
        load_env_file "$ENV_FILE_PATH"
fi

DB_USER=${DB_USER:-${MYSQL_ENV_DB_USER}}
DB_PASS=${DB_PASS:-${MYSQL_ENV_DB_PASS}}
DB_NAME=${DB_NAME:-${MYSQL_ENV_DB_NAME}}
DB_HOST=${DB_HOST:-${MYSQL_ENV_DB_HOST}}
DB_PORT=${DB_PORT:-3306}

# 用于管道导出并导入
DB_TABLE_PORT=${DB_TABLE_PORT:-${DB_PORT}}
DB_TABLE_HOST=${DB_TABLE_HOST:-${DB_HOST}}

# 用于SSH远端执行的MySQL连接信息（远端可能需要内网IP）
DB_HOST_BY_SSH=${DB_HOST_BY_SSH:-${DB_HOST}}
DB_PORT_BY_SSH=${DB_PORT_BY_SSH:-${DB_PORT}}

IGNORE_DATABASE=${IGNORE_DATABASE}
IGNORE_TABLES=${IGNORE_TABLES}
MYSQL_TABLES_ONLY_SYNC=${MYSQL_TABLES_ONLY_SYNC}
ASYNC_WAIT=${ASYNC_WAIT}
ASYNC_WAIT_MAX=${ASYNC_WAIT_MAX:-100}
ASYNC_WAIT_DB_MAX=${ASYNC_WAIT_DB_MAX:-10}
DUMP_PV=${DUMP_PV:-6m}
DUMP_WAIT_SECONDS=${DUMP_WAIT_SECONDS:-0.6}

# MySQL数据目录，用于加速判断表文件是否修改
MYSQL_DATA_DIR=${MYSQL_DATA_DIR:-}

# 分页同步配置
PAGE_SYNC_ENABLED=${PAGE_SYNC_ENABLED:-1}                    # 是否启用分页同步（1启用，0禁用）
PAGE_SIZE=${PAGE_SIZE:-5000}                                  # 每页数据量
PAGE_SYNC_TABLES=${PAGE_SYNC_TABLES:-}                        # 指定启用分页同步的表（逗号分隔，为空则所有表）
PAGE_SYNC_MIN_ROWS=${PAGE_SYNC_MIN_ROWS:-5000}                # 最小行数阈值，低于此值不分页

# ========== 表分组where过滤配置 ==========
# 用法(组号NN支持任意多组):
#   SYNC_WHERE_TABLES_01="orders,order_items,db2.logs"
#   SYNC_WHERE_STR_01="is_deleted=0 AND created_at>'2024-01-01'"
#   SYNC_WHERE_TABLES_02="db3.*"
#   SYNC_WHERE_STR_02="level_id<4"
# 表条目匹配优先级(多个组同时命中时, 取更精确的; 同精度取组号小的):
#   1. db.table  精确匹配指定库的指定表
#   2. db.*      匹配指定库的全部表
#   3. table     匹配所有库下的同名表
#   4. *         匹配所有表
# 生效范围: 远端行数统计 / mysqldump --where 导出导入 / 分页同步的分页查询与CRC32校验
# 行为说明: 配置了where的表跳过整表CHECKSUM快速路径(改用 --replace 按条件同步);
#           分页同步末尾的"删除目标端超范围数据"和"AUTO_INCREMENT回写"会被跳过,
#           避免误删被条件排除、但目标库已存在的行
# 注意: 条件内字符串值请用单引号, 不要用双引号(SSH远端SQL转义困难)
escape_where_for_ssh() {
        # 转义用于嵌入SSH远端SQL的where(远端bash会在双引号内再解析一次)
        # \ -> \\    $ -> \$    ` -> \`
        printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/\$/\\$/g' -e 's/`/\\`/g'
}

# 枚举所有已定义的 SYNC_WHERE_TABLES_NN 组号(按组号从小到大)
SYNC_WHERE_GROUP_NUMS=()
for _vname in $( { printenv | sed -n 's/^SYNC_WHERE_TABLES_\([0-9][0-9]*\)=.*/\1/p'; compgen -v 2>/dev/null | sed -n 's/^SYNC_WHERE_TABLES_//p' | grep -E '^[0-9]+$'; } | sort -n | uniq ); do
        SYNC_WHERE_GROUP_NUMS+=("$_vname")
done
unset _vname

TABLE_WHERE_RESULT=""
TABLE_WHERE_SOURCE=""
get_table_where() {
        # 用法: get_table_where <db> <table>
        # 结果: TABLE_WHERE_RESULT=命中的where(空=无过滤)  TABLE_WHERE_SOURCE=来源描述
        local db=$1 table=$2
        local n tvar svar tvals twhere item rank _items
        local best_rank=99 best_where="" best_from=""
        for n in "${SYNC_WHERE_GROUP_NUMS[@]}"; do
                tvar="SYNC_WHERE_TABLES_$n"
                svar="SYNC_WHERE_STR_$n"
                tvals="${!tvar:-}"
                twhere="${!svar:-}"
                [[ -z "$tvals" || -z "$twhere" ]] && continue
                IFS=',' read -ra _items <<< "$tvals"
                for item in "${_items[@]}"; do
                        item="${item#"${item%%[![:space:]]*}"}"
                        item="${item%"${item##*[![:space:]]}"}"
                        [[ -z "$item" ]] && continue
                        rank=-1
                        if [[ "$item" == "$db.$table" ]]; then
                                rank=0
                        elif [[ "$item" == "$db.*" ]]; then
                                rank=1
                        elif [[ "$item" == "$table" ]]; then
                                rank=2
                        elif [[ "$item" == "*" ]]; then
                                rank=3
                        fi
                        if [[ $rank -ge 0 && $rank -lt $best_rank ]]; then
                                best_rank=$rank
                                best_where="$twhere"
                                best_from="组$n($item)"
                        fi
                done
        done
        TABLE_WHERE_RESULT="$best_where"
        TABLE_WHERE_SOURCE="$best_from"
}

if [[ ${#SYNC_WHERE_GROUP_NUMS[@]} -eq 0 ]]; then
        echo '未配置SYNC_WHERE_TABLES_NN/SYNC_WHERE_STR_NN分组where过滤，按原逻辑同步'
else
        echo '======== 分组where过滤配置 ========'
        for _n in "${SYNC_WHERE_GROUP_NUMS[@]}"; do
                _tvar="SYNC_WHERE_TABLES_$_n"
                _svar="SYNC_WHERE_STR_$_n"
                _tval="${!_tvar:-}"
                _sval="${!_svar:-}"
                if [[ -z "$_sval" ]]; then
                        echo "警告: 组$_n 缺少SYNC_WHERE_STR_$_n，该组忽略"
                        continue
                fi
                if [[ -z "${_tval//,/}" ]]; then
                        echo "警告: 组$_n 表清单为空，该组忽略"
                        continue
                fi
                if [[ "$_sval" == *'"'* ]]; then
                        echo "警告: 组$_n 的where包含双引号，SSH远端SQL可能转义失败，建议条件内字符串用单引号"
                fi
                echo "组$_n: 表=[$_tval] where=[$_sval]"
        done
        echo '=================================='
fi
unset _n _tvar _svar _tval _sval

RUN_LIMIT_START=${RUN_LIMIT_START};
RUN_LIMIT_START_MYSQLDUMP=${RUN_LIMIT_START_MYSQLDUMP};
if [[ -n "$CPUQUOTA" ]];then
        RUN_LIMIT_START="sudo systemd-run --uid=\$(whoami) --gid=\$(id -gn) --scope -p CPUQuota=$CPUQUOTA ";
        RUN_LIMIT_START_MYSQLDUMP="";
        echo "通过systemd-run限制CPU配额 $CPUQUOTA";
fi
if [[ -n "$IONICE_C" ]];then
        RUN_LIMIT_START="ionice -c$IONICE_C "
        RUN_LIMIT_START_MYSQLDUMP=$RUN_LIMIT_START
        echo "通过ionice限制CPU配额 $IONICE_C";
fi

# systemd-run --scope -p CPUQuota=30%
# ionice -c3

# DUMP_ARGS=
#  docker build -f ./Dockerfile -t adockero/mysqldump:tables-ssh-pv --build-arg APK_ARG=pv --build-arg FILE_ARG=dump-import.md5.pv.sh  .


if [[ ${DB_USER} == "" ]]; then
        echo "Missing DB_USER env variable"
        exit 1
fi
if [[ ${DB_PASS} == "" ]]; then
        echo "Missing DB_PASS env variable"
        exit 1
fi
if [[ ${DB_HOST} == "" ]]; then
        echo "Missing DB_HOST env variable"
        exit 1
fi


# mysqldump 进程的关键字
# KEYWORD="mysqldump"
# KEYWORD="ssh -o"
# IMPORT_KEYWORD="mysql"
IFS=',' read -ra IGNORE_PAIRS <<< "$IGNORE_DATABASE_TABLES"


STRICT_HOST_KEY_CHECKING=${STRICT_HOST_KEY_CHECKING:no}

SSH_CONTROL_PATH="/tmp/ssh_mux_%h_%p_%r"
SSH_CONTROL_OPTS="-o ControlMaster=auto -o ControlPath=$SSH_CONTROL_PATH -o ControlPersist=60"

sshRun=$(echo sshpass -p \'"$SSH_PASSWORD"\' ssh $SSH_CONTROL_OPTS -o "LogLevel=ERROR" -o "StrictHostKeyChecking=$STRICT_HOST_KEY_CHECKING" $SSH_ARGS $SSH_USER@$SSH_IP)
echo '下面是执行的ssh'
echo $sshRun

eval "$sshRun pwd"

if [ $? -eq 0 ]; then
        echo '开始运行';
else
    echo "ssh异常，直接结束."
    exit 1
fi

a=$(eval "$sshRun 'if [ -f "/tmp/dump-import-ssh" ];then echo 1;else echo 2;fi'")

firstBool=0
if [[ "$a" != 1 ]];then
        #  首次
        echo '首次';
        firstBool=1
fi

# 初始化
# eval "$sshRun bash -c \"pwd && rm -Rf /tmp/dump-import-ssh-temp && mkdir -p /tmp/dump-import-ssh-temp/mysql_error_log_dir\""
mkdir -p /tmp/dump-import-ssh-temp;







# 使用SSH执行远程命令来获取CPU空闲率
cpuScript=$(cat <<EOF

while true; do
echo \$(mpstat 1 1 |grep "Average:" | awk '{print "远端-CPU空闲率 "\$NF}');

echo '远端-ps有mysqldump的数量 '\$(ps -ef|grep mysqldump|grep -v grep|wc -l);
date "+%Y-%m-%d %H:%M:%S";
sleep 2;

done

EOF
    )

echo '监听cpu空闲率的脚本'
echo $cpuScript


# get_remote_cpu_idle
#  exec -a "aaa" $(eval echo $sshRun)
# echo 100 > /tmp/get_remote_cpu_idle
async_write_file(){
        {
# 避免keyword匹配到
        echo $cpuScript | (exec -a "监听CPU空闲率" sshpass -p "$SSH_PASSWORD" ssh $SSH_ARGS -v -o "LogLevel=ERROR" -o "StrictHostKeyChecking=$STRICT_HOST_KEY_CHECKING" $SSH_USER@$SSH_IP 'bash -s') | while IFS= read -r line; do
                # echo $line > /tmp/get_remote_cpu_idle
                # echo "cpu空闲率=${line}"
                echo $line;
                echo $line | grep 'mysqldump的' | awk '{print $2}' > /tmp/remote_mysqldump_num;
        done
        } &
}
async_write_file
{
        sleep 2;
        while true; do
                if ! pgrep -f "监听CPU空闲率" > /dev/null; then
                        async_write_file
                fi
                sleep 2
        done
} &
echo '监听cpu空闲率'





echo '开始循环数据库--下面是执行的命令';
echo eval "$sshRun 'mysql --user=\"${DB_USER}\" --password=\"${DB_PASS}\" --host=\"${DB_HOST_BY_SSH}\" --port=\"${DB_PORT_BY_SSH}\" -e \"SHOW DATABASES;\"'"

databases=$(echo "DB_PASS=\"${DB_PASS}\";mysql --user=\"${DB_USER}\" --password=\"\${DB_PASS}\" --host=\"${DB_HOST_BY_SSH}\" --port=\"${DB_PORT_BY_SSH}\" -e \"SHOW DATABASES;\"" | eval "$sshRun 'bash -s'" | tr -d "| " | grep -v Database)
echo '开始循环数据库---'$databases;

num_databases=0;
databases_arr=();
for db in $databases; do
        (( num_databases++ ));
        databases_arr+=($db)
done

# for ((i = 0; i < num_databases; i++)); do
#     db=${databases_arr[$i]}
#     echo $db;
# done;

# databases=("db1" "db2" "db3")
# num_databases=$(echo -n $databases | wc -l)
echo "数据库-库数量--${num_databases}";

declare -A DB_RUNNING_STATUS

echo '' > /tmp/databases_count.run.log
echo '' > /tmp/databases_count.end.log

# 数据库并发控制相关变量
DB_WAIT_NUM=0
DB_CONTINUE_BOOL=0
DB_CONTINUE_BOOL_USE=0

# 等待数据库并发槽位可用（循环等待直到有可用槽位）
# 参数: db - 数据库名
# 使用全局变量: DB_WAIT_NUM, DB_CONTINUE_BOOL, DB_CONTINUE_BOOL_USE, ASYNC_WAIT_DB_MAX
wait_db_async_slot() {
        local db=$1

        while true; do
                local current_jobs=$(pgrep -f "mysqldump" | wc -l)
                current_jobs=$(( current_jobs + 1 ))
                local running_count=0
                for k in "${!DB_RUNNING_STATUS[@]}"; do
                        if [[ "${DB_RUNNING_STATUS[$k]}" == "1" ]]; then
                                (( running_count++ ))
                        fi
                done
                local remote_mysqldump_num=$(cat /tmp/remote_mysqldump_num 2>/dev/null || echo 0)
                local run_log_count=$(cat /tmp/databases_count.run.log | wc -l)

                if [[ "$running_count" -ge "$ASYNC_WAIT_DB_MAX" ]]; then
                        if [[ "$DB_WAIT_NUM" -gt "3" ]] && [[ "$remote_mysqldump_num" -lt "$ASYNC_WAIT_DB_MAX" ]]; then
                                if [[ "$DB_WAIT_NUM" -lt "3" ]];then
                                        (( DB_WAIT_NUM++ ));
                                else
                                        echo $(date "+%Y-%m-%d %H:%M:%S")"--远端mysqldump已结束，开始  导出${db}   waitNum=${DB_WAIT_NUM}------------------------";
                                        DB_CONTINUE_BOOL=$(( run_log_count + 1 ))
                                        DB_CONTINUE_BOOL_USE=1;
                                fi
                                DB_WAIT_NUM=0;
                        elif [[ "$remote_mysqldump_num" -lt "$ASYNC_WAIT_DB_MAX" ]];then
                                (( DB_WAIT_NUM++ ));
                        else
                                DB_WAIT_NUM=0;
                        fi

                        if [[ "$DB_CONTINUE_BOOL" -lt 1 ]];then
                                echo "$(date "+%Y-%m-%d %H:%M:%S")--本地等待库${db}  当前${current_jobs}  waitNum=${DB_WAIT_NUM}";
                                sleep 2;
                                continue;
                        elif [[ "$DB_CONTINUE_BOOL" = "$(( run_log_count + 1 ))" ]];then
                                if [[ "$DB_CONTINUE_BOOL_USE" -lt 1 ]];then
                                        echo "$(date "+%Y-%m-%d %H:%M:%S")--本地等待库${db}  当前${current_jobs}  waitNum=${DB_WAIT_NUM}  等待上一次放过去的导出进入mysqldump";
                                        sleep 2;
                                        continue;
                                else
                                        DB_CONTINUE_BOOL_USE=0;
                                        break;
                                fi
                        else
                                DB_CONTINUE_BOOL=0;
                                echo "$(date "+%Y-%m-%d %H:%M:%S")--本地等待库${db}  当前${current_jobs}  waitNum=${DB_WAIT_NUM}  continueBool=0";
                                sleep 2;
                                continue;
                        fi
                else
                        break;
                fi
        done

        DB_RUNNING_STATUS[$db]=1
}


mkdir -p /tmp/dump-import-ssh-temp/;
counter_file="/tmp/dump-import-ssh-temp/page_async_count"
echo 0 > "$counter_file"

page_sync_table() {
        local db=$1
        local table=$2
        local primary_key=$3
        local remote_table_rows=$4
        local skip_md5=$5
        local table_where=$6

        # where过滤片段: 远端SQL用转义版, 本地SQL用原始版
        local remote_filter_sql=""
        local local_filter_sql=""
        if [[ -n "$table_where" ]]; then
                local where_ssh
                where_ssh=$(escape_where_for_ssh "$table_where")
                remote_filter_sql=" AND ($where_ssh)"
                local_filter_sql=" AND ($table_where)"
        fi


        local all_columns_list=$(echo "DB_PASS=\"${DB_PASS}\";mysql --user=\"${DB_USER}\" --port=\"${DB_PORT_BY_SSH}\" --password=\"\${DB_PASS}\" --host=\"${DB_HOST_BY_SSH}\" -N -e \"SELECT COLUMN_NAME FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='$db' AND TABLE_NAME='$table' ORDER BY ORDINAL_POSITION;\" 2>/dev/null" | eval "$sshRun 'bash -s'" | tr -d '\r' | awk 'NF{printf "\\\\\\`%s\\\\\\`,", $0}' | sed 's/,$//')
        local all_columns_import=$(mysql --skip-ssl --user="${IMPORT_DB_USER}" --password="${IMPORT_DB_PASS}" --host="${IMPORT_DB_HOST}" -N -e "SELECT COLUMN_NAME FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='$db' AND TABLE_NAME='$table' ORDER BY ORDINAL_POSITION;" 2>/dev/null | tr -d '\r' | awk 'NF{printf "\\\\\\`%s\\\\\\`,", $0}' | sed 's/,$//')
        local all_columns=""
        if [[ -n "$all_columns_list" ]]; then
                all_columns="$all_columns_list"
        elif [[ -n "$all_columns_import" ]]; then
                all_columns="$all_columns_import"
        else
                all_columns="\`$primary_key\`"
                echo "无法获取列名，使用主键列--$db.$table"
        fi
        echo "$db.$table all_columns=$all_columns"

        increment_counter() {
                flock -x "$counter_file.lock" -c "echo \$(( \$(cat '$counter_file' 2>/dev/null || echo 0) + 1 )) > '$counter_file'"
        }
        decrement_counter() {
                flock -x "$counter_file.lock" -c "echo \$(( \$(cat '$counter_file' 2>/dev/null || echo 0) - 1 )) > '$counter_file'"
        }
        get_counter() {
                cat "$counter_file" 2>/dev/null || echo 0
        }

        process_page() {
                local page_start_actual=$1
                local page_end_local=$2
                local skip_md5=$3

                if [[ "$skip_md5" == "0" ]]; then
                        remote_checksum=$(echo "DB_PASS=\"${DB_PASS}\";mysql --user=\"${DB_USER}\" --port=\"${DB_PORT_BY_SSH}\" --password=\"\${DB_PASS}\" --host=\"${DB_HOST_BY_SSH}\" -N -e \"SELECT CRC32(GROUP_CONCAT((CONCAT_WS('|', $all_columns)) ORDER BY \\\`$primary_key\\\` SEPARATOR '')) FROM $db.\\\`$table\\\` WHERE \\\`$primary_key\\\` >= $page_start_actual AND \\\`$primary_key\\\` <= $page_end_local${remote_filter_sql};\" 2>/dev/null" | eval "$sshRun 'bash -s'" | tr -d '[:space:]')
                        import_checksum=$(mysql --skip-ssl --user="${IMPORT_DB_USER}" --password="${IMPORT_DB_PASS}" --host="${IMPORT_DB_HOST}" -N -e "SELECT CRC32(GROUP_CONCAT(CRC32(CONCAT_WS('|', $all_columns)) ORDER BY \`$primary_key\` SEPARATOR '')) FROM $db.\`$table\` WHERE \`$primary_key\` >= $page_start_actual AND \`$primary_key\` <= $page_end_local${local_filter_sql};" 2>/dev/null | tr -d '[:space:]')

                        if [[ "$remote_checksum" == "$import_checksum" ]]; then
                                echo "分页CHECKSUM一致，跳过--$db.$table 范围=$page_start_actual-$page_end_local"
                                decrement_counter
                                return 0
                        else
                                echo "分页CHECKSUM差异，同步--$db.$table 范围=$page_start_actual-$page_end_local 远端=$remote_checksum IMPORT端=$import_checksum"
                        fi
                else
                        echo "分页同步--$db.$table 范围=$page_start_actual-$page_end_local"
                fi

                local page_where="\`$primary_key\` >= $page_start_actual AND \`$primary_key\` <= $page_end_local"
                [[ -n "$table_where" ]] && page_where="$page_where AND ($table_where)"

                for ((retry=1; retry<=3; retry++)); do
                        error_output=$( (time (mysqldump --skip-ssl --skip-add-locks --no-tablespaces --no-create-info --replace --user="${DB_USER}" --port="${DB_TABLE_PORT}" --password="${DB_PASS}" --host="${DB_TABLE_HOST}" $DUMP_ARGS $db "$table" --where="$page_where" | pv -L $DUMP_PV | mysql --skip-ssl --user="${IMPORT_DB_USER}" --password="${IMPORT_DB_PASS}" --host="${IMPORT_DB_HOST}" $IMPORT_ARGS "$db")) 2>&1) && break
                        echo "分页同步失败(第${retry}次): $db.$table 范围=$page_start_actual-$page_end_local"
                        echo "错误信息: $error_output"
                done
                decrement_counter
        }

        local page_start=0
        local page_end_local=""
        local total_pages=0
        local src_max_id=""

        while true; do
                while true; do
                        local cur_count=$(get_counter)
                        if [[ "$cur_count" -lt "$ASYNC_WAIT_MAX" ]]; then
                                break
                        fi
                        sleep 0.3
                done
                increment_counter

                # echo "DB_PASS=\"${DB_PASS}\";mysql --user=\"${DB_USER}\" --port=\"${DB_PORT_BY_SSH}\" --password=\"\${DB_PASS}\" --host=\"${DB_HOST_BY_SSH}\" -N -e \"SELECT \\\`$primary_key\\\` FROM $db.\\\`$table\\\` WHERE \\\`$primary_key\\\` > $page_start ORDER BY \\\`$primary_key\\\` LIMIT ${PAGE_SIZE};\""

                # echo "DB_PASS=\"${DB_PASS}\";mysql --user=\"${DB_USER}\" --port=\"${DB_PORT_BY_SSH}\" --password=\"\${DB_PASS}\" --host=\"${DB_HOST_BY_SSH}\" -N -e \"SELECT \\\`$primary_key\\\` FROM $db.\\\`$table\\\` WHERE \\\`$primary_key\\\` > $page_start ORDER BY \\\`$primary_key\\\` LIMIT ${PAGE_SIZE};\"" | eval "$sshRun 'bash -s'"

                remote_pk_list=$(echo "DB_PASS=\"${DB_PASS}\";mysql --user=\"${DB_USER}\" --port=\"${DB_PORT_BY_SSH}\" --password=\"\${DB_PASS}\" --host=\"${DB_HOST_BY_SSH}\" -N -e \"SELECT \\\`$primary_key\\\` FROM $db.\\\`$table\\\` WHERE \\\`$primary_key\\\` > $page_start${remote_filter_sql} ORDER BY \\\`$primary_key\\\` LIMIT ${PAGE_SIZE};\" 2>/dev/null" | eval "$sshRun 'bash -s'")

                if [[ -z "$remote_pk_list" ]]; then
                        echo "没有数据 remote_pk_list  $db.$table "
                        decrement_counter
                        break
                fi

                # echo "$db.$table  remote_pk_list=$remote_pk_list"

                local page_start_actual=$(echo "$remote_pk_list" | head -1)
                page_end_local=$(echo "$remote_pk_list" | tail -1)
                src_max_id=$page_end_local
                (( total_pages++ ))

                process_page "$page_start_actual" "$page_end_local" "$skip_md5" &

                local pk_count=$(echo "$remote_pk_list" | wc -l)
                if [[ "$pk_count" -lt "${PAGE_SIZE}" ]]; then
                        break
                else
                        page_start=$page_end_local
                fi
        done

        echo "开始等待 $db.$table 总页数=$total_pages"
        wait
        rm -f "$counter_file" "$counter_file.lock"

        if [[ -z "$table_where" && ${#all_pages[@]} -gt 0 ]]; then
                src_max_id=${all_pages[-1]##*:}
                dst_max_id=$(mysql --skip-ssl --user="${IMPORT_DB_USER}" --password="${IMPORT_DB_PASS}" --host="${IMPORT_DB_HOST}" -N -e "SELECT MAX(\`$primary_key\`) FROM $db.\`$table\`;" 2>/dev/null | tr -d '[:space:]')
                echo "删除后续数据检查--$db.$table 源表最大ID=$src_max_id 目标表最大ID=$dst_max_id"
                if [[ -n "$src_max_id" && -n "$dst_max_id" && "$dst_max_id" -gt "$src_max_id" ]]; then
                        echo "删除目标表后续数据--$db.$table 删除 $primary_key > $src_max_id 的数据"
                        mysql --skip-ssl --user="${IMPORT_DB_USER}" --password="${IMPORT_DB_PASS}" --host="${IMPORT_DB_HOST}" -e "DELETE FROM $db.\`$table\` WHERE \`$primary_key\` > $src_max_id;" 2>/dev/null
                fi
                src_auto_increment=$(echo "DB_PASS=\"${DB_PASS}\";mysql --user=\"${DB_USER}\" --port=\"${DB_PORT_BY_SSH}\" --password=\"\${DB_PASS}\" --host=\"${DB_HOST_BY_SSH}\" -N -e \"SELECT AUTO_INCREMENT FROM information_schema.TABLES WHERE TABLE_SCHEMA='$db' AND TABLE_NAME='$table';\" 2>/dev/null" | eval "$sshRun 'bash -s'" | tr -d '[:space:]')
                if [[ -n "$src_auto_increment" ]]; then
                        echo "同步自增ID--$db.$table 源表AUTO_INCREMENT=$src_auto_increment"
                        mysql --skip-ssl --user="${IMPORT_DB_USER}" --password="${IMPORT_DB_PASS}" --host="${IMPORT_DB_HOST}" -e "ALTER TABLE $db.\`$table\` AUTO_INCREMENT=$src_auto_increment;" 2>/dev/null
                fi
        fi
}

for ((i = 0; i < num_databases; i++)); do
    db=${databases_arr[$i]}
    # 执行循环体的代码
#     echo "Processing database $((i + 1)): $db"
# done
# for db in $databases; do
    if [[ "$db" != "information_schema" ]] && [[ "$db" != "performance_schema" ]] && [[ "$db" != "mysql" ]] && [[ "$db" != _* ]] && [[ "$db" != "$IGNORE_DATABASE" ]]; then
# break;

        # 等待数据库并发槽位可用
        wait_db_async_slot "$db"

        # 先通过SSH获取表列表
        echo "获取数据库 $db 的表列表..."
        tables=$(echo "DB_PASS=\"${DB_PASS}\";mysql --user=\"${DB_USER}\" --port=\"${DB_PORT_BY_SSH}\" --password=\"\${DB_PASS}\" --host=\"${DB_HOST_BY_SSH}\" -N -e \"SHOW TABLES;\" $db 2>/dev/null" | eval "$sshRun 'bash -s'" | tr -d "| " | grep -v -e '^$')
        # echo "获取到表列表: $tables"

        # 转为数组并过滤忽略的表
        tables_arr=();
        echo "忽略表的列表: $IGNORE_TABLES"
        IFS=',' read -ra IGNORE_TABLES_ARR <<< "$IGNORE_TABLES"
        IFS=',' read -ra ONLY_SYNC_TABLES_ARR <<< "$MYSQL_TABLES_ONLY_SYNC"
        for table in $tables; do
                skip_table=0
                for ignore_table in "${IGNORE_TABLES_ARR[@]}"; do
                        if [[ "$table" == "$ignore_table" ]]; then
                                skip_table=1
                                echo "忽略表: $db.$table "
                                break
                        fi
                done
                if [[ $skip_table -eq 0 && -n "$MYSQL_TABLES_ONLY_SYNC" ]]; then
                        found=0
                        for only_table in "${ONLY_SYNC_TABLES_ARR[@]}"; do
                                if [[ "$table" == "$only_table" || "$db.$table" == "$only_table" ]]; then
                                        found=1
                                        break
                                fi
                        done
                        if [[ $found -eq 0 ]]; then
                                skip_table=1
                                echo "不在同步列表，跳过: $db.$table "
                        fi
                fi
                if [[ $skip_table -eq 0 ]]; then
                        tables_arr+=($table)
                fi
        done
        num_tables=${#tables_arr[@]}
        echo "数据库 $db 表数量: $num_tables"

        echo $db >> /tmp/databases_count.run.log;

        CURRENT_JOBS_COUNT=0
        # 本地循环每个表，并发处理
        for ((t = 0; t < num_tables; t++)); do
                table=${tables_arr[$t]}

                # 解析该表的分组where过滤条件
                get_table_where "$db" "$table"
                table_where="$TABLE_WHERE_RESULT"
                table_where_from="$TABLE_WHERE_SOURCE"
                table_where_ssh=""
                table_where_count_sql=""
                dump_where_arr=()
                if [[ -n "$table_where" ]]; then
                        table_where_ssh=$(escape_where_for_ssh "$table_where")
                        table_where_count_sql=" WHERE ($table_where_ssh)"
                        dump_where_arr=(--where="($table_where)")
                        echo "表启用where过滤--$db.$table 来源=$table_where_from where=$table_where"
                fi

                # 并发控制：等待当前并发数小于最大值
                while true; do
                        if [[ "$CURRENT_JOBS_COUNT" -lt "$ASYNC_WAIT_MAX" ]]; then
                                break
                        fi
                        CURRENT_JOBS_COUNT=$(pgrep -f "mysqldump" | wc -l)
                        CURRENT_JOBS_COUNT=$(( CURRENT_JOBS_COUNT + 1 ))
                        echo "$(date "+%Y-%m-%d %H:%M:%S")--等待并发槽位 $db.$table 当前jobs=$CURRENT_JOBS_COUNT ASYNC_WAIT_MAX=$ASYNC_WAIT_MAX"
                        sleep 2
                done
                CURRENT_JOBS_COUNT=$(( CURRENT_JOBS_COUNT + 1 ))

                schema_changed=0
                is_first_sync=0

                # 发给ssh时候`要三个\反义
                schema_md5_data=$(echo "DB_PASS=\"${DB_PASS}\";mysql --skip-ssl --default-character-set=utf8mb4 --user=\"${DB_USER}\" --port=\"${DB_PORT_BY_SSH}\" --password=\"\${DB_PASS}\" --host=\"${DB_HOST_BY_SSH}\" -N -e \"SHOW CREATE TABLE $db.\\\`$table\\\`;\" 2>/dev/null" | eval "$sshRun 'bash -s'")
                schema_md5=$(echo "$schema_md5_data" | sed 's/AUTO_INCREMENT=[0-9]*//g' | md5sum | awk '{print $1}')

                table_exists=$(mysql --skip-ssl --user="${IMPORT_DB_USER}" --password="${IMPORT_DB_PASS}" --host="${IMPORT_DB_HOST}" -N -e "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA='$db' AND TABLE_NAME='$table';" 2>/dev/null)

                if [[ "$table_exists" == "0" ]]; then
                        is_first_sync=1
                        echo "目标表不存在，首次同步: $db.$table "
                else
                        target_schema_md5_data=$(mysql --skip-ssl --default-character-set=utf8mb4 --user="${IMPORT_DB_USER}" --password="${IMPORT_DB_PASS}" --host="${IMPORT_DB_HOST}" -N -e "SHOW CREATE TABLE $db.\`$table\`;" 2>/dev/null)
                        target_schema_md5=$(echo "$target_schema_md5_data" | sed 's/AUTO_INCREMENT=[0-9]*//g' | md5sum | awk '{print $1}')

                        if [[ "$schema_md5" != "$target_schema_md5" ]]; then
                                schema_changed=1
                                echo "表结构有差异: $db.$table "
                                echo "远端表结构: $schema_md5_data"
                                echo "target端表结构: $target_schema_md5_data"
                        else
                                echo "表结构无差异: $db.$table "
                        fi
                fi

                if [[ "$schema_changed" == "1" || "$is_first_sync" == "1" ]]; then
                        echo "同步表结构: $db.$table "
                        for ((schema_retry=1; schema_retry<=3; schema_retry++)); do
                                error_output=$( (time (mysqldump --skip-ssl --skip-add-locks --no-tablespaces --no-data --user="${DB_USER}" --port="${DB_TABLE_PORT}" --password="${DB_PASS}" --host="${DB_TABLE_HOST}" $DUMP_ARGS $db "$table" | mysql --skip-ssl --user="${IMPORT_DB_USER}" --password="${IMPORT_DB_PASS}" --host="${IMPORT_DB_HOST}" $IMPORT_ARGS "$db")) 2>&1) && break
                                echo "同步表结构失败(第${schema_retry}次): $db.$table "
                                echo "错误信息: $error_output"
                        done
                fi

                {
                        echo "开始判断表数据同步  $db.$table "

                        # 不依赖远端存储diff，直接在本地处理
                        # 获取远端表的主键信息
                        remote_pk_result=$(echo "DB_PASS=\"${DB_PASS}\";mysql --user=\"${DB_USER}\" --port=\"${DB_PORT_BY_SSH}\" --password=\"\${DB_PASS}\" --host=\"${DB_HOST_BY_SSH}\" -N -e \"SELECT COLUMN_NAME FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='$db' AND TABLE_NAME='$table' AND COLUMN_KEY='PRI' ORDER BY ORDINAL_POSITION LIMIT 1;\" 2>/dev/null" | eval "$sshRun 'bash -s'")
                        primary_key=$(echo "$remote_pk_result" | tr -d '[:space:]')

                        # 获取远端表行数
                        remote_table_rows=$(echo "DB_PASS=\"${DB_PASS}\";mysql --user=\"${DB_USER}\" --port=\"${DB_PORT_BY_SSH}\" --password=\"\${DB_PASS}\" --host=\"${DB_HOST_BY_SSH}\" -N -e \"SELECT COUNT(*) FROM $db.\\\`$table\\\`${table_where_count_sql};\" 2>/dev/null" | eval "$sshRun 'bash -s'" | tr -d '[:space:]')
                        echo "$table 远端行数=$remote_table_rows"

                        # 检查表是否有数据
                        if [[ -z "$remote_table_rows" || "$remote_table_rows" == "0" ]]; then
                                echo "空表跳过同步--$db.$table"
                        else
                                # 判断是否启用分页同步
                                use_page_sync=0
                                if [[ "$PAGE_SYNC_ENABLED" == "1" && -n "$primary_key" && "$remote_table_rows" -ge "$PAGE_SYNC_MIN_ROWS" ]]; then
                                        # 检查主键是否是数值类型
                                        remote_pk_type=$(echo "DB_PASS=\"${DB_PASS}\";mysql --user=\"${DB_USER}\" --port=\"${DB_PORT_BY_SSH}\" --password=\"\${DB_PASS}\" --host=\"${DB_HOST_BY_SSH}\" -N -e \"SELECT DATA_TYPE FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='$db' AND TABLE_NAME='$table' AND COLUMN_NAME='$primary_key';\" 2>/dev/null" | eval "$sshRun 'bash -s'" | tr -d '[:space:]')

                                        if [[ "$remote_pk_type" =~ ^(int|bigint|smallint|tinyint|mediumint)$ ]]; then
                                                if [[ -z "$PAGE_SYNC_TABLES" ]]; then
                                                        use_page_sync=1
                                                else
                                                        IFS=',' read -ra PAGE_TABLES_ARR <<< "$PAGE_SYNC_TABLES"
                                                        for pt in "${PAGE_TABLES_ARR[@]}"; do
                                                                if [[ "$table" == "$pt" || "$db.$table" == "$pt" ]]; then
                                                                        use_page_sync=1
                                                                        break
                                                                fi
                                                        done
                                                fi
                                        fi
                                fi

                                echo "$table schema_changed=$schema_changed is_first_sync=$is_first_sync use_page_sync=$use_page_sync"

                                # 表结构改变或首次同步：数据需要全量同步
                                if [[ "$schema_changed" == "1" || "$is_first_sync" == "1" ]]; then
                                        if [[ "$use_page_sync" == "1" ]]; then
                                                echo "schema-page-sync $table 主键=$primary_key 行数=$remote_table_rows"
                                                page_sync_table "$db" "$table" "$primary_key" "$remote_table_rows" 1 "$table_where"
                                                echo "schema-page-sync-done $table"
                                        else
                                                # 不支持分页同步：全量同步
                                                echo "全量同步--$db.$table"
                                                for ((retry=1; retry<=3; retry++)); do
                                                        error_output=$( (time (mysqldump --skip-ssl --skip-add-locks --no-tablespaces --user="${DB_USER}" --port="${DB_TABLE_PORT}" --password="${DB_PASS}" --host="${DB_TABLE_HOST}" $DUMP_ARGS $db "$table" "${dump_where_arr[@]}" | pv -L $DUMP_PV | mysql --skip-ssl --user="${IMPORT_DB_USER}" --password="${IMPORT_DB_PASS}" --host="${IMPORT_DB_HOST}" $IMPORT_ARGS "$db")) 2>&1) && break
                                                        echo "全量同步失败(第${retry}次): $db.$table"
                                                        echo "错误信息: $error_output"
                                                done
                                                echo "全量同步结束--$db.$table"
                                        fi
                                else
                                        # 非首次同步且表结构未改变，并发对比MD5
                                        if [[ "$use_page_sync" == "1" ]]; then
                                                echo "启用分页同步 $table 主键=$primary_key 行数=$remote_table_rows"
                                                page_sync_table "$db" "$table" "$primary_key" "$remote_table_rows" 0 "$table_where"
                                                echo "分页同步完成--$db.$table "
                                        else
                                                if [[ -n "$table_where" ]]; then
                                                        # CHECKSUM TABLE不感知WHERE, 配置了过滤条件的表跳过整表CHECKSUM, 直接按条件replace同步
                                                        echo "表配置了where过滤，跳过整表CHECKSUM，按条件同步--$db.$table where=$table_where"
                                                        for ((retry=1; retry<=3; retry++)); do
                                                                error_output=$( (time (mysqldump --skip-ssl --replace --skip-add-locks --no-tablespaces --no-create-info --user="${DB_USER}" --port="${DB_TABLE_PORT}" --password="${DB_PASS}" --host="${DB_TABLE_HOST}" $DUMP_ARGS $db "$table" "${dump_where_arr[@]}" | pv -L $DUMP_PV | mysql --skip-ssl --user="${IMPORT_DB_USER}" --password="${IMPORT_DB_PASS}" --host="${IMPORT_DB_HOST}" $IMPORT_ARGS "$db")) 2>&1) && break
                                                                echo "条件同步失败(第${retry}次): $db.$table "
                                                                echo "错误信息: $error_output"
                                                        done
                                                        echo "条件同步结束--$db.$table "
                                                else
                                                remote_checksum=$(echo "DB_PASS=\"${DB_PASS}\";mysql --user=\"${DB_USER}\" --port=\"${DB_PORT_BY_SSH}\" --password=\"\${DB_PASS}\" --host=\"${DB_HOST_BY_SSH}\" -N -e \"CHECKSUM TABLE $db.\\\`$table\\\`;\" 2>/dev/null" | eval "$sshRun 'bash -s'" | awk '{print $2}' | tail -1)
                                                import_checksum=$(mysql --skip-ssl --user="${IMPORT_DB_USER}" --password="${IMPORT_DB_PASS}" --host="${IMPORT_DB_HOST}" -N -e "CHECKSUM TABLE $db.\`$table\`;" 2>/dev/null | awk '{print $2}' | tail -1)

                                                if [[ "$remote_checksum" == "$import_checksum" ]]; then
                                                        echo "整表CHECKSUM一致，跳过--$db.$table "
                                                else
                                                        echo "整表CHECKSUM差异，同步--$db.$table 远端=$remote_checksum IMPORT端=$import_checksum"
                                                        for ((retry=1; retry<=3; retry++)); do
                                                                error_output=$( (time (mysqldump --skip-ssl --replace --skip-add-locks --no-tablespaces --no-create-info --user="${DB_USER}" --port="${DB_TABLE_PORT}" --password="${DB_PASS}" --host="${DB_TABLE_HOST}" $DUMP_ARGS $db "$table" | pv -L $DUMP_PV | mysql --skip-ssl --user="${IMPORT_DB_USER}" --password="${IMPORT_DB_PASS}" --host="${IMPORT_DB_HOST}" $IMPORT_ARGS "$db")) 2>&1) && break
                                                                echo "差异同步失败(第${retry}次): $db.$table "
                                                                echo "错误信息: $error_output"
                                                        done
                                                fi
                                                echo "整表CHECKSUM对比处理结束--$db.$table "
                                                fi
                                        fi
                                fi
                        fi
                } &
                sleep $DUMP_WAIT_SECONDS;
        done

        # 等待当前库的所有表处理完成
        # wait

        echo $db >> /tmp/databases_count.end.log;
        DB_RUNNING_STATUS[$db]=0

        echo $(date "+%Y-%m-%d %H:%M:%S")"--异步导出库--结束--$db--------------------------------------";
# exit;
    fi
done


# 非R状态计数器
NON_R_COUNT=0
NON_R_THRESHOLD=60  # 连续60次非R状态才判定结束

# 检测 mysqldump 进程是否存在的函数（跳过睡眠状态和异常状态）
check_mysqldump_process() {
        # 获取匹配的进程 ID
        local pids=$(pgrep -f "(ssh -o|mysql|sshpass -p)" 2>/dev/null)

        # 如果没有进程，返回1（不存在）
        [[ -z "$pids" ]] && return 1

        # 检查每个进程的状态
        for pid in $pids; do
                local state=$(cat /proc/$pid/status 2>/dev/null | grep "^State:" | awk '{print $2}')
                # 只保留运行状态(R)，跳过睡眠(S)、停止(T)、僵尸(Z)、不可中断睡眠(D)等
                if [[ "$state" == "R" ]]; then
                        NON_R_COUNT=0  # 发现运行中的进程，重置计数器
                        return 0
                fi
        done

        # 没有运行中的进程，增加计数器
        ((NON_R_COUNT++))
        if [[ $NON_R_COUNT -ge $NON_R_THRESHOLD ]]; then
                return 1  # 连续达到阈值，判定结束
        fi
        return 0  # 未达阈值，继续检测
}

# 循环检测 mysqldump 进程是否存在
while check_mysqldump_process; do
        echo $(date "+%Y-%m-%d %H:%M:%S")" 最后导入 last  Waiting for mysqldump process to complete...${DB_HOST}  本地mysql数量=$(ps -ef|grep /usr/bin/mysql|wc -l)  非R计数=${NON_R_COUNT}/${NON_R_THRESHOLD}"
        sleep 1  # 等待 1 秒后重新检测
done

echo $(date "+%Y-%m-%d %H:%M:%S")" 最后导入 last  mysqldump process has completed.  "${DB_HOST}

# 清理临时目录
# eval "$sshRun bash -c \"rm -Rf /tmp/dump-import-ssh-temp\""
rm -Rf /tmp/dump-import-ssh-temp/


echo $(date "+%Y-%m-%d %H:%M:%S")'-------全部结束--------'
