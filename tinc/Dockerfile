FROM debian:experimental

# see https://github.com/JensErat/docker-tinc/blob/master/Dockerfile


# Remove SUID programs
RUN for i in `find / -perm +6000 -type f 2>/dev/null`; do chmod a-s $i; done

RUN echo "deb http://http.debian.net/debian experimental main" >> /etc/apt/sources.list && \
    apt-get update && \
    echo 'start install' && apt search ifconfig \
    && apt-get install -y libssl iputils-ping && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y libssl && \
    echo 'start install tinc' && \
    mkdir -p /etc/tinc/nets.boot && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y -t experimental net-tools tinc && \
    echo 'end install tinc' && \
    mkdir -p /dev/net/tun \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

EXPOSE 655/tcp 655/udp
VOLUME /etc/tinc

COPY docker-entrypoint.sh /docker-entrypoint.sh

ENTRYPOINT [ "/docker-entrypoint.sh" ]


ENV LOG_LEVEL 2
ENV CONFIG_MORE ""
ENV NETMASK ""
ENV PORT ""
ENV ETH0_IP ""
ENV INVITE_URL ""
ENV NODE_NAME ""
ENV NODE_IP ""
