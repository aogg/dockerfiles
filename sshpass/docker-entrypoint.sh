#!/usr/bin/env ash


#socks4         127.0.0.1 9050

if [ -n "$SOCKS_PORT" ];then
    SOCKS_HOST=${SOCKS_HOST:=127.0.0.1}
    sed -i 's/^socks4/#&/' /etc/proxychains/proxychains.conf
    if [ -z "$(cat /etc/proxychains/proxychains.conf|grep -e '^socks5')" ];then
        echo "socks5 ${SOCKS_HOST} "$SOCKS_PORT >> /etc/proxychains/proxychains.conf
    fi
    exec proxychains sshpass "$@"
fi


exec sshpass "$@"
