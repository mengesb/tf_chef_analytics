# Outputs
output "fqdn" {
  value = "${aws_instance.chef-analytics.tags.Name}"
}
output "private_ip" {
  value = "${aws_instance.chef-analytics.private_ip}"
}
output "public_ip" {
  value = "${aws_instance.chef-analytics.public_ip}"
}
output "security_group_id" {
  value = "${aws_security_group.chef-analytics.id}"
}

