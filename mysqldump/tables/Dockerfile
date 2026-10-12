
# https://github.com/camilb/kube-mysqldump-cron/blob/master/Docker/Dockerfile

# FROM camil/mysqldump

ARG BASE_FROM=mysql:5.7-debian

FROM ${BASE_FROM}

RUN mv /etc/apt/sources.list.d/mysql.list /tmp/mysql.list \
    && VERSION_ID=$(grep VERSION_ID /etc/os-release | cut -d'=' -f2 | tr -d '"') \
    && CODENAME=$(grep VERSION_CODENAME /etc/os-release | cut -d'=' -f2 | tr -d '"') \
    && if [ "$VERSION_ID" -le 11 ]; then \
        echo "deb http://archive.debian.org/debian ${CODENAME} main contrib non-free" > /etc/apt/sources.list; \
        echo "deb http://archive.debian.org/debian-security ${CODENAME}/updates main contrib non-free" >> /etc/apt/sources.list; \
        # buster才有buster-updates；bullseye没有bullseye-updates归档源，只给<=10增加
        if [ "$VERSION_ID" -le 10 ]; then \
            echo "deb http://archive.debian.org/debian ${CODENAME}-updates main contrib non-free" >> /etc/apt/sources.list; \
        fi; \
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






