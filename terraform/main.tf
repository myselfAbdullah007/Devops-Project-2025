provider "aws" {
  region = var.aws_region
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

# VPC and Networking
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name = "mern-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["${var.aws_region}a", "${var.aws_region}b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  # Enable DNS hostnames and support
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Enable flow logs
  enable_flow_log                      = true
  create_flow_log_cloudwatch_log_group = true
  create_flow_log_cloudwatch_iam_role  = true

  # Tags for EKS
  tags = {
    Environment = "production"
    Project     = "mern-stack"
    "kubernetes.io/cluster/mern-cluster" = "shared"
  }

  public_subnet_tags = {
    "kubernetes.io/cluster/mern-cluster" = "shared"
    "kubernetes.io/role/elb"             = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/mern-cluster" = "shared"
    "kubernetes.io/role/internal-elb"    = "1"
  }
}

# EKS Cluster
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.0.0"

  cluster_name    = "mern-cluster"
  cluster_version = "1.28"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Enable cluster endpoint access
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true
  cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]

  # Enable IAM OIDC provider
  enable_irsa = true

  eks_managed_node_groups = {
    general = {
      desired_size = 2
      min_size     = 1
      max_size     = 3

      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"

      # Enable detailed monitoring
      enable_monitoring = true

      # Add security group rules
      vpc_security_group_ids = [aws_security_group.eks_nodes.id]
    }
  }

  tags = {
    Environment = "production"
    Project     = "mern-stack"
  }
}

# Get current AWS account ID and user ARN
data "aws_caller_identity" "current" {}

# Security group for EKS nodes
resource "aws_security_group" "eks_nodes" {
  name        = "eks-node-sg"
  description = "Security group for EKS nodes"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "eks-node-sg"
  }
}

# AWS Load Balancer Controller IAM Policy
resource "aws_iam_policy" "aws_load_balancer_controller" {
  name        = "AWSLoadBalancerControllerIAMPolicy"
  description = "Policy for AWS Load Balancer Controller"
  policy      = file("${path.module}/aws-load-balancer-controller-policy.json")
}

# AWS Load Balancer Controller IAM Role
module "aws_load_balancer_controller_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.20.0"

  role_name                     = "aws-load-balancer-controller"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}

# Install AWS Load Balancer Controller using Helm
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.4.7"

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.aws_load_balancer_controller_irsa.iam_role_arn
  }

  set {
    name  = "region"
    value = var.aws_region
  }

  set {
    name  = "vpcId"
    value = module.vpc.vpc_id
  }

  depends_on = [module.eks]
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

# Create MongoDB deployment
resource "kubernetes_deployment" "mongodb" {
  metadata {
    name = "mongodb"
    labels = {
      app = "mongodb"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "mongodb"
      }
    }

    template {
      metadata {
        labels = {
          app = "mongodb"
        }
      }

      spec {
        container {
          image = "mongo:latest"
          name  = "mongodb"

          port {
            container_port = 27017
          }

          volume_mount {
            name       = "mongodb-data"
            mount_path = "/data/db"
          }
        }

        volume {
          name = "mongodb-data"
          empty_dir {}
        }
      }
    }
  }
}

# Create MongoDB service
resource "kubernetes_service" "mongodb" {
  metadata {
    name = "mongodb"
  }

  spec {
    selector = {
      app = "mongodb"
    }

    port {
      port        = 27017
      target_port = 27017
    }
  }
}

# Create Backend deployment
resource "kubernetes_deployment" "backend" {
  metadata {
    name = "backend"
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "backend"
      }
    }

    template {
      metadata {
        labels = {
          app = "backend"
        }
      }

      spec {
        container {
          image = "myselfabii/mern-backend:latest"
          name  = "backend"
          image_pull_policy = "Always"

          port {
            container_port = 5001
          }

          env {
            name  = "MONGODB_URI"
            value = "mongodb://mongodb:27017/mern-crud"
          }

          env {
            name  = "PORT"
            value = "5001"
          }

          env {
            name  = "CORS_ORIGIN"
            value = "*"
          }

          resources {
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
            requests = {
              cpu    = "250m"
              memory = "256Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/api/health"
              port = 5001
            }
            initial_delay_seconds = 30
            period_seconds       = 10
            timeout_seconds      = 1
            failure_threshold    = 3
          }

          readiness_probe {
            http_get {
              path = "/api/health"
              port = 5001
            }
            initial_delay_seconds = 5
            period_seconds       = 5
            timeout_seconds      = 1
            failure_threshold    = 3
          }
        }
      }
    }
  }
}

