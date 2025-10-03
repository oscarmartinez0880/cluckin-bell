# GitOps Restructure Documentation

## Overview

This document outlines the phased migration from raw Kubernetes manifests and Terraform-managed platform components to a unified Helm + Argo CD ApplicationSet-based GitOps approach for the Cluckin Bell platform.

## Rationale

**Why are we making this change?**
- **Reduce Terraform day-2 churn**: Moving application deployments and platform add-ons from Terraform to GitOps reduces the need for Terraform runs for routine updates
- **Unify release workflow**: Consolidate deployment processes under a single GitOps pattern
- **Parameterize environments**: Use Helm values to eliminate environment-specific manifest duplication
- **Improve deployment velocity**: Enable automated deployments through Argo CD sync policies
- **Simplify rollbacks**: Leverage Argo CD's built-in rollback capabilities

## Migration Phases

| Phase | Status | Description | Deliverables |
|-------|--------|-------------|--------------|
| **Phase 0** | ✅ Complete | Infrastructure & Argo CD Bootstrap | EKS clusters, Argo CD installation, app-of-apps pattern |
| **Phase 1** | ✅ Complete | Helm Charts + ApplicationSets (Non-breaking) | Helm charts, ApplicationSets, parallel structure |
| **Phase 2** | 🟡 In Progress | Platform Component Migration Bootstrap | Scaffold + env-specific values, K8s 1.33.0 target, migration docs |
| **Phase 3** | ⏳ Planned | Platform Component Enablement | Enable ALB Controller, ExternalDNS, cert-manager individually |
| **Phase 4** | ⏳ Planned | Legacy Manifest Removal | Remove k8s/ directories, test parity |
| **Phase 5** | ⏳ Planned | IAM Role Consolidation | Streamline IRSA roles, update workflows |
| **Phase 6** | ⏳ Planned | Image Updater Integration | Automated image tag updates |
| **Phase 7** | ⏳ Planned | Karpenter Migration | Move from Cluster Autoscaler to Karpenter |

## Phase 1 Implementation Details

### New Directory Structure

```
charts/
├── app-frontend/          # Helm chart for drumstick-web (frontend)
├── app-wingman-api/       # Helm chart for wingman-api (backend)
└── platform-addons/      # Umbrella chart for platform components (Phase 2 scaffold)

values/
├── env/
│   ├── dev.yaml          # Development environment values
│   ├── qa.yaml           # QA environment values
│   └── prod.yaml         # Production environment values
└── platform/
    ├── nonprod.yaml      # Platform add-ons values (dev + qa cluster)
    ├── prod.yaml         # Platform add-ons values (prod cluster) 
    └── default.yaml      # Platform add-ons values (legacy)

apps/
├── applicationset-apps.yaml          # ApplicationSet for frontend + wingman-api
└── application-platform-addons.yaml # Application for platform components
```

### Helm Charts

#### app-frontend (drumstick-web)
- **Image**: Configurable ECR repository per environment
- **Health Probes**: HTTP checks on port 80 (`/`)
- **Resources**: 100m CPU / 128Mi memory requests, 500m CPU / 512Mi memory limits
- **Replicas**: 2 (configurable)
- **ConfigMap**: Runtime configuration mounted at `/usr/share/nginx/html/env.js`
- **Ingress**: Optional, ALB-ready annotations (disabled by default)

#### app-wingman-api (wingman-api)
- **Image**: Configurable ECR repository per environment
- **Health Probes**: HTTP checks on `/livez` (liveness) and `/readyz` (readiness)
- **Resources**: 100m CPU / 128Mi memory requests, 500m CPU / 512Mi memory limits  
- **Replicas**: 2 (configurable)
- **Environment Variables**: `ROOT_PATH=/api`, `CMS_BASE_URL=http://cms-svc.`
- **Ingress**: Optional, ALB-ready annotations (disabled by default)

