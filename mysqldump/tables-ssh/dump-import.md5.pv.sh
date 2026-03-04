#!/bin/bash

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
ASYNC_WAIT=${ASYNC_WAIT}
ASYNC_WAIT_MAX=${ASYNC_WAIT_MAX:-100}
ASYNC_WAIT_DB_MAX=${ASYNC_WAIT_DB_MAX:-10}
DUMP_PV=${DUMP_PV:-6m}
DUMP_WAIT_SECONDS=${DUMP_WAIT_SECONDS:-0.6}

# MySQL数据目录，用于加速判断表文件是否修改
MYSQL_DATA_DIR=${MYSQL_DATA_DIR:-}

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
sshRun=$(echo sshpass -p \'"$SSH_PASSWORD"\' ssh -o "StrictHostKeyChecking=$STRICT_HOST_KEY_CHECKING" $SSH_ARGS $SSH_USER@$SSH_IP)
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
eval "$sshRun bash -c \"pwd && mkdir -p /tmp/dump-import-ssh-diff && rm -Rf /tmp/dump-import-ssh-temp && mkdir -p /tmp/dump-import-ssh-temp/mysql_error_log_dir\""







# 使用SSH执行远程命令来获取CPU空闲率
cpuScript=$(cat <<EOF

while true; do 
echo \$(mpstat 1 1 |grep "Average:" | awk '{print "远端-CPU空闲率 "\$NF}'); 

echo '远端-导出文件数量 '\$(ls -al /tmp/dump-import-ssh-temp/*/*.md5|wc -l);

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
        echo $cpuScript | (exec -a "监听CPU空闲率" sshpass -p "$SSH_PASSWORD" ssh $SSH_ARGS -v -o "StrictHostKeyChecking=$STRICT_HOST_KEY_CHECKING" $SSH_USER@$SSH_IP 'bash -s') | while IFS= read -r line; do
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
waitNum=0;
continueBool=0
continueBoolUse=0;

for ((i = 0; i < num_databases; i++)); do
    db=${databases_arr[$i]}
    # 执行循环体的代码
#     echo "Processing database $((i + 1)): $db"
# done
# for db in $databases; do
    if [[ "$db" != "information_schema" ]] && [[ "$db" != "performance_schema" ]] && [[ "$db" != "mysql" ]] && [[ "$db" != _* ]] && [[ "$db" != "$IGNORE_DATABASE" ]]; then
# break;

        # 运行完库的没运行完表的
        if [[ "$(cat /tmp/databases_count.log | grep -v -e '^$' | wc -l)" -ge "$ASYNC_WAIT_DB_MAX" ]]; then

                if [[ "$waitNum" -gt "3" ]] && [[ "$(cat /tmp/remote_mysqldump_num)" -lt "$ASYNC_WAIT_DB_MAX" ]]; then
                        if [[ "$waitNum" -lt "3" ]];then
                                (( waitNum++ ));
                        else
                                echo $(date "+%Y-%m-%d %H:%M:%S")"--远端mysqldump已结束，开始  导出${db}   waitNum=${waitNum}------------------------";
                                # 累计多次
                                # sed -i "/$db/d" /tmp/databases_count.log;
                                continueBool=$(( $(cat /tmp/databases_count.run.log | wc -l) + 1 ))
                                continueBoolUse=1;
                        fi
                        waitNum=0;
                elif [[ "$(cat /tmp/remote_mysqldump_num)" -lt "$ASYNC_WAIT_DB_MAX" ]];then
                        (( waitNum++ ));
                else
                        waitNum=0;     
                fi
                
                if [[ "$continueBool" -lt 1 ]];then
                        (( i-- ));
                        echo "$(date "+%Y-%m-%d %H:%M:%S")--本地等待库${db}  当前${current_jobs}  waitNum=${waitNum}";
                        sleep 2;
                        continue;
                elif [[ "$continueBool" = "$(( $(cat /tmp/databases_count.run.log | wc -l) + 1 ))" ]];then
                        # 还没出现mysqldump $db
                        if [[ "$continueBoolUse" -lt 1 ]];then
                                (( i-- ));
                                echo "$(date "+%Y-%m-%d %H:%M:%S")--本地等待库${db}  当前${current_jobs}  waitNum=${waitNum}  等待上一次放过去的导出进入mysqldump";
                                sleep 2;
                                continue;
                        else
                                # 首次放行
                                continueBoolUse=0;
                        fi
                else        
                        # 已生成mysqldump，归0
                        continueBool=0;
                        (( i-- ));
                        echo "$(date "+%Y-%m-%d %H:%M:%S")--本地等待库${db}  当前${current_jobs}  waitNum=${waitNum}  continueBool=0";
                        sleep 2;
                        continue;
                fi
        fi
        echo $db >> /tmp/databases_count.log;

        # 先通过SSH获取表列表
        echo "获取数据库 $db 的表列表..."
        tables=$(echo "DB_PASS=\"${DB_PASS}\";mysql --user=\"${DB_USER}\" --port=\"${DB_PORT}\" --password=\"\${DB_PASS}\" --host=\"${DB_HOST}\" -N -e \"SHOW TABLES;\" $db 2>/dev/null" | eval "$sshRun 'bash -s'" | tr -d "| " | grep -v -e '^$')
        echo "获取到表列表: $tables"
        
        # 转为数组并过滤忽略的表
        tables_arr=();
        echo "忽略表的列表: $IGNORE_TABLES"
        IFS=',' read -ra IGNORE_TABLES_ARR <<< "$IGNORE_TABLES"
        for table in $tables; do
                # 检查是否在忽略列表中
                skip_table=0
                for ignore_table in "${IGNORE_TABLES_ARR[@]}"; do
                        if [[ "$table" == "$ignore_table" ]]; then
                                skip_table=1
                                echo "忽略表: $db.$table"
                                break
                        fi
                done
                if [[ $skip_table -eq 0 ]]; then
                        tables_arr+=($table)
                fi
        done
        num_tables=${#tables_arr[@]}
        echo "数据库 $db 表数量: $num_tables"
        
        echo $db >> /tmp/databases_count.run.log;
        
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
                
                {
                        # 单个表的SSH判断脚本：同时检查修改时间和MD5
                        table_command=$(cat << BASH
DB_PASS="${DB_PASS}";
MYSQL_DATA_DIR="${MYSQL_DATA_DIR}";
table="${table}";
mkdir -p /tmp/dump-import-ssh-temp/$db/;
mkdir -p /tmp/dump-import-ssh-temp/mtime/$db/;

mtime_changed=0;

# 检查表文件修改时间是否改变（如果MYSQL_DATA_DIR存在）
if [[ -n "\$MYSQL_DATA_DIR" && -d "\$MYSQL_DATA_DIR" ]]; then
        db_dir="\${MYSQL_DATA_DIR}/$db";
        if [[ -d "\$db_dir" ]]; then
                mtime_file="";
                if [[ -f "\${db_dir}/\${table}.ibd" ]]; then
                        mtime_file="\${db_dir}/\${table}.ibd";
                elif [[ -f "\${db_dir}/\${table}.MYD" ]]; then
                        mtime_file="\${db_dir}/\${table}.MYD";
                fi
                
                if [[ -n "\$mtime_file" ]]; then
                        current_mtime=\$(stat -c %Y "\$mtime_file" 2>/dev/null || stat -f %m "\$mtime_file" 2>/dev/null);
                        stored_mtime=\$(cat /tmp/dump-import-ssh-diff/mtime/$db/\${table}.mtime 2>/dev/null || echo 0);
                        echo "\$current_mtime" > /tmp/dump-import-ssh-temp/mtime/$db/\${table}.mtime;
                        
                        if [[ "\$current_mtime" != "\$stored_mtime" ]]; then
                                mtime_changed=1;
                        fi
                fi
        fi
fi

# 导出表并计算MD5
$RUN_LIMIT_START_MYSQLDUMP mysqldump --no-tablespaces --log-error=/tmp/dump-import-ssh-temp/mysql_error_log_dir/$db-\${table}.log --no-create-info --skip-comments --user="${DB_USER}" --port="${DB_PORT}" --password="\${DB_PASS}" --host="${DB_HOST}" $DUMP_ARGS $db \$table 2>/dev/null | grep -e '^INSERT INTO' | md5sum | awk -v table="\$table" '{print table, \$1}' > /tmp/dump-import-ssh-temp/$db/\$table.md5;

# 判断是否有差异
temp_md5=\$(cat /tmp/dump-import-ssh-temp/$db/\$table.md5);

if [[ -f "/tmp/dump-import-ssh-diff/$db/\$table.md5" ]]; then
        diff_md5=\$(cat /tmp/dump-import-ssh-diff/$db/\$table.md5);
        if [[ "\$temp_md5" != "\$diff_md5" ]]; then
                echo "diff-sync 有差异表名 \$table";
        elif [[ "\$mtime_changed" == "1" ]]; then
                echo "diff-sync 文件修改时间改变 \$table";
        fi
else
        echo "diff-sync 新表 \$table";
fi

BASH
                        )
                        
                        # 执行SSH并处理输出
                        printf "%s\n" "$table_command" | eval "$sshRun '$RUN_LIMIT_START bash -c \"exec -a 导出表-$db.$table bash -s\" 2> /dev/null'" | while read -r line; do
                                echo "差异判断输出: " . $db.$line;
                                
                                # 只处理有差异的表
                                if [[ $line == "diff-sync "* ]]; then
                                
                                        # 导入成功后立即保存到diff目录
                                        {
                                                eval "$sshRun bash -c \"mkdir -p /tmp/dump-import-ssh-diff/$db /tmp/dump-import-ssh-diff/mtime/$db && cp /tmp/dump-import-ssh-temp/$db/$import_table.md5 /tmp/dump-import-ssh-diff/$db/ 2>/dev/null; cp /tmp/dump-import-ssh-temp/mtime/$db/$import_table.mtime /tmp/dump-import-ssh-diff/mtime/$db/ 2>/dev/null\""
                                                echo "已保存到diff: $db.$import_table";
                                        } &

                                        import_table=$(echo $line | awk '{print $3}')
                                        
                                        echo "进程数小于最大等待数，异步导入--$db.$import_table";
                                        for ((retry=1; retry<=3; retry++)); do
                                                error_output=$(time (mysqldump --skip-ssl --no-tablespaces --user="${DB_USER}" --port="${DB_TABLE_PORT}" --password="${DB_PASS}" --host="${DB_TABLE_HOST}" $DUMP_ARGS $db "$import_table"  | pv -L $DUMP_PV | mysql --skip-ssl --user="${IMPORT_DB_USER}" --password="${IMPORT_DB_PASS}" --host="${IMPORT_DB_HOST}" $IMPORT_ARGS "$db") 2>&1) && break

                                                echo "导入失败(第${retry}次): $db.$import_table"
                                                echo "执行命令: mysqldump --skip-ssl --no-tablespaces --user=\"${DB_USER}\" --port=\"${DB_TABLE_PORT}\" --password=\"***\" --host=\"${DB_TABLE_HOST}\" $DUMP_ARGS $db \"$import_table\" | pv -L $DUMP_PV | mysql --skip-ssl --user=\"${IMPORT_DB_USER}\" --password=\"***\" --host=\"${IMPORT_DB_HOST}\" $IMPORT_ARGS \"$db\""
                                                echo "错误信息: $error_output"
                                        done
                                        echo $(date "+%Y-%m-%d %H:%M:%S")"--导入结束  $db.$import_table";
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