# Create Backend service
resource "kubernetes_service" "backend" {
  metadata {
    name = "backend"
  }
  spec {
    selector = {
      app = "backend"
    }
    port {
      port        = 80
      target_port = 5001
      protocol    = "TCP"
    }
  }
}

# Create Frontend deployment
resource "kubernetes_deployment" "frontend" {
  metadata {
    name = "frontend"
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "frontend"
      }
    }

    template {
      metadata {
        labels = {
          app = "frontend"
        }
      }

      spec {
        container {
          image = "myselfabii/mern-frontend:latest"
          name  = "frontend"
          image_pull_policy = "Always"

          port {
            container_port = 3000
          }

          env {
            name  = "NEXT_PUBLIC_API_URL"
            value = "http://k8s-mernapp-10da5b7777-954776261.us-east-1.elb.amazonaws.com"
          }

          env {
            name  = "NODE_ENV"
            value = "production"
          }

          env {
            name  = "NEXT_TELEMETRY_DISABLED"
            value = "1"
          }

          env {
            name  = "HOSTNAME"
            value = "0.0.0.0"
          }

          env {
            name  = "PORT"
            value = "3000"
          }

          env {
            name  = "NEXT_PUBLIC_BASE_PATH"
            value = ""
          }

          env {
            name  = "NEXT_PUBLIC_ASSET_PREFIX"
            value = ""
          }

          env {
            name  = "NEXT_PUBLIC_STATIC_URL"
            value = "/_next/static"
          }

          resources {
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
            requests = {
              cpu    = "250m"
              memory = "256Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 3000
            }

            initial_delay_seconds = 30
            period_seconds       = 10
            timeout_seconds      = 1
            failure_threshold    = 3
          }

          readiness_probe {
            http_get {
              path = "/"
              port = 3000
            }

            initial_delay_seconds = 5
            period_seconds       = 5
            timeout_seconds      = 1
            failure_threshold    = 3
          }
        }
      }
    }
  }
}

# Create frontend service
resource "kubernetes_service" "frontend" {
  metadata {
    name = "frontend"
  }

  spec {
    selector = {
      app = "frontend"
    }

    port {
      port        = 80
      target_port = 3000
    }

    type = "ClusterIP"
  }
}

# Create Ingress
resource "kubernetes_ingress_v1" "app_ingress" {
  metadata {
    name = "app-ingress"
    annotations = {
      "kubernetes.io/ingress.class"                = "alb"
      "alb.ingress.kubernetes.io/scheme"          = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"     = "ip"
      "alb.ingress.kubernetes.io/backend-protocol" = "HTTP"
      "alb.ingress.kubernetes.io/group.name"      = "mern-app"
      "alb.ingress.kubernetes.io/healthcheck-path" = "/"
      "alb.ingress.kubernetes.io/success-codes"   = "200-399"
      "alb.ingress.kubernetes.io/listen-ports"    = jsonencode([{ HTTP = 80 }])
      "alb.ingress.kubernetes.io/load-balancer-attributes" = "routing.http.drop_invalid_header_fields.enabled=true"
    }
  }

  spec {
    rule {
      http {
        path {
          path      = "/_next/static"
          path_type = "Prefix"
          backend {
            service {
              name = "frontend"
              port {
                number = 80
              }
            }
          }
        }

        path {
          path      = "/_next/data"
          path_type = "Prefix"
          backend {
            service {
              name = "frontend"
              port {
                number = 80
              }
            }
          }
        }

        path {
          path      = "/_next/image"
          path_type = "Prefix"
          backend {
            service {
              name = "frontend"
              port {
                number = 80
              }
            }
          }
        }

        path {
          path      = "/static"
          path_type = "Prefix"
          backend {
            service {
              name = "frontend"
              port {
                number = 80
              }
            }
          }
        }

        path {
          path      = "http://k8s-mernapp-10da5b7777-954776261.us-east-1.elb.amazonaws.com/api"
          path_type = "Prefix"
          backend {
            service {
              name = "backend"
              port {
                number = 80
              }
            }
          }
        }

        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "frontend"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
} 