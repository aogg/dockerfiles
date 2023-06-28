

FROM openresty/openresty:alpine


COPY ./lua.host.dir.conf /etc/nginx/conf.d/lua.host.dir.conf

COPY ./docker-run.sh /docker-run.sh

ENV CLIENT_MAX_BODY_SIZE=200M

CMD /docker-run.sh
