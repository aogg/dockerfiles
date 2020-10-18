FROM openresty/openresty:alpine-fat

RUN cp -a /usr/local/openresty/nginx/conf/* /etc/nginx/ \
  # 原有日志
  && mkdir -p /var/log/nginx/ \
  && ln -sf /dev/stdout /var/log/nginx/access.log \
  && ln -sf /dev/stderr /var/log/nginx/error.log \
  # 用户
  && addgroup -g 101 -S nginx \
  && adduser -S -D -H -u 101 -h /var/cache/nginx -s /sbin/nologin -G nginx -g nginx nginx
  

CMD ["/usr/local/openresty/bin/openresty", "-p", "/etc/nginx/", "-c", "/etc/nginx/nginx.conf", "-g", "daemon off;"]


