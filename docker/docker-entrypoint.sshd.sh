#!/usr/bin/env ash 


if [ -f /open-sshd-jsh.sh ];then
    /open-sshd-jsh.sh;
    rm /open-sshd-jsh.sh;
fi

/open-sshd-passwd.sh


if [ -f /usr/local/bin/dockerd-entrypoint.sh ];then
    if [ -z "$@" ];then
        /usr/local/bin/dockerd-entrypoint.sh
    else
        /usr/local/bin/dockerd-entrypoint.sh "$@"
    fi
else
    if [ -z "$@" ];then
        /usr/local/bin/docker-entrypoint.sh
    else
        /usr/local/bin/docker-entrypoint.sh "$@"
    fi
fi


