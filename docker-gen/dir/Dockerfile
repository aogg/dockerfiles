FROM alpine


RUN apk add --no-cache docker-cli

# 文件夹
ENV GEN_DIR=/gen/
# docker命令
ENV GEN_DOCKER_COMMAND=

VOLUME [ "/gen" ]

ADD ./docker-entrypoint.sh /

ENTRYPOINT ["/docker-entrypoint.sh"]