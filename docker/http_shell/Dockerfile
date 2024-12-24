FROM docker:dind


EXPOSE 8080

ENV HTTP_SHELL_PORT 8080

# RUN echo '开始' \
#     && ((/usr/local/bin/docker-entrypoint.sh ) &) \
#     && sleep 4 \
#     && docker pull adockero/http-shell:alpine

ADD ./docker-entrypoint.http_shell.sh /

ENTRYPOINT ["/docker-entrypoint.http_shell.sh"]

CMD [ "dockerd" ]
