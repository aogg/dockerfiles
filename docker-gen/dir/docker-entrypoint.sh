#!/usr/bin/env ash 



cd "$GEN_DIR" || exit 1

for file in *
do

    if [ -f "$file" ] && ; then
        if echo "$GEN_DOCKER_COMMAND" | grep -q "{file_name}";then
            NEW_COMMAND=$(echo "$GEN_DOCKER_COMMAND" | sed "s/{file_name}/$file/")

            echo 'file-运行下面命令';
            echo "$NEW_COMMAND"
            $NEW_COMMAND
        elif echo "$GEN_DOCKER_COMMAND" | grep -q "{file_full_name}";then
            file_full_name=$GEN_DIR/$file;
            NEW_COMMAND=$(echo "$GEN_DOCKER_COMMAND" | sed "s/{file_full_name}/$file_full_name/")

            echo 'file-运行下面命令';
            echo "$NEW_COMMAND"
            $NEW_COMMAND
        if
    fi

    if [ -d "$file" ]; then

        if echo "$GEN_DOCKER_COMMAND" | grep -q "{dir_name}";then
            NEW_COMMAND=$(echo "$GEN_DOCKER_COMMAND" | sed "s/{dir_name}/$file/")

            echo 'dir-运行下面命令';
            echo "$NEW_COMMAND"
            $NEW_COMMAND
        elif echo "$GEN_DOCKER_COMMAND" | grep -q "{dir_full_name}";then
            file_full_name=$GEN_DIR/$file/;
            NEW_COMMAND=$(echo "$GEN_DOCKER_COMMAND" | sed "s/{dir_full_name}/$file_full_name/")

            echo 'dir-运行下面命令';
            echo "$NEW_COMMAND"
            $NEW_COMMAND
        if
    fi

done



