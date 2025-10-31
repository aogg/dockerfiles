

FROM metacubex/mihomo


RUN apk add --no-cache yq curl perl

ENV PORT=7890
ENV EXTERNAL_PORT=9090
ENV PROXIE_NAME="自动选择"

EXPOSE 7890

COPY mihomo-curl-line/docker-entrypoint.sh /docker-entrypoint.sh
COPY common/proxies-select.sh /proxies-select.sh

# ENTRYPOINT [ "/curl-docker-entrypoint.sh" ]
ENTRYPOINT [ "/docker-entrypoint.sh" ]






