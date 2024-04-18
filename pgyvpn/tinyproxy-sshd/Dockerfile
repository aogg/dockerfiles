FROM adockero/pgyvpn:tinyproxy


COPY ./common/open-sshd-passwd.sh /open-sshd-passwd.sh


COPY ./pgyvpn/tinyproxy-sshd/docker-entrypoint.sh /docker-entrypoint-sshd.sh
ENTRYPOINT [ "/docker-entrypoint-sshd.sh" ]

