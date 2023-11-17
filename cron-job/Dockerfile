
# FROM busybox
# FROM curlimages/curl
FROM mikefarah/yq

USER root

RUN apk add --no-cache curl


COPY  docker-entrypoint.sh /docker-entrypoint.sh
# COPY --chown=curl_group:curl_user docker-entrypoint.sh /docker-entrypoint.sh
ENTRYPOINT [ "/docker-entrypoint.sh" ]


COPY --chown=yq:yq default.json /default.json


ENV SLEEP_TIME 1222
ENV NAME aogg



USER yq












