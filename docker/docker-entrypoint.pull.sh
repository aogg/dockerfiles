#!/usr/bin/env ash 




mkdir -p /etc/systemd/system/docker.service.d
echo '[Service]' > /etc/systemd/system/docker.service.d/http-proxy.conf
if [ -n "$PULL_HTTP_PROXY" ];then
    echo 'Environment="HTTP_PROXY='${PULL_HTTP_PROXY}'"' >> /etc/systemd/system/docker.service.d/http-proxy.conf
fi
if [ -n "$PULL_HTTP_PROXY" ];then
    echo 'Environment="HTTPS_PROXY='${PULL_HTTP_PROXY}'"' >> /etc/systemd/system/docker.service.d/http-proxy.conf
fi



if [ -f /usr/local/bin/dockerd-entrypoint.sh ];then
    if [ -z "$@"];then
        /usr/local/bin/dockerd-entrypoint.sh
    else
        /usr/local/bin/dockerd-entrypoint.sh "$@"
    fi
else
    if [ -z "$@"];then
        /usr/local/bin/docker-entrypoint.sh
    else
        /usr/local/bin/docker-entrypoint.sh "$@"
    fi
fi


