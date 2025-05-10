variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "mern-cluster"
}

variable "node_instance_type" {
  description = "EC2 instance type for the node groups"
  type        = string
  default     = "t3.medium"
}

variable "desired_nodes" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "min_nodes" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "max_nodes" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 3
}

variable "backend_image" {
  description = "Backend container image"
  type        = string
  default     = "your-backend-image:latest"  # Replace with your actual backend image
}

variable "frontend_image" {
  description = "Frontend container image"
  type        = string
  default     = "your-frontend-image:latest"  # Replace with your actual frontend image
} 