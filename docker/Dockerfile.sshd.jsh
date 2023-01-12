ARG FROM_BASE=adockero/docker:ubuntu-ssh
FROM ${FROM_BASE}


ENV SSHD_PORT=22
ENV SSHD_PASSWORD=''


ADD ./common/open-sshd-passwd.sh /

CMD sh -c "/open-sshd-passwd.sh; dockerd"