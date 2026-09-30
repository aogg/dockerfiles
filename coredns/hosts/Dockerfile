

FROM coredns/coredns AS coredns
# 官方镜像是 distroless (无 shell/curl), 换 debian-slim 才能跑 entrypoint 脚本
FROM debian:12-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends curl ca-certificates \
 && rm -rf /var/lib/apt/lists/*

COPY --from=coredns /coredns /coredns




# /data/hosts
# VOLUME [ "/data/hosts" ]
VOLUME [ "/data/" ]
# VOLUME [ "/etc/coredns/Corefile" ]
VOLUME [ "/etc/coredns/" ]



COPY hosts /data/hosts
COPY Corefile /etc/coredns/Corefile
COPY docker-entrypoint.sh /docker-entrypoint.sh

EXPOSE 53/udp
ENTRYPOINT ["/docker-entrypoint.sh"]

CMD [ "-conf", "/etc/coredns/Corefile" ]













