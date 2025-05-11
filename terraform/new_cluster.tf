module "vpc_new" {
  source = "./modules/vpc"

  vpc_cidr             = "10.1.0.0/16"
  availability_zones   = ["us-east-1a", "us-east-1b"]
  private_subnet_cidrs = ["10.1.1.0/24", "10.1.2.0/24"]
  public_subnet_cidrs  = ["10.1.101.0/24", "10.1.102.0/24"]
}

module "eks_new" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = "mern-cluster-new"
  cluster_version = "1.27"

  vpc_id     = module.vpc_new.vpc_id
  subnet_ids = concat(module.vpc_new.private_subnets, module.vpc_new.public_subnets)

  eks_managed_node_groups = {
    general = {
      desired_size = 2
      min_size     = 1
      max_size     = 3

      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
    }
  }

  # Use separate IAM role policy resources instead of inline policies
  create_iam_role = true
  iam_role_use_name_prefix = false
  iam_role_name = "mern-cluster-new-role"
} 