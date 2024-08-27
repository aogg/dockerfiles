
FROM adockero/uiauto-dev


ENV ANDROID_DEVICES ""
ENV ADB_SLEEP_SEC 5


COPY ./common/adb-auto.sh /adb-auto.sh
COPY ./uiauto-dev/adb/docker-entrypoint.sh /docker-entrypoint.sh

ENTRYPOINT [ "/docker-entrypoint.sh" ]