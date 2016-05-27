#!/usr/bin/env bash

#
# Variables
#

ATTRIBUTES=0
CHEF_A=0
CHEF_H=0
CHEF_I=0
COUNT=1
M_PATH=0
RABBITMQ=0
RESULT=0

#
# Functions
#

usage()
{
  cat << EOF
  usage: $0 options

  This script is designed to produce a new attributes json file with Chef Analytics
  required changes for tf_chef_analytics Terraform plan.

  OPTIONS:
    -a  Chef Analytics FQDN
    -c  Chef Server FQDN
    -h  This help message
    -i  Chef Server IP
    -p  Path to find 'files/chef_api_request'
    -t  target directory
    -v  Verbose output
EOF
}

while getopts "a:hc:i:p:t:v" OPTION; do
  case "$OPTION" in
    a)
      CHEF_A=$OPTARG    ;;
    c)
      CHEF_H=$OPTARG    ;;
    h)
      usage && exit 0   ;;
    i)
      CHEF_I=$OPTARG    ;;
    p)
      M_PATH=$OPTARG    ;;
    t)
      T_DIR=$OPTARG     ;;
    v)
      set -x            ;;
    ?)
      usage && exit 0   ;;
  esac
done

#
# Main
#

[ -d ${T_DIR} ] && rm -rf ${T_DIR}
mkdir -p ${T_DIR}

# Talk with Chef Server API; get existing attributes (best effort)
while [ $COUNT -le 5 ]
do
  [ -f ${T_DIR}/attributes.json.orig ] && rm -f ${T_DIR}/attributes.json.orig
  ${M_PATH}/files/chef_api_request GET "/nodes/${CHEF_H}" | jq '.normal' > ${T_DIR}/attributes.json.orig
  COUNT=$((COUNT + 1))
  grep -q configuration ${T_DIR}/attributes.json.orig
  [ $? -eq 0 ] && COUNT=$((COUNT + 5)) || sleep 5
done

grep -q configuration ${T_DIR}/attributes.json.orig
[ $? -eq 0 ] && echo "Attributes harvest OK" || exit 1

COUNT=1

# See if there's a RabbitMQ configuration
cp ${T_DIR}/attributes.json.orig ${T_DIR}/attributes.json
grep -q rabbitmq ${T_DIR}/attributes.json.orig

if [ $? -eq 0 ]
then
  # Delete potentially conflicting RabbitMQ configuration found
  sed "s/rabbitmq\['vip'\][[:space:]]=[[:space:]]'\([[:digit:]]*\.\)\{3\}[[:digit:]]*'\\\n//"             ${T_DIR}/attributes.json > ${T_DIR}/attributes.json.new
  [ -f ${T_DIR}/attributes.json.new ] && mv ${T_DIR}/attributes.json.new ${T_DIR}/attributes.json
  sed "s/rabbitmq\['node_ip_address'\][[:space:]]=[[:space:]]'\([[:digit:]]*\.\)\{3\}[[:digit:]]*'\\\n//" ${T_DIR}/attributes.json > ${T_DIR}/attributes.json.new
  [ -f ${T_DIR}/attributes.json.new ] && mv ${T_DIR}/attributes.json.new ${T_DIR}/attributes.json
else
  echo "No pre-existing RabbitMQ configuration detected"
fi

# Inspect oc_id['applications']
grep -q 'applications' ${T_DIR}/attributes.json.orig
RESULT=$?

# Found oc_id['applications']; appending
if [ $RESULT -eq 0 ]
then
  sed "s/\(applications.*\\\n  }\)\\\n/\1,\\\n  'analytics' => {\\\n    'redirect_uri' => 'https:\/\/${CHEF_A}\/'\\\n  }\\\n/" ${T_DIR}/attributes.json > ${T_DIR}/attributes.json.new
  [ -f ${T_DIR}/attributes.json.new ] && mv ${T_DIR}/attributes.json.new ${T_DIR}/attributes.json
  sed "s/\(configuration.*\)\",/\1\\\nrabbitmq['vip'] = '${CHEF_I}'\\\nrabbitmq['node_ip_address'] = '0.0.0.0'\\\n\",/"        ${T_DIR}/attributes.json > ${T_DIR}/attributes.json.new
  [ -f ${T_DIR}/attributes.json.new ] && mv ${T_DIR}/attributes.json.new ${T_DIR}/attributes.json
else
  sed "s/\(configuration.*\)\",/\1\\\nrabbitmq['vip'] = '${CHEF_I}'\\\nrabbitmq['node_ip_address'] = '0.0.0.0'\\\noc_id['applications'] = {\\\n  'analytics' => {\\\n    'redirect_uri' => 'https:\/\/${CHEF_A}\/'\\\n  }\\\n}\\\n\",/" ${T_DIR}/attributes.json > ${T_DIR}/attributes.json.new
  [ -f ${T_DIR}/attributes.json.new ] && mv ${T_DIR}/attributes.json.new ${T_DIR}/attributes.json
fi

tee ${T_DIR}/rabbitmq.modify <<-EOF
rabbitmq['vip'] = '${CHEF_I}'
rabbitmq['node_ip_address'] = '0.0.0.0'
EOF

echo "Modified Chef server attributes at ${T_DIR}/attributes.json"
exit 0
