FROM ictu/sshpass

RUN apk update && apk add proxychains-ng

COPY docker-entrypoint.sh /docker-entrypoint.sh

ENTRYPOINT [ "/docker-entrypoint.sh" ]