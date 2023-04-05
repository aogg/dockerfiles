FROM node:lts-alpine

ARG VERSION=latest

ENV WHISTLE_VERSION=${VERSION}}

RUN apk add --no-cache procps \
    && if [ $VERSION = "latest" ];then npm install -g whistle; fi \
    && if [ $VERSION != "latest" ];then npm install -g whistle @${VERSION};fi \
    && whistle status

COPY docker-entrypoint.sh /usr/local/bin/

# 父级有
# ENTRYPOINT ["docker-entrypoint.sh"]

CMD []
