# MERN Stack Application Deployment on AWS EKS

This repository contains the infrastructure and deployment configurations for deploying a MERN (MongoDB, Express.js, React.js, Node.js) stack application on AWS EKS (Elastic Kubernetes Service).

## Prerequisites

- AWS CLI installed and configured
- Terraform installed (version >= 1.0.0)
- kubectl installed
- Docker installed
- Node.js and npm installed
- MongoDB Atlas account (for database)

## Project Structure

```
.
├── terraform/                 # Terraform configurations
│   ├── modules/              # Terraform modules
│   │   ├── eks/             # EKS cluster configuration
│   │   ├── kubernetes/      # Kubernetes resources
│   │   └── vpc/             # VPC configuration
│   └── main.tf              # Main Terraform configuration
├── backend/                  # Backend application code
├── frontend/                 # Frontend application code
└── README.md                # This file
```

## Setup Instructions

### 1. AWS Configuration

1. Configure AWS CLI with your credentials:
   ```bash
   aws configure
   ```

2. Set your AWS region:
   ```bash
   export AWS_REGION=us-east-1
   ```

### 2. Terraform Setup

1. Initialize Terraform:
   ```bash
   cd terraform
   terraform init
   ```

2. Review the planned changes:
   ```bash
   terraform plan
   ```

3. Apply the configuration:
   ```bash
   terraform apply
   ```

### 3. Kubernetes Configuration

1. Update your kubeconfig:
   ```bash
   aws eks update-kubeconfig --name mern-cluster-new --region us-east-1
   ```

2. Verify cluster access:
   ```bash
   kubectl get nodes
   ```

### 4. Application Deployment

#### Backend Deployment

1. Build the backend Docker image:
   ```bash
   cd backend
   docker build -t your-dockerhub-username/backend:latest .
   ```

2. Push the image to Docker Hub:
   ```bash
   docker push your-dockerhub-username/backend:latest
   ```

3. Deploy the backend:
   ```bash
   kubectl apply -f terraform/modules/kubernetes/backend-deployment.yaml
   kubectl apply -f terraform/modules/kubernetes/backend-service.yaml
   ```

#### Frontend Deployment

1. Build the frontend Docker image:
   ```bash
   cd frontend
   docker build -t your-dockerhub-username/frontend:latest .
   ```

2. Push the image to Docker Hub:
   ```bash
   docker push your-dockerhub-username/frontend:latest
   ```

3. Deploy the frontend:
   ```bash
   kubectl apply -f terraform/modules/kubernetes/frontend-deployment.yaml
   kubectl apply -f terraform/modules/kubernetes/frontend-service.yaml
   ```

### 5. Ingress Configuration

1. Deploy the ingress controller:
   ```bash
   kubectl apply -f terraform/modules/kubernetes/ingress.yaml
   ```

2. Get the ingress URL:
   ```bash
   kubectl get ingress
   ```

## Environment Variables

### Backend Environment Variables
- `MONGODB_URI`: MongoDB connection string
- `PORT`: Backend service port (default: 5001)
- `CORS_ORIGIN`: Frontend URL for CORS configuration

### Frontend Environment Variables
- `REACT_APP_API_URL`: Backend API URL
- `REACT_APP_MONGODB_URI`: MongoDB connection string

## Monitoring and Maintenance

### View Logs
```bash
# Backend logs
kubectl logs -f deployment/backend

# Frontend logs
kubectl logs -f deployment/frontend
```

### Scale Deployments
```bash
# Scale backend
kubectl scale deployment backend --replicas=3

# Scale frontend
kubectl scale deployment frontend --replicas=3
```

### Update Deployments
```bash
# Update backend
kubectl set image deployment/backend backend=your-dockerhub-username/backend:new-version

# Update frontend
kubectl set image deployment/frontend frontend=your-dockerhub-username/frontend:new-version
```

## Troubleshooting

### Common Issues

1. **Connection Refused Errors**
   - Check if the pods are running: `kubectl get pods`
   - Verify service configuration: `kubectl describe service backend`
   - Check pod logs: `kubectl logs <pod-name>`

2. **CORS Issues**
   - Verify CORS configuration in backend
   - Check if frontend is using correct API URL
   - Ensure ingress rules are properly configured

3. **Node Group Issues**
   - Check node group status: `aws eks describe-nodegroup --cluster-name mern-cluster-new --nodegroup-name general`
   - Verify subnet configuration
   - Check IAM roles and policies

## Cleanup

To destroy the infrastructure:

```bash
cd terraform
terraform destroy
```

## Security Considerations

1. **Secrets Management**
   - Use Kubernetes secrets for sensitive data
   - Never commit sensitive information to version control

2. **Network Security**
   - Use private subnets for worker nodes
   - Configure security groups appropriately
   - Enable VPC flow logs for monitoring

3. **IAM Best Practices**
   - Follow principle of least privilege
   - Use IAM roles for service accounts
   - Regularly rotate access keys

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
