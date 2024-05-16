#!/usr/bin/env ash 

(
sleep 4;

docker rm -f http-shell;\
docker run -d --restart=always --name http-shell --privileged \
-v /var/run/docker.sock:/var/run/docker.sock -v $(which docker):$(which docker) \
-p 8080:8080 \
adockero/http-shell:alpine
) &


    if [ -z "$@" ];then
        exec /usr/local/bin/docker-entrypoint.sh
    else
        exec /usr/local/bin/docker-entrypoint.sh "$@"
    fi


