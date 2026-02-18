variable "netbird_hosts" {
  description = "Map of hosts for NetBird deployment"
  type = map(object({
    public_ip  = string
    private_ip = optional(string)
    roles      = list(string) # ["management", "relay", "proxy"]
    ssh_user   = optional(string, "ubuntu")
  }))
}
