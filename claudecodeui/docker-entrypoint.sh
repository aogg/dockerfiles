#!/usr/bin/env bash

# 初始化 SSHD 服务
/open-sshd-passwd.sh

# 如果当前是root用户，就切换node用户执行传入的命令
if [ $# -eq 0 ]; then
    exec gosu node cloudcli $@
fi
# 如果不是root，直接执行传入命令
exec "$@"
