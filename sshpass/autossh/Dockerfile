
FROM alpine:edge

RUN apk --update --no-cache add sshpass openssh rsync autossh

ENV SERVER_ALIVE_INTERVAL 30
ENV SERVER_ALIVE_COUNT_MAX 3
ENV STRICT_HOST_KEY_CHECKING no

COPY docker-entrypoint.sh /docker-entrypoint.sh

ENTRYPOINT [ "/docker-entrypoint.sh" ]
# ENTRYPOINT ["sshpass"]

# CMD ["--help"]

