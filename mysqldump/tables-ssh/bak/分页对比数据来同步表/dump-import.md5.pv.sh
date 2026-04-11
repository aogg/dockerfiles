#!/bin/bash
set +x

# ai要求
# 变量table不用规则时，需要后面加个空格"$table "
# ai要求

DB_USER=${DB_USER:-${MYSQL_ENV_DB_USER}}
DB_PASS=${DB_PASS:-${MYSQL_ENV_DB_PASS}}
DB_NAME=${DB_NAME:-${MYSQL_ENV_DB_NAME}}
DB_HOST=${DB_HOST:-${MYSQL_ENV_DB_HOST}}
DB_PORT=${DB_PORT:-3306}

# 用于管道导出并导入
DB_TABLE_PORT=${DB_TABLE_PORT:-${DB_PORT}}
DB_TABLE_HOST=${DB_TABLE_HOST:-${DB_HOST}}

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

# 密码加引用就需要eval
sshRun=$(echo sshpass -p \'"$SSH_PASSWORD"\' ssh -o "LogLevel=ERROR" -o "StrictHostKeyChecking=$STRICT_HOST_KEY_CHECKING" $SSH_ARGS $SSH_USER@$SSH_IP)
# sshRun=$(echo $sshRun)
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
eval "$sshRun bash -c \"pwd && mkdir -p /tmp/dump-import-ssh-diff && (ls -al /tmp/dump-import-ssh-diff/* | wc -l)  && rm -Rf /tmp/dump-import-ssh-temp && mkdir -p /tmp/dump-import-ssh-temp/mysql_error_log_dir\""







# 使用SSH执行远程命令来获取CPU空闲率
cpuScript=$(cat <<EOF

while true; do 
echo \$(mpstat 1 1 |grep "Average:" | awk '{print "远端-CPU空闲率 "\$NF}'); 

echo '远端-导出文件数量 '\$(ls -al /tmp/dump-import-ssh-temp/*/*.md5|wc -l || echo "temp下的md5空, 无需理会");

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
echo eval "$sshRun 'mysql --user=\"${DB_USER}\" --password=\"${DB_PASS}\" --host=\"${DB_HOST}\" -e \"SHOW DATABASES;\"'"

databases=$(echo "DB_PASS=\"${DB_PASS}\";mysql --user=\"${DB_USER}\" --password=\"\${DB_PASS}\" --host=\"${DB_HOST}\" -e \"SHOW DATABASES;\"" | eval "$sshRun 'bash -s'" | tr -d "| " | grep -v Database)
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
# exit;

echo '' > /tmp/databases_count.log
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
                local running_count=$(cat /tmp/databases_count.log | grep -v -e '^$' | wc -l)
                local remote_mysqldump_num=$(cat /tmp/remote_mysqldump_num 2>/dev/null || echo 0)
                local run_log_count=$(cat /tmp/databases_count.run.log | wc -l)
                
                # 检查当前运行库数量是否达到上限
                if [[ "$running_count" -ge "$ASYNC_WAIT_DB_MAX" ]]; then
                        # 远端mysqldump已结束，可以放行新的库
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
                        
                        # 检查是否需要继续等待
                        if [[ "$DB_CONTINUE_BOOL" -lt 1 ]];then
                                echo "$(date "+%Y-%m-%d %H:%M:%S")--本地等待库${db}  当前${current_jobs}  waitNum=${DB_WAIT_NUM}";
                                sleep 2;
                                continue;
                        elif [[ "$DB_CONTINUE_BOOL" = "$(( run_log_count + 1 ))" ]];then
                                # 还没出现mysqldump $db
                                if [[ "$DB_CONTINUE_BOOL_USE" -lt 1 ]];then
                                        echo "$(date "+%Y-%m-%d %H:%M:%S")--本地等待库${db}  当前${current_jobs}  waitNum=${DB_WAIT_NUM}  等待上一次放过去的导出进入mysqldump";
                                        sleep 2;
                                        continue;
                                else
                                        # 首次放行
                                        DB_CONTINUE_BOOL_USE=0;
                                        break;
                                fi
                        else
                                # 已生成mysqldump，归0
                                DB_CONTINUE_BOOL=0;
                                echo "$(date "+%Y-%m-%d %H:%M:%S")--本地等待库${db}  当前${current_jobs}  waitNum=${DB_WAIT_NUM}  continueBool=0";
                                sleep 2;
                                continue;
                        fi
                else
                        # 有可用槽位，退出循环
                        break;
                fi
        done
        
        # 可以继续处理，记录到日志
        echo $db >> /tmp/databases_count.log;
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
        tables=$(echo "DB_PASS=\"${DB_PASS}\";mysql --user=\"${DB_USER}\" --port=\"${DB_PORT}\" --password=\"\${DB_PASS}\" --host=\"${DB_HOST}\" -N -e \"SHOW TABLES;\" $db 2>/dev/null" | eval "$sshRun 'bash -s'" | tr -d "| " | grep -v -e '^$')
        echo "获取到表列表: $tables"
        
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
        
        # 提前创建该数据库相关的diff目录结构，避免后续多处重复创建
        eval "$sshRun bash -c \"echo '开始mkdir';mkdir -p /tmp/dump-import-ssh-diff/$db /tmp/dump-import-ssh-diff/pages/$db /tmp/dump-import-ssh-diff/mtime/$db;\""
        
        # 本地循环每个表，并发处理
        for ((t = 0; t < num_tables; t++)); do
                table=${tables_arr[$t]}
                
                # 并发控制：等待当前并发数小于最大值
                while true; do
                        current_jobs=$(pgrep -f "mysqldump" | wc -l)
                        current_jobs=$(( $current_jobs + 1 ))
                        if [[ "$current_jobs" -lt "$ASYNC_WAIT_MAX" ]]; then
                                break
                        fi
                        echo "$(date "+%Y-%m-%d %H:%M:%S")--等待并发槽位 $db.$table 当前jobs=$current_jobs ASYNC_WAIT_MAX=$ASYNC_WAIT_MAX"
                        sleep 1
                done

                schema_changed=0
                is_first_sync=0
                
                # 发给ssh时候`要三个\反义
                schema_md5_data=$(echo "DB_PASS=\"${DB_PASS}\";mysql --skip-ssl --default-character-set=utf8mb4 --user=\"${DB_USER}\" --port=\"${DB_PORT}\" --password=\"\${DB_PASS}\" --host=\"${DB_HOST}\" -N -e \"SHOW CREATE TABLE $db.\\\`$table\\\`;\" 2>/dev/null" | eval "$sshRun 'bash -s'")
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
                                error_output=$(time (mysqldump --skip-ssl --skip-add-locks --no-tablespaces --no-data --user="${DB_USER}" --port="${DB_TABLE_PORT}" --password="${DB_PASS}" --host="${DB_TABLE_HOST}" $DUMP_ARGS $db "$table" | mysql --skip-ssl --user="${IMPORT_DB_USER}" --password="${IMPORT_DB_PASS}" --host="${IMPORT_DB_HOST}" $IMPORT_ARGS "$db") 2>&1) && break
                                echo "同步表结构失败(第${schema_retry}次): $db.$table "
                                echo "错误信息: $error_output"
                        done
                fi
                
                {
                        schema_changed=$schema_changed
                        is_first_sync=$is_first_sync
                        # 单个表的SSH判断脚本：同时检查修改时间和MD5，支持分页同步
                        table_command=$(cat << BASH
set +x;

MYSQL_DATA_DIR="${MYSQL_DATA_DIR}";
DB_PASS="${DB_PASS}";
table="${table}";
PAGE_SYNC_ENABLED="${PAGE_SYNC_ENABLED}";
PAGE_SIZE="${PAGE_SIZE}";
PAGE_SYNC_TABLES="${PAGE_SYNC_TABLES}";
PAGE_SYNC_MIN_ROWS="${PAGE_SYNC_MIN_ROWS}";

mkdir -p /tmp/dump-import-ssh-temp/$db/;
mkdir -p /tmp/dump-import-ssh-temp/mtime/$db/;
mkdir -p /tmp/dump-import-ssh-temp/pages/$db/;

# 初始化跨表共享的分页并发计数器
mkdir -p /tmp/dump-import-ssh-temp/;


# 获取表的主键信息
primary_key=\$(mysql --user="${DB_USER}" --port="${DB_PORT}" --password="\${DB_PASS}" --host="${DB_HOST}" -N -e "SELECT COLUMN_NAME FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='$db' AND TABLE_NAME='\$table' AND COLUMN_KEY='PRI' ORDER BY ORDINAL_POSITION LIMIT 1;" 2>/dev/null);


#echo ------------------------------------
#mysql --user="${DB_USER}" --port="${DB_PORT}" --password="\${DB_PASS}" --host="${DB_HOST}" -N -e "SELECT COUNT(*) FROM $db.\\\`$table\\\`;";

#mysql --user="${DB_USER}" --port="${DB_PORT}" --password="\${DB_PASS}" --host="${DB_HOST}" -N -e "SELECT COUNT(*) FROM $db.\`$table\`;";

#mysql --user="${DB_USER}" --port="${DB_PORT}" --password="\${DB_PASS}" --host="${DB_HOST}" -N -e "SELECT COUNT(*) FROM qimall.qimall_user;";
#echo ------------------------------------

# 获取表行数
table_rows=\$(mysql --user="${DB_USER}" --port="${DB_PORT}" --password="\${DB_PASS}" --host="${DB_HOST}" -N -e "SELECT COUNT(*) FROM $db.\\\`$table\\\`;" 2>/dev/null);
echo "$table 行数=\$table_rows";

# 检查表是否有数据，没有数据则跳过
if [[ -z "\$table_rows" || "\$table_rows" == "0" ]]; then
        echo "empty-table \$table 行数=\$table_rows";
        echo "empty-table-done \$table";
else
        # 有数据，继续判断是否启用分页同步
use_page_sync=0;
if [[ "\$PAGE_SYNC_ENABLED" == "1" && -n "\$primary_key" && "\$table_rows" -ge "\$PAGE_SYNC_MIN_ROWS" ]]; then
        # 检查主键是否是数值类型（支持 id > 0 分页）
        pk_type=\$(mysql --user="${DB_USER}" --port="${DB_PORT}" --password="\${DB_PASS}" --host="${DB_HOST}" -N -e "SELECT DATA_TYPE FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='$db' AND TABLE_NAME='\$table' AND COLUMN_NAME='\$primary_key';" 2>/dev/null);
        
        if [[ "\$pk_type" =~ ^(int|bigint|smallint|tinyint|mediumint)$ ]]; then
                # 检查是否在指定表列表中（如果配置了）
                if [[ -z "\$PAGE_SYNC_TABLES" ]]; then
                        use_page_sync=1;
                else
                        IFS=',' read -ra PAGE_TABLES_ARR <<< "\$PAGE_SYNC_TABLES";
                        for pt in "\${PAGE_TABLES_ARR[@]}"; do
                                if [[ "\$table" == "\$pt" || "\$db.\$table" == "\$pt" ]]; then
                                        use_page_sync=1;
                                        break;
                                fi
                        done
                fi
        fi
fi


echo "$table schema_changed=\$schema_changed  is_first_sync=\$is_first_sync  use_page_sync=\$use_page_sync";

# 表结构改变或首次同步：数据需要全量同步
if [[ "\$schema_changed" == "1" || "\$is_first_sync" == "1" ]]; then
        if [[ "\$use_page_sync" == "1" ]]; then
                # 支持分页同步：全量分页同步数据
                echo "schema-page-sync \$table 主键=\$primary_key 行数=\$table_rows";
                
                # 清空旧的分页MD5文件
                rm -f /tmp/dump-import-ssh-temp/pages/$db/$table/*.md5 2>/dev/null;
                
                # 迭代分页获取数据，使用 LIMIT 获取固定数量，动态计算分页范围
                page_start=0;
                page_num=0;
                has_more=1;

                
                while [[ "\$has_more" == "1" ]]; do
                        # 并发控制（跨表共享）
                        echo "表结构同步后同步数据的等待--schema-page-sync  db=$db table=\$table has_more=\$has_more-----"\$(date "+%Y-%m-%d %H:%M:%S")
                        
                        # 获取该页的主键范围（只查询主键列，提高效率）
                        pk_list=\$(mysql --user="${DB_USER}" --port="${DB_PORT}" --password="\${DB_PASS}" --host="${DB_HOST}" -N -e "SELECT \\\`\$primary_key\\\` FROM $db.\\\`$table\\\` WHERE \\\`\$primary_key\\\` > \$page_start ORDER BY \\\`\$primary_key\\\` LIMIT \${PAGE_SIZE};" 2>/dev/null);

                        
                        echo "表结构同步后同步数据的等待--schema-page-sync-- db=$db table=\$table pk_list=\${#pk_list[@]}"
                        
                        # 检查是否有数据
                        if [[ -z "\$pk_list" ]]; then
                                has_more=0;
                        else
                                # 获取本页的实际起始和结束主键值
                                page_start_actual=\$(echo "\$pk_list" | head -1);
                                page_end_local=\$(echo "\$pk_list" | tail -1);
                                
                                # 获取该页数据并计算MD5
                                page_data=\$(mysql --user="${DB_USER}" --port="${DB_PORT}" --password="\${DB_PASS}" --host="${DB_HOST}" -N -e "SELECT * FROM $db.\\\`$table\\\` WHERE \\\`\$primary_key\\\` >= \$page_start_actual AND \\\`\$primary_key\\\` <= \$page_end_local ORDER BY \\\`\$primary_key\\\`;" 2>/dev/null);
                                page_md5=\$(echo "\$page_data" | md5sum | awk '{print \$1}');
                                
                                # 保存分页MD5
                                mkdir -p /tmp/dump-import-ssh-temp/pages/$db/$table/;
                                mkdir -p /tmp/dump-import-ssh-diff/pages/$db/$table/;
                                echo "\$page_md5" > /tmp/dump-import-ssh-temp/pages/$db/$table/page_\${page_num}.md5;
                                echo "写入md5了1，非首次---$db $table  \$page_end_local \$page_num";
                                
                                # 表结构改变或首次同步，所有分页都需要同步
                                echo "page-diff \$table \$page_start_actual \$page_end_local \$page_num";
                                

                                # 检查是否还有更多数据（获取的记录数小于PAGE_SIZE说明是最后一页）
                                pk_count=\$(echo "\$pk_list" | wc -l);
                                if [[ "\$pk_count" -lt "\${PAGE_SIZE}" ]]; then
                                        has_more=0;
                                else
                                        page_start=\$page_end_local;
                                        ((page_num++));
                                fi
                        fi
                done
                
                # 合并所有分页MD5作为整表MD5
                cat /tmp/dump-import-ssh-temp/pages/$db/$table/*.md5 2>/dev/null | sort | md5sum | awk -v table="\$table" '{print table, \$1}' > /tmp/dump-import-ssh-temp/$db/\$table.md5;
                
                echo "schema-page-sync-done \$table 总页数=\$((page_num + 1))";
        else
                # 不支持分页同步：全量同步（表结构+数据）
                $RUN_LIMIT_START_MYSQLDUMP mysqldump --no-tablespaces --log-error=/tmp/dump-import-ssh-temp/mysql_error_log_dir/$db-\${table}.log --skip-comments --user="${DB_USER}" --port="${DB_PORT}" --password="\${DB_PASS}" --host="${DB_HOST}" $DUMP_ARGS $db \$table 2>/dev/null | md5sum | awk -v table="\$table" '{print table, \$1}' > /tmp/dump-import-ssh-temp/$db/\$table.md5;
                echo "full-sync \$table";
        fi
else
        # 非首次同步且表结构未改变，检查分页差异
        if [[ "\$use_page_sync" == "1" ]]; then
                echo "启用分页同步 \$table 主键=\$primary_key 行数=\$table_rows";
                
                # 清空旧的分页MD5文件
                rm -f /tmp/dump-import-ssh-temp/pages/$db/$table/*.md5 2>/dev/null;
                
                # 迭代分页获取数据，使用 LIMIT 获取固定数量，动态计算分页范围
                page_start=0;
                page_num=0;
                has_more=1;
                
                while [[ "\$has_more" == "1" ]]; do
                        
                        # 获取该页的主键范围（只查询主键列，提高效率）
                        pk_list=\$(mysql --user="${DB_USER}" --port="${DB_PORT}" --password="\${DB_PASS}" --host="${DB_HOST}" -N -e "SELECT \\\`\$primary_key\\\` FROM $db.\\\`$table\\\` WHERE \\\`\$primary_key\\\` > \$page_start ORDER BY \\\`\$primary_key\\\` LIMIT \${PAGE_SIZE};" 2>/dev/null);
                        
                        # 检查是否有数据
                        if [[ -z "\$pk_list" ]]; then
                                has_more=0;
                        else
                                # 获取本页的实际起始和结束主键值
                                page_start_actual=\$(echo "\$pk_list" | head -1);
                                page_end_local=\$(echo "\$pk_list" | tail -1);
                                
                                # 获取该页数据并计算MD5
                                page_data=\$(mysql --user="${DB_USER}" --port="${DB_PORT}" --password="\${DB_PASS}" --host="${DB_HOST}" -N -e "SELECT * FROM $db.\\\`$table\\\` WHERE \\\`\$primary_key\\\` >= \$page_start_actual AND \\\`\$primary_key\\\` <= \$page_end_local ORDER BY \\\`\$primary_key\\\`;" 2>/dev/null);
                                page_md5=\$(echo "\$page_data" | md5sum | awk '{print \$1}');
                                
                                # 保存分页MD5
                                mkdir -p /tmp/dump-import-ssh-temp/pages/$db/$table/;
                                mkdir -p /tmp/dump-import-ssh-diff/pages/$db/$table/;
                                echo "\$page_md5" > /tmp/dump-import-ssh-temp/pages/$db/$table/page_\${page_num}.md5;
                                echo "写入md5了2，非首次---$db $table  最后id=\$page_end_local \$page_num";
                                
                                # 对比差异
                                old_page_md5="";
                                if [[ -f "/tmp/dump-import-ssh-diff/pages/$db/$table/page_\${page_num}.md5" ]]; then
                                        old_page_md5=\$(cat /tmp/dump-import-ssh-diff/pages/$db/$table/page_\${page_num}.md5);
                                fi
                                
                                if [[ "\$page_md5" != "\$old_page_md5" ]]; then
                                        echo "page-diff \$table \$page_start_actual \$page_end_local \$page_num";
                                fi
                                
                                # 检查是否还有更多数据（获取的记录数小于PAGE_SIZE说明是最后一页）
                                pk_count=\$(echo "\$pk_list" | wc -l);
                                if [[ "\$pk_count" -lt "\${PAGE_SIZE}" ]]; then
                                        has_more=0;
                                else
                                        page_start=\$page_end_local;
                                        ((page_num++));
                                fi
                        fi
                done
                
                # 等待所有后台任务完成
                wait;
                
                # 合并所有分页MD5作为整表MD5
                cat /tmp/dump-import-ssh-temp/pages/$db/$table/*.md5 2>/dev/null | sort | md5sum | awk -v table="\$table" '{print table, \$1}' > /tmp/dump-import-ssh-temp/$db/\$table.md5;
                
                echo "page-sync-done \$table 总页数=\$((page_num + 1))";
        else
                # 传统方式：导出表并计算MD5
                $RUN_LIMIT_START_MYSQLDUMP mysqldump --no-tablespaces --log-error=/tmp/dump-import-ssh-temp/mysql_error_log_dir/$db-\${table}.log --no-create-info --skip-comments --user="${DB_USER}" --port="${DB_PORT}" --password="\${DB_PASS}" --host="${DB_HOST}" $DUMP_ARGS $db \$table 2>/dev/null | grep -e '^INSERT INTO' | md5sum | awk -v table="\$table" '{print table, \$1}' > /tmp/dump-import-ssh-temp/$db/\$table.md5;
                
                # 判断是否有差异
                temp_md5=\$(cat /tmp/dump-import-ssh-temp/$db/\$table.md5 2>/dev/null || echo "");
                
                if [[ -f "/tmp/dump-import-ssh-diff/$db/\$table.md5" ]]; then
                        diff_md5=\$(cat /tmp/dump-import-ssh-diff/$db/\$table.md5);
                        if [[ "\$temp_md5" != "\$diff_md5" ]]; then
                                echo "diff-sync \$table";
                        else
                                echo "数据没有差异 \$table ";
                        fi
                else
                        echo "diff-sync \$table";
                fi
        fi
fi
# 关闭空表检查的else块
fi

BASH
                        )
                        
                        # 执行SSH并处理输出
                        printf "%s\n" "$table_command" | eval "$sshRun '$RUN_LIMIT_START bash -c \"exec -a 导出表-$db.$table bash -s\" 2> /dev/null'" | while read -r line; do
                                echo "原文输出: " $db.$line " ";
                                
                                # 处理分页差异同步（包括首次同步和增量同步）
                                if [[ $line == "page-diff "* ]]; then
                                        import_table=$(echo $line | awk '{print $2}')
                                        page_start=$(echo $line | awk '{print $3}')
                                        page_end=$(echo $line | awk '{print $4}')
                                        page_num=$(echo $line | awk '{print $5}')
                                        
                                        
                                        # 获取主键名称
                                        pk_result=$(echo "DB_PASS=\"${DB_PASS}\";mysql --user=\"${DB_USER}\" --port=\"${DB_PORT}\" --password=\"\${DB_PASS}\" --host=\"${DB_HOST}\" -N -e \"SELECT COLUMN_NAME FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='$db' AND TABLE_NAME='$import_table' AND COLUMN_KEY='PRI' ORDER BY ORDINAL_POSITION LIMIT 1;\" 2>/dev/null" | eval "$sshRun 'bash -s'")
                                        primary_key=$(echo "$pk_result" | tr -d '[:space:]')

                                        echo "分页差异同步--$db.$import_table 页码=$page_num 范围=$page_start-$page_end; primary_key=$primary_key";

                                        
                                        if [[ -z "$import_table" ]]; then
                                                continue;
                                        fi
                                        
                                        if [[ -z "$primary_key" ]]; then
                                                continue;
                                        fi

                                        for ((retry=1; retry<=3; retry++)); do
                                                echo "执行分页同步命令(第${retry}次): mysqldump --skip-ssl --skip-add-locks --no-tablespaces --no-create-info --replace --user=\"${DB_USER}\" --port=\"${DB_TABLE_PORT}\" --password=\"***\" --host=\"${DB_TABLE_HOST}\" $DUMP_ARGS $db \"$import_table\" --where=\"\`$primary_key\` >= $page_start AND \`$primary_key\` <= $page_end\" | pv -L $DUMP_PV | mysql --skip-ssl --user=\"${IMPORT_DB_USER}\" --password=\"***\" --host=\"${IMPORT_DB_HOST}\" $IMPORT_ARGS \"$db\""
                                                error_output=$(time (mysqldump --skip-ssl --skip-add-locks --no-tablespaces --no-create-info --replace --user="${DB_USER}" --port="${DB_TABLE_PORT}" --password="${DB_PASS}" --host="${DB_TABLE_HOST}" $DUMP_ARGS $db "$import_table" --where="\`$primary_key\` >= $page_start AND \`$primary_key\` <= $page_end"  | pv -L $DUMP_PV | mysql --skip-ssl --user="${IMPORT_DB_USER}" --password="${IMPORT_DB_PASS}" --host="${IMPORT_DB_HOST}" $IMPORT_ARGS "$db") 2>&1) && break

                                                echo "分页导入失败(第${retry}次): $db.$import_table 页码=$page_num"
                                                echo "错误信息: $error_output"
                                        done
                                        
                                        if [[ $? -eq 0 ]] && [[ -n "$import_table" ]]; then
                                                eval "$sshRun bash -c \"echo /tmp/dump-import-ssh-diff/pages/$db/$import_table;mkdir -p /tmp/dump-import-ssh-diff/pages/$db/$import_table; cp /tmp/dump-import-ssh-temp/pages/$db/$import_table/page_${page_num}.md5 /tmp/dump-import-ssh-diff/pages/$db/$import_table/\""
                                                echo "已保存分页diff: $db.$import_table 页码=$page_num";
                                        fi
                                        
                                        echo $(date "+%Y-%m-%d %H:%M:%S")"--分页同步结束  $db.$import_table 页码=$page_num";
                                        
                                # 处理全量同步（表结构改变或首次同步不支持分页）
                                elif [[ $line == "full-sync "* ]]; then
                                        import_table=$(echo $line | awk '{print $2}')
                                        echo "全量同步--$db.$import_table";
                                        
                                        if [[ -z "$import_table" ]]; then
                                                continue;
                                        fi

                                        for ((retry=1; retry<=3; retry++)); do
                                                echo "执行命令(第${retry}次): mysqldump --skip-ssl --skip-add-locks --no-tablespaces --user=\"${DB_USER}\" --port=\"${DB_TABLE_PORT}\" --password=\"***\" --host=\"${DB_TABLE_HOST}\" $DUMP_ARGS $db \"$import_table\" | pv -L $DUMP_PV | mysql --skip-ssl --user=\"${IMPORT_DB_USER}\" --password=\"***\" --host=\"${IMPORT_DB_HOST}\" $IMPORT_ARGS \"$db\""
                                                error_output=$(time (mysqldump --skip-ssl --skip-add-locks --no-tablespaces --user="${DB_USER}" --port="${DB_TABLE_PORT}" --password="${DB_PASS}" --host="${DB_TABLE_HOST}" $DUMP_ARGS $db "$import_table"  | pv -L $DUMP_PV | mysql --skip-ssl --user="${IMPORT_DB_USER}" --password="${IMPORT_DB_PASS}" --host="${IMPORT_DB_HOST}" $IMPORT_ARGS "$db") 2>&1) && break

                                                echo "全量同步--导入失败(第${retry}次): $db.$import_table"
                                                echo "错误信息: $error_output"
                                        done
                                        
                                        if [[ $? -eq 0 ]] && [[ -n "$import_table" ]]; then
                                                eval "$sshRun bash -c \"echo /tmp/dump-import-ssh-diff/pages/$db/$import_table;mkdir -p /tmp/dump-import-ssh-diff/pages/$db/$import_table; cp /tmp/dump-import-ssh-temp/$db/$import_table.md5 /tmp/dump-import-ssh-diff/$db/; rm -Rf /tmp/dump-import-ssh-diff/pages/$db/$import_table/* 2>/dev/null; if ls /tmp/dump-import-ssh-temp/pages/$db/$import_table/*.md5 1> /dev/null 2>&1; then cp -r /tmp/dump-import-ssh-temp/pages/$db/$import_table/*.md5 /tmp/dump-import-ssh-diff/pages/$db/$import_table/; fi\""
                                                echo "已保存到diff(含表结构): $db.$import_table";
                                        fi
                                        
                                        echo $(date "+%Y-%m-%d %H:%M:%S")"--全量同步结束  $db.$import_table";
                                        
                                # 处理普通差异同步（非分页模式）
                                elif [[ $line == "diff-sync "* ]]; then
                                
                                        import_table=$(echo $line | awk '{print $2}')
                                        echo "差异同步--$db.$import_table";

                                        if [[ -z "$import_table" ]]; then
                                                continue;
                                        fi
                                        
                                        for ((retry=1; retry<=3; retry++)); do
                                                echo "执行命令(第${retry}次): mysqldump --skip-ssl --replace --skip-add-locks --no-tablespaces --no-create-info --user=\"${DB_USER}\" --port=\"${DB_TABLE_PORT}\" --password=\"***\" --host=\"${DB_TABLE_HOST}\" $DUMP_ARGS $db \"$import_table\" | pv -L $DUMP_PV | mysql --skip-ssl --user=\"${IMPORT_DB_USER}\" --password=\"***\" --host=\"${IMPORT_DB_HOST}\" $IMPORT_ARGS \"$db\""
                                                error_output=$(time (mysqldump --skip-ssl --replace --skip-add-locks --no-tablespaces --no-create-info --user="${DB_USER}" --port="${DB_TABLE_PORT}" --password="${DB_PASS}" --host="${DB_TABLE_HOST}" $DUMP_ARGS $db "$import_table"  | pv -L $DUMP_PV | mysql --skip-ssl --user="${IMPORT_DB_USER}" --password="${IMPORT_DB_PASS}" --host="${IMPORT_DB_HOST}" $IMPORT_ARGS "$db") 2>&1) && break

                                                echo "差异同步--导入失败(第${retry}次): $db.$import_table"
                                                echo "错误信息: $error_output"
                                        done
                                        
                                        if [[ $? -eq 0 ]] && [[ -n "$import_table" ]]; then
                                                eval "$sshRun bash -c \"echo /tmp/dump-import-ssh-temp/$db/$import_table.md5;cp /tmp/dump-import-ssh-temp/$db/$import_table.md5 /tmp/dump-import-ssh-diff/$db/; cp /tmp/dump-import-ssh-temp/mtime/$db/$import_table.mtime /tmp/dump-import-ssh-diff/mtime/$db/ 2>/dev/null\""
                                                echo "已保存到diff: $db.$import_table";
                                        fi
                                        
                                        echo $(date "+%Y-%m-%d %H:%M:%S")"--差异同步结束  $db.$import_table";
                                        
                                # 处理表结构改变或首次同步的分页同步开始
                                elif [[ $line == "schema-page-sync "* ]]; then
                                        import_table=$(echo $line | awk '{print $2}')
                                        echo "schema-page-sync-分页同步--$db.$import_table";
                                        
                                        if [[ -z "$import_table" ]]; then
                                                continue;
                                        fi
                                        
                                # 处理表结构改变或首次同步的分页同步完成
                                elif [[ $line == "schema-page-sync-done "* ]]; then
                                        import_table=$(echo $line | awk '{print $2}')
                                        echo "表结构改变/首次同步-分页同步完成--$db.$import_table";
                                        
                                        if [[ -z "$import_table" ]]; then
                                                continue;
                                        fi
                                        
                                        # 删除目标表中超过源表最大主键的数据
                                        pk_result=$(echo "DB_PASS=\"${DB_PASS}\";mysql --user=\"${DB_USER}\" --port=\"${DB_PORT}\" --password=\"\${DB_PASS}\" --host=\"${DB_HOST}\" -N -e \"SELECT COLUMN_NAME FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='$db' AND TABLE_NAME='$import_table' AND COLUMN_KEY='PRI' ORDER BY ORDINAL_POSITION LIMIT 1;\" 2>/dev/null" | eval "$sshRun 'bash -s'")
                                        primary_key=$(echo "$pk_result" | tr -d '[:space:]')
                                        
                                        if [[ -n "$primary_key" ]]; then
                                                # 获取源表最大主键
                                                src_max_id=$(echo "DB_PASS=\"${DB_PASS}\";mysql --user=\"${DB_USER}\" --port=\"${DB_PORT}\" --password=\"\${DB_PASS}\" --host=\"${DB_HOST}\" -N -e \"SELECT MAX(\\\`$primary_key\\\`) FROM $db.\\\`$import_table\\\`;\" 2>/dev/null" | eval "$sshRun 'bash -s'" | tr -d '[:space:]')
                                                # 获取目标表最大主键
                                                dst_max_id=$(mysql --skip-ssl --user="${IMPORT_DB_USER}" --password="${IMPORT_DB_PASS}" --host="${IMPORT_DB_HOST}" -N -e "SELECT MAX(\`$primary_key\`) FROM $db.\`$import_table\`;" 2>/dev/null | tr -d '[:space:]')
                                                
                                                echo "删除后续数据检查--$db.$import_table 源表最大ID=$src_max_id 目标表最大ID=$dst_max_id";
                                                
                                                if [[ -n "$src_max_id" && -n "$dst_max_id" && "$dst_max_id" -gt "$src_max_id" ]]; then
                                                        echo "删除目标表后续数据--$db.$import_table 删除 $primary_key > $src_max_id 的数据";
                                                        mysql --skip-ssl --user="${IMPORT_DB_USER}" --password="${IMPORT_DB_PASS}" --host="${IMPORT_DB_HOST}" -e "DELETE FROM $db.\`$import_table\` WHERE \`$primary_key\` > $src_max_id;" 2>/dev/null
                                                        echo "已删除后续数据: $db.$import_table";
                                                fi
                                        fi
                                        
                                        # 保存schema、整表MD5和所有分页MD5
                                        if [[ -n "$import_table" ]]; then
                                                eval "$sshRun bash -c \"echo /tmp/dump-import-ssh-diff/pages/$db/$import_table;mkdir -p /tmp/dump-import-ssh-diff/pages/$db/$import_table; cp /tmp/dump-import-ssh-temp/$db/$import_table.md5 /tmp/dump-import-ssh-diff/$db/; rm -Rf /tmp/dump-import-ssh-diff/pages/$db/$import_table/* 2>/dev/null; if ls /tmp/dump-import-ssh-temp/pages/$db/$import_table/*.md5 1> /dev/null 2>&1; then cp -r /tmp/dump-import-ssh-temp/pages/$db/$import_table/*.md5 /tmp/dump-import-ssh-diff/pages/$db/$import_table/; fi\""
                                                echo "已保存同步记录(含表结构和分页): $db.$import_table";
                                        fi
                                        
                                # 处理首次分页同步完成（旧逻辑保留兼容）
                                elif [[ $line == "first-page-sync-done "* ]]; then
                                        import_table=$(echo $line | awk '{print $2}')
                                        echo "首次分页同步完成--$db.$import_table";
                                        # 保存schema、整表MD5和所有分页MD5
                                        if [[ -n "$import_table" ]]; then
                                                eval "$sshRun bash -c \"echo /tmp/dump-import-ssh-diff/pages/$db/$import_table;mkdir -p /tmp/dump-import-ssh-diff/pages/$db/$import_table; cp /tmp/dump-import-ssh-temp/$db/$import_table.md5 /tmp/dump-import-ssh-diff/$db/; rm -Rf /tmp/dump-import-ssh-diff/pages/$db/$import_table/* 2>/dev/null; if ls /tmp/dump-import-ssh-temp/pages/$db/$import_table/*.md5 1> /dev/null 2>&1; then cp -r /tmp/dump-import-ssh-temp/pages/$db/$import_table/*.md5 /tmp/dump-import-ssh-diff/pages/$db/$import_table/; fi\""
                                                echo "已保存首次同步记录: $db.$import_table";
                                        fi
                                        
                                # 处理分页同步完成
                                elif [[ $line == "page-sync-done "* ]]; then
                                        import_table=$(echo $line | awk '{print $2}')
                                        echo "分页同步完成--$db.$import_table";
                                        
                                        if [[ -z "$import_table" ]]; then
                                                continue;
                                        fi
                                        
                                        # 删除目标表中超过源表最大主键的数据
                                        pk_result=$(echo "DB_PASS=\"${DB_PASS}\";mysql --user=\"${DB_USER}\" --port=\"${DB_PORT}\" --password=\"\${DB_PASS}\" --host=\"${DB_HOST}\" -N -e \"SELECT COLUMN_NAME FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='$db' AND TABLE_NAME='$import_table' AND COLUMN_KEY='PRI' ORDER BY ORDINAL_POSITION LIMIT 1;\" 2>/dev/null" | eval "$sshRun 'bash -s'")
                                        primary_key=$(echo "$pk_result" | tr -d '[:space:]')
                                        
                                        if [[ -n "$primary_key" ]]; then
                                                # 获取源表最大主键
                                                src_max_id=$(echo "DB_PASS=\"${DB_PASS}\";mysql --user=\"${DB_USER}\" --port=\"${DB_PORT}\" --password=\"\${DB_PASS}\" --host=\"${DB_HOST}\" -N -e \"SELECT MAX(\\\`$primary_key\\\`) FROM $db.\\\`$import_table\\\`;\" 2>/dev/null" | eval "$sshRun 'bash -s'" | tr -d '[:space:]')
                                                # 获取目标表最大主键
                                                dst_max_id=$(mysql --skip-ssl --user="${IMPORT_DB_USER}" --password="${IMPORT_DB_PASS}" --host="${IMPORT_DB_HOST}" -N -e "SELECT MAX(\`$primary_key\`) FROM $db.\`$import_table\`;" 2>/dev/null | tr -d '[:space:]')
                                                
                                                echo "删除后续数据检查--$db.$import_table 源表最大ID=$src_max_id 目标表最大ID=$dst_max_id";
                                                
                                                if [[ -n "$src_max_id" && -n "$dst_max_id" && "$dst_max_id" -gt "$src_max_id" ]]; then
                                                        echo "删除目标表后续数据--$db.$import_table 删除 $primary_key > $src_max_id 的数据";
                                                        mysql --skip-ssl --user="${IMPORT_DB_USER}" --password="${IMPORT_DB_PASS}" --host="${IMPORT_DB_HOST}" -e "DELETE FROM $db.\`$import_table\` WHERE \`$primary_key\` > $src_max_id;" 2>/dev/null
                                                        echo "已删除后续数据: $db.$import_table";
                                                fi
                                        fi
                                        
                                        # 保存schema和整表MD5
                                        if [[ -n "$import_table" ]]; then
                                                eval "$sshRun bash -c \"cp /tmp/dump-import-ssh-temp/$db/$import_table.md5 /tmp/dump-import-ssh-diff/$db/;\""
                                                echo "已保存同步记录: $db.$import_table";
                                        fi
                                        
                                # 处理空表（无数据）
                                elif [[ $line == "empty-table "* ]]; then
                                        import_table=$(echo $line | awk '{print $2}')
                                        echo "空表跳过同步--$db.$import_table";
                                        
                                # 处理空表完成
                                elif [[ $line == "empty-table-done "* ]]; then
                                        import_table=$(echo $line | awk '{print $2}')
                                        echo "空表处理完成--$db.$import_table";
                                fi
                        done
                } &
                sleep $DUMP_WAIT_SECONDS;
        done
        
        # 等待当前库的所有表处理完成
        # wait
        
        echo $db >> /tmp/databases_count.end.log;
        sed -i "/$db/d" /tmp/databases_count.log;
        
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

# 清理临时目录（已改为逐个保存到diff）
eval "$sshRun bash -c \"rm -Rf /tmp/dump-import-ssh-temp\""


echo $(date "+%Y-%m-%d %H:%M:%S")'-------全部结束--------'