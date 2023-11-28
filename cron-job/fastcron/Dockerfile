
# FROM busybox
# FROM curlimages/curl
FROM mikefarah/yq

USER root

RUN apk add --no-cache curl tzdata

RUN ln -snf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && echo Asia/Shanghai > /etc/timezone \
    && chmod 777 /etc/localtime \
    && chmod 777 /etc/timezone

ARG DOCKER_ENTRYPOINT_FILE docker-entrypoint.sh

COPY  $DOCKER_ENTRYPOINT_FILE /docker-entrypoint.sh
# COPY --chown=curl_group:curl_user docker-entrypoint.sh /docker-entrypoint.sh
ENTRYPOINT [ "/docker-entrypoint.sh" ]


COPY --chown=yq:yq default.json /default.json


# 等待多久检测一次
ENV SLEEP_TIME 1222
# 任务名称
ENV NAME aogg
# https://www.fastcron.com/user  的token
ENV ACCESS_TOKEN ''
# 时区
ENV TIMEZONE Asia/Shanghai
# 创建任务的多少秒后发送通知
ENV INC_TIME ''

# 是否启用随机秒数
ENV RANDOM_TIME_BOOL ''



USER yq












