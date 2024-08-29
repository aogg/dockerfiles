

FROM python:3.6


# ARG PIP_ARGS


# ENV ANDROID_DEVICES ""
# ENV REMOTE_ADB true
# ENV REMOTE_ADB_POLLING_SEC 5


# COPY wireless_autoconnect.sh /wireless_autoconnect.sh
# COPY wireless_connect.sh /wireless_connect.sh


RUN apt update \
    && apt install -y adb libgl1-mesa-glx \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && apt-get clean \
    && rm -Rf /var/log/* \
    && echo "apt结束"

RUN pip install --no-cache-dir airtest \
    && pip install --no-cache-dir pocoui \
    && rm -Rf /var/log/* \
    && echo "pip结束" \


# 保存授权
VOLUME [ "/root/.android/" ]

COPY docker-entrypoint.sh /docker-entrypoint.sh

ENTRYPOINT [ "/docker-entrypoint.sh" ]




