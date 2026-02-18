locals {
  instances = [
    for hostname, config in var.netbird_hosts : {
      hostname  = hostname
      public_ip = config.public_ip
      ip        = coalesce(config.private_ip, config.public_ip)
      roles     = config.roles
      ssh_user  = config.ssh_user
    }
  ]

  management_nodes    = [for i in local.instances : i if contains(i.roles, "management")]
  relay_nodes         = [for i in local.instances : i if contains(i.roles, "relay")]
  reverse_proxy_nodes = [for i in local.instances : i if contains(i.roles, "proxy")]
}
