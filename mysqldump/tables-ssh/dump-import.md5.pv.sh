#!/bin/bash

DB_USER=${DB_USER:-${MYSQL_ENV_DB_USER}}
DB_PASS=${DB_PASS:-${MYSQL_ENV_DB_PASS}}
DB_NAME=${DB_NAME:-${MYSQL_ENV_DB_NAME}}
DB_HOST=${DB_HOST:-${MYSQL_ENV_DB_HOST}}
DB_PORT=${DB_PORT:-3306}
DB_TABLE_PORT=${DB_TABLE_PORT:-${DB_PORT}}
IGNORE_DATABASE=${IGNORE_DATABASE}
ASYNC_WAIT=${ASYNC_WAIT}
ASYNC_WAIT_MAX=${ASYNC_WAIT_MAX:-100}
ASYNC_WAIT_DB_MAX=${ASYNC_WAIT_DB_MAX:-10}
DUMP_PV=${DUMP_PV:-6m}
DUMP_WAIT_SECONDS=${DUMP_WAIT_SECONDS:-0.6}

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
                
                if [[ "$continueBool" < 1 ]];then
                        (( i-- ));
                        echo $(date "+%Y-%m-%d %H:%M:%S")"--本地等待库${db}  当前${current_jobs}  waitNum=${waitNum}";
                        sleep 2;
                        continue;
                elif [[ "$continueBool" = "$(( $(cat /tmp/databases_count.run.log | wc -l) + 1 ))" ]];then
                        # 还没出现mysqldump $db
                        if [[ "$continueBoolUse" < 1 ]];then
                                (( i-- ));
                                echo $(date "+%Y-%m-%d %H:%M:%S")"--本地等待库${db}  当前${current_jobs}  waitNum=${waitNum}  等待上一次放过去的导出进入mysqldump";
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
                        echo $(date "+%Y-%m-%d %H:%M:%S")"--本地等待库${db}  当前${current_jobs}  waitNum=${waitNum}  continueBool=0";
                        sleep 2;
                        continue;
                fi
        fi
        echo $db >> /tmp/databases_count.log;


        {
                echo "Dumping database: $db"
                # 空文件的md5=d41d8cd98f00b204e9800998ecf8427e
                command=$(cat << BASH
DB_PASS="${DB_PASS}";
echo '开始运行mysqldump $db';
mkdir -p /tmp/dump-import-ssh-temp/$db/;
lastTable='';
ionice -c3 mysqldump --log-error=/tmp/dump-import-ssh-temp/mysql_error_log_dir/$db.log --no-create-info --skip-comments --user="${DB_USER}" --port="${DB_PORT}" --password="\${DB_PASS}" --host="${DB_HOST}" $DUMP_ARGS $db | pv -L $DUMP_PV |grep -e '^INSERT INTO'  | while read -r line; do 
        table=\$(echo "\$line" | awk -F '\`' '{print \$2}');
        echo -n "\$line" | md5sum | awk -v table="\$table" '{print table, \$1}' >> /tmp/dump-import-ssh-temp/$db/\$table.md5;
        if [[ -z "\$lastTable" ]];then
                lastTable=\$table;
                echo \$lastTable > /tmp/dump-import-ssh-temp/$db.lastTable.log;
        fi;
        if [[ "\$lastTable" != "\$table" ]];then
                if [[ "\$(cat /tmp/dump-import-ssh-temp/$db/\$lastTable.md5 | md5sum)" != "\$(cat /tmp/dump-import-ssh-diff/$db/\$lastTable.md5 | md5sum)" ]];then
                        echo '有差异表名 '\$lastTable;
                fi
                lastTable=\$table;
                echo \$lastTable > /tmp/dump-import-ssh-temp/$db.lastTable.log;
        fi;
done;

lastTable=\$(cat /tmp/dump-import-ssh-temp/$db.lastTable.log);
if [[ -n "\$lastTable" ]];then
        if [[ -f "/tmp/dump-import-ssh-diff/$db/\$lastTable.md5" ]]
                if [[ "\$(cat /tmp/dump-import-ssh-temp/$db/\$lastTable.md5 | md5sum)" != "\$(cat /tmp/dump-import-ssh-diff/$db/\$lastTable.md5 | md5sum)" ]];then
                        echo '有差异表名 '\$lastTable;
                fi;
        else
                echo '有差异表名 '\$lastTable;
        fi
fi

echo '结束运行mysqldump $db';

BASH
                )

                # printf "%s\n" "$command"

# todo 还要管道导出表
# ionice -c3 
                time (
                        # printf "%s\n" "$command" | eval "$sshRun 'exec -a \"导出数据库-$db\" bash -s 2> /dev/null'" | while read -r line; do 
                        # printf "%s\n" "$command" | eval "$sshRun 'ionice -c3 bash -s 2> /dev/null'" | while read -r line; do 
                        printf "%s\n" "$command" | eval "$sshRun 'ionice -c3 bash -c \"exec -a 导出数据库-$db bash -s\" 2> /dev/null'" | while read -r line; do 
                                echo $db.$line;
                                if [[ $line = "开始运行mysqldump $db" ]];then
                                        echo $db >> /tmp/databases_count.run.log;
                                        continue;
                                fi
                                if [[ $line = "结束运行mysqldump $db" ]];then
                                        echo $db >> /tmp/databases_count.end.log;
                                        continue;
                                fi

                                table=$(echo $line | awk '{print $2}')
                                current_jobs=$(pgrep -f "mysqldump" | wc -l)
                                current_jobs=$(( $current_jobs + 1 ))

                                if [[ "$current_jobs" -lt "$ASYNC_WAIT_MAX" ]]; then
                                        {
                                                echo "进程数小于最大等待数，异步导入--$db.$table";
                                                time (mysqldump --user="${DB_USER}" --port="${DB_TABLE_PORT}" --password="${DB_PASS}" --host="${DB_HOST}" $DUMP_ARGS $db "$table"  | pv -L $DUMP_PV | mysql --user="${IMPORT_DB_USER}" --password="${IMPORT_DB_PASS}" --host="${IMPORT_DB_HOST}" $IMPORT_ARGS "$db") 
                                                echo $(date "+%Y-%m-%d %H:%M:%S")"--导入结束  $db.$table";
                                        } &
                                        sleep $DUMP_WAIT_SECONDS;
                                else
                                        echo "进程数大于最大等待数，同步等待导入-$db.$table";
                                        # sleep 20;
                                        time (mysqldump --user="${DB_USER}" --port="${DB_TABLE_PORT}" --password="${DB_PASS}" --host="${DB_HOST}" $DUMP_ARGS $db "$table"  | pv -L $DUMP_PV | mysql --user="${IMPORT_DB_USER}" --password="${IMPORT_DB_PASS}" --host="${IMPORT_DB_HOST}" $IMPORT_ARGS "$db") 
                                        echo $(date "+%Y-%m-%d %H:%M:%S")"--导入结束  $db.$table";
                                fi
                                
                        done;
                 )
                # time (eval "$sshRun 'bash -s'" < $command)


                sed -i "/$db/d" /tmp/databases_count.log;
                # sed -i "/$db/d" /tmp/databases_count.run.log;
                
                
                echo $(date "+%Y-%m-%d %H:%M:%S")"--异步导出库--结束--$db----continueBool=$continueBool--------------------------------------";


                # 
        # }
        } &
        sleep 2;
# exit;
    fi
done


# 检测 mysqldump 进程是否存在的函数
check_mysqldump_process() {
        # 使用 pgrep 命令查找与关键字匹配的进程 ID
        pgrep -f "(ssh -o|mysql|sshpass -p)" >/dev/null 2>&1
}

# 循环检测 mysqldump 进程是否存在
while check_mysqldump_process; do
        echo $(date "+%Y-%m-%d %H:%M:%S")" 最后导入 last  Waiting for mysqldump process to complete...${DB_HOST}  本地mysql数量=$(ps -ef|grep /usr/bin/mysql|wc -l)"
        sleep 1  # 等待 1 秒后重新检测
done

echo $(date "+%Y-%m-%d %H:%M:%S")" 最后导入 last  mysqldump process has completed.  "${DB_HOST}

# 运行成功就存储到diff
eval "$sshRun bash -c \"pwd && rm -Rf /tmp/dump-import-ssh-diff && mv /tmp/dump-import-ssh-temp /tmp/dump-import-ssh-diff\""


echo $(date "+%Y-%m-%d %H:%M:%S")'-------全部结束--------'