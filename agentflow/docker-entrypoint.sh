#!/usr/bin/env bash 


# /home/node/.agentflow/bin/agentflow start
# AgentFlow

if [ ! -f /home/node/.agentflow/data/agentflow.env ];then
    cp -a /home/node/.agentflow/data_bak/* /home/node/.agentflow/data/
fi

exec /home/node/.agentflow/bin/agentflow