#### platform-addons (Phase 2 Bootstrap)
- **Components**: ALB Controller, ExternalDNS, cert-manager, kube-prometheus-stack, metrics-server
- **Status**: Scaffold available, all disabled by default (managed by Terraform until individually enabled)
- **Values Files**: Environment-specific (`nonprod.yaml`, `prod.yaml`) with IRSA placeholders
- **Target Kubernetes Version**: 1.33.0 (minimum 1.30)
- **IAM Dependencies**: Requires roles from cluckin-bell-infra Terraform before enablement

#### Observability Stack (Enabled)
- **metrics-server**: Enabled in nonprod and prod for pod/node metrics
- **kube-prometheus-stack**: Enabled in nonprod and prod, includes:
  - Prometheus for metrics collection
  - Alertmanager for alert routing
  - Grafana for visualization (LoadBalancer service type)
  - kube-state-metrics for cluster resource metrics
  - node-exporter for node-level metrics
- **Grafana Access**: 
  - Service type: LoadBalancer (initial setup, will migrate to Ingress with ALB Controller)
  - Default credentials: admin/admin (should be changed via secret in production)
  - Find Grafana URL: `kubectl get svc -n monitoring kube-prometheus-stack-grafana`
- **ServiceMonitors**: Configured for wingman-api in dev, qa, and prod namespaces
  - Scrape endpoint: `/metrics` on port 8080
  - Interval: 30s

### ApplicationSet Configuration

**Matrix Generator Strategy:**
- **Environments**: dev, qa, prod
- **Applications**: frontend, wingman-api
- **Result**: 6 Applications (3 environments × 2 apps)

**Per-Application Configuration:**
- Repository: `https://github.com/oscarmartinez0880/cluckin-bell`
- Path: `charts/{chart-name}`
- Values: `values/env/{environment}.yaml`
- Sync Policy: Automated with prune/self-heal enabled

### Environment-Specific Values

#### Development (dev.yaml)
- **ECR Account**: 264765154707
- **Cluster**: cluckn-bell-nonprod
- **Namespace**: cluckn-bell-dev
- **Image Tags**: `dev`
- **Domains**: `dev.cluckn-bell.com`, `api.dev.cluckn-bell.com`

#### QA (qa.yaml)
- **ECR Account**: 264765154707  
- **Cluster**: cluckn-bell-nonprod
- **Namespace**: cluckn-bell-qa
- **Image Tags**: `qa`
- **Domains**: `qa.cluckn-bell.com`, `api.qa.cluckn-bell.com`

#### Production (prod.yaml)
- **ECR Account**: 346746763840
- **Cluster**: cluckn-bell-prod
- **Namespace**: cluckn-bell-prod
- **Image Tags**: `prod`
- **Domains**: `cluckn-bell.com`, `api.cluckn-bell.com`

### Argo CD UI Access

**Service Type**: LoadBalancer (enabled in both nonprod and prod)
- Provides direct access to Argo CD UI without port-forwarding
- Will be migrated to Ingress with TLS once ALB Controller and cert-manager are fully enabled

**Access Instructions**:
1. Get the LoadBalancer URL:
   ```bash
   kubectl get svc argocd-server -n argocd
   ```
2. Access via the EXTERNAL-IP (may take a few minutes to provision)
3. Default credentials:
   - Username: `admin`
   - Password: Retrieved via:
     ```bash
     kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
     ```

**Note**: The Argo CD server is configured with `insecure: true` for initial setup. TLS will be enabled when switching to Ingress.

## Testing Strategy

### Validation Steps (Phase 1)

1. **Helm Linting**:
   ```bash
   helm lint charts/app-frontend
   helm lint charts/app-wingman-api  
   helm lint charts/platform-addons
   ```

2. **Template Rendering**:
   ```bash
   helm template frontend charts/app-frontend -f values/env/dev.yaml
   helm template wingman-api charts/app-wingman-api -f values/env/qa.yaml
   helm template platform-addons charts/platform-addons -f values/platform/default.yaml
   ```

