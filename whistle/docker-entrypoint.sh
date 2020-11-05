#!/usr/bin/env ash 

set -e

if [ "${1#-}" != "${1}" ] || [ -z "$(command -v "${1}")" ]; then
  w2 start "$@"

  tail -f /.dockerenv
fi

exec "$@"


# 必须start
