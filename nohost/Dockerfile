# whistle for Dockerfile
FROM alpine:latest

RUN set -ex && \
    apk add --no-cache bash && \
    apk add --no-cache npm && \
    npm i -g @nohost/server

ENTRYPOINT ["n2", "run"]
