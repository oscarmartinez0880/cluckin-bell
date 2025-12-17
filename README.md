# Cluckn' Bell Kubernetes

This repo contains Kubernetes resources and GitHub Actions deploy workflows for the Cluckn' Bell platform.

## GitOps Restructure (Phase 2 - Platform Addons Bootstrap)

⚠️ **Phase 2 Initiation**: Platform component migration scaffold is now available. All components remain disabled by default and managed by Terraform until individually enabled.

**New Structure (Helm + ApplicationSets)**:
- `charts/` - Helm charts for applications and platform add-ons
- `values/env/` - Environment-specific configuration (dev.yaml, qa.yaml, prod.yaml)
- `values/platform/` - Platform component configuration (nonprod.yaml, prod.yaml)
- `apps/applicationset-apps.yaml` - ApplicationSet for matrix-based app deployments
- `apps/application-platform-addons.yaml` - Platform components Application

**Legacy Structure (Active)**:
- `k8s/` - Raw Kubernetes manifests (current production deployments)
- `apps/` - Individual Argo CD Applications per environment

**Target Kubernetes Version**: 1.33.0 (minimum 1.30)
> **Note**: If EKS has not yet GA'd 1.33 at cluster creation time, use latest available minor (e.g., 1.30–1.32) and upgrade when GA.

For platform component enablement, see [docs/PLATFORM_ADDONS_MIGRATION.md](docs/PLATFORM_ADDONS_MIGRATION.md).
For detailed migration information, see [docs/GITOPS_RESTRUCTURE.md](docs/GITOPS_RESTRUCTURE.md).

## Architecture Overview

### ArgoCD Projects

The platform uses two ArgoCD Projects for security isolation and access control:

- **cluckn-bell-platform**: Platform infrastructure components (ArgoCD, Karpenter, External Secrets, platform add-ons)
  - Full cluster-wide permissions for infrastructure management
  - Source repos include Helm chart repositories and OCI registries
  
- **cluckn-bell-apps**: Application workloads (frontend, APIs)
  - Scoped to application namespaces (`cluckn-bell-*`)
  - Developer role with sync permissions
  - Source repos include application repositories

### Sync Wave Ordering

ArgoCD Applications are deployed in a specific order using sync waves to ensure dependencies are available:

| Sync Wave | Component | Purpose |
|-----------|-----------|---------|
| -5 | ArgoCD | Self-managed ArgoCD installation |
| -4 | External Secrets | Secrets management from AWS Secrets Manager |
| -3 | Karpenter | Node autoscaling and provisioning |
| -2 | Platform Add-ons | AWS Load Balancer Controller, ExternalDNS, cert-manager, metrics-server, monitoring |
| 1 | Applications | Frontend and API workloads |

### Karpenter Integration

Karpenter is deployed via ArgoCD/Helm for efficient node autoscaling:

- **NodePool Configuration**: Defines compute requirements and consolidation policies
  - Nonprod: Mix of spot and on-demand instances, faster consolidation (30s)
  - Prod: On-demand only, conservative consolidation (1m)
  
- **EC2NodeClass**: AWS-specific node configuration
  - AMI Family: Amazon Linux 2023 (AL2023)
  - Instance Profile: Managed by Terraform
  - Subnet/Security Group Discovery: Tagged with `karpenter.sh/discovery: <cluster-name>`
  - Block Devices: 50Gi gp3 encrypted root volume

- **Configuration Files**:
  - `charts/karpenter/`: Helm chart with Karpenter as a dependency
  - `values/platform/karpenter-nonprod.yaml`: Nonprod cluster configuration
  - `values/platform/karpenter-prod.yaml`: Prod cluster configuration
  - `apps/karpenter.yaml`: ArgoCD Application definition

### External Secrets Integration

External Secrets Operator enables secure secrets management:

- Secrets stored in AWS Secrets Manager
- Synchronized to Kubernetes Secrets via `ExternalSecret` resources
- Configured per application via `externalSecrets.enabled` in values files
- Supports multiple keys per secret with property mapping

## GitOps Branching Strategy

This repository implements **Option 2: Branch-based promotion** for environment management:

| Environment | Git Branch | Purpose |
|-------------|------------|---------|
| **dev** | `develop` | Development environment for active feature development |
| **qa** | `develop` | QA/staging environment for testing features from develop |
| **prod** | `main` | Production environment for stable, tested releases |

### Key Principles:
- Development environments (dev, qa) track the `develop` branch
- Production environment (prod) tracks the `main` branch  
- Changes flow: `develop` → `main` via pull requests
- Production deployments only occur from validated `main` branch commits

### Code Review & Protection:
- **CODEOWNERS enforcement**: Production-sensitive paths (`values/env/prod.yaml`, `apps/*prod*`) require review
- **Promotion boundary**: Changes flow `develop` → `main` via pull requests with proper approvals

For complete branching documentation, see [docs/GITOPS_BRANCHING.md](docs/GITOPS_BRANCHING.md) and [docs/GITOPS_RESTRUCTURE.md](docs/GITOPS_RESTRUCTURE.md).

## Environments and clusters
- dev and qa share a single EKS 1.33 cluster in AWS account 264765154707
  - Namespaces: cluckn-bell-dev, cluckn-bell-qa
- prod runs on its own EKS 1.33 cluster in AWS account 346746763840
  - Namespace: cluckn-bell-prod

