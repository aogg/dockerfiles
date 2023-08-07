

FROM dreamacro/clash


RUN apk add --no-cache yq

# ENV PORT=7890

# EXPOSE 7890

COPY docker-entrypoint.sh /docker-entrypoint.sh

# ENTRYPOINT [ "/curl-docker-entrypoint.sh" ]
ENTRYPOINT [ "/docker-entrypoint.sh" ]






