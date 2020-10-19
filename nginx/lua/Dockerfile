FROM openresty/openresty:alpine-fat

RUN cp -a /usr/local/openresty/nginx/conf/* /etc/nginx/ \
  # 原有日志
  && mkdir -p /var/log/nginx/ \
  && ln -sf /dev/stdout /var/log/nginx/access.log \
  && ln -sf /dev/stderr /var/log/nginx/error.log \
  && ln -sf /var/log/nginx/ /etc/nginx/logs \
  # 用户
  && addgroup -g 101 -S nginx \
  && adduser -S -D -H -u 101 -h /var/cache/nginx -s /sbin/nologin -G nginx -g nginx nginx \
  # nginx的alias
  && mv /usr/local/openresty/nginx/sbin/nginx /usr/local/openresty/nginx/sbin/nginx_origin \
  && ln -sf /usr/local/openresty/nginx/sbin/nginx_origin /usr/local/openresty/bin/openresty \
  && echo "alias nginx='/usr/local/openresty/bin/openresty -p /etc/nginx/ -c /etc/nginx/nginx.conf'" >> /root/.bashrc
  
  
COPY docker-entrypoint.sh /usr/local/bin/ 
CMD ["docker-entrypoint.sh"] 


