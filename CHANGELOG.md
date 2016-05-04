tf_chef_analytics CHANGELOG
========================

This file is used to list changes made in each version of the tf_chef_analytics Terraform plan.

v1.3.0 (2016-05-24)
-------------------
- [Brian Menges] - Added a [CONTRIBUTING](CONTRIBUTING.md) document
- [Brian Menges] - Updated [README.md](README.md) to refer to [CONTRIBUTING](CONTRIBUTING.md) document
- [Brian Menges] - Updated `client_version` to `12.10.24`
- [Brian Menges] - Replaced remote-exec for firewall disables with a script [disable_firewall.sh](files/disable_firewall.sh)
- [Brian Menges] - Replaced local execute for chef cookbooks with [chef-cookbooks.sh](files/chef-cookbooks.sh) script
- [Brian Menges] - Added [terraform.tfvars.example](terraform.tfvars.example) to provide an example for `terraform.tfvars`
- [Brian Menges] - Documentation updates


v1.2.3 (2016-05-03)
-------------------
- [Brian Menges] - Fixed syntax issue in [main.tf](main.tf), missing comma in remote-exec call

v1.2.2 (2016-05-03)
-------------------
- [Brian Menges] - Adding manual '.license.accepted' method to accepting Chef MLSA

v1.2.1 (2016-05-03)
-------------------
- [Brian Menges] - Finally fixed Chef MLSA handling

v1.2.0 (2016-05-03)
-------------------
- [Brian Menges] - missed [CHANGELOG.md](CHANGELOG.md) in prior commit

v1.1.9 (2016-05-03)
-------------------
- [Brian Menges] - missed [main.tf](main.tf) in prior commit

v1.1.8 (2016-05-03)
-------------------
- [Brian Menges] - Too many issues using `null_resource.oc_id-analytics`. Using `null_resource.chef_mlsa` now

v1.1.7 (2016-05-03)
-------------------
- [Brian Menges] - Somehow tabs got into this thing...

v1.1.6 (2016-05-02)
-------------------
- [Brian Menges] - Terraform variables in `terraform.tfvars` or command-line are strings, not boolean like in `variables.tf` or other plan files

v1.1.5 (2016-05-02)
-------------------
- [Brian Menges] - Cookbook chef-analytics not updated to handle `accept_license` upstream.
- [Brian Menges] - Revised Chef MLSA acceptance method using existing `null_resource.oc_id-analytics` resource

v1.1.4 (2016-05-02)
-------------------
- [Brian Menges] - Remove tags on root_block_device

v1.1.3 (2016-05-02)
-------------------
- [Brian Menges] - Replaced `accept_license` numeric with boolean. Now part of `template_file.attributes-json`
- [Brian Menges] - Added `volume_size` and `volume_type` specifications and `root_` variables for mentioned tunables to instance deployted
- [Brian Menges] - Removed `null_resource` for Chef MLSA handles
- [Brian Menges] - Added `analytics_version` to specify Chef Analytics installation version
- [Brian Menges] - Set default `root_volume_size` to 20 GB
- [Brian Menges] - Set default `root_volume_type` to `standard`
- [Brian Menges] - Added Name tag to `root_block_device` of `${var.hostname}.${var.domain} /`
- [Brian Menges] - NOTE: incompatible with root type `io1`
- [Brian Menges] - Fidgiting with `api_fqdn` in [attributes-json.tpl](files/attributes-json.tpl)

v1.1.2 (2016-04-29)
-------------------
- [Brian Menges] - Fix certificate location in template

v1.1.1 (2016-04-28)
-------------------
- [Brian Menges] - Chef now requires accepting their MLSA. Added handles for that
- [Brian Menges] - Variable `accept_license` accepts `0` for false (default) and `1` for true (required)
- [Brian Menges] - Updated `/var/opt/analytics` to `/var/opt/opscode-analytics`
- [Brian Menges] - Added `null_resource` handles to take care of `accept_license`

v1.1.0 (2016-04-25)
-------------------
- [Brian Menges] - Update comments to several segments
- [Brian Menges] - Remove sg <-> sg global between Analytics and Chef Server
- [Brian Menges] - Remove unnecessary template write

v1.0.7 (2016-04-22)
-------------------
- [Brian Menges] - Because `sed` sucks across platforms, doing some awful things

v1.0.6 (2016-04-21)
-------------------
- [Brian Menges] - Updated usage of `wait_on`

v1.0.5 (2016-04-20)
-------------------
- [Brian Menges] - Syntax issue in a remote-exec

v1.0.4 (2016-04-20)
-------------------
- [Brian Menges] - Removed template method to generate scripts - intrepreting ${ ... } in the script

v1.0.3 (2016-04-20)
-------------------
- [Brian Menges] - remote_oc_script template using wrong template source; fixed

v1.0.2 (2016-04-20)
-------------------
- [Brian Menges] - Files not pushed in commit

v1.0.1 (2016-04-20)
-------------------
- [Brian Menges] - Convert large remote/local-exec blocks to template written scripts and execute
- [Brian Menges] - Add chef-client::cron to run_list

v1.0.0 (2016-04-20)
-------------------
- [Brian Menges] - `api_fqdn` in [attributes-json.tpl](files/attributes-json.tpl) not correct until second run. Using `analytics_fqdn` again
- [Brian Menges] - Insert `null_resource.wait_on` into aws instance creation
- [Brian Menges] - Release v1.0.0

v0.1.17 (2016-04-19)
-------------------
- [Brian Menges] - replaced echo with tee + HEREDOC

v0.1.16 (2016-04-19)
-------------------
- [Brian Menges] - Still working on getting analytics to deploy right

v0.1.15 (2016-04-19)
-------------------
- [Brian Menges] - Using `wait_on` in `null_resource` to enforce waiting

v0.1.14 (2016-04-18)
-------------------
- [Brian Menges] - Adding variable `wait_on` to handle waiting on other module outputs

v0.1.13 (2016-04-18)
-------------------
- [Brian Menges] - Removed file size check, replaced with `grep -q`
- [Brian Menges] - Redirect echo into file

v0.1.12 (2016-04-18)
-------------------
- [Brian Menges] - Fixed deleting files after transfered in
- [Brian Menges] - Fixed math on `f_size`

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

