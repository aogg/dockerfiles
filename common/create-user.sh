#!/bin/sh

# CREATE_USER=$GIT_DIR_USER
if [ -n "$1" ];then
    CREATE_USER=$1;
elif [ -z "$CREATE_USER" ];then
    exit;
fi

# 创建用户$CREATE_USER
if [ -z "$(id $CREATE_USER 2>/dev/null)" ]; then
    if [ -n "$(cat /etc/os-release|grep alpine)" ];then
        addgroup $CREATE_USER;
        adduser -S -D -u $CREATE_USER -h /var/cache/$CREATE_USER -s /bin/sh -G $CREATE_USER -g $CREATE_USER $CREATE_USER;
        # adduser -S -D -H -u $CREATE_USER -h /var/cache/$CREATE_USER -s /sbin/nologin -G $CREATE_USER -g $CREATE_USER $CREATE_USER

    elif [ -n "$(cat /etc/os-release|grep centos)" ];then
        groupadd -g $CREATE_USER ${CREATE_USER}-group
        adduser -p $CREATE_USER -u $CREATE_USER -d /var/cache/$CREATE_USER-user -s /bin/bash -G ${CREATE_USER}-group -g $CREATE_USER $CREATE_USER-user;
    fi;
fi;