tf_chef_analytics CHANGELOG
========================

This file is used to list changes made in each version of the tf_chef_analytics Terraform plan.

v0.1.11 (2016-04-18)
-------------------
- [Brian Menges] - Missing commas in `remote-exec` call

v0.1.10 (2016-04-18)
-------------------
- [Brian Menges] - Update rabbitmq outside chef, then use chef with provided attributes update to win

v0.1.9 (2016-04-18)
-------------------
- [Brian Menges] - Attempting to fix Analytics installation

v0.1.8 (2016-04-15)
-------------------
- [Brian Menges] - Fix local-exec, use variable `${var.chef_ip}` in both test cases, not just one
- [Brian Menges] - Fix syntax error in `attributes-json.tpl`

v0.1.7 (2016-04-15)
-------------------
- [Brian Menges] - Update `attributes-json.tpl`, set `system` cookbook to restart network immediately on set
- [Brian Menges] - Alphabetize `attributes-json.tpl`, except for `fqdn`
- [Brian Menges] - Add attributes and run_list to setup chef-client as cron job with splay
- [Brian Menges] - Replaced `analytics_fqdn` with `api_fqdn` to prevent duplicate line entry in `opscode-analytics.rb` generation

v0.1.6 (2016-04-14)
-------------------
- [Brian Menges] - Remove `fqdn` from `attributes-json.tpl`: conflicting duplicate entry during first chef-client run

v0.1.5 (2016-04-14)
-------------------
- [Brian Menges] - DNS can be slow... adding laziness to API call

v0.1.4 (2016-04-14)
-------------------
- [Brian Menges] - Missing decleration `provider "aws"`

v0.1.3 (2016-04-14)
-------------------
- [Brian Menges] - Change instance provision ami lookup

v0.1.2 (2016-04-13)
-------------------
- [Brian Menges] - Fix execution of chef_api_request

v0.1.1 (2016-04-13)
-------------------
- [Brian Menges] - Add `log_to_file` variable for chef-client runtime logging

v0.1.0 (2016-04-13)
-------------------
- [Brian Menges] - Reformat [CHANGELOG.md](CHANGELOG.md)
- [Brian Menges] - Remove Route53 hooks
- [Brian Menges] - Add `client_version` variable for chef-client version control
- [Brian Menges] - Documentation updates
- [Brian Menges] - Add `public_ip` input variable to indicate public IP association to AWS instance

v0.0.1 (2016-03-28)
-------------------
- [Brian Menges] - initial commit

