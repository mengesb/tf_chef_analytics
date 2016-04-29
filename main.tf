# Chef Analytics AWS security group https://docs.chef.io/server_firewalls_and_ports.html#chef-analytics-title
resource "aws_security_group" "chef-analytics" {
  name        = "${var.hostname}.${var.domain} security group"
  description = "Analytics server ${var.hostname}.${var.domain}"
  vpc_id      = "${var.aws_vpc_id}"
  tags        = {
    Name      = "${var.hostname}.${var.domain} security group"
  }
}
# SSH - allowed_cidrs
resource "aws_security_group_rule" "chef-analytics_allow_22_tcp_all" {
  type        = "ingress"
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["${split(",", var.allowed_cidrs)}"]
  security_group_id = "${aws_security_group.chef-analytics.id}"
}
# HTTP (nginx)
resource "aws_security_group_rule" "chef-analytics_allow_80_tcp_all" {
  type        = "ingress"
  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.chef-analytics.id}"
}
# HTTPS (nginx)
resource "aws_security_group_rule" "chef-analytics_allow_443_tcp_all" {
  type        = "ingress"
  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.chef-analytics.id}"
}
# Analytics -> Chef Server RabbitMQ
resource "aws_security_group_rule" "chef-server_allow_all_chef-analytics" {
  type        = "ingress"
  from_port   = 5672
  to_port     = 5672
  protocol    = "tcp"
  source_security_group_id = "${aws_security_group.chef-analytics.id}"
  security_group_id = "${var.chef_sg}"
}
# Egress: ALL
resource "aws_security_group_rule" "chef-analytics_allow_all" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.chef-analytics.id}"
}
# AWS settings
provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region     = "${var.aws_region}"
}
#
# Provisioning template
#
resource "template_file" "attributes-json" {
  template = "${file("${path.module}/files/attributes-json.tpl")}"
  vars {
    cert      = "/var/opt/analytics/ssl/${var.hostname}.${var.domain}.crt"
    domain    = "${var.domain}"
    host      = "${var.hostname}"
    cert_key  = "/var/opt/analytics/ssl/${var.hostname}.${var.domain}.key"
  }
}
#
# Wait on
#
resource "null_resource" "wait_on" {
  provisioner "local-exec" {
    command = "echo Waited on ${var.wait_on} before proceeding"
  }
}
#
# Analytics oc-id
#
resource "null_resource" "oc_id-analytics" {
  depends_on = ["template_file.attributes-json","null_resource.wait_on"]
  connection {
    user        = "${lookup(var.ami_usermap, var.ami_os)}"
    private_key = "${var.aws_private_key_file}"
    host        = "${var.chef_fqdn}"
  }
  # Generate new attributes file with analytics oc_id subscription
  provisioner "local-exec" {
    command = <<-EOC
      set +x
      rm -rf .analytics ; mkdir -p .analytics
      echo "Artifical sleep...ZZzzZZzz" && sleep 30
      bash ${path.module}/files/chef_api_request GET "/nodes/${var.chef_fqdn}" | jq '.normal' > .analytics/attributes.json.orig
      grep -q 'configuration' .analytics/attributes.json.orig
      [ $? -ne 0 ] && rm -f .analytics/attributes.json.orig && echo "Taking another 30s nap" && sleep 30 && bash ${path.module}/files/chef_api_request GET "/nodes/${var.chef_fqdn}" | jq '.normal' > .analytics/attributes.json.orig
      cp .analytics/attributes.json.orig .analytics/attributes.json
      grep -q 'rabbitmq' .analytics/attributes.json.orig
      rabbit=$?
      # Delete any potentially existing rabbitmq configuration that will hurt us
      [ $rabbit -eq 0 ] && sed "s/rabbitmq\['vip'\][[:space:]]=[[:space:]]'\([[:digit:]]*\.\)\{3\}[[:digit:]]*'\\\n//"             .analytics/attributes.json > .analytics/attributes.json.new
      [ -f .analytics/attributes.json.new ] && mv .analytics/attributes.json.new .analytics/attributes.json
      [ $rabbit -eq 0 ] && sed "s/rabbitmq\['node_ip_address'\][[:space:]]=[[:space:]]'\([[:digit:]]*\.\)\{3\}[[:digit:]]*'\\\n//" .analytics/attributes.json > .analytics/attributes.json.new
      [ -f .analytics/attributes.json.new ] && mv .analytics/attributes.json.new .analytics/attributes.json
      # Look for existing oc_id['applications']
      grep -q 'applications' .analytics/attributes.json.orig
      result=$?
      # FOUND... appending
      [ $result -eq 0 ] && sed "s/\(applications.*\\\n  }\)\\\n/\1,\\\n  'analytics' => {\\\n    'redirect_uri' => 'https:\/\/${var.hostname}.${var.domain}\/'\\\n  }\\\n/" .analytics/attributes.json > .analytics/attributes.json.new
      [ -f .analytics/attributes.json.new ] && mv .analytics/attributes.json.new .analytics/attributes.json
      [ $result -eq 0 ] && sed "s/\(configuration.*\)\",/\1\\\nrabbitmq['vip'] = '${var.chef_ip}'\\\nrabbitmq['node_ip_address'] = '0.0.0.0'\\\n\",/"                       .analytics/attributes.json > .analytics/attributes.json.new
      [ -f .analytics/attributes.json.new ] && mv .analytics/attributes.json.new .analytics/attributes.json
      # NOT FOUND... adding
      [ $result -ne 0 ] && sed "s/\(configuration.*\)\",/\1\\\nrabbitmq['vip'] = '${var.chef_ip}'\\\nrabbitmq['node_ip_address'] = '0.0.0.0'\\\noc_id['applications'] = {\\\n  'analytics' => {\\\n    'redirect_uri' => 'https:\/\/${var.hostname}.${var.domain}\/'\\\n  }\\\n}\\\n\",/" .analytics/attributes.json > .analytics/attributes.json.new
      [ -f .analytics/attributes.json.new ] && mv .analytics/attributes.json.new .analytics/attributes.json
      tee .analytics/rabbitmq.modify <<EOF
      rabbitmq['vip'] = '${var.chef_ip}'
      rabbitmq['node_ip_address'] = '0.0.0.0'
      EOF
      echo "Modified Chef server attributes at .analytics/attributes.json"
      EOC
  }
  # Upload new attributes file
  provisioner "file" {
    source      = ".analytics/attributes.json"
    destination = "attributes.json"
  }
  # Upload new rabbitmq settings
  provisioner "file" {
    source      = ".analytics/rabbitmq.modify"
    destination = "rabbitmq.modify"
  }
  # Execute new Chef run if no analytics.json exists
  # https://docs.chef.io/install_analytics.html
  provisioner "remote-exec" {
    inline = [
      "rm -rf .analytics ; mkdir -p .analytics",
      "[ -f /etc/opscode/oc-id-applications/analytics.json ] && analytics=0 || analytics=1",
      "if [ $analytics -eq 0 ]",
      "then",
      "  echo Existing configuration found... harvesting",
      "  sudo cp /etc/opscode/oc-id-applications/analytics.json .analytics/analytics.json",
      "  sudo cp /etc/opscode-analytics/actions-source.json .analytics/actions-source.json",
      "  sudo chown ${lookup(var.ami_usermap, var.ami_os)} .analytics/analytics.json .analytics/actions-source.json",
      "  exit 0",
      "fi",
      "sudo grep -q rabbitmq /etc/opscode/chef-server.rb",
      "if [ $? -eq 0 ]",
      "then",
      "  sudo grep rabbitmq /etc/opscode/chef-server.rb > .analytics/rabbitmq.saved",
      "  sudo chown ${lookup(var.ami_usermap, var.ami_os)} .analytics/rabbitmq.saved",
      "  sudo sed -i.bak '/rabbitmq/d' /etc/opscode/chef-server.rb",
      "fi",
      "sudo chef-server-ctl stop",
      "cat rabbitmq.modify | sudo tee -a /etc/opscode/chef-server.rb",
      "echo '/etc/opscode/chef-server.rb contents:' && sudo cat /etc/opscode/chef-server.rb",
      "sudo chef-server-ctl reconfigure",
      "sudo chef-server-ctl restart",
      "sudo opscode-manage-ctl reconfigure",
      "echo 'Taking a 15 second nap...' && sleep 15",
      "sudo chef-client -j attributes.json",
      "mv attributes.json rabbitmq.modify /tmp",
      "sudo cp /etc/opscode/oc-id-applications/analytics.json .analytics/analytics.json",
      "sudo cp /etc/opscode-analytics/actions-source.json .analytics/actions-source.json",
      "sudo chown ${lookup(var.ami_usermap, var.ami_os)} .analytics/analytics.json .analytics/actions-source.json",
    ]
  }
  # Copy back configuration
  provisioner "local-exec" {
    command = "scp -r -o StrictHostKeyChecking=no ${lookup(var.ami_usermap, var.ami_os)}@${var.chef_fqdn}:.analytics/*.json .analytics/"
  }
  # Download required cookbooks
  provisioner "local-exec" {
    command = "rm -rf cookbooks ; git clone https://github.com/chef-cookbooks/chef-analytics cookbooks/chef-analytics"
  }
  # Remove conflicting .chef directory
  provisioner "local-exec" {
    command = "rm -rf cookbooks/chef-analytics/.chef"
  }
  # Upload required cookbooks
  provisioner "local-exec" {
    command = "cd cookbooks/chef-analytics && berks install && berks upload"
  }
  # Clean up
  provisioner "local-exec" {
    command = "rm -rf cookbooks"
  }
}
#
# Accept Chef MLSA
#
resource "null_resource" "chef_mlsa" {
  depends_on = ["null_resource.oc_id-analytics"]
  count = "${var.accept_license}"
  provisioner "local-exec" {
    command = "touch .analytics/.license.accepted"
  }
}
#
# Provision server
#
resource "aws_instance" "chef-analytics" {
  depends_on    = ["null_resource.wait_on","null_resource.oc_id-analytics","null_resource.chef_mlsa"]
  ami           = "${lookup(var.ami_map, "${var.ami_os}-${var.aws_region}")}"
  count         = "${var.server_count}"
  instance_type = "${var.aws_flavor}"
  associate_public_ip_address = "${var.public_ip}"
  subnet_id     = "${var.aws_subnet_id}"
  vpc_security_group_ids = ["${aws_security_group.chef-analytics.id}"]
  key_name      = "${var.aws_key_name}"
  tags = {
    Name        = "${var.hostname}.${var.domain}"
    Description = "${var.tag_description}"
  }
  root_block_device = {
    delete_on_termination = "${var.root_delete_termination}"
  }
  connection {
    user        = "${lookup(var.ami_usermap, var.ami_os)}"
    private_key = "${var.aws_private_key_file}"
    host        = "${self.public_ip}"
  }
  # Clean up any potential node/client conflicts
  provisioner "local-exec" {
    command = "knife node-delete   ${var.hostname}.${var.domain} -y -c ${var.knife_rb} ; echo OK"
  }
  provisioner "local-exec" {
    command = "knife client-delete ${var.hostname}.${var.domain} -y -c ${var.knife_rb} ; echo OK"
  }
  # Handle iptables
  provisioner "remote-exec" {
    inline = [
      "sudo service iptables stop",
      "sudo chkconfig iptables off",
      "sudo ufw disable",
      "echo Say WHAT one more time"
    ]
  }
  # Prepare some directories to stage files
  provisioner "remote-exec" {
    inline = [
      "mkdir -p .analytics",
      "sudo mkdir -p /etc/opscode-analytics /var/opt/opscode-analytics/ssl",
    ]
  }
  # Transfer in required files
  provisioner "file" {
    source      = ".analytics/.license.accepted"
    destination = ".analytics/.license.accepted"
  }
  provisioner "file" {
    source      = ".analytics/actions-source.json"
    destination = ".analytics/actions-source.json"
  }
  provisioner "file" {
    source      = "${var.ssl_cert}"
    destination = ".analytics/${var.hostname}.${var.domain}.crt"
  }
  provisioner "file" {
    source      = "${var.ssl_key}"
    destination = ".analytics/${var.hostname}.${var.domain}.key"
  }
  # Move files to final location
  provisioner "remote-exec" {
    inline = [
      "sudo mv .analytics/.license.accepted /var/opt/opscode-analytics/.license.accepted",
      "sudo mv .analytics/${var.hostname}.${var.domain}.* /var/opt/opscode-analytics/ssl",
      "sudo mv .analytics/actions-source.json /etc/opscode-analytics/actions-source.json",
      "sudo chown -R root:root /etc/opscode-analytics /var/opt/opscode-analytics",
    ]
  }
  # Provision with Chef
  provisioner "chef" {
    attributes_json = "${template_file.attributes-json.rendered}"
    environment     = "_default"
    run_list        = ["recipe[system::default]","recipe[chef-client::default]","recipe[chef-client::config]","recipe[chef-client::cron]","recipe[chef-client::delete_validation]","recipe[chef-analytics::default]"]
    log_to_file     = "${var.log_to_file}"
    node_name       = "${aws_instance.chef-analytics.tags.Name}"
    server_url      = "https://${var.chef_fqdn}/organizations/${var.chef_org}"
    validation_client_name = "${var.chef_org}-validator"
    validation_key  = "${file("${var.chef_org_validator}")}"
    version         = "${var.client_version}"
  }
}

