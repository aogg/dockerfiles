

FROM coredns/coredns




# /data/hosts
# VOLUME [ "/data/hosts" ]
VOLUME [ "/data/" ]
# VOLUME [ "/etc/coredns/Corefile" ]
VOLUME [ "/etc/coredns/" ]



COPY hosts /data/hosts
COPY Corefile /etc/coredns/Corefile

EXPOSE 53/udp

CMD [ "-conf", "/etc/coredns/Corefile" ]














