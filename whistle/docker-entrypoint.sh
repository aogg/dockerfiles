#!/usr/bin/env ash 

set -e
echo '数据目录在: /root/.WhistleAppData/.whistle/';



if [ "${1#-}" != "${1}" ] || [ -z "$(command -v "${1}")" ]; then
  # w2 start "$@"

  # tail -f /.dockerenv

  supervisord --user root --logfile /dev/null --pidfile /dev/null -c /etc/supervisord.conf -n
  # exec w2 run "$@"
fi

exec "$@"


# 必须start
