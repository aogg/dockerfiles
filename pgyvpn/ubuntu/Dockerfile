
FROM ubuntu:20.04

RUN apt update \
    && apt install -y wget net-tools inetutils-ping \
    && echo '开始pgyvpn' \
    && wget https://pgy.oray.com/softwares/153/download/2156/PgyVisitor_6.2.0_x86_64.deb \
    && dpkg -i PgyVisitor_6.2.0_x86_64.deb \
    && echo '开始apt remove' \
    && apt remove --purge --auto-remove -y wget \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && apt-get clean

ENV PGY_USERNAME ""
ENV PGY_PASSWORD ""

COPY ./pgyvpn/ubuntu/docker-entrypoint.sh /docker-entrypoint.sh
ENTRYPOINT [ "/docker-entrypoint.sh" ]



COPY ./pgyvpn/ubuntu/service.pgyvpn.sh /etc/init.d/pgyvpn.sh


