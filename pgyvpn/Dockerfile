
FROM bestoray/pgyvpn


COPY --from=monokal/tinyproxy /opt/docker-tinyproxy/run.sh /docker-tinyproxy-run.sh

COPY --chmod 0755 docker-entrypoint.sh /docker-entrypoint.sh
# COPY docker-entrypoint.sh /docker-entrypoint.sh

# 通过代理来使用

RUN apk add --no-cache tinyproxy \
    && ln -s /usr/bin/tinyproxy /usr/sbin/







