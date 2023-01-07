#!/bin/sh

# CREATE_USER=$GIT_DIR_USER


# 创建用户$CREATE_USER
if [ -z "$(id $CREATE_USER 2>/dev/null)" ]; then
    if [ -n "$(cat /etc/os-release|grep alpine)" ];then
        addgroup -g $CREATE_GROUP_ID $CREATE_GROUP;
        adduser -S -D -u $CREATE_USER_ID -h /var/cache/$CREATE_USER -s /bin/sh -G $CREATE_GROUP -g $CREATE_GROUP_ID $CREATE_USER;
        # adduser -S -D -H -u $CREATE_USER -h /var/cache/$CREATE_USER -s /sbin/nologin -G $CREATE_USER -g $CREATE_USER $CREATE_USER

        echo $CREATE_USER:$CREATE_USER|chpasswd

    elif [ -n "$(cat /etc/os-release|grep centos)" ];then
    # 未写
        echo '当前系统类型未写';
        # groupadd -g $CREATE_USER ${CREATE_USER}-group
        # adduser -p $CREATE_USER -u $CREATE_USER -d /var/cache/$CREATE_USER-user -s /bin/bash -G ${CREATE_USER}-group -g $CREATE_USER $CREATE_USER-user;
    fi;
fi;