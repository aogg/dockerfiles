

FROM python:3


# ARG PIP_ARGS


ENV ANDROID_DEVICES ""
ENV REMOTE_ADB true
ENV REMOTE_ADB_POLLING_SEC 5


COPY wireless_autoconnect.sh /wireless_autoconnect.sh
COPY wireless_connect.sh /wireless_connect.sh


RUN pip install --no-cache-dir pocoui \
    && pip install --no-cache-dir airtest \
    && echo "结束"


RUN apt update \
    && apt install -y adb libgl1-mesa-glx \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && apt-get clean \
    && echo "结束"


# 保存授权
VOLUME [ "/root/.android/" ]

COPY docker-entrypoint.sh /docker-entrypoint.sh

ENTRYPOINT [ "/docker-entrypoint.sh" ]




