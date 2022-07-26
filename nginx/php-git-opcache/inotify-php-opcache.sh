#!/bin/sh


# src=/data/www/
inotifywaitFile=$1;
inotifywait -mrq --timefmt '%d/%m/%y %H:%M' --format '%T %w%f%e' -e modify,delete,create,attrib $inotifywaitFile |  while read file
do
      echo "  ${file} inotifywait"
      






if [ -n "$UPDATE_BEFORE_SHELL_STRING" ];then
    echo $UPDATE_BEFORE_SHELL_STRING;
    su  $GIT_DIR_USER_ENV /bin/sh  -c "eval $UPDATE_BEFORE_SHELL_STRING";
fi;



# chmod 777 /tmp/git_pull_files.log;



cp -f /opcacheUpdate.php $GIT_DIR_USER_ENV/opcacheUpdate.php;
chmod 777 $GIT_DIR_USER_ENV/opcacheUpdate.php;
curl --data-binary "@"$inotifywaitFile localhost/opcacheUpdate.php;
rm -f $GIT_DIR_USER_ENV/opcacheUpdate.php;


if [ -n "$UPDATE_AFTER_SHELL_STRING" ];then
    echo $UPDATE_AFTER_SHELL_STRING;
    su  $GIT_DIR_USER_ENV /bin/sh  -c "eval $UPDATE_AFTER_SHELL_STRING";
fi;


done