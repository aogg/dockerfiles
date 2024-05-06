#!/usr/bin/env ash


# --body-data
        # --post-data STR Send STR using POST method
        # --post-file FILE        Send FILE using POST method
execute_with_retry_out=''
send_str=''

execute_with_retry() {
    # command=$1
    max_retries=5
    retries=0

    while [ $retries -lt $max_retries ]; do
        echo -e "执行命令：$@\n" >&2
        temp=$(eval "$@")
        ifBool=$?
        export execute_with_retry_out=$temp
        echo '返回结果' >&2
        echo $execute_with_retry_out

        if [ $ifBool -eq 0 ]; then
            echo -e "命令执行成功\n" >&2
            return 0
        else
            retries=`expr $retries + 1`
            echo -e "命令执行失败，进行第 $retries 次重试\n" >&2
            random_time=`expr 1 + $RANDOM % 3`
            sleep $random_time
        fi
    done

    echo "达到最大重试次数，命令执行失败" >&2
    return 1
}

calculate_time() {
    # 设置下一个时间段
    # 获取当前时间的秒数
    current_seconds=$(date +%s)
    echo '-----当前秒数-------'$(echo $current_seconds)'------'
    # 计算增加后的时间秒数
    if [ -z $INC_TIME ];then
        INC_TIME=$(($SLEEP_TIME + $SLEEP_TIME + $SLEEP_TIME + 100))
    fi

    new_seconds=$(($current_seconds + $INC_TIME))

    # 将新时间秒数转换为小时和分钟
    hours=$(date -d @$new_seconds +%H)
    minutes=$(date -d @$new_seconds +%M)

    # yq -o json -i ".job.schedule.hours[0] = \"$hours\"" "$json_file"
    yq -o json -i ".expression = \"${minutes} ${hours} * * *\"" "$json_file"


    send_str=$(cat $json_file | sed "s/{{cron_run_date}}/${hours}时${minutes}分/g")

}


echo '-------------容器开始'$(date)'-----------------------------'

full_title=$(echo 'docker-auto-job-'$NAME)

# jq_filter='
# reduce env[] as $env ({}; 
#   . as $output | 
#     $env | 
#       split(".") as $keys | 
#         reduce $keys[] as $key ($output; 
#           $output[$key] = if $key|length == 1 then env[$env] else . end)
# )'
# create_json_true="$(jq "$jq_filter" <<< "$create_json")"
# 循环遍历以jq_前缀命名的环境变量


json_file=/default.json

yq -o json -i ".name = \"$full_title\"" "$json_file"
# yq -o json -i ".job.schedule.timezone = \"$TIMEZONE\"" "$json_file"

ln -snf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
echo $TIMEZONE > /etc/timezone

cat $json_file


echo '-------------容器开始----循环环境变量'$(date)'-----------------------------'

for var in $(env | grep '^yq_' | cut -d '=' -f 1); do
    # 提取环境变量名中的键名
    key=$(echo "$var" | sed 's/^yq_//')

    echo '$var = ' $var
    echo '$key = ' $key
    # 提取环境变量的值
    # value=${!var}
    # echo "eval value=\"\${$var}\""
    # eval "value=\"\${$var}\""
    value=$(env | grep "^${var}" | sed "s/^${var}=//")
    value=$(echo $value | sed 's/"/\\"/g');

    echo '$value =' $value
    # 使用jq工具修改JSON文件中的值
    yq -o json -i ".$key = \"${value}\"" "$json_file";
done

echo '----------------最终发送json--default--start---'$(date)'-----------------------------'
cat $json_file

echo '----------------最终发送json--default--end---'$(date)'-----------------------------'


while true; do

    if [ -n "$RANDOM_TIME_BOOL" ]; then
        random_time=$((1 + RANDOM % 10))
        echo '----------------增加随机秒数'$random_time'----'$(date)'-----------------------------'
        SLEEP_TIME=$(($SLEEP_TIME + $random_time))
    fi


