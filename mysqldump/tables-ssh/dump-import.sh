#!/bin/bash

DB_USER=${DB_USER:-${MYSQL_ENV_DB_USER}}
DB_PASS=${DB_PASS:-${MYSQL_ENV_DB_PASS}}
DB_NAME=${DB_NAME:-${MYSQL_ENV_DB_NAME}}
DB_HOST=${DB_HOST:-${MYSQL_ENV_DB_HOST}}
IGNORE_DATABASE=${IGNORE_DATABASE}
ASYNC_WAIT=${ASYNC_WAIT}
ASYNC_WAIT_MAX=${ASYNC_WAIT_MAX:-100}

# DUMP_ARGS=


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
KEYWORD="mysqldump"
IMPORT_KEYWORD="mysql"
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
eval "$sshRun bash -c \"pwd && mkdir -p /tmp/dump-import-ssh-diff && mkdir -p /tmp/dump-import-ssh && mkdir -p /tmp/dump-import-ssh-temp\""


echo '开始循环数据库--下面是执行的命令';
echo eval "$sshRun 'mysql --user=\"${DB_USER}\" --password=\"${DB_PASS}\" --host=\"${DB_HOST}\" -e \"SHOW DATABASES;\"'"

databases=$(eval "$sshRun 'mysql --user=\"${DB_USER}\" --password=\"${DB_PASS}\" --host=\"${DB_HOST}\" -e \"SHOW DATABASES;\"'" | tr -d "| " | grep -v Database)
echo '开始循环数据库---'$databases;

for db in $databases; do
    if [[ "$db" != "information_schema" ]] && [[ "$db" != "performance_schema" ]] && [[ "$db" != "mysql" ]] && [[ "$db" != _* ]] && [[ "$db" != "$IGNORE_DATABASE" ]]; then
        echo "Dumping database: $db"
# break;

        eval "$sshRun 'mkdir -p /tmp/dump-import-ssh/$db && mkdir -p /tmp/dump-import-ssh-diff/$db && mkdir -p /tmp/dump-import-ssh-temp/$db'"


        echo '开始循环库里的所有表--下面是执行的命令'
        echo eval "$sshRun 'mysql --user=\"${DB_USER}\" --password=\"${DB_PASS}\" --host=\"${DB_HOST}\" -e \"SHOW TABLES IN $db;\"'" | tr -d "| " | grep -v Tables_in
        tables=$(eval "$sshRun 'mysql --user=\"${DB_USER}\" --password=\"${DB_PASS}\" --host=\"${DB_HOST}\" -e \"SHOW TABLES IN $db;\"'" | tr -d "| " | grep -v Tables_in)
        echo '开始循环库里的所有表--数量-'$(echo $tables | wc -l)

        for table in $tables; do
                ignore_table=false


                for pair in "${IGNORE_PAIRS[@]}"; do
                        IFS='.' read -ra DB_TABLE <<< "$pair"
                        if [[ "${#DB_TABLE[@]}" -eq 2 ]]; then
                                if [[ "$db" == "${DB_TABLE[0]}" ]] && [[ "$table" == "${DB_TABLE[1]}" ]]; then
                                        ignore_table=true
                                        break
                                fi
                        elif [[ "${#DB_TABLE[@]}" -eq 1 ]]; then
                                if [[ "$table" == "${DB_TABLE[0]}" ]]; then
                                        ignore_table=true
                                        break
                                fi
                        fi

                done

                if $ignore_table;then
                        continue;
                fi

                
        
                if [[ ${ASYNC_WAIT} == "" ]]; then
                        eval "$sshRun 'mysqldump --skip-comments --user=\"${DB_USER}\" --password=\"${DB_PASS}\" --host=\"${DB_HOST}\" $DUMP_ARGS $db \"$table\" > /tmp/dump-import-ssh-temp/$db'"
                else
                        while true; do
                                current_jobs=$(pgrep -f "$KEYWORD" | wc -l)
                                if [[ "$current_jobs" -lt "$ASYNC_WAIT_MAX" ]]; then
                                        echo $(date "+%Y-%m-%d %H:%M:%S")" dump-import.sh  ..."${db}"."${table}
                                        # mysqldump --user="${DB_USER}" --password="${DB_PASS}" --host="${DB_HOST}" $DUMP_ARGS $db "$table"  | mysql --user="${IMPORT_DB_USER}" --password="${IMPORT_DB_PASS}" --host="${IMPORT_DB_HOST}" $IMPORT_ARGS "$db" &
                                        eval "$sshRun 'mysqldump --skip-comments --user=\"${DB_USER}\" --password=\"${DB_PASS}\" --host=\"${DB_HOST}\" $DUMP_ARGS $db \"$table\" > /tmp/dump-import-ssh-temp/$db/${table}.sql'" &
                                        break
                                else
                                        echo $(date "+%Y-%m-%d %H:%M:%S")" dump-import.sh  Waiting for mysqldump process to complete..."${db}
                                        sleep 1
                                fi
                        done
                fi
        done


        echo '循环结束--'$db;
    fi
