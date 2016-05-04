#!/usr/bin/env bash

#
# Variables
#

ME=$(whoami)

#
# Functions
#

usage()
{
  cat << EOF
  usage: $0 options

  This script is designed to execute against a Chef Server for tf_chef_analytics.
  It will make necessary modifications supporting Chef Analytics

  OPTIONS:
    -h  This help message
    -v  Verbose output
EOF
}

while getopts "hv" OPTION; do
  case "$OPTION" in
    h)
      usage && exit 0   ;;
    v)
      set -x            ;;
    ?)
      usage && exit 0   ;;
  esac
done

#
# Main
#

[ -d .analytics ] && rm -rf .analytics
mkdir -p .analytics

# If we find an existing 'analytics' or 'rabbitmq' configs; move them out of the way
[ -f /etc/opscode/oc-id-applications/analytics.json ] && sudo mv /etc/opscode/oc-id-applications/analytics.json .analytics/analytics.json.before
[ -f /etc/opscode-analytics/actions-source.json ]     && sudo mv /etc/opscode-analytics/actions-source.json .analytics/actions-source.json.before

sudo sed -i.before '/rabbitmq/d' /etc/opscode/chef-server.rb
sudo mv /etc/opscode/chef-server.rb.before .analytics/chef-server.before
sudo chown -R ${ME} .analytics

# Stop Chef
sudo chef-server-ctl stop

# RabbitMQ updates
cat rabbitmq.modify | sudo tee -a /etc/opscode/chef-server.rb
# echo '/etc/opscode/chef-server.rb contents:' && sudo cat /etc/opscode/chef-server.rb # DEBUG

# Reconfigure Chef and Chef Manage w/RabbitMQ changes
sudo chef-server-ctl reconfigure
sudo chef-server-ctl restart
[ -x /usr/bin/opscode-manage-ctl ] && sudo opscode-manage-ctl reconfigure || echo "Chef Manage not found, moving on"

echo 'Taking a 10 second nap...' && sleep 10

# Run chef-client with new attributes
sudo chef-client -j attributes.json
mv attributes.json rabbitmq.modify /tmp

# Stage required files
[ -f /etc/opscode/oc-id-applications/analytics.json ] && sudo cp /etc/opscode/oc-id-applications/analytics.json .analytics/analytics.json
[ -f /etc/opscode-analytics/actions-source.json ]     && sudo cp /etc/opscode-analytics/actions-source.json .analytics/actions-source.json
sudo chown -R ${ME} .analytics

exit 0
