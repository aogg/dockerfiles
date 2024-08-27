#!/usr/bin/env ash

/adb-auto.sh &

echo '开始运行uiauto.dev'
exec uiauto.dev server --host 0.0.0.0 "$@"