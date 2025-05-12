#!/bin/bash


for_num=${FOR:-1}
fork_num=${FORK:-1}
wait_num=${WAIT:-3}

# 获取当前时间的时间戳
current_time=$(date +%s)
# 计算等待时间后的时间戳
wait_time=$((current_time + ${wait_num}))
currentDatetimeDir=/data/apifox/$(date "+%Y-%m-%d--%H-%M-%S")
    mkdir -p $currentDatetimeDir

# 定义并发执行函数
run_command() {
    # 循环当前时间是否大于wait_time
    # 获取当前时间的时间戳
    current_timestamp=$(date +%s)
    echo "当前时间的时间戳: $current_timestamp"

    # 循环检查当前时间是否大于等待时间
    while [ "$current_timestamp" -le "$wait_time" ]; do
        # 输出当前时间，便于查看进度
        current_time=$(date +"%Y-%m-%d %H:%M:%S")
        echo "当前时间: $current_time，尚未超过等待时间，继续等待..."
        
        sleep 1
        
        # 更新当前时间戳
        current_timestamp=$(date +%s)
    done

    local num=$2

    echo "开始$1，循环${num}次"

    apifox run ${APIFOX_URL} --env-var "apifox_run_i=$1" -n $num -r html,cli --verbose --out-dir $currentDatetimeDir --out-file apifox-report-$1
}

# 获取环境变量num的值，如果未设置则默认为30
# 循环指定次数，将命令放入后台执行
for ((i = 1; i <= fork_num; i++)); do
    (run_command $i $for_num) &
done


# 等待所有后台任务完成
wait