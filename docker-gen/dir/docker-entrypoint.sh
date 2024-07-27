#!/usr/bin/env ash 



cd "$GEN_DIR" || exit 1

for file in *
do
    NEW_COMMAND=$(echo "$GEN_DOCKER_COMMAND" | sed "s/{file_name}/$file/")

    echo '运行下面命令';
    echo "$NEW_COMMAND"
    $NEW_COMMAND
done



