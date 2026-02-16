variable "manual_hosts" {
  description = "List of manual hosts"
  type        = list(any)
}

locals {
  instances = [
    for h in var.manual_hosts : {
      ip        = h.ip
      public_ip = try(h.public_ip, "")
      hostname  = h.hostname
      role      = h.role
      cloud     = "manual"
      ssh_user  = try(h.ssh_user, "ubuntu") # Allow override
      metadata  = {}
    }
  ]
}

output "instances" {
  value = local.instances
}
