#!/usr/bin/env bash

#
# Variables
#

D=$PWD

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

# If there's a local cookbooks directory, purge
[ -d cookbooks ] && rm -rf cookbooks

# Get community Chef Analytics cookbook from GitHub (not available via Supermarket)
git clone https://github.com/chef-cookbooks/chef-analytics cookbooks/chef-analytics

# Remove conflicting .chef directory
rm -rf cookbooks/chef-analytics/.chef

# Upload to Chef Server
cd cookbooks/chef-analytics && berks install && berks upload

# Clean up
cd $D && rm -rf cookbooks

exit 0
