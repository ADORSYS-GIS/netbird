# Discover running EC2 instances with specified tags
data "aws_instances" "netbird" {
  filter {
    name   = "tag:${var.tag_key}"
    values = var.tag_values
  }

  filter {
    name   = "instance-state-name"
    values = ["running"]
  }
}

# Get detailed information for each discovered instance
data "aws_instance" "details" {
  for_each    = toset(data.aws_instances.netbird.ids)
  instance_id = each.value
}

# Transform AWS instances into standardized VM format
locals {
  vms = [for id, instance in data.aws_instance.details : {
    name        = lookup(instance.tags, "Name", id)
    public_ip   = instance.public_ip
    private_ip  = instance.private_ip
    ssh_user    = var.ssh_user
    roles       = split(",", lookup(instance.tags, var.tag_key, "netbird-primary"))
    cloud       = "aws"
    region      = instance.availability_zone
    instance_id = id
  }]
}
