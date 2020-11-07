#!/usr/bin/env ash 

if [ -n "$PROXY_ADDR" ];then
    PROXY_ADDR='\* '$PROXY_ADDR' reqHeaders://\`host=${reqHeaders.host}\`'
fi;

rulesString=$LOCAL_RULE'\n\n'$PROXY_ADDR
sed -i -e "s%#localRules#%`echo $rulesString`%g" /usr/local/lib/node_modules/whistle/.whistle.js



w2 start $MORE_OPTIONS -p $PROXY_PORT -P $UI_PORT \
    -n $ADMIN_USERNAME -w $ADMIN_PASSWORD \
    -N $GUEST_USERNAME -W $GUEST_PASSWORD -M keepXFF

w2 add --force /usr/local/lib/node_modules/whistle/.whistle.js

tail -f /.dockerenv