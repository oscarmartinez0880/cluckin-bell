# Cluckin Bell GitOps Bootstrap

This directory contains the GitOps bootstrap configuration for Cluckin Bell Kubernetes clusters using Argo CD.

## Architecture

- **Nonprod Environment** (Account: 264765154707)
  - Cluster: `cluckn-bell-nonprod`
  - Node groups: `env=dev` and `env=qa`
  - Namespaces: `dev`, `qa`
  - Applications: drumstick-web, wingman-api

- **Prod Environment** (Account: 346746763840)
  - Cluster: `cluckn-bell-prod`
  - Node group: `env=prod`
  - Namespace: `prod`
  - Applications: drumstick-web, wingman-api

## Deployment Order

### Phase 1: Argo CD Bootstrap (Deploy immediately after Terraform apply)

#### For Nonprod Cluster (cluckn-bell-nonprod)

1. **Connect to nonprod cluster:**
   ```bash
   aws eks update-kubeconfig --region us-east-1 --name cluckn-bell-nonprod --profile nonprod
   ```

2. **Install Argo CD namespace and bootstrap:**
   ```bash
   kubectl apply -f argocd/namespace.yaml
   kubectl apply -f argocd/nonprod/argocd-installation.yaml
   ```

3. **Wait for Argo CD to be ready:**
   ```bash
   kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
   ```

4. **Deploy app-of-apps pattern:**
   ```bash
   kubectl apply -f argocd/nonprod/app-of-apps.yaml
   ```

#### For Prod Cluster (cluckn-bell-prod)

1. **Connect to prod cluster:**
   ```bash
   aws eks update-kubeconfig --region us-east-1 --name cluckn-bell-prod --profile prod
   ```

2. **Install Argo CD namespace and bootstrap:**
   ```bash
   kubectl apply -f argocd/namespace.yaml
   kubectl apply -f argocd/prod/argocd-installation.yaml
   ```

3. **Wait for Argo CD to be ready:**
   ```bash
   kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
   ```

4. **Deploy app-of-apps pattern:**
   ```bash
   kubectl apply -f argocd/prod/app-of-apps.yaml
   ```

### Phase 2: Application Deployment (Automated via GitOps)

Once the app-of-apps pattern is deployed, Argo CD will automatically:

1. **Sync application manifests** from `apps/` directory
2. **Deploy applications** to appropriate namespaces:
   - `dev` namespace: dev environment apps
   - `qa` namespace: qa environment apps  
   - `prod` namespace: prod environment apps

### Access Argo CD UI

#### Nonprod
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Access at https://localhost:8080
```

#### Prod
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Access at https://localhost:8080
```

**Default credentials:**
- Username: `admin`
- Password: Get with `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d`

## Directory Structure

```
argocd/
├── namespace.yaml                    # Argo CD namespace
├── nonprod/
│   ├── argocd-installation.yaml     # Argo CD Helm installation for nonprod
│   └── app-of-apps.yaml            # Root application for nonprod
└── prod/
    ├── argocd-installation.yaml     # Argo CD Helm installation for prod
    └── app-of-apps.yaml            # Root application for prod

apps/
├── dev/
│   └── application.yaml             # Dev environment application
├── qa/
│   └── application.yaml             # QA environment application
└── prod/
    └── application.yaml             # Prod environment application

k8s/
├── dev/                             # Dev environment manifests
├── qa/                              # QA environment manifests
└── prod/                            # Prod environment manifests
```

## Application Configuration

### ECR Repositories
- **Nonprod** (264765154707): 
  - Frontend: `cluckin-bell-app:latest`
  - API: `wingman-api:latest`
- **Prod** (346746763840):
  - Frontend: `cluckin-bell-app:latest`
  - API: `wingman-api:latest`

### Service Account Annotations (IRSA)
Already configured in serviceaccount.yaml files with appropriate IAM role ARNs for each environment.

## Monitoring and Operations

### Check Application Status
```bash
# List all applications
kubectl get applications -n argocd

# Get application details
kubectl describe application cluckn-bell-dev -n argocd
kubectl describe application cluckn-bell-qa -n argocd
kubectl describe application cluckn-bell-prod -n argocd
```

### Manual Sync (if needed)
```bash
# Sync specific application
kubectl patch application cluckn-bell-dev -n argocd --type merge -p '{"operation":{"sync":{"syncOptions":["Prune=true"]}}}'
```

### Troubleshooting
```bash
# Check Argo CD server logs
kubectl logs -f deployment/argocd-server -n argocd

# Check application controller logs
kubectl logs -f deployment/argocd-application-controller -n argocd

# Check repo server logs
kubectl logs -f deployment/argocd-repo-server -n argocd
```