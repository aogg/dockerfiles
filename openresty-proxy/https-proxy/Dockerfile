
FROM adockero/openssl:crt as builder

FROM openresty/openresty:alpine


COPY --from=builder /openssl/server.crt /etc/nginx/server.crt
COPY --from=builder /openssl/server.key /etc/nginx/server.key

COPY ./lua.https.proxy.conf /etc/nginx/conf.d/lua.https.proxy.conf

COPY ./docker-run.sh /docker-run.sh

RUN echo '' >> /usr/local/openresty/nginx/conf/nginx.conf \
    && echo 'env PROXY_PASS_DEFAULT;' >> /usr/local/openresty/nginx/conf/nginx.conf \
    && echo 'env PROXY_PASS_ALL;' >> /usr/local/openresty/nginx/conf/nginx.conf

ENV CLIENT_MAX_BODY_SIZE=200M
# http才指向PROXY_PASS_DEFAULT
ENV PROXY_PASS_DEFAULT="http://nginx"
# 不管是否http都指向PROXY_PASS_ALL
ENV PROXY_PASS_ALL=""

VOLUME /etc/nginx/ssl

CMD /docker-run.sh
