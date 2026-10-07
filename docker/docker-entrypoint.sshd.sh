#!/usr/bin/env ash 


# 时区支持：优先使用 TIMEZONE（仓库约定），未设置时回退用 TZ（docker 通用惯例）
: "${TIMEZONE:=$TZ}"

if [ -n "$TIMEZONE" ];then
    export TIMEZONE TZ="$TIMEZONE";
fi

if [ -f /timezone-set.sh ];then
    /timezone-set.sh;
fi


if [ -f /open-sshd-jsh.sh ];then
    /open-sshd-jsh.sh;
    rm /open-sshd-jsh.sh;
fi

/open-sshd-passwd.sh


if [ -f /usr/local/bin/dockerd-entrypoint.sh ];then
    if [ -z "$@" ];then
        exec /usr/local/bin/dockerd-entrypoint.sh
    else
        exec /usr/local/bin/dockerd-entrypoint.sh "$@"
    fi
else
    if [ -z "$@" ];then
        exec /usr/local/bin/docker-entrypoint.sh
    else
        exec /usr/local/bin/docker-entrypoint.sh "$@"
    fi
fi


