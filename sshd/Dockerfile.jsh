ARG FROM_ARG=adockero/sshd

FROM $FROM_ARG

ENV SSHD_OPEN_JSH=1

# 留意path要./，不能指定到下层文件夹
ADD ./common/open-sshd-jsh.sh /

# --no-cache没有/var/cache/apk
RUN open-sshd-jsh.sh




