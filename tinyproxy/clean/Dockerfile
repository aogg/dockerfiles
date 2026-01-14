FROM adockero/tinyproxy


COPY ./docker-entrypoint.sh /docker-entrypoint-tinyproxy.sh


ENV DELETE_ALL_CONNECT_PORTS ""

ENTRYPOINT [ "/docker-entrypoint-tinyproxy.sh" ]
