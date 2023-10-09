

FROM coredns/coredns




# /data/hosts
VOLUME [ "/data/hosts" ]
VOLUME [ "/etc/coredns/Corefile" ]



COPY Corefile /etc/coredns/Corefile

EXPOSE 53/udp

CMD [ "-conf", "/etc/coredns/Corefile" ]














