#!/usr/bin/env ash


# --body-data
        # --post-data STR Send STR using POST method
        # --post-file FILE        Send FILE using POST method


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

yq -o json -i ".job.title = \"$full_title\"" "$json_file"
yq -o json -i ".job.schedule.timezone = \"$TIMEZONE\"" "$json_file"

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

# id = $(cat )
    json=$(
        curl --location --request GET 'https://api.cron-job.org/jobs' \
        --header 'Authorization: Bearer '${ACCESS_TOKEN}
    )
    
    echo '----------------获取到的列表json----start----'$(date)'-----------------------------'
    echo $json

    echo '----------------获取到的列表json----end---'$(date)'-----------------------------'


    # jobId=$(echo "'$json'" | yq -p json '.jobs.0.jobId')
    jobIds=$(echo $json | yq -p json e '.jobs[] | select(.title | contains("'"$full_title"'")) | .jobId' -)

    echo '$jobIds = ' $jobIds

    # 存在就删除
    # 循环遍历每个 jobId 进行处理
    if [ -n "$jobIds" ]; then
        for jobId in $jobIds; do
            echo "--------------之前的jobId = $jobId"

            # 存在就删除
            if [ -n "$jobId" ]; then
                if [ "$jobId" -gt 0 ]; then
                    echo '----------------删除之前的-------'$(date)'-----------------------------'
                    
                    # 执行删除操作
                    curl --location --request DELETE 'https://api.cron-job.org/jobs/'${jobId} \
                    --header 'Authorization: Bearer '${ACCESS_TOKEN} \
                # else
                #     echo "jobId 不大于 0"  
                fi
            fi
        done
    fi

    echo '----------------开始创建定时任务-------'$(date)'-----------------------------'

    # 设置下一个时间段
    # 获取当前时间的秒数
    current_seconds=$(date +%s)
    echo '-----当前秒数-------'$(echo $current_seconds)'------'
    # 计算增加后的时间秒数
    if [ -z $INC_TIME ];then
        INC_TIME=$(($SLEEP_TIME + $SLEEP_TIME + 100))
    fi

    new_seconds=$(($current_seconds + $INC_TIME))

    # 将新时间秒数转换为小时和分钟
    hours=$(date -d @$new_seconds +%H)
    minutes=$(date -d @$new_seconds +%M)

    yq -o json -i ".job.schedule.hours[0] = \"$hours\"" "$json_file"
    yq -o json -i ".job.schedule.minutes[0] = \"$minutes\"" "$json_file"

    echo '----------------最终发送json----start---'$(date)'-----------------------------'
    cat $json_file

    echo '----------------最终发送json----end---'$(date)'-----------------------------'


    curl --location --request PUT 'https://api.cron-job.org/jobs' \
    --header 'Authorization: Bearer '${ACCESS_TOKEN} \
    --header 'Content-Type: application/json' \
    --data "$(cat $json_file)"

    
    echo "----------------开始等待${SLEEP_TIME}-------"$(date)'-----------------------------'
    sleep $SLEEP_TIME

done



echo '-------------容器结束-----------------------------'