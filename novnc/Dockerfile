
FROM alpine


RUN apk add python3 bash \
    && echo '安装临时包' \
    && apk add --no-cache --virtual .apk-cache git openssl \
    && git clone --depth 1 https://github.com/novnc/noVNC /noVNC \
    && rm -Rf /noVNC/.git \
    && cd /noVNC/utils \
    && git clone --depth 1 https://github.com/novnc/websockify ./websockify \
    && rm -Rf ./websockify/.git \
    && openssl req -new -newkey rsa:4096 -days 36500 -nodes -x509 -subj "/C=CN/ST=Guangdong/L=Guangzhou/O=YourOrganization/CN=www.google.com" -keyout /etc/ssl/novnc.key -out /etc/ssl/novnc.cert \
    && apk del .apk-cache





WORKDIR /noVNC

ENV VNC_ADDRESS ""

EXPOSE 6080

ENTRYPOINT ["/noVNC/utils/novnc_proxy"]

CMD ["--vnc", "$VNC_ADDRESS", "--key", "/etc/ssl/novnc.key", "--cert", "/etc/ssl/novnc.cert", "--ssl-only", "$MORE_ARGS"]