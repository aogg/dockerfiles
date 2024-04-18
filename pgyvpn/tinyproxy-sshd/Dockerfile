FROM adockero/pgyvpn:tinyproxy

RUN apk add --no-cache openssh

COPY ./common/open-sshd-passwd.sh /open-sshd-passwd.sh


COPY ./pgyvpn/tinyproxy-sshd/docker-entrypoint.sh /docker-entrypoint-sshd.sh
ENTRYPOINT [ "/docker-entrypoint-sshd.sh" ]

