#!/usr/bin/env bash


/open-sshd-passwd.sh &

exec /docker-entrypoint.sh "$@"


