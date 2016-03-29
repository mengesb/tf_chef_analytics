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
  "firewall": {
    "allow_established": true,
    "allow_ssh": true
  },
  "system": {
    "short_hostname": "${host}",
    "domain_name": "${domain}",
    "manage_hostsfile": true
  },
  "tags": []
}

