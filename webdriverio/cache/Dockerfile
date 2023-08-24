FROM adockero/webdriverio

RUN apt update \
    && apt install -y rsync \
    && rm -rf  /var/lib/apt/lists/*

ENV NPM_I_ARGS=    

COPY docker-entrypoint.sh /docker-entrypoint.sh

ENTRYPOINT [ "/docker-entrypoint.sh" ]