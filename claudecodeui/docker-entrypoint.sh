#!/usr/bin/env bash

# 初始化 SSHD 服务
/open-sshd-passwd.sh


exec "$@"
