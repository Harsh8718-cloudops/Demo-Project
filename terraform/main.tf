terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}


module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  name    = "demo-vpc"
  cidr    = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true
}


module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version = "20.8.5"
  name    = "demo-eks"
  kubernetes_version = "1.29"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  endpoint_public_access  = true
  endpoint_private_access = true

  enable_irsa = true

  depends_on = [module.vpc]

  eks_managed_node_groups = {
    default = {
      desired_size = 1
      min_size     = 1
      max_size     = 2

      instance_types = ["t3.medium"]

      iam_role_additional_policies = {
        worker = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
        cni    = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
        ecr    = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
      }

      additional_security_group_rules = {
        ingress_cluster_to_node_kubelet = {
          description                   = "Cluster API to kubelet"
          protocol                      = "tcp"
          from_port                     = 10250
          to_port                       = 10250
          type                          = "ingress"
          source_cluster_security_group = true
        }

        ingress_self_all = {
          description = "Node to node communication"
          protocol    = "-1"
          from_port   = 0
          to_port     = 0
          type        = "ingress"
          self        = true
        }
      }
    }
  }
}
