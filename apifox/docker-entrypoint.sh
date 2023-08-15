#!/usr/bin/env bash



exec apifox run ${APIFOX_URL} -r html,cli "$@"