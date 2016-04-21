#!/usr/bin/env bash
set +x
rm -rf .analytics ; mkdir -p .analytics
echo "Artifical sleep...ZZzzZZzz" && sleep 30

# Get current attributes for ${chef_fqdn}
bash ${chef_api} GET "/nodes/${chef_fqdn}" | jq '.normal' > .analytics/attributes.json.orig

# Check if we got anything back
grep -q 'configuration' .analytics/attributes.json.orig
if [ $? -ne 0 ]
then
  rm -f .analytics/attributes.json.orig
  echo "Taking another 30s nap"
  sleep 30
  bash ${chef_api} GET "/nodes/${chef_fqdn}" | jq '.normal' > .analytics/attributes.json.orig
fi

# Make a local edit copy
cp .analytics/attributes.json.orig .analytics/attributes.json

# Check for rabbitmq settings
grep -q 'rabbitmq' .analytics/attributes.json.orig
rabbit=$?
# Delete any potentially existing rabbitmq configuration that will hurt us
if [ $rabbit -eq 0 ]
then
  sed "s/rabbitmq\['vip'\][[:space:]]=[[:space:]]'\([[:digit:]]*\.\)\{3\}[[:digit:]]*'\\\n//"             -i.bak .analytics/attributes.json && rm -f .analytics/attributes.json.bak
  sed "s/rabbitmq\['node_ip_address'\][[:space:]]=[[:space:]]'\([[:digit:]]*\.\)\{3\}[[:digit:]]*'\\\n//" -i.bak .analytics/attributes.json && rm -f .analytics/attributes.json.bak
fi

# Check for existing oc_id['applications']
grep -q 'applications' .analytics/attributes.json.orig
result=$?
# FOUND... appending
if [ $result -eq 0 ]
then
  sed "s/\(applications.*\\\n  }\)\\\n/\1,\\\n  'analytics' => {\\\n    'redirect_uri' => 'https:\/\/${hostname}.${domain}\/'\\\n  }\\\n/" -i.bak .analytics/attributes.json && rm -f .analytics/attributes.json.bak
  sed "s/\(configuration.*\)\",/\1\\\nrabbitmq['vip'] = '${chef_ip}'\\\nrabbitmq['node_ip_address'] = '0.0.0.0'\\\n\",/"                       -i.bak .analytics/attributes.json && rm -f .analytics/attributes.json.bak
else
  # NOT FOUND... adding
  sed "s/\(configuration.*\)\",/\1\\\nrabbitmq['vip'] = '${chef_ip}'\\\nrabbitmq['node_ip_address'] = '0.0.0.0'\\\noc_id['applications'] = {\\\n  'analytics' => {\\\n    'redirect_uri' => 'https:\/\/${hostname}.${domain}\/'\\\n  }\\\n}\\\n\",/" -i.bak .analytics/attributes.json && rm -f .analytics/attributes.json.bak
fi

# rabbitmq settings
tee .analytics/rabbitmq.modify <<EOF
rabbitmq['vip'] = '${chef_ip}'
rabbitmq['node_ip_address'] = '0.0.0.0'
EOF
echo "Modified Chef server attributes at .analytics/attributes.json"
EOC

