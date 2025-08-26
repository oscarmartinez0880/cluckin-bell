# Cluckin Bell Kubernetes Manifests

This directory contains Kubernetes manifests for deploying the Cluckin Bell frontend (drumstick-web) and API (wingman-api) applications across development, QA, and production environments.

## Directory Structure

```
k8s/
├── dev/          # Development environment manifests
├── qa/           # QA environment manifests  
├── prod/         # Production environment manifests
└── README.md     # This file
```

## Environments and Namespaces

| Environment | Namespace | AWS Account | Account ID |
|-------------|-----------|-------------|------------|
| Development | `cluckin-bell-dev` | cluckin-bell-qa | 264765154707 |
| QA | `cluckin-bell-qa` | cluckin-bell-qa | 264765154707 |
| Production | `cluckin-bell-prod` | cluckin-bell-prod | 346746763840 |

## Applications

### drumstick-web (Frontend)
- **Purpose**: Single Page Application (SPA) frontend
- **Container Port**: 80 (nginx)
- **ECR Image Path**: 
  - Dev/QA: `264765154707.dkr.ecr.us-east-1.amazonaws.com/cluckin-bell-app:latest`
  - Prod: `346746763840.dkr.ecr.us-east-1.amazonaws.com/cluckin-bell-app:latest`
- **Domains**:
  - Dev: `dev.cluckin-bell.com`
  - QA: `qa.cluckin-bell.com`
  - Prod: `cluckin-bell.com`

### wingman-api (Backend API)
- **Purpose**: Backend REST API
- **Container Port**: 8080
- **ECR Image Path**:
  - Dev/QA: `264765154707.dkr.ecr.us-east-1.amazonaws.com/wingman-api:latest`
  - Prod: `346746763840.dkr.ecr.us-east-1.amazonaws.com/wingman-api:latest`
- **Domains**:
  - Dev: `api.dev.cluckin-bell.com`
  - QA: `api.qa.cluckin-bell.com`
  - Prod: `api.cluckin-bell.com`

## IRSA (IAM Roles for Service Accounts)

Each application uses AWS IAM roles via IRSA for secure AWS resource access:

### drumstick-web ServiceAccount Annotations
- **Dev**: `eks.amazonaws.com/role-arn: arn:aws:iam::264765154707:role/cb-app-web-sa-role-dev`
- **QA**: `eks.amazonaws.com/role-arn: arn:aws:iam::264765154707:role/cb-app-web-sa-role-qa`
- **Prod**: `eks.amazonaws.com/role-arn: arn:aws:iam::346746763840:role/cb-app-web-sa-role-prod`

### wingman-api ServiceAccount Annotations
- **Dev**: `eks.amazonaws.com/role-arn: arn:aws:iam::264765154707:role/cb-api-sa-role-dev`
- **QA**: `eks.amazonaws.com/role-arn: arn:aws:iam::264765154707:role/cb-api-sa-role-qa`
- **Prod**: `eks.amazonaws.com/role-arn: arn:aws:iam::346746763840:role/cb-api-sa-role-prod`

## Runtime Configuration

### env.js ConfigMap

The frontend application requires runtime configuration to connect to the appropriate API endpoint. This is achieved through a ConfigMap that mounts an `env.js` file at `/usr/share/nginx/html/env.js` inside the container.

**Mount Details**:
- **ConfigMap Name**: `drumstick-web-runtime-config`
- **Mount Path**: `/usr/share/nginx/html/env.js`
- **SubPath**: `env.js`

**Configuration Values per Environment**:

#### Development
```javascript
window.__ENV = {
  API_BASE_URL: "https://api.dev.cluckin-bell.com"
};
```

#### QA
```javascript
window.__ENV = {
  API_BASE_URL: "https://api.qa.cluckin-bell.com"
};
```

#### Production
```javascript
window.__ENV = {
  API_BASE_URL: "https://api.cluckin-bell.com"
};
```

## Deployment Instructions

### Prerequisites

1. **EKS Cluster**: Ensure you have an EKS cluster running in the target AWS account
2. **kubectl**: Configured to connect to your EKS cluster
3. **Nginx Ingress Controller**: Must be installed and configured in your cluster
4. **IAM Roles**: The IRSA roles mentioned above must exist and be properly configured
5. **ECR Access**: Ensure your EKS cluster has permission to pull from the ECR repositories
6. **DNS**: Domain names must be configured to point to your ingress controller

### Applying Manifests

To deploy a specific environment, apply all manifests in the environment directory:

```bash
# Development Environment
kubectl apply -f k8s/dev/

# QA Environment  
kubectl apply -f k8s/qa/

# Production Environment
kubectl apply -f k8s/prod/
```

### Applying Individual Components

You can also apply specific components if needed:

```bash
# Apply namespace first
kubectl apply -f k8s/dev/namespace.yaml

# Apply ServiceAccounts
kubectl apply -f k8s/dev/serviceaccounts.yaml

# Apply ConfigMap
kubectl apply -f k8s/dev/configmap.yaml

# Apply Deployments
kubectl apply -f k8s/dev/deployments.yaml

# Apply Services
kubectl apply -f k8s/dev/services.yaml

# Apply Ingress
kubectl apply -f k8s/dev/ingress.yaml
```

### Verification

After deployment, verify the resources are created:

```bash
# Check namespace
kubectl get namespaces | grep cluckin-bell

# Check all resources in a namespace
kubectl get all -n cluckin-bell-dev

# Check ingress
kubectl get ingress -n cluckin-bell-dev

# Check ConfigMap
kubectl get configmap -n cluckin-bell-dev

# Check ServiceAccounts
kubectl get serviceaccounts -n cluckin-bell-dev
```

### Troubleshooting

**Common Issues**:

1. **Pod not starting**: Check if ECR image pull is working
   ```bash
   kubectl describe pod -n cluckin-bell-dev -l app=drumstick-web
   ```

2. **Ingress not working**: Verify nginx ingress controller is running
   ```bash
   kubectl get pods -n ingress-nginx
   ```

3. **ConfigMap not mounted**: Check volume mounts in pod description
   ```bash
   kubectl describe pod -n cluckin-bell-dev -l app=drumstick-web
   ```

4. **IRSA not working**: Verify IAM role exists and trust policy is correct
   ```bash
   kubectl describe serviceaccount drumstick-web -n cluckin-bell-dev
   ```

## Resource Scaling

Default replica counts:
- **Dev/QA**: 2 replicas per application
- **Prod**: 3 replicas per application

To scale applications:

```bash
# Scale drumstick-web in dev
kubectl scale deployment drumstick-web -n cluckin-bell-dev --replicas=3

# Scale wingman-api in prod
kubectl scale deployment wingman-api -n cluckin-bell-prod --replicas=5
```

## Cleanup

To remove all resources for an environment:

```bash
# Remove all resources in dev environment
kubectl delete -f k8s/dev/

# Or delete the entire namespace (removes everything)
kubectl delete namespace cluckin-bell-dev
```