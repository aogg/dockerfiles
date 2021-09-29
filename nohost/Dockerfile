# whistle for Dockerfile
FROM alpine:latest

RUN set -ex && \
    apk update && \
    apk add --no-cache bash && \
    apk add --no-cache npm && \
    npm i -g @nohost/server --registry=https://r.npm.taobao.org

ENTRYPOINT ["n2", "run"]
