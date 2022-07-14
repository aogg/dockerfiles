#!/bin/ash



# 替换nginx访问的php
cp -f /etc/nginx/conf.d/default.conf.bak /etc/nginx/conf.d/default.conf
sed -e 's#--php-host-port--#'$PHP_HOST_PORT'#' /etc/nginx/conf.d/default.conf > /etc/nginx/conf.d/default.conf;
sed -e 's#--git-dir--#'$GIT_DIR'#' /etc/nginx/conf.d/default.conf > /etc/nginx/conf.d/default.conf;
nginx &;



# 监听
mkdir -p /mnt;
touch /mnt/git-inotify;

ash /inotify-php-git-opcache.sh /mnt/git-inotify &
# 立即更新
echo '' >> /mnt/git-inotify;


tail -f /mnt/git-inotify;