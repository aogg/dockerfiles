

FROM dreamacro/clash


RUN apk add --no-cache yq curl

ENV PORT=7890
ENV PROXIE_NAME="自动选择"

EXPOSE 7890

COPY curl/docker-entrypoint.sh /docker-entrypoint.sh
COPY common/proxies-select.sh /proxies-select.sh

# ENTRYPOINT [ "/curl-docker-entrypoint.sh" ]
ENTRYPOINT [ "/docker-entrypoint.sh" ]






