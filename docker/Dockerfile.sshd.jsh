ARG FROM_BASE=adockero/docker:sshd
FROM ${FROM_BASE}


ENV SSHD_OPEN_JSH=1

# configure container
# 留意path要./，不能指定到下层文件夹
ADD ./common/open-sshd-jsh.sh /
