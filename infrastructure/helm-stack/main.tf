# Provision the EKS cluster (example using module)
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.28"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    default = {
      instance_types = ["t3.medium"]
      min_size       = 2
      max_size       = 5
      desired_size   = 3
    }
  }

  tags = {
    Environment = var.environment
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = {
    Environment = var.environment
  }
}

module "database" {
  source = "../modules/database"

  database_type = var.database_type
  database_mode = var.database_mode
  enable_ha     = true

  cloud_provider = var.cloud_provider
  vpc_id         = module.vpc.vpc_id
  subnet_ids     = module.vpc.private_subnets

  tags = { Environment = var.environment }
}

module "keycloak" {
  source = "../modules/keycloak"

  keycloak_url   = var.keycloak_url
  realm_name     = var.keycloak_realm
  netbird_domain = var.netbird_domain
}

resource "kubernetes_namespace" "netbird" {
  metadata {
    name = var.namespace
  }
}

resource "helm_release" "netbird" {
  name       = "netbird"
  repository = "https://netbirdio.github.io/netbird-helm"
  chart      = "netbird"
  version    = var.helm_chart_version
  namespace  = kubernetes_namespace.netbird.metadata[0].name

  values = [
    templatefile("${path.module}/templates/values.yaml.tpl", {
      netbird_domain    = var.netbird_domain
      netbird_version   = var.netbird_version
      database_engine   = module.database.database_engine
      database_dsn      = module.database.database_dsn
      database_host     = module.database.database_endpoint
      database_port     = module.database.database_port
      database_name     = module.database.database_name
      database_user     = module.database.database_username
      database_pass     = module.database.database_password
      database_sslmode  = module.database.database_sslmode
      keycloak_url      = var.keycloak_url
      keycloak_realm    = module.keycloak.realm_name
      keycloak_client_id = module.keycloak.client_id
      keycloak_oidc_endpoint = module.keycloak.oidc_config_endpoint
      relay_auth_secret  = random_password.relay_auth_secret.result
      netbird_encryption_key = random_id.netbird_encryption_key.b64_std
    })
  ]

  depends_on = [module.eks, module.database, module.keycloak]
}

resource "random_password" "relay_auth_secret" {
  length  = 32
  special = true
}

resource "random_id" "netbird_encryption_key" {
  byte_length = 32
}
