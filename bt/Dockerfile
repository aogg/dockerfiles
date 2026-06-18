FROM ubuntu:24.10


RUN apt update \
    && apt install -y wget \
    && echo "apt结束" \
    &&wget -O install_panel.sh https://download.bt.cn/install/install_panel.sh \
    && sudo bash install_panel.sh ed8484bec \
    && (bt stop || echo 1) \
    && mkdir -p /www \
    && mv /www /www-bak \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && apt-get clean \
    && rm -Rf /var/log/* \
    && echo "结束"


COPY docker-entrypoint.sh /docker-entrypoint.sh

ENTRYPOINT [ "/docker-entrypoint.sh" ]