# id = $(cat )
    # json=$(
        execute_with_retry curl --location --request GET "'https://app.fastcron.com/api/v1/cron_list?token=${ACCESS_TOKEN}'"
    # )
    json=$execute_with_retry_out
    
    echo '----------------获取到的列表json----start----'$(date)'-----------------------------'
    echo $json

    echo '----------------获取到的列表json----end---'$(date)'-----------------------------'


    # jobId=$(echo "'$json'" | yq -p json '.jobs.0.jobId')
    jobIds=$(echo $json | yq -p json e '.data[] | select(.name | contains("'"$full_title"'")) | .id' -)

    echo 'Id = ' $jobIds

    # 存在就删除
    # 循环遍历每个 jobId 进行处理
    if [ -n "$jobIds" ]; then
        jobIdsLength=0
        for jobId in $jobIds; do
            if [ -n "$jobId" ]; then
                if [ "$jobId" -gt 0 ]; then
                    jobIdsLength=$((jobIdsLength + 1))
                fi
            fi
        done
        echo '数量 jobIdsLength = ' $jobIdsLength

        editBool=0
        i=1
        for jobId in $jobIds; do
            echo "--------------之前的Id = $jobId"

            # 存在就删除
            if [ -n "$jobId" ]; then
                if [ "$jobId" -gt 0 ]; then
                    if [ $i -eq $jobIdsLength ]; then
                        editBool=1
                        echo '----------------修改之前的-------'$(date)'-----------------------------'
                        
                        calculate_time
                        # todo 
                        # send_str=$(echo "$send_str" | yq eval '. + {"id": "'${jobId}'"}' -)
                        send_str=$(echo "$send_str" | yq -o json ".id = \"${jobId}\"")

                        echo '----------------最终发送json----start---'$(date)'-----------------------------'
                        # cat $json_file
                        echo -e $send_str

                        echo '----------------最终发送json----end---'$(date)'-----------------------------'
                        
                        # 执行删除操作
                        sleep 1
                        execute_with_retry curl --location --request POST "'https://app.fastcron.com/api/v1/cron_edit?token=${ACCESS_TOKEN}'"  \
                        --header "'Content-Type: application/json'" \
                        --data-raw "'$(echo $send_str)'"


                    else
                        echo '----------------删除之前的-------'$(date)'-----------------------------'
                        
                        # 执行删除操作
                        sleep 1
                        execute_with_retry curl --location --request POST "'https://app.fastcron.com/api/v1/cron_delete?token=${ACCESS_TOKEN}&id=${jobId}'"
                    fi
                # else
                #     echo "jobId 不大于 0"  
                fi
            fi

            i=$((i + 1))
        done

        if [ -n "$editBool" ];then
            echo "----------------开始等待${SLEEP_TIME}-------"$(date)'-----------------------------'
            sleep $SLEEP_TIME
            continue
        fi
    fi

    
    echo '----------------确认是否已删除----start----'$(date)'-----------------------------'
        sleep 1
        execute_with_retry curl --location --request GET "'https://app.fastcron.com/api/v1/cron_list?token=${ACCESS_TOKEN}'"
    echo '----------------确认是否已删除----end----'$(date)'-----------------------------'

    echo '----------------开始创建定时任务-------'$(date)'-----------------------------'

    calculate_time


    echo '----------------最终发送json----start---'$(date)'-----------------------------'
    # cat $json_file
    echo -e $send_str

    echo '----------------最终发送json----end---'$(date)'-----------------------------'

    sleep 1
    execute_with_retry curl --location --request POST "'https://app.fastcron.com/api/v1/cron_add?token=${ACCESS_TOKEN}'"  \
    --header "'Content-Type: application/json'" \
    --data-raw "'$(echo $send_str)'"

    
    echo "----------------开始等待${SLEEP_TIME}-------"$(date)'-----------------------------'
    sleep $SLEEP_TIME

done



echo '-------------容器结束-----------------------------'