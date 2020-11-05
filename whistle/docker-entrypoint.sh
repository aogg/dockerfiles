#!/usr/bin/env ash 

set -e

if [ "${1#-}" != "${1}" ] || [ -z "$(command -v "${1}")" ]; then
  set -- w2 start "$@"
  read
fi

exec "$@"


# 必须start
