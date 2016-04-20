{
  "fqdn": "${host}.${domain}",
  "chef-analytics": {
    "configuration": {
      "analytics_fqdn": "${host}.${domain}",
      "ssl": {
        "certificate": "${cert}",
        "certificate_key": "${cert_key}"
      }
    }
  },
  "chef_client": {
    "init_style": "none"
  },
  "firewall": {
    "allow_established": true,
    "allow_ssh": true
  },
  "system": {
    "delay_network_restart": false,
    "domain_name": "${domain}",
    "manage_hostsfile": true,
    "short_hostname": "${host}"
  },
  "tags": []
}
