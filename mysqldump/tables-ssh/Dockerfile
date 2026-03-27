
# https://github.com/camilb/kube-mysqldump-cron/blob/master/Docker/Dockerfile

# FROM camil/mysqldump

FROM alpine

ARG APK_ARG=
# MYSQL_CLIENT: mariadb (默认) 或 mysql (原版MySQL客户端)
ARG MYSQL_CLIENT=mariadb

RUN if [ "$MYSQL_CLIENT" = "mysql" ]; then \
        apk add --no-cache --repository=http://dl-cdn.alpinelinux.org/alpine/edge/community \
            mysql-community-client bash openssh-client sshpass ${APK_ARG}; \
    else \
        apk add --update mysql-client bash openssh-client sshpass ${APK_ARG}; \
    fi && rm -rf /var/cache/apk/*

ARG FILE_ARG=dump-import.sh
ENV ENTRYPOINT_RUN /$FILE_ARG

COPY $FILE_ARG /

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

# ssh
ENV STRICT_HOST_KEY_CHECKING "no"
ENV SSH_ARGS ""
ENV SSH_PASSWORD ""
ENV SSH_USER ""
ENV SSH_IP ""

ENTRYPOINT $ENTRYPOINT_RUN