## Domains (hosted in prod; dev/qa delegated to the dev/qa account)
- Frontend:
  - dev: dev.cluckn-bell.com
  - qa: qa.cluckn-bell.com
  - prod: cluckn-bell.com
- API:
  - dev: api.dev.cluckn-bell.com
  - qa: api.qa.cluckn-bell.com
  - prod: api.cluckn-bell.com

## Images
- Frontend (from cluckin-bell-app repo):
  - Dev/QA account: 264765154707.dkr.ecr.us-east-1.amazonaws.com/cluckin-bell-app:latest
  - Prod account:    346746763840.dkr.ecr.us-east-1.amazonaws.com/cluckin-bell-app:latest
- API (wingman-api):
  - Dev/QA account: 264765154707.dkr.ecr.us-east-1.amazonaws.com/wingman-api:latest
  - Prod account:    346746763840.dkr.ecr.us-east-1.amazonaws.com/wingman-api:latest

## Ingress
- We standardize on AWS Load Balancer Controller (ALB). ExternalDNS manages Route53 records. Both are installed/managed by Terraform in cluckin-bell-infra.

## Deployments
- GitHub Actions in this repo assume OIDC and minimal roles created by cluckin-bell-infra.
- Per-environment deploys pick the right cluster and namespace.

## Structure

### New Helm-based Structure (Phase 2)
```
charts/
  app-frontend/           # Helm chart for drumstick-web
  app-wingman-api/        # Helm chart for wingman-api
  platform-addons/        # Platform components umbrella chart
  karpenter/              # Karpenter with NodePool and EC2NodeClass
values/
  env/
    dev.yaml              # Dev environment values
    qa.yaml               # QA environment values
    prod.yaml             # Prod environment values
  platform/
    nonprod.yaml          # Platform add-ons values (dev + qa)
    prod.yaml             # Platform add-ons values (prod)
    default.yaml          # Platform add-ons values (legacy)
    karpenter-nonprod.yaml  # Karpenter configuration (nonprod)
    karpenter-prod.yaml     # Karpenter configuration (prod)
apps/
  applicationset-apps.yaml          # Matrix ApplicationSet
  application-platform-addons.yaml  # Platform Application
  karpenter.yaml                    # Karpenter Application
  external-secrets.yaml             # External Secrets Application
argocd/
  projects/
    apps-project.yaml               # Application workloads project
    platform-project.yaml           # Platform infrastructure project
  notifications/
    notifications-cm.yaml           # ArgoCD notifications config
```

### Legacy Structure (Current Production)
```
k8s/
  dev/
    namespace.yaml
    serviceaccounts.yaml
    configmap.yaml
    deployments.yaml
    services.yaml
    ingress.yaml
  qa/
  prod/
```

## Observability Access

### Argo CD

#### Nonprod (cluckn-bell-nonprod cluster)

**Get LoadBalancer URL (when exposed as LoadBalancer):**
```bash
kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
# Access at https://<elb-hostname>
```

**Get admin password:**
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo  # newline
```

**Port-forward alternative:**
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Access at https://localhost:8080
# Username: admin
```

#### Prod (cluckn-bell-prod cluster)

Same commands as nonprod, just connect to the prod cluster first:
```bash
aws eks update-kubeconfig --region us-east-1 --name cluckn-bell-prod --profile prod
```

### Grafana

Grafana is deployed via kube-prometheus-stack in the `monitoring` namespace.

#### Nonprod (cluckn-bell-nonprod cluster)

**Get LoadBalancer URL (when exposed as LoadBalancer):**
```bash
kubectl get svc -n monitoring kube-prometheus-stack-grafana -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
# Access at http://<elb-hostname>
```

**Get admin password:**
```bash
kubectl get secret -n monitoring kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 -d
echo  # newline
# Default username: admin
```

**Port-forward alternative:**
```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
# Access at http://localhost:3000
# Username: admin
```

#### Prod (cluckn-bell-prod cluster)

Same commands as nonprod, just connect to the prod cluster first.

### Prometheus

Prometheus is deployed via kube-prometheus-stack in the `monitoring` namespace.

#### Access Prometheus UI (port-forward)

**Nonprod:**
```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Access at http://localhost:9090
```

**Prod:**
```bash
# Connect to prod cluster first, then:
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Access at http://localhost:9090
```

#### Check targets

```bash
# View Prometheus targets status
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090 &
curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'
```

### Alertmanager

Alertmanager is deployed via kube-prometheus-stack in the `monitoring` namespace.

#### Access Alertmanager UI (port-forward)

**Nonprod:**
```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093
# Access at http://localhost:9093
```

**Prod:**
```bash
# Connect to prod cluster first, then:
kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093
# Access at http://localhost:9093
```

### Note on Service Exposure

Per PR #39, Argo CD, Grafana, Prometheus, and Alertmanager services are initially exposed as LoadBalancer type for easy access. Once ALB Controller and cert-manager are fully enabled and configured, these will be migrated to use Ingress resources with TLS certificates for proper domain-based access and SSL termination.

## Notes
- IRSA is only required if pods need AWS APIs; image pulls are handled by node IAM roles.
- TLS: add ACM certificates and ALB annotations when ready (see ingress.yaml TODOs).
- **Migration**: Currently in Phase 1 - Helm charts available for testing, legacy manifests remain active.

See .github/workflows/deploy.yaml for CI/CD deployment automation.