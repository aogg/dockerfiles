#!/usr/bin/env sh 

# 判断：目录存在 且 目录内无任何文件
cpBool=0
if [ ! -d "/etc/ssh/" ] || [ -z "$(ls -A "/etc/ssh/" 2>/dev/null)" ];then

  cp -a "/etc/ssh_bak/." "/etc/ssh/"
fi

/one-exec.sh

exec /open-sshd-passwd.sh -D