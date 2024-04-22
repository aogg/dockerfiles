#!/bin/sh
#chkconfig: 345 90 10 
#description: pgyvpn

start_monitor()
{
        pgyvpn_monitor_pid=$(pidof pgyvpn_monitor)
        if [ -z "$pgyvpn_monitor_pid" ];then
                /usr/share/pgyvpn/script/pgyvpn_monitor >/dev/null 2>&1 &
        fi
}

force_stop()
{
        killall -9 pgyvpn_monitor >/dev/null 2>&1
        killall -9 pgyvpn_svr >/dev/null 2>&1
        killall -9 pgyvpn_proxy >/dev/null 2>&1
}

stop_all()
{
        killall -9 pgyvpn_monitor >/dev/null 2>&1
        killall -15 pgyvpn_svr >/dev/null 2>&1
        sleep 2
        killall -9 pgyvpn_proxy >/dev/null 2>&1
}

case $1 in
        stop)
                stop_all
                ;;
        *)
                force_stop
                start_monitor
                ;;
esac

