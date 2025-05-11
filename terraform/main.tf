provider "aws" {
  region = var.aws_region
}

# VPC and Networking
# module "vpc" {
#   source = "./modules/vpc"

#   vpc_cidr             = var.vpc_cidr
#   availability_zones   = var.availability_zones
#   private_subnet_cidrs = var.private_subnet_cidrs
#   public_subnet_cidrs  = var.public_subnet_cidrs
# }

# EKS Cluster
# module "eks" {
#   source  = "terraform-aws-modules/eks/aws"
#   version = "19.21.0"

#   cluster_name    = "mern-cluster-new"
#   cluster_version = var.cluster_version
#   vpc_id          = module.vpc.vpc_id
#   subnet_ids      = concat(module.vpc.private_subnet_ids, module.vpc.public_subnet_ids)

#   eks_managed_node_groups = {
#     general = {
#       desired_size = 2
#       min_size     = 1
#       max_size     = 3

#       instance_types = ["t3.medium"]
#       capacity_type  = "ON_DEMAND"
#     }
#   }
# }

# Get current AWS account ID and user ARN
data "aws_caller_identity" "current" {}

# AWS Load Balancer Controller IAM Policy
resource "aws_iam_policy" "aws_load_balancer_controller" {
  name        = "AWSLoadBalancerControllerIAMPolicy"
  description = "Policy for AWS Load Balancer Controller"
  policy      = file("${path.module}/aws-load-balancer-controller-policy.json")
}

# AWS Load Balancer Controller IAM Role
module "aws_load_balancer_controller_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name                     = "aws-load-balancer-controller"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks_new.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  depends_on = [module.eks_new]
}

# Add a delay to ensure cluster is ready
resource "time_sleep" "wait_for_cluster" {
  depends_on = [module.eks_new]
  create_duration = "30s"
}

# Create IAM role for EKS admin
resource "aws_iam_role" "eks_admin" {
  name = "eks-admin-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::814022331516:user/cli-user"
        }
      }
    ]
  })
}

# Attach EKS admin policies to the role
resource "aws_iam_role_policy_attachment" "eks_admin_cluster" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_admin.name
}

resource "aws_iam_role_policy_attachment" "eks_admin_service" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.eks_admin.name
}

# Create a separate file for Kubernetes resources
resource "local_file" "k8s_manifest" {
  content = templatefile("${path.module}/templates/k8s-manifest.tpl", {
    cluster_name = var.cluster_name
    region       = var.aws_region
    aws_load_balancer_controller_role_arn = module.aws_load_balancer_controller_irsa.iam_role_arn
  })
  filename = "${path.module}/k8s-manifest.yaml"
}

resource "null_resource" "k8s_setup" {
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]  # Force Bash instead of default /bin/sh
    command = <<-EOT
      if [ ! -x /usr/local/bin/kubectl ]; then
        echo "kubectl is not installed or not executable at /usr/local/bin/kubectl"
        exit 1
      fi

      aws eks update-kubeconfig --name ${var.cluster_name} --region ${var.aws_region}

      /usr/local/bin/kubectl apply -f ${path.module}/aws-auth.yaml
      /usr/local/bin/kubectl apply -f ${path.module}/k8s-manifest.yaml
    EOT
  }



  depends_on = [
    module.eks_new,
    time_sleep.wait_for_cluster,
    local_file.k8s_manifest
  ]
} 