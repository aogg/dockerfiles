FROM adockero/pgyvpn:tinyproxy

RUN apk add --no-cache openssh

ENV SSHD_PORT 22
ENV SSHD_PASSWORD=''
COPY ./common/open-sshd-passwd.sh /open-sshd-passwd.sh


COPY ./pgyvpn/tinyproxy-sshd/docker-entrypoint.sh /docker-entrypoint-sshd.sh
ENTRYPOINT [ "/docker-entrypoint-sshd.sh" ]

