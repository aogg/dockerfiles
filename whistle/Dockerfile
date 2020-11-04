FROM node:lts-alpine

ARG VERSION=latest

RUN if [ $VERSION = "latest" ]; then npm install -g whistle fi; \
    && if [ $VERSION != "latest" ]; then npm install -g whistle @${VERSION}fi;


CMD w2 run
