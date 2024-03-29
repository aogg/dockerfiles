
# https://github.com/camilb/kube-mysqldump-cron/blob/master/Docker/Dockerfile

# FROM camil/mysqldump

FROM alpine:3.4
RUN apk add --update mysql-client bash openssh-client && rm -rf /var/cache/apk/*
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

ENTRYPOINT ["/dump.sh"]






