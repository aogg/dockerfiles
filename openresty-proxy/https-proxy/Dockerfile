

FROM openresty/openresty:alpine


COPY --from=adockero/openssl:crt /openssl/server.crt /etc/nginx/server.crt
COPY --from=adockero/openssl:crt /openssl/server.key /etc/nginx/server.key

COPY ./lua.https.proxy.conf /etc/nginx/conf.d/lua.https.proxy.conf

COPY ./docker-run.sh /docker-run.sh

ENV CLIENT_MAX_BODY_SIZE=200M
ENV PROXY_PASS_DEFAULT="http://nginx"

VOLUME /etc/nginx/ssl

CMD /docker-run.sh
