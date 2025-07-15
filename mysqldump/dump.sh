#!/bin/bash

DB_USER=${DB_USER:-${MYSQL_ENV_DB_USER}}
DB_PASS=${DB_PASS:-${MYSQL_ENV_DB_PASS}}
DB_NAME=${DB_NAME:-${MYSQL_ENV_DB_NAME}}
DB_HOST=${DB_HOST:-${MYSQL_ENV_DB_HOST}}
ALL_DATABASES=${ALL_DATABASES}
IGNORE_DATABASE=${IGNORE_DATABASE}
ASYNC_WAIT=${ASYNC_WAIT}

id

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

if [[ ${ALL_DATABASES} == "" ]]; then
        if [[ ${DB_NAME} == "" ]]; then
                echo "Missing DB_NAME env variable"
                exit 1
        fi
        mysqldump --user="${DB_USER}" --password="${DB_PASS}" --host="${DB_HOST}" "$@" "${DB_NAME}" > /mysqldump/"${DB_NAME}".sql
else
        echo "开始导出所有数据库";

        databases=`mysql --user="${DB_USER}" --password="${DB_PASS}" --host="${DB_HOST}" -e "SHOW DATABASES;" | tr -d "| " | grep -v Database`
for db in $databases; do
    if [[ "$db" != "information_schema" ]] && [[ "$db" != "performance_schema" ]] && [[ "$db" != "mysql" ]] && [[ "$db" != _* ]] && [[ "$db" != "$IGNORE_DATABASE" ]]; then
        echo "Dumping database: $db"

        if [[ ${ASYNC_WAIT} == "" ]]; then
                echo "执行 同步 导出  $db，下面是执行命令"
                cat <<EOF
mysqldump --user="${DB_USER}" --password="${DB_PASS}" --host="${DB_HOST}" $@ --databases $db > /mysqldump/$db.sql
EOF

                mysqldump --user="${DB_USER}" --password="${DB_PASS}" --host="${DB_HOST}" $@ --databases $db > /mysqldump/$db.sql
        else
                echo "执行 异步 导出  $db，下面是执行命令"
                cat <<EOF
mysqldump --user="${DB_USER}" --password="${DB_PASS}" --host="${DB_HOST}" $@ --databases $db > /mysqldump/$db.sql &
EOF

                mysqldump --user="${DB_USER}" --password="${DB_PASS}" --host="${DB_HOST}" $@ --databases $db > /mysqldump/$db.sql &
                jobs
        fi
    fi
done
fi


# 结束
if [[ ${ASYNC_WAIT} == "" ]]; then
        echo 'finish all';
else
        echo "开始等待异步导出"
        # mysqldump 进程的关键字
        KEYWORD="mysqldump"

        # 检测 mysqldump 进程是否存在的函数
        check_mysqldump_process() {
                # 使用 pgrep 命令查找与关键字匹配的进程 ID
                pgrep -f "$KEYWORD"  2>&1

                # 检查当前是否有作业
                if [ $(jobs | wc -l) -gt 0 ]; then
                        echo "There are jobs running in the background."
                fi
        }
        echo "下面是 ps -ef"
        ps -ef
        echo "下面是 jobs"
        jobs
        echo "下面是 check_mysqldump_process"
        check_mysqldump_process

        # 循环检测 mysqldump 进程是否存在
        while true; do
                if [[ ! $(check_mysqldump_process) ]];then
                        break
                fi
                echo $(date "+%Y-%m-%d %H:%M:%S")" dump.sh  Waiting for mysqldump process to complete..."${DB_HOST}
                check_mysqldump_process
                sleep 1  # 等待 1 秒后重新检测
        done

        echo $(date "+%Y-%m-%d %H:%M:%S")" dump.sh  mysqldump process has completed.  "${DB_HOST}

fi
