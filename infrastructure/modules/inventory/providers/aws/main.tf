terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

data "aws_instances" "netbird" {
  dynamic "filter" {
    for_each = var.tag_filters
    content {
      name   = "tag:${filter.key}"
      values = [filter.value == "*" ? "*" : filter.value] # Glob support needs explicit list usually, but * works in AWS filter values
    }
  }

  filter {
    name   = "instance-state-name"
    values = ["running"]
  }
}

data "aws_instance" "details" {
  for_each    = toset(data.aws_instances.netbird.ids)
  instance_id = each.value
}

locals {
  instances = [
    for id, inst in data.aws_instance.details : {
      ip        = inst.private_ip
      public_ip = inst.public_ip
      hostname  = try(inst.tags["Name"], id)
      role      = try(inst.tags["NetBirdRole"], "unknown")
      cloud     = "aws"
      # Network details
      vpc_id          = try(inst.vpc_id, null)
      subnet_id       = try(inst.subnet_id, null)
      security_groups = try(inst.vpc_security_group_ids, [])

      # Metadata
      az          = inst.availability_zone
      instance_id = id
    }
  ]
}
