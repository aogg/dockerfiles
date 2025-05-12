FROM node


# @see https://github.com/xiaojun207/docker-apifox-cli

RUN npm install -g apifox-cli

COPY docker-entrypoint.sh /docker-entrypoint.sh
COPY for.sh /for.sh

ENTRYPOINT ["/docker-entrypoint.sh"]