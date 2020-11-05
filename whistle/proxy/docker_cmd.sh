#!/usr/bin/env ash 


w2 start $MORE_OPTIONS -p $PROXY_PORT -P $UI_PORT \
    -n $ADMIN_USERNAME -w $ADMIN_PASSWORD \
    -N $GUEST_USERNAME -W $GUEST_PASSWORD -M keepXFF

read
