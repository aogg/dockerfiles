#!/bin/bash

DB_USER=${DB_USER:-${MYSQL_ENV_DB_USER}}
DB_PASS=${DB_PASS:-${MYSQL_ENV_DB_PASS}}
DB_NAME=${DB_NAME:-${MYSQL_ENV_DB_NAME}}
DB_HOST=${DB_HOST:-${MYSQL_ENV_DB_HOST}}
IGNORE_DATABASE=${IGNORE_DATABASE}
ASYNC_WAIT=${ASYNC_WAIT}
ASYNC_WAIT_MAX=${ASYNC_WAIT_MAX:-100}


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
IFS=',' read -ra IGNORE_PAIRS <<< "$IGNORE_DATABASE_TABLES"


databases=$(mysql --user="${DB_USER}" --password="${DB_PASS}" --host="${DB_HOST}" -e "SHOW DATABASES;" | tr -d "| " | grep -v Database)
for db in $databases; do
    if [[ "$db" != "information_schema" ]] && [[ "$db" != "performance_schema" ]] && [[ "$db" != "mysql" ]] && [[ "$db" != _* ]] && [[ "$db" != "$IGNORE_DATABASE" ]]; then
        echo "Dumping database: $db"
        mkdir -p /mysqldump/$db
        tables=$(mysql --user="${DB_USER}" --password="${DB_PASS}" --host="${DB_HOST}" -e "SHOW TABLES IN $db;" | tr -d "| " | grep -v Tables_in)
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
                        mysqldump --user="${DB_USER}" --password="${DB_PASS}" --host="${DB_HOST}" "$@" $db "$table" > "/mysqldump/$db/$table.sql"
                else
                        while true; do
                        current_jobs=$(pgrep -f "$KEYWORD" | wc -l)
                        if [ "$current_jobs" -lt "$ASYNC_WAIT_MAX" ]; then
                                mysqldump --user="${DB_USER}" --password="${DB_PASS}" --host="${DB_HOST}" "$@" $db "$table" > "/mysqldump/$db/$table.sql" &
                                break
                        else
                                echo $(date "+%Y-%m-%d %H:%M:%S")" dump.sh  Waiting for mysqldump process to complete..."${db}
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
                echo $(date "+%Y-%m-%d %H:%M:%S")" dump.sh last  Waiting for mysqldump process to complete..."${DB_HOST}
                sleep 1  # 等待 1 秒后重新检测
        done

        echo $(date "+%Y-%m-%d %H:%M:%S")" dump.sh last  mysqldump process has completed.  "${DB_HOST}

fi
