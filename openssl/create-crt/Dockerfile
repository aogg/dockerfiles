

FROM itzg/openssl-ubuntu

COPY docker-entrypoint.sh /docker-entrypoint.sh



ONBUILD RUN docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]




