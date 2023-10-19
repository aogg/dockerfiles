#!/usr/bin/env ash


# -p "[p#1 密码]" ssh -o StrictHostKeyChecking=no [p#2 账号]@[p#3 地址] -vvv -L 0.0.0.0:[p#4 远端和本地的端口]:127.0.0.1:[p#4 远端和本地的端口] -N


SERVER_ALIVE_INTERVAL=${SERVER_ALIVE_INTERVAL:-30}
SERVER_ALIVE_COUNT_MAX=${SERVER_ALIVE_COUNT_MAX:-3}
STRICT_HOST_KEY_CHECKING=${STRICT_HOST_KEY_CHECKING:no}

exec sshpass -p "$PASSWORD" autossh -M 1234  -o "StrictHostKeyChecking=$STRICT_HOST_KEY_CHECKING" -o "ServerAliveInterval $SERVER_ALIVE_INTERVAL" -o "ServerAliveCountMax $SERVER_ALIVE_COUNT_MAX" $@