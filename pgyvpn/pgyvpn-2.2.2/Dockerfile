
FROM adockero/pgyvpn:2.2.2


COPY --from=monokal/tinyproxy /opt/docker-tinyproxy/run.sh /docker-tinyproxy-run.sh

# COPY --chmod 0755 docker-entrypoint.sh /docker-entrypoint.sh
COPY ./pgyvpn/pgyvpn-2.2.2/docker-entrypoint.sh /docker-entrypoint.sh

# 通过代理来使用

RUN apt update \
    && apt install -y tinyproxy \
    && rm -rf  /var/lib/apt/lists/* \
    && ln -s /usr/bin/tinyproxy /usr/sbin/



COPY ./pgyvpn/pgyvpn-tinyproxy/tinyproxy-run-proxy.sh /tinyproxy-run-proxy.sh
COPY ./pgyvpn/pgyvpn-tinyproxy/tinyproxy-proxy.conf /etc/tinyproxy/tinyproxy-proxy.conf  



EXPOSE 8888


# 一次脚本
COPY ./common/one-exec.sh /one-exec.sh
ENV ONE_EXEC ""

ENTRYPOINT [ "/docker-entrypoint.sh" ]