3. **ApplicationSet Syntax**:
   ```bash
   kubectl apply --dry-run=client -f apps/applicationset-apps.yaml
   kubectl apply --dry-run=client -f apps/application-platform-addons.yaml
   ```

### Side-by-Side Testing (Phase 2)

1. **Deploy Helm-based Applications** to test namespaces (e.g., `test-dev`, `test-qa`)
2. **Compare Resource Outputs** with existing manifest-based deployments
3. **Functional Testing** of applications deployed via Helm charts
4. **Performance Comparison** between old and new deployment methods

## Rollback Procedures

### Phase 1 Rollback (Non-disruptive)
Since Phase 1 is additive only:
1. **Disable ApplicationSets**: Set sync policies to manual or delete Applications
2. **Continue Using Existing**: Legacy k8s/ manifests remain functional
3. **Remove Helm Resources**: Clean up any test deployments from Helm charts

### Phase 2+ Rollback (If needed)
1. **Revert Platform Components**: Re-enable Terraform-managed platform add-ons
2. **Restore Legacy Manifests**: Re-deploy from k8s/ directories if removed
3. **Update Argo CD Applications**: Point back to k8s/ paths instead of Helm charts
4. **Image Updates**: Manual process until automation is restored

## Migration Checklist

### Phase 1 (Current)
- [x] Create Helm charts for applications (app-frontend, app-wingman-api)
- [x] Create platform-addons placeholder chart
- [x] Create environment-specific values files
- [x] Create ApplicationSet manifests
- [x] Validate Helm chart linting
- [x] Test template rendering with environment values
- [x] Document migration phases and procedures
- [x] Update README.md with new structure references

### Phase 2 Bootstrap (Current)
- [x] Create environment-specific platform values files (nonprod.yaml, prod.yaml)
- [x] Expand platform-addons chart with configurable component sections
- [x] Add IRSA ServiceAccount annotation placeholders
- [x] Create PLATFORM_ADDONS_MIGRATION.md documentation
- [x] Update documentation with Phase 2 initiation and K8s 1.33.0 target
- [ ] Create IAM roles in cluckin-bell-infra Terraform repository
- [ ] Update application-platform-addons.yaml for environment-specific values

### Phase 3 (Next)
- [ ] Enable AWS Load Balancer Controller (nonprod, then prod)
- [ ] Enable ExternalDNS (nonprod, then prod)
- [ ] Enable cert-manager (nonprod, then prod)
- [ ] Enable metrics-server (nonprod, then prod)
- [ ] Enable monitoring stack (nonprod, then prod)
- [ ] Enable ingress in application charts
- [ ] Validate all platform components working correctly

### Phase 4 (Later)
- [ ] Validate parity between Helm and legacy manifest deployments
- [ ] Remove legacy k8s/ directories
- [ ] Update CI/CD workflows to trigger Argo CD syncs instead of kubectl applies
- [ ] Archive Terraform application deployment modules

## Troubleshooting

### Common Issues

**ApplicationSet not generating Applications:**
- Check generator matrix configuration
- Verify repository access and path existence
- Review Argo CD ApplicationSet controller logs

**Helm chart template errors:**
- Run `helm lint` to identify syntax issues
- Test template rendering with `helm template`
- Check values file structure and indentation

**Environment values not applied:**
- Verify values file path in ApplicationSet template
- Check Helm valueFiles configuration
- Validate YAML syntax in environment values files

**Missing resources in deployment:**
- Compare Helm template output with existing manifests
- Check for missing volumes, environment variables, or probes
- Verify service account and RBAC configurations

### Support Contacts

- **GitOps Architecture**: Platform Team
- **Helm Chart Issues**: Development Team  
- **Argo CD Operations**: SRE Team
- **Infrastructure**: Cloud Team

## References

- [Argo CD ApplicationSets Documentation](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/)
- [Helm Best Practices](https://helm.sh/docs/chart_best_practices/)
- [Cluckin Bell Infrastructure Repository](https://github.com/oscarmartinez0880/cluckin-bell-infra)
- [Existing Deployment Workflows](.github/workflows/)