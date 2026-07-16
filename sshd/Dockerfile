FROM alpine

ARG MORE_APK

# --no-cache没有/var/cache/apk
RUN apk add --no-cache openssh tzdata $MORE_APK;

ENV SSHD_PORT=22
ENV SSHD_PASSWORD='root'
# 允许端口转发
ENV SSH_ALLOW_TCP_FORWARDING='1'

# 留意path要./，不能指定到下层文件夹
ADD ./common/open-sshd-passwd.sh /

ADD ./common/one-exec.sh /


ADD ./sshd/docker-entrypoint.sh /

ENTRYPOINT [ "/docker-entrypoint.sh" ]
# CMD ["/open-sshd-passwd.sh", "-D"]