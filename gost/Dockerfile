FROM gogost/gost

ARG CONFIG_DIR_NAME=""

COPY gost/docker-entrypoint.sh /
COPY gost/${CONFIG_DIR_NAME}/config.yaml /etc/gost/config.yaml
COPY common/env-yaml-generate.sh /

ENTRYPOINT ["/docker-entrypoint.sh"]
