# Configure AWS provider
provider "aws" {
  region = "us-east-1"  # Change to your region
  profile = "olabode"  # Change to your AWS CLI profile if needed
}

# 1. Create VPC for EKS
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "url-shortener-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true  # Cost-saving for dev
}

# 2. Create ECR repository for Docker images
resource "aws_ecr_repository" "url_shortener" {
  name                 = "url-shortener"
  image_tag_mutability = "MUTABLE"  # Allow same tag overwrites (set to "IMMUTABLE" for prod)

  image_scanning_configuration {
    scan_on_push = true  # Enable vulnerability scanning
  }
}

# 3. Create EKS cluster
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.16.0"

  cluster_name    = "url-shortener-eks"
  cluster_version = "1.28"
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnets
  enable_irsa     = true  # Enable IAM Roles for Service Accounts (IRSA)

  eks_managed_node_groups = {
    default = {
      min_size     = 1
      max_size     = 3
      desired_size = 1
      instance_types = ["t3.small"]
      capacity_type  = "SPOT"  # Save costs
    }
  }
}

# Output ECR repository URL for CI/CD
output "ecr_repository_url" {
  value = aws_ecr_repository.url_shortener.repository_url
}

# Output EKS cluster name for kubectl
output "eks_cluster_name" {
  value = module.eks.cluster_name
}
