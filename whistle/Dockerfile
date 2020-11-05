FROM node:lts-alpine

ARG VERSION=latest

ENV WHISTLE_VERSION=${VERSION}}

RUN apk add --no-cache procps \
    && if [ $VERSION = "latest" ];then npm install -g whistle; fi \
    && if [ $VERSION != "latest" ];then npm install -g whistle @${VERSION};fi

COPY docker-entrypoint.sh /usr/local/bin/

CMD []
