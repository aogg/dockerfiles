FROM ictu/sshpass

RUN apk update && apk add proxychains-ng

COPY docker-entrypoint.sh /docker-entrypoint.sh

# 添加可执行权限
RUN chmod +x /docker-entrypoint.sh

ENTRYPOINT [ "/docker-entrypoint.sh" ]