done

# 导出结束
if [[ ${ASYNC_WAIT} == "" ]]; then
        echo 'finish all';
else


        # 检测 mysqldump 进程是否存在的函数
        check_mysqldump_process() {
                # 使用 pgrep 命令查找与关键字匹配的进程 ID
                pgrep -f "$KEYWORD" >/dev/null 2>&1
        }

        # 循环检测 mysqldump 进程是否存在
        while check_mysqldump_process; do
                echo $(date "+%Y-%m-%d %H:%M:%S")" 导出 last  Waiting for mysqldump process to complete..."${DB_HOST}
                sleep 1  # 等待 1 秒后重新检测
        done

        echo $(date "+%Y-%m-%d %H:%M:%S")" 导出 last  mysqldump process has completed.  "${DB_HOST}

fi


# 开始导入

# 迁移到diff
eval "$sshRun bash -c \"pwd && rm -Rf /tmp/dump-import-ssh-diff && mkdir -p /tmp/dump-import-ssh && mv /tmp/dump-import-ssh /tmp/dump-import-ssh-diff && mkdir -p /tmp/dump-import-ssh-temp && mv /tmp/dump-import-ssh-temp /tmp/dump-import-ssh\""


# diff赋值
for db in $databases; do
        if [[ "$db" != "information_schema" ]] && [[ "$db" != "performance_schema" ]] && [[ "$db" != "mysql" ]] && [[ "$db" != _* ]] && [[ "$db" != "$IGNORE_DATABASE" ]]; then
                echo "对比$db--赋值变量"
                content=$(eval "$sshRun diff -rq /tmp/dump-import-ssh/$db /tmp/dump-import-ssh-diff/$db")

                echo -e "$content"
                
                # 定义动态变量 content_$db
                eval "content_$db='$content'"
        fi
done


