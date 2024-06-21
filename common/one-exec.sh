#!/usr/bin/env sh

# 运行
# /one-exec.sh

echo 'start one-exec.sh';
if [ ! -f "$(cd ~ && pwd)/.one" ];then
    echo 1 > ~/.one

    if [ -n "$ONE_EXEC" ];then
        echo $ONE_EXEC
        eval $ONE_EXEC
    fi
fi

