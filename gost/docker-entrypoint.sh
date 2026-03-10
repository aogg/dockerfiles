#!/usr/bin/env ash 


/env-yaml-generate.sh /etc/gost/config.yaml

exec gost -C /etc/gost/config.yaml
