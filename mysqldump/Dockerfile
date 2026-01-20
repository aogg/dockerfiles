
# https://github.com/camilb/kube-mysqldump-cron/blob/master/Docker/Dockerfile

# FROM camil/mysqldump
ARG BASE_FROM=mysql:5.7-debian

FROM ${BASE_FROM}

RUN mv /etc/apt/sources.list.d/mysql.list /tmp/mysql.list \
    && (apt update || (echo 'update报错但依然运行' && true)) \
    && apt install -y curl \
    && rm -rf /var/lib/apt/lists/* \
    && mv /tmp/mysql.list /etc/apt/sources.list.d/mysql.list
# RUN apk add --update mysql-client bash && rm -rf /var/cache/apk/*
COPY dump.sh /
COPY import.sh /

# 支持异步并发执行，然后等待所有
ENV ASYNC_WAIT ""
# 操作所有数据库，忽略默认系统数据库
ENV ALL_DATABASES ""
# 手动忽略的数据库
ENV IGNORE_DATABASE ""

ENV DB_HOST ""
ENV DB_NAME ""
ENV DB_PASS ""
ENV DB_USER ""
ENV DB_PORT 3306

ENTRYPOINT ["/dump.sh"]






