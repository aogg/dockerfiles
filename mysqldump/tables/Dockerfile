
# https://github.com/camilb/kube-mysqldump-cron/blob/master/Docker/Dockerfile

# FROM camil/mysqldump

ARG BASE_FROM=mysql:5.7-debian

FROM ${BASE_FROM}

RUN mv /etc/apt/sources.list.d/mysql.list /tmp/mysql.list \
    && if [ "$(cat /etc/os-release | grep VERSION_ID | cut -d'=' -f2 | tr -d '"')" -le 10 ]; then \
        echo "deb http://archive.debian.org/debian buster main contrib non-free" > /etc/apt/sources.list; \
        echo "deb http://archive.debian.org/debian-security buster/updates main contrib non-free" >> /etc/apt/sources.list; \
        echo "deb http://archive.debian.org/debian buster-updates main contrib non-free" >> /etc/apt/sources.list; \
    fi \
    && (apt update || (echo 'update报错但依然运行' && true)) \
    && apt install -y curl procps \
    && rm -rf /var/lib/apt/lists/* \
    && mv /tmp/mysql.list /etc/apt/sources.list.d/mysql.list

COPY dump.sh /
COPY import.sh /
COPY dump-import.sh /

# 支持异步并发执行，然后等待所有
ENV ASYNC_WAIT ""
# 最大进程数
ENV ASYNC_WAIT_MAX "100"

# 手动忽略的数据库
ENV IGNORE_DATABASE ""

# 手动忽略的数据库的表，多个逗号分割
ENV IGNORE_DATABASE_TABLES ""

ENV DB_HOST ""
ENV DB_NAME ""
ENV DB_PASS ""
ENV DB_USER ""

ENTRYPOINT ["/dump.sh"]






