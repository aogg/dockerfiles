#!/usr/bin/env bash 


# /home/claude/.agentflow/bin/agentflow start
# AgentFlow

if [ ! -f /home/claude/.agentflow/data/agentflow.env ];then
    cp -a /home/claude/.agentflow/data_bak/* /home/claude/.agentflow/data/
fi

exec /home/claude/.agentflow/bin/agentflow