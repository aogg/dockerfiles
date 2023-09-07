

FROM openresty/openresty:alpine


COPY ./default.conf /etc/nginx/conf.d/default.conf
COPY ./lua.https.proxy.template.conf /etc/nginx/lua.https.proxy.template.conf

COPY ./docker-run.sh /docker-run.sh

ENV CLIENT_MAX_BODY_SIZE=200M

CMD /docker-run.sh
