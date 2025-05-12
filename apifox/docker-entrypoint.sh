#!/usr/bin/env bash


echo ${APIFOX_URL}

exec apifox run ${APIFOX_URL} -r html,cli --verbose --out-dir /data/apifox "$@"