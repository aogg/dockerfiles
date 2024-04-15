#!/usr/bin/env sh



if [ ! -f "~/.one" ];then
    echo 1 > ~/.one

    if [ -n "$ONE_EXEC" ];then
        eval $ONE_EXEC
    fi
fi

