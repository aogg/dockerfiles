

FROM metacubex/mihomo


RUN apk add --no-cache yq curl

ENV PORT=7890
ENV PROXIE_NAME="load"
# github 相关 URL (geox-url / rule-providers / proxy-providers) 的代理前缀, 置空禁用
ENV GITHUB_PROXY=https://hk.gh-proxy.org/

EXPOSE 7890

COPY mihomo-curl/docker-entrypoint.sh /docker-entrypoint.sh
COPY common/proxies-select.sh /proxies-select.sh

# ENTRYPOINT [ "/curl-docker-entrypoint.sh" ]
ENTRYPOINT [ "/docker-entrypoint.sh" ]







