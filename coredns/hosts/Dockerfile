

FROM coredns/coredns



COPY Corefile /etc/coredns/Corefile


# /data/hosts
VOLUME [ "/data/hosts" ]
VOLUME [ "/etc/coredns/Corefile" ]

EXPOSE 53/udp

CMD [ "-conf", "/etc/coredns/Corefile" ]














