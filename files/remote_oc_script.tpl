#!/usr/bin/env bash

rm -rf .analytics ; mkdir -p .analytics
[ -f /etc/opscode/oc-id-applications/analytics.json ] && analytics=0 || analytics=1

if [ $analytics -eq 0 ]
then
  echo Existing configuration found... harvesting
  sudo cp /etc/opscode/oc-id-applications/analytics.json .analytics/analytics.json
  sudo cp /etc/opscode-analytics/actions-source.json .analytics/actions-source.json
  sudo chown ${user} .analytics/analytics.json .analytics/actions-source.json
  exit 0
fi

sudo grep -q rabbitmq /etc/opscode/chef-server.rb

if [ $? -eq 0 ]
  sudo grep rabbitmq /etc/opscode/chef-server.rb > .analytics/rabbitmq.saved
  sudo chown ${user} .analytics/rabbitmq.saved
  sudo sed -i '/rabbitmq/d' /etc/opscode/chef-server.rb
fi

sudo chef-server-ctl stop

cat rabbitmq.modify | sudo tee -a /etc/opscode/chef-server.rb

# debugging
# echo '/etc/opscode/chef-server.rb contents:' && sudo cat /etc/opscode/chef-server.rb

sudo chef-server-ctl reconfigure
sudo chef-server-ctl restart
sudo opscode-manage-ctl reconfigure

echo 'Taking a 15 second nap...' && sleep 15

sudo chef-client -j attributes.json

mv attributes.json rabbitmq.modify /tmp
sudo cp /etc/opscode/oc-id-applications/analytics.json .analytics/analytics.json
sudo cp /etc/opscode-analytics/actions-source.json .analytics/actions-source.json
sudo chown ${user} .analytics/analytics.json .analytics/actions-source.json

