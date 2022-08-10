#!/bin/sh



# 替换nginx访问的php
cp -f /etc/nginx/conf.d/default.conf.bak /etc/nginx/conf.d/default.conf
sed -ie 's#--php-host-port--#'$PHP_HOST_PORT'#' /etc/nginx/conf.d/default.conf;
sed -ie 's#--git-dir--#'$GIT_DIR_ENV'#' /etc/nginx/conf.d/default.conf;
nginx &


# 创建用户$GIT_DIR_USER
/create-user.sh $GIT_DIR_USER_ENV
# 处理.ssh/known_hosts
if [ -d /var/cache/$GIT_DIR_USER_ENV ]; then
    if [ ! -f /var/cache/$GIT_DIR_USER_ENV/.ssh/known_hosts ];then
        mkdir -p /var/cache/$GIT_DIR_USER_ENV/.ssh;
        touch /var/cache/$GIT_DIR_USER_ENV/.ssh/known_hosts;
        chmod 600 /var/cache/$GIT_DIR_USER_ENV/.ssh/known_hosts;
        chown $GIT_DIR_USER_ENV:$GIT_DIR_USER_ENV /home/$GIT_DIR_USER_ENV/.ssh/known_hosts;
    fi;
fi

if [ -d /home/$GIT_DIR_USER_ENV ]; then
    if [ ! -f /home/$GIT_DIR_USER_ENV/.ssh/known_hosts ];then
        mkdir -p /home/$GIT_DIR_USER_ENV/.ssh;
        touch /home/$GIT_DIR_USER_ENV/.ssh/known_hosts;
        chmod 600 /home/$GIT_DIR_USER_ENV/.ssh/known_hosts;
        chown $GIT_DIR_USER_ENV:$GIT_DIR_USER_ENV /home/$GIT_DIR_USER_ENV/.ssh/known_hosts;
    fi;

fi;


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