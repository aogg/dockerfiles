FROM alpine

ARG MORE_APK

# --no-cache没有/var/cache/apk
RUN apk add --no-cache openssh $MORE_APK;

ENV SSHD_PORT=22
ENV SSHD_PASSWORD='root'

# 留意path要./，不能指定到下层文件夹
ADD ./common/open-sshd-passwd.sh /

CMD ["/docker-sshd.passwd.sh", "-D"]