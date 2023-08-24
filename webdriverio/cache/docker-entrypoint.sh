#!/usr/bin/env ash

VOLUME_DIR=${VOLUME_DIR:-"/webdriverio"}
RUN_DIR=/webdriverio
cd /webdriverio;

if [ -z "$VOLUME_DIR" ];then
    # 将.复制过去
    rsync -avl --stats --progress "$VOLUME_DIR" $RUN_DIR
    cp -a "$VOLUME_DIR" $RUN_DIR
    RUN_DIR="$VOLUME_DIR"
fi

if [ -z "$CODE_DIR" ];then
    cp -a "$CODE_DIR" $VOLUME_DIR
fi


if [ -z "$NPM_I_ARGS" ];then
    npm install $NPM_I_ARGS
fi


exec "$@"


