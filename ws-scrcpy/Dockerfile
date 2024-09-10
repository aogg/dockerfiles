FROM node:16-alpine
# MAINTAINER Scavin <scavin@appinn.com>
# @see https://github.com/scavin/ws-scrcpy-docker/blob/main/Dockerfile

ENV LANG C.UTF-8

RUN npm install -g node-gyp \
    && apk add --no-cache build-base android-tools \
    && wget https://github.com/NetrisTV/ws-scrcpy/archive/refs/heads/master.zip \
    && unzip master.zip \
    && rm -f master.zip \
    && cd ws-scrcpy-master \
    && npm install \
    && npm run dist \
    && apk del build-base \
    && npm uninstall -g node-gyp \
    && rm -f /var/log/*.log \
    && rm -Rf node_modules \
    && echo '结束'

WORKDIR /ws-scrcpy-master

# RUN apt update;apt install android-tools-adb -y
# RUN git clone https://github.com/NetrisTV/ws-scrcpy.git .
# RUN npm install
# RUN npm run dist

EXPOSE 8000

CMD ["node","/ws-scrcpy-master/dist/index.js"]