
FROM bestoray/pgyvpn


COPY --from=dannydirect/tinyproxy /opt/docker-tinyproxy/run.sh /docker-tinyproxy-run.sh

COPY --chmod 755 docker-entrypoint.sh /docker-entrypoint.sh

# 通过代理来使用

RUN apk add --no-cache tinyproxy







