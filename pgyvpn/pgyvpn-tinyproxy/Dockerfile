
FROM bestoray/pgyvpn


COPY --from=monokal/tinyproxy /opt/docker-tinyproxy/run.sh /docker-tinyproxy-run.sh

# COPY --chmod 0755 docker-entrypoint.sh /docker-entrypoint.sh
COPY ./pgyvpn/pgyvpn-tinyproxy/docker-entrypoint.sh /docker-entrypoint.sh

# 通过代理来使用

RUN apk add --no-cache tinyproxy \
    && ln -s /usr/bin/tinyproxy /usr/sbin/ \
    && touch /var/log/tinyproxy/tinyproxy.log \
    && chmod 777 /var/log/tinyproxy/tinyproxy.log



COPY ./pgyvpn/pgyvpn-tinyproxy/tinyproxy-run-proxy.sh /tinyproxy-run-proxy.sh
COPY ./pgyvpn/pgyvpn-tinyproxy/tinyproxy-proxy.conf /etc/tinyproxy/tinyproxy-proxy.conf  


EXPOSE 8888

# 一次脚本
COPY ./common/one-exec.sh /one-exec.sh
ENV ONE_EXEC ""

ENTRYPOINT [ "/docker-entrypoint.sh" ]





