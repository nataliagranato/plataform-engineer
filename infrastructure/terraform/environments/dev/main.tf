terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Environment   = var.environment
      Project       = var.project_name
      ManagedBy     = "terraform"
      Owner         = var.team
    }
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# VPC Module
module "vpc" {
  source = "../modules/vpc"
  
  name             = "${var.project_name}-${var.environment}"
  cidr             = var.vpc_cidr
  azs              = var.availability_zones
  private_subnets  = var.private_subnets
  public_subnets   = var.public_subnets
  
  enable_nat_gateway = true
  enable_vpn_gateway = false
  enable_dns_hostnames = true
  enable_dns_support = true
  
  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# EKS Cluster Module
module "eks" {
  source = "../modules/eks"
  
  cluster_name    = "${var.project_name}-${var.environment}"
  cluster_version = var.cluster_version
  
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnets
  
  node_groups = {
    platform = {
      instance_types = ["t3.large"]
      capacity_type  = "ON_DEMAND"
      min_size       = 2
      max_size       = 10
      desired_size   = 3
      
      labels = {
        role = "platform"
      }
      
      taints = {
        dedicated = {
          key    = "platform"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      }
    }
    
    applications = {
      instance_types = ["t3.medium"]
      capacity_type  = "SPOT"
      min_size       = 1
      max_size       = 20
      desired_size   = 2
      
      labels = {
        role = "applications"
      }
    }
  }
  
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }
  
  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# RDS Module for Backstage
module "backstage_db" {
  source = "../modules/rds"
  
  identifier = "${var.project_name}-${var.environment}-backstage"
  
  engine         = "postgres"
  engine_version = "15.4"
  instance_class = "db.t3.micro"
  allocated_storage = 20
  storage_encrypted = true
  
  database_name = "backstage"
  username      = "backstage"
  
  vpc_security_group_ids = [module.security_groups.backstage_db_sg_id]
  db_subnet_group_name   = module.vpc.database_subnet_group
  
  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"
  
  deletion_protection = var.environment == "prod" ? true : false
  skip_final_snapshot = var.environment != "prod" ? true : false
  
  tags = {
    Environment = var.environment
    Project     = var.project_name
    Service     = "backstage"
  }
}

# Security Groups Module
module "security_groups" {
  source = "../modules/security-groups"
  
  name   = "${var.project_name}-${var.environment}"
  vpc_id = module.vpc.vpc_id
  
  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# ECR Repositories
resource "aws_ecr_repository" "repositories" {
  for_each = toset(var.ecr_repositories)
  
  name = "${var.project_name}/${each.value}"
  
  image_tag_mutability = "MUTABLE"
  
  image_scanning_configuration {
    scan_on_push = true
  }
  
  encryption_configuration {
    encryption_type = "AES256"
  }
  
  lifecycle_policy {
    policy = jsonencode({
      rules = [
        {
          rulePriority = 1
          description  = "Keep last 30 images"
          selection = {
            tagStatus     = "tagged"
            tagPrefixList = ["v"]
            countType     = "imageCountMoreThan"
            countNumber   = 30
          }
          action = {
            type = "expire"
          }
        },
        {
          rulePriority = 2
          description  = "Delete untagged images older than 1 day"
          selection = {
            tagStatus   = "untagged"
            countType   = "sinceImagePushed"
            countUnit   = "days"
            countNumber = 1
          }
          action = {
            type = "expire"
          }
        }
      ]
    })
  }
  
  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}
