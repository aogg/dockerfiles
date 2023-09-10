
FROM adockero/openssl:crt as builder

FROM openresty/openresty:alpine


COPY --from=builder /openssl/server.crt /etc/nginx/server.crt
COPY --from=builder /openssl/server.key /etc/nginx/server.key

COPY ./lua.https.proxy.conf /etc/nginx/conf.d/lua.https.proxy.conf

COPY ./docker-run.sh /docker-run.sh

RUN echo '' >> /usr/local/openresty/nginx/conf/nginx.conf \
    && echo 'env PROXY_PASS_DEFAULT;' >> /usr/local/openresty/nginx/conf/nginx.conf

ENV CLIENT_MAX_BODY_SIZE=200M
ENV PROXY_PASS_DEFAULT="http://nginx"

VOLUME /etc/nginx/ssl

CMD /docker-run.sh
