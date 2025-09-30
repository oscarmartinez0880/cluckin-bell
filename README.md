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
  platform-addons/       # Platform components (Phase 2 scaffold)
values/
  env/
    dev.yaml             # Dev environment values
    qa.yaml              # QA environment values
    prod.yaml            # Prod environment values
  platform/
    nonprod.yaml         # Platform add-ons values (dev + qa)
    prod.yaml            # Platform add-ons values (prod)
    default.yaml         # Platform add-ons values (legacy)
apps/
  applicationset-apps.yaml          # Matrix ApplicationSet
  application-platform-addons.yaml # Platform Application
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

## Notes
- IRSA is only required if pods need AWS APIs; image pulls are handled by node IAM roles.
- TLS: add ACM certificates and ALB annotations when ready (see ingress.yaml TODOs).
- **Migration**: Currently in Phase 1 - Helm charts available for testing, legacy manifests remain active.

See .github/workflows/deploy.yaml for CI/CD deployment automation.
