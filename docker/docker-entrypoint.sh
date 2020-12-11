#!/usr/bin/env ash 



/usr/sbin/sshd -D


if [ -f /usr/local/bin/dockerd-entrypoint.sh ];then
    /usr/local/bin/dockerd-entrypoint.sh "$@"
else
    /usr/local/bin/docker-entrypoint.sh "$@"
fi


