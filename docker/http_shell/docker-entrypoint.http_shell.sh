#!/usr/bin/env ash 

HTTP_SHELL_PORT=${HTTP_SHELL_PORT:-8080}
echo "HTTP_SHELL_PORT=$HTTP_SHELL_PORT"

(

sleep 8;
docker network create common-all

echo '运行http-shell';
docker rm -f http-shell;\
docker run -d --restart=always --network common-all --name http-shell --privileged \
-v /var/run/docker.sock:/var/run/docker.sock -v $(which docker):$(which docker) \
-p $HTTP_SHELL_PORT:8080 \
adockero/http-shell:alpine

) &

echo '运行dockerd';

if [ -z "$@" ];then
    exec /usr/local/bin/docker-entrypoint.sh dockerd
else
    exec /usr/local/bin/docker-entrypoint.sh "$@"
fi