# 对比文件夹
echo '有差异的文件'
for db in $databases; do
        if [[ "$db" != "information_schema" ]] && [[ "$db" != "performance_schema" ]] && [[ "$db" != "mysql" ]] && [[ "$db" != _* ]] && [[ "$db" != "$IGNORE_DATABASE" ]]; then
                echo "对比$db"
                eval "content=\$content_$db"
                content=$(echo -e "$content" | grep -e "^Files")
                echo -e "$content"

                if [ -z "$content" ]; then
                        echo "空$db"
                        continue;
                fi

                echo -e "$content" | awk '{print $2}' | while read -r full_file; do 
                        echo "导入有差异文件--$db.$full_file";

                        if [[ ${ASYNC_WAIT} == "" ]]; then
                                eval "$sshRun 'cat \"$full_file\"'" | mysql --user="${IMPORT_DB_USER}" --password="${IMPORT_DB_PASS}" --host="${IMPORT_DB_HOST}" $IMPORT_ARGS "$db";
                        else
                                while true; do
                                        current_jobs=$(pgrep -f "$IMPORT_KEYWORD" | wc -l)
                                        if [[ "$current_jobs" -lt "$ASYNC_WAIT_MAX" ]]; then
                                                echo $(date "+%Y-%m-%d %H:%M:%S")" 导入  ..."${db}"."${full_file}
                                                
                                                {
                                                        eval "$sshRun 'cat \"$full_file\"'" | mysql --user="${IMPORT_DB_USER}" --password="${IMPORT_DB_PASS}" --host="${IMPORT_DB_HOST}" $IMPORT_ARGS "$db";
                                                } &
                                                break
                                        else
                                                echo $(date "+%Y-%m-%d %H:%M:%S")" 导入  Waiting for mysqldump process to complete..."${db}
                                                sleep 1
                                        fi
                                done
                        fi
                

                done
        fi
done


# 新增
echo '有新增的文件'
for db in $databases; do
        if [[ "$db" != "information_schema" ]] && [[ "$db" != "performance_schema" ]] && [[ "$db" != "mysql" ]] && [[ "$db" != _* ]] && [[ "$db" != "$IGNORE_DATABASE" ]]; then
                echo "对比$db"
                eval "content=\$content_$db"


                content=$(echo -e "$content" | grep -e "^Only in /tmp/dump-import-ssh/$db:")
                echo -e "$content"

                if [ -z "$content" ]; then
                        echo "空$db"
                        continue;
                fi

                echo -e "$content" | awk -F' ' '{print $4}' | while read -r file; do 
                        echo "导入新增--$db.$file";



                        if [[ ${ASYNC_WAIT} == "" ]]; then
                                eval "$sshRun 'cat \"/tmp/dump-import-ssh/$db/$file\"'" | mysql --user="${IMPORT_DB_USER}" --password="${IMPORT_DB_PASS}" --host="${IMPORT_DB_HOST}" $IMPORT_ARGS "$db";
                        else
                                while true; do
                                        current_jobs=$(pgrep -f "$IMPORT_KEYWORD" | wc -l)
                                        if [[ "$current_jobs" -lt "$ASYNC_WAIT_MAX" ]]; then
                                                echo $(date "+%Y-%m-%d %H:%M:%S")" 导入  ..."${db}"."${file}
                                                
                                                {
                                                        eval "$sshRun 'cat \"/tmp/dump-import-ssh/$db/$file\"'" | mysql --user="${IMPORT_DB_USER}" --password="${IMPORT_DB_PASS}" --host="${IMPORT_DB_HOST}" $IMPORT_ARGS "$db";
                                                } &
                                                break
                                        else
                                                echo $(date "+%Y-%m-%d %H:%M:%S")" 导入  Waiting for mysqldump process to complete..."${db}
                                                sleep 1
                                        fi
                                done
                        fi


                done
        fi
done


# 结束
if [[ ${ASYNC_WAIT} == "" ]]; then
        echo 'finish all';
else


        # 检测 mysqldump 进程是否存在的函数
        check_mysqldump_process() {
                # 使用 pgrep 命令查找与关键字匹配的进程 ID
                pgrep -f "$IMPORT_KEYWORD" >/dev/null 2>&1
        }

        # 循环检测 mysqldump 进程是否存在
        while check_mysqldump_process; do
                echo $(date "+%Y-%m-%d %H:%M:%S")" 最后导入 last  Waiting for mysqldump process to complete..."${DB_HOST}
                sleep 1  # 等待 1 秒后重新检测
        done

        echo $(date "+%Y-%m-%d %H:%M:%S")" 最后导入 last  mysqldump process has completed.  "${DB_HOST}

fi



echo $(date "+%Y-%m-%d %H:%M:%S")'-------全部结束--------'