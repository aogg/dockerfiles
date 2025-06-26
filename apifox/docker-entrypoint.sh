#!/usr/bin/env bash


echo ${APIFOX_URL}

echo "apifox版本"
apifox -v

echo "最终运行命令"
echo apifox run ${APIFOX_URL} -r html,cli --verbose --out-dir /data/apifox "$@"

exec apifox run ${APIFOX_URL} -r html,cli --verbose --out-dir /data/apifox "$@"