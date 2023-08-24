
ARG FROM_ARGS=node

FROM ${FROM_ARGS}

RUN mkdir /webdriverio \
    && cd /webdriverio \
    && npm init -f \
    && npm install --save webdriverio

WORKDIR /webdriverio