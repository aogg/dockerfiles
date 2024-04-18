#!/usr/bin/env sh


echo 'start one-exec.sh';
if [ ! -f "~/.one" ];then
    echo 1 > ~/.one

    if [ -n "$ONE_EXEC" ];then
        echo $ONE_EXEC
        eval $ONE_EXEC
    fi
fi

