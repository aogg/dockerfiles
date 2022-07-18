#!/bin/ash



# 替换nginx访问的php
cp -f /etc/nginx/conf.d/default.conf.bak /etc/nginx/conf.d/default.conf
sed -e 's#--php-host-port--#'$PHP_HOST_PORT'#' /etc/nginx/conf.d/default.conf > /etc/nginx/conf.d/default.conf;
sed -e 's#--git-dir--#'$GIT_DIR'#' /etc/nginx/conf.d/default.conf > /etc/nginx/conf.d/default.conf;
nginx &


# 创建用户$GIT_DIR_USER
if [ -z "$(id $GIT_DIR_USER 2>/dev/null)" ]; then
    addgroup $GIT_DIR_USER;
    adduser -S -D -u $GIT_DIR_USER -h /var/cache/$GIT_DIR_USER -s /bin/ash -G $GIT_DIR_USER -g $GIT_DIR_USER $GIT_DIR_USER;
    # adduser -S -D -H -u $GIT_DIR_USER -h /var/cache/$GIT_DIR_USER -s /sbin/nologin -G $GIT_DIR_USER -g $GIT_DIR_USER $GIT_DIR_USER
fi;


# 监听
mkdir -p /mnt;
touch /mnt/git-inotify.txt;

ash /inotify-php-git-opcache.sh /mnt/git-inotify.txt &
# 立即更新
echo '' >> /mnt/git-inotify.txt;


tail -f /mnt/git-inotify.txt;