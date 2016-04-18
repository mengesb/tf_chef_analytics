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
# Chef Server -> Analytics
resource "aws_security_group_rule" "chef-analytics_allow_all_chef-server" {
  type        = "ingress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  source_security_group_id = "${var.chef_sg}"
  security_group_id = "${aws_security_group.chef-analytics.id}"
}
# Analytics -> Chef Server
resource "aws_security_group_rule" "chef-server_allow_all_chef-analytics" {
  type        = "ingress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
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
# Analytics authenticates on Chef Server OC-ID service
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
resource "null_resource" "oc_id-analytics" {
  depends_on = ["template_file.attributes-json"]
  connection {
    user        = "${lookup(var.ami_usermap, var.ami_os)}"
    private_key = "${var.aws_private_key_file}"
    host        = "${var.chef_fqdn}"
  }
  # Generate new attributes file with analytics oc_id subscription
  provisioner "local-exec" {
    command = <<-EOC
      rm -rf .analytics ; mkdir -p .analytics
      echo "Artifical sleep...ZZzzZZzz" && sleep 30
      bash ${path.module}/files/chef_api_request GET "/nodes/${var.chef_fqdn}" | jq '.normal' > .analytics/attributes.json.orig
      f_size=`wc -c <.analytics/attributes.json.orig`
      [ $fsize -le 5 ] && rm -f .analytics/attributes.json.orig && echo "Taking another 30s nap" && sleep 30 && bash ${path.module}/files/chef_api_request GET "/nodes/${var.chef_fqdn}" | jq '.normal' > .analytics/attributes.json.orig
      grep -q 'applications' .analytics/attributes.json.orig
      result=$?
      [ $result -eq 0 ] && sed "s/\(configuration.*}\)\\\n}\\\n\",/\1,\\\n  'analytics' => {\\\n    'redirect_uri' => 'https:\/\/${var.hostname}.${var.domain}\/'\\\n  }\\\n}\\\\nrabbitmq['vip'] = '${var.chef_ip}'\\\nrabbitmq['node_ip_address'] = '0.0.0.0'\\\n\",/" .analytics/attributes.json.orig > .analytics/attributes.json
      [ $result -ne 0 ] && sed "s/\(configuration.*\)\",/\1\\\noc_id['applications'] = {\\\n  'analytics' => {\\\n    'redirect_uri' => 'https:\/\/${var.hostname}.${var.domain}\/'\\\n  }\\\n}\\\nrabbitmq['vip'] = '${var.chef_ip}'\\\nrabbitmq['node_ip_address'] = '0.0.0.0'\\\n\",/" .analytics/attributes.json.orig > .analytics/attributes.json
      echo -en "rabbitmq['vip'] = '${var.chef_ip}'\nrabbitmq['node_ip_address'] = '0.0.0.0'\n" .analytics/rabbitmq.modify
      echo "Modified Chef server attributes at .analytics/attributes.json"
      EOC
  }
  # Upload new attributes file
  provisioner "file" {
    source      = ".analytics/attributes.json"
    destination = ".analytics/attributes.json"
  }
  # Upload new rabbitmq settings
  provisioner "file" {
    source      = ".analytics/rabbitmq.modify"
    destination = ".analytics/rabbitmq.modify"
  }
  # Execute new Chef run if no analytics.json exists
  # https://docs.chef.io/install_analytics.html
  provisioner "remote-exec" {
    inline = [
      "rm -rf .analytics ; mkdir -p .analytics",
      "[ -f /etc/opscode/oc-id-applications/analytics.json ] && echo ABORT ABORT ABORT ABORT",
      "[ -f /etc/opscode/oc-id-applications/analytics.json ] && exit 1",
      "sudo grep -q rabbitmq /etc/opscode/chef-server.rb",
      "[ $? -eq 0 ] && sudo grep rabbitmq /etc/opscode/chef-server.rb > .analytics/rabbitmq.saved",
      "sudo chown ${lookup(var.ami_usermap, var.ami_os)} .analytics/rabbitmq.saved",
      "[ -f .analytics/rabbitmq.saved ] && sudo sed -i '/rabbitmq/d' /etc/opscode/chef-server.rb",
      "sudo chef-server-ctl stop",
      "cat .analytics/rabbitmq.hack | sudo tee -a /etc/opscode/chef-server.rb",
      "sudo chef-server-ctl reconfigure",
      "sudo chef-server-ctl restart",
      "sudo opscode-manage-ctl reconfigure",
      "sudo chef-client -j .analytics/attributes.json",
      "rm -f .analytics/attributes.json",
      "rm -f .analytics/rabbitmq.modify",
      "sudo cp /etc/opscode/oc-id-applications/analytics.json .analytics/analytics.json",
      "sudo cp /etc/opscode-analytics/actions-source.json .analytics/actions-source.json",
      "sudo chown ${lookup(var.ami_usermap, var.ami_os)} .analytics/analytics.json .analytics/actions-source.json",
    ]
  }
  # Copy back configuration
  provisioner "local-exec" {
    command = "scp -r -o StrictHostKeyChecking=no ${lookup(var.ami_usermap, var.ami_os)}@${var.chef_fqdn}:.analytics/*.json .analytics/"
  }
  provisioner "local-exec" {
    command = "rm -rf cookbooks ; git clone https://github.com/chef-cookbooks/chef-analytics cookbooks/chef-analytics"
  }
  provisioner "local-exec" {
    command = "rm -rf cookbooks/chef-analytics/.chef"
  }
  provisioner "local-exec" {
    command = "cd cookbooks/chef-analytics && berks install && berks upload"
  }
  provisioner "local-exec" {
    command = "rm -rf cookbooks"
  }
}
#
# Analytics
#
resource "aws_instance" "chef-analytics" {
  depends_on    = ["null_resource.oc_id-analytics"]
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
  provisioner "remote-exec" {
    inline = [
      "mkdir -p .analytics",
      "sudo mkdir -p /etc/opscode-analytics /var/opt/analytics/ssl",
    ]
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
  provisioner "remote-exec" {
    inline = [
      "cat > attributes.json <<EOF",
      "${template_file.attributes-json.rendered}",
      "EOF",
      ""
    ]
  }
  provisioner "remote-exec" {
    inline = [
      "sudo mv .analytics/${var.hostname}.${var.domain}.* /var/opt/analytics/ssl",
      "sudo chown -R root:root /var/opt/analytics/ssl",
      "sudo mv .analytics/actions-source.json /etc/opscode-analytics/actions-source.json",
      "sudo chown -R root:root /etc/opscode-analytics",
    ]
  }
  # Provision with Chef
  provisioner "chef" {
    attributes_json = "${template_file.attributes-json.rendered}"
    environment     = "_default"
    run_list        = ["recipe[system::default]","recipe[chef-client::default]","recipe[chef-client::config]","recipe[chef-client::delete_validation]","recipe[chef-analytics::default]"]
    log_to_file     = "${var.log_to_file}"
    node_name       = "${aws_instance.chef-analytics.tags.Name}"
    server_url      = "https://${var.chef_fqdn}/organizations/${var.chef_org}"
    validation_client_name = "${var.chef_org}-validator"
    validation_key  = "${file("${var.chef_org_validator}")}"
    version         = "${var.client_version}"
  }
}

