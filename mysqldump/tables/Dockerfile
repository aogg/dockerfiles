
# https://github.com/camilb/kube-mysqldump-cron/blob/master/Docker/Dockerfile

# FROM camil/mysqldump

FROM alpine:3.4
RUN apk add --update mysql-client bash openssh-client && rm -rf /var/cache/apk/*
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






