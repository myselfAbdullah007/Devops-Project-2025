aws_region    = "us-east-1"
environment   = "production"
cluster_name  = "mern-cluster"
desired_nodes = 2
min_nodes     = 1
max_nodes     = 3
backend_image = "myselfabii/mern-backend:latest"  # Replace with your actual backend image
frontend_image = "myselfabii/mern-frontend:latest"  # Replace with your actual frontend image 