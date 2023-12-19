#!/usr/bin/env sh


if [ -n "$TIMEZONE" ];then
    ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
    echo "${TIMEZONE}" > /etc/timezone

fi