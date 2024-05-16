#!/usr/bin/env ash 

(

sleep 8;

echo '运行http-shell';
docker rm -f http-shell;\
docker run -d --restart=always --name http-shell --privileged \
-v /var/run/docker.sock:/var/run/docker.sock -v $(which docker):$(which docker) \
-p 8080:8080 \
adockero/http-shell:alpine

) &

echo '运行dockerd';

if [ -z "$@" ];then
    exec /usr/local/bin/docker-entrypoint.sh dockerd
else
    exec /usr/local/bin/docker-entrypoint.sh "$@"
fi


