#!/bin/sh



# 替换nginx访问的php
cp -f /etc/nginx/conf.d/default.conf.bak /etc/nginx/conf.d/default.conf
sed -e 's#--php-host-port--#'$PHP_HOST_PORT'#' /etc/nginx/conf.d/default.conf > /etc/nginx/conf.d/default.conf;
sed -e 's#--git-dir--#'$GIT_DIR_ENV'#' /etc/nginx/conf.d/default.conf > /etc/nginx/conf.d/default.conf;
nginx &


# 创建用户$GIT_DIR_USER
/create-user.sh $GIT_DIR_USER_ENV

# 监听
mkdir -p /mnt;
touch /mnt/git-inotify.txt;

if [ -n "$GIT_AUTO_PULL_FALSE" ];then

/inotify-php-opcache.sh /mnt/git_pull_files.log &
# 立即更新
echo '' >> /mnt/git_pull_files.log;
else

/inotify-php-git-opcache.sh /mnt/git-inotify.txt &
# 立即更新
echo '' >> /mnt/git-inotify.txt;
fi;


tail -f /mnt/git-inotify.txt;