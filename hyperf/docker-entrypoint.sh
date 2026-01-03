#!/usr/bin/env bash 


bash /run-dir-file.sh /script/ bash

# 输出当前时区
eco "当前时区为："
cat /etc/timezone
echo "当前时间为："
date

echo "执行命令：$@"
exec "$@"
