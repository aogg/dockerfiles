#!/usr/bin/env sh



if [ ! -f "~/.one" ];then
    echo 1 > ~/.one

    if [ -z "ONE_EXEC"];then
        exec $ONE_EXEC
    fi
fi

