ARG VERSION=latest
FROM docker:${VERSION}


RUN apk --update add openssh git &&\
    rm -rf /tmp/* /var/cache/apk/*

ENV SSHD_PORT=22
ENV SSHD_PASSWORD=''

# configure container
ADD docker-entrypoint.sh /

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD []