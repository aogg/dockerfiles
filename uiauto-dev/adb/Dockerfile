
FROM adockero/uiauto-dev


ENV ANDROID_DEVICES ""
ENV ADB_SLEEP_SEC 5


RUN apk add --no-cache android-tools \
    && echo "结束"

# --no-install-recommends
# RUN apt update \
#     && apt install --no-install-recommends -y adb \
#     && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/log/* \
#     && apt-get clean \
#     && echo "结束"

COPY ./common/adb-auto.sh /adb-auto.sh
COPY ./uiauto-dev/adb/docker-entrypoint.sh /docker-entrypoint.sh

ENTRYPOINT [ "/docker-entrypoint.sh" ]