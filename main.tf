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
    license   = "${var.accept_license}"
    cert      = "/var/opt/opscode-analytics/ssl/${var.hostname}.${var.domain}.crt"
    domain    = "${var.domain}"
    host      = "${var.hostname}"
    cert_key  = "/var/opt/opscode-analytics/ssl/${var.hostname}.${var.domain}.key"
    version   = "${var.analytics_version}"
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
    command = "${path.module}/files/analytics-oc-id.sh -v -c ${var.chef_fqdn} -i ${var.chef_ip} -p ${path.module} -t .analytics"
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
  #
  provisioner "remote-exec" {
    script      = "${path.module}/files/apply-analytics.sh"
  }
  # Copy back configuration
  provisioner "local-exec" {
    command     = "scp -r -o StrictHostKeyChecking=no ${lookup(var.ami_usermap, var.ami_os)}@${var.chef_fqdn}:.analytics/actions-source.json .analytics/"
  }
  # Download required cookbooks
  provisioner "local-exec" {
    command     = "rm -rf cookbooks ; git clone https://github.com/chef-cookbooks/chef-analytics cookbooks/chef-analytics"
  }
  # Remove conflicting .chef directory
  provisioner "local-exec" {
    command     = "rm -rf cookbooks/chef-analytics/.chef"
  }
  # Upload required cookbooks
  provisioner "local-exec" {
    command     = "cd cookbooks/chef-analytics && berks install && berks upload"
  }
  # Clean up
  provisioner "local-exec" {
    command     = "rm -rf cookbooks"
  }
}
#
# Provision server
#
resource "aws_instance" "chef-analytics" {
  depends_on    = ["null_resource.wait_on","null_resource.oc_id-analytics"]
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
    volume_size = "${var.root_volume_size}"
    volume_type = "${var.root_volume_type}"
  }
  connection {
    user        = "${lookup(var.ami_usermap, var.ami_os)}"
    private_key = "${var.aws_private_key_file}"
    host        = "${self.public_ip}"
  }
  # Clean up any potential node/client conflicts
  provisioner "local-exec" {
    command     = "knife node-delete   ${var.hostname}.${var.domain} -y -c ${var.knife_rb} ; echo OK"
  }
  provisioner "local-exec" {
    command     = "knife client-delete ${var.hostname}.${var.domain} -y -c ${var.knife_rb} ; echo OK"
  }
  # Handle iptables
  provisioner "remote-exec" {
    script      = "${path.module}/files/disable_firewall.sh"
  }
  # Prepare some directories to stage files
  provisioner "remote-exec" {
    inline = [
      "mkdir -p .analytics",
      "sudo mkdir -p /etc/opscode-analytics /var/opt/opscode-analytics/ssl",
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
  # Move files to final location
  provisioner "remote-exec" {
    inline = [
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

