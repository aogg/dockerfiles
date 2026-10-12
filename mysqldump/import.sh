#!/bin/bash

DB_USER=${DB_USER:-${MYSQL_ENV_DB_USER}}
DB_PASS=${DB_PASS:-${MYSQL_ENV_DB_PASS}}
DB_NAME=${DB_NAME:-${MYSQL_ENV_DB_NAME}}
DB_HOST=${DB_HOST:-${MYSQL_ENV_DB_HOST}}
ALL_DATABASES=${ALL_DATABASES}
ASYNC_WAIT=${ASYNC_WAIT}


# 库别名：ENV_DB_ALIAS_源库名=目标库名，把 /mysqldump/源库名.sql 导入到目标库
# 库名可能含 - 等字符，不是合法的 bash 变量名，所以用 printenv 按名字取环境变量
# 未设置别名时返回源库名
get_db_target() {
        local db="$1"
        local target
        target=$(printenv "ENV_DB_ALIAS_${db}")
        if [[ ${target} == "" ]]; then
                printf '%s' "${db}"
        else
                printf '%s' "${target}"
        fi
}

# 转义 sed 模式里的特殊字符，库名可能含 . 等字符
sed_pattern_escape() {
        printf '%s' "$1" | sed -e 's/[][\/.^$*]/\\&/g'
}

# 转义 sed 替换串里的特殊字符
sed_replacement_escape() {
        printf '%s' "$1" | sed -e 's/[\/&]/\\&/g'
}

# 把 dump 流里 USE、CREATE DATABASE 语句中的源库名替换成目标库名
# dump.sh 在 ALL_DATABASES 模式用 --databases 导出，文件里带 USE `源库`; 和 CREATE DATABASE `源库`;，
# 只改 mysql 命令行上的库名会被文件里的 USE 语句切回源库，所以要在流里替换；
# 只替换这两类语句里的库名，不做全文替换，避免误伤表数据
filter_dump_db_name() {
        local src_esc
        local tgt_esc
        src_esc=$(sed_pattern_escape "$1")
        tgt_esc=$(sed_replacement_escape "$2")
        sed -e "/^[[:space:]]*USE[[:space:]]/s/\`${src_esc}\`/\`${tgt_esc}\`/g" \
                -e "/^[[:space:]]*CREATE[[:space:]]\{1,\}DATABASE[[:space:]]/s/\`${src_esc}\`/\`${tgt_esc}\`/g"
}

# 导入一个库：参数1=源库名（dump 文件 /mysqldump/源库名.sql），参数2=目标库名，其余参数原样传给 mysql
import_database() {
        local src_db="$1"
        local target_db="$2"
        shift 2

        if [[ ${src_db} != ${target_db} ]]; then
                # 目标库设置了别名且可能不存在，先建库，否则没有 CREATE DATABASE 语句的 dump 会报 Unknown database
                mysql --user="${DB_USER}" --password="${DB_PASS}" --host="${DB_HOST}" "$@" \
                        -e "CREATE DATABASE IF NOT EXISTS \`${target_db}\`"
        fi

        if [[ ${src_db} == ${target_db} ]]; then
                # 无别名：保持原有行为，不过滤 dump 内容
                mysql --user="${DB_USER}" --password="${DB_PASS}" --host="${DB_HOST}" "$@" "${target_db}" < /mysqldump/"${src_db}".sql
        else
                # 有别名：过滤流里的 USE / CREATE DATABASE 语句后导入到目标库
                filter_dump_db_name "${src_db}" "${target_db}" < /mysqldump/"${src_db}".sql | mysql --user="${DB_USER}" --password="${DB_PASS}" --host="${DB_HOST}" "$@" "${target_db}"
        fi
}


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
        # 单库模式：dump 文件名仍用原库名，目标库用别名
        target_db=$(get_db_target "${DB_NAME}")
        if [[ ${target_db} != ${DB_NAME} ]]; then
                echo "Importing database: ${DB_NAME} -> ${target_db} (alias)"
        fi
        import_database "${DB_NAME}" "${target_db}" "$@"
else
        cd /mysqldump
        databases=`for f in *.sql; do
        printf '%s\n' "${f%.sql}"
        done`
for db in $databases; do
          if [[ "$db" != "information_schema.sql" ]] && [[ "$db" != "performance_schema.sql" ]] && [[ "$db" != "mysql.sql" ]] && [[ "$db" != _* ]]; then
                target_db=$(get_db_target "$db")
                if [[ ${target_db} == ${db} ]]; then
                        echo "Importing database: $db"
                else
                        echo "Importing database: $db -> ${target_db} (alias)"
                fi

                if [[ ${ASYNC_WAIT} == "" ]]; then
                import_database "$db" "${target_db}" "$@"
                else
                import_database "$db" "${target_db}" "$@" &
                fi

          fi
done
fi



# 结束
if [[ ${ASYNC_WAIT} == "" ]]; then
        echo 'finish all';
else

        # mysqldump 进程的关键字
        KEYWORD="mysqldump"

        # 检测 mysqldump 进程是否存在的函数
        check_mysqldump_process() {
                # 使用 pgrep 命令查找与关键字匹配的进程 ID
                pgrep -f "$KEYWORD" >/dev/null 2>&1
        }

        # 循环检测 mysqldump 进程是否存在
        while check_mysqldump_process; do
                echo $(date "+%Y-%m-%d %H:%M:%S")" import  Waiting for mysqldump process to complete..."${DB_HOST}
                sleep 1  # 等待 1 秒后重新检测
        done

        echo $(date "+%Y-%m-%d %H:%M:%S")" import  mysqldump process has completed.  "${DB_HOST}

fi
