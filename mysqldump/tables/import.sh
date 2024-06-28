#!/bin/bash

DB_USER=${DB_USER:-${MYSQL_ENV_DB_USER}}
DB_PASS=${DB_PASS:-${MYSQL_ENV_DB_PASS}}
DB_NAME=${DB_NAME:-${MYSQL_ENV_DB_NAME}}
DB_HOST=${DB_HOST:-${MYSQL_ENV_DB_HOST}}
ALL_DATABASES=${ALL_DATABASES}
ASYNC_WAIT=${ASYNC_WAIT}
ASYNC_WAIT_MAX=${ASYNC_WAIT_MAX:100}


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
KEYWORD="mysql"

cd /mysqldump

databases=$(find . -type d -maxdepth 1 -mindepth 1 -exec basename {} \;)

for db in $databases; do
    if [[ "$db" != "information_schema" ]] && [[ "$db" != "performance_schema" ]] && [[ "$db" != "mysql" ]] && [[ "$db" != _* ]]; then
        echo "Importing database: $db"
        for table_file in /mysqldump/$db/*.sql; do
            table=$(basename "$table_file" .sql)
            echo "Importing table: $table from database: $db"
            if [[ ${ASYNC_WAIT} == "" ]]; then
                mysql --user="${DB_USER}" --password="${DB_PASS}" --host="${DB_HOST}" "$@" "$db" < "$table_file"
            else
                while true; do
                    current_jobs=$(pgrep -f "$KEYWORD" | wc -l)
                    if [ "$current_jobs" -lt "$ASYNC_WAIT_MAX" ]; then
                        mysql --user="${DB_USER}" --password="${DB_PASS}" --host="${DB_HOST}" "$@" "$db" < "$table_file" &
                        break
                    else
                        echo $(date "+%Y-%m-%d %H:%M:%S")" import  Waiting for mysql process to complete..."${db}"."${table}
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
                pgrep -f "$KEYWORD" >/dev/null 2>&1
        }

        # 循环检测 mysqldump 进程是否存在
        while check_mysqldump_process; do
                echo $(date "+%Y-%m-%d %H:%M:%S")" import  Waiting for mysql process to complete..."${DB_HOST}
                sleep 1  # 等待 1 秒后重新检测
        done

        echo $(date "+%Y-%m-%d %H:%M:%S")" import  mysql process has completed.  "${DB_HOST}

fi
