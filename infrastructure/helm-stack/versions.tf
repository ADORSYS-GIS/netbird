terraform {
  required_version = \">= 1.6.0\"

  required_providers {
    aws = {
      source  = \"hashicorp/aws\"
      version = \"~> 5.0\"
    }
    kubernetes = {
      source  = \"hashicorp/kubernetes\"
      version = \"~> 2.0\"
    }
    helm = {
      source  = \"hashicorp/helm\"
      version = \"~> 2.0\"
    }
    random = {
      source  = \"hashicorp/random\"
      version = \"~> 3.0\"
    }
  }
}

provider \"aws\" {
  region = var.aws_region
}

data \"aws_eks_cluster_auth\" \"cluster\" {
  name = module.eks.cluster_name
}

provider \"kubernetes\" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider \"helm\" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}
