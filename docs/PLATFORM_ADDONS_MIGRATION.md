# Platform Add-ons Migration Guide

## Overview

This document describes the process for migrating platform components from Terraform management to the GitOps-managed `platform-addons` Helm chart. This is part of Phase 2 of the GitOps restructure initiative.

## Target Kubernetes Version

**Target Version**: 1.34.0 (minimum 1.30)

**Note**: If EKS has not yet GA'd Kubernetes 1.34 at cluster creation time, use the latest available minor version (e.g., 1.30–1.32) and upgrade when 1.34 becomes generally available.

## Component Migration Order

Components should be enabled in the following order to ensure proper dependencies:

1. **AWS Load Balancer Controller** → Provides ALB/NLB functionality
2. **ExternalDNS** → Manages Route53 DNS records
3. **cert-manager** → Provides TLS certificate management
4. **metrics-server** → Provides resource metrics
5. **kube-prometheus-stack** → Provides monitoring and alerting

## Prerequisites

### IAM Roles (cluckin-bell-infra Terraform)

The following IAM roles must be created in the `cluckin-bell-infra` repository before enabling components:

| Component | IAM Role Name | Purpose |
|-----------|---------------|---------|
| AWS Load Balancer Controller | `ROLE_ALB_CONTROLLER` | Manage ALB/NLB resources |
| ExternalDNS | `ROLE_EXTERNAL_DNS` | Manage Route53 DNS records |
| cert-manager (optional) | `ROLE_CERT_MANAGER_DNS` | DNS-01 challenge validation |

### Environment-Specific Values Files

Platform components use environment-specific configuration:

- **Nonprod**: `values/platform/nonprod.yaml` (dev + qa cluster)
- **Prod**: `values/platform/prod.yaml`

**Application Configuration**: The `apps/application-platform-addons.yaml` currently references `values/platform/default.yaml`. Once IAM roles are created and components are ready for enablement, update the Application to reference the appropriate environment-specific values file, or create separate Applications per cluster.

## Enablement Process

### Step 1: Prepare IAM Roles

1. Create IAM roles in `cluckin-bell-infra` Terraform
2. Update placeholder ARNs in platform values files:
   - Replace `arn:aws:iam::ACCOUNT_ID:role/ROLE_ALB_CONTROLLER`
   - Replace `arn:aws:iam::ACCOUNT_ID:role/ROLE_EXTERNAL_DNS`

### Step 2: Enable Component

1. **Create feature branch**:
   ```bash
   git checkout develop  # or main for prod
   git checkout -b feature/enable-alb-controller-nonprod
   ```

2. **Update values file**:
   ```yaml
   # In values/platform/nonprod.yaml or prod.yaml
   platformAddons:
     awsLoadBalancerController:
       enabled: true  # Change from false to true
   ```

3. **Commit and create PR**:
   ```bash
   git add values/platform/nonprod.yaml
   git commit -m "Enable AWS Load Balancer Controller in nonprod"
   git push origin feature/enable-alb-controller-nonprod
   ```

4. **Monitor Argo CD Application health** after merge

### Step 3: Validation

After each component is enabled, validate proper functionality:

#### AWS Load Balancer Controller
```bash
# Check controller deployment
kubectl get deployment -n aws-load-balancer-controller

# Check logs
kubectl logs -n aws-load-balancer-controller deployment/aws-load-balancer-controller

# Validate ALB creation (after enabling app ingress)
kubectl get ingress -A
```

#### ExternalDNS
```bash
# Check ExternalDNS deployment
kubectl get deployment -n external-dns

# Check DNS record management
kubectl logs -n external-dns deployment/external-dns

# Validate Route53 records created
aws route53 list-resource-record-sets --hosted-zone-id <zone-id>
```

#### cert-manager
```bash
# Check cert-manager deployment
kubectl get deployment -n cert-manager

# Check certificate issuers
kubectl get clusterissuer

# Test certificate creation
kubectl get certificates -A
```

#### metrics-server
```bash
# Check metrics-server deployment
kubectl get deployment -n kube-system metrics-server

# Validate metrics collection
kubectl top nodes
kubectl top pods -A
```

#### Monitoring (kube-prometheus-stack)
```bash
# Check Prometheus operator
kubectl get deployment -n monitoring

# Access Grafana (port-forward)
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# Check Prometheus targets
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
```

## Application Integration

Once platform components are enabled, applications can be updated to use them:

### Enable Ingress in Applications

Update application values (e.g., `values/env/dev.yaml`):

```yaml
app-frontend:
  ingress:
    enabled: true  # Change from false
    annotations:
      kubernetes.io/ingress.class: alb
      alb.ingress.kubernetes.io/scheme: internet-facing
      alb.ingress.kubernetes.io/target-type: ip
      external-dns.alpha.kubernetes.io/hostname: dev.cluckn-bell.com
      cert-manager.io/cluster-issuer: letsencrypt-staging
```

## Rollback Procedures

### Immediate Rollback

If a component causes issues, disable it immediately:

1. **Revert values file**:
   ```yaml
   platformAddons:
     awsLoadBalancerController:
       enabled: false  # Change back to false
   ```

2. **Emergency commit**:
   ```bash
   git add values/platform/nonprod.yaml
   git commit -m "ROLLBACK: Disable AWS Load Balancer Controller due to issues"
   git push origin develop
   ```

3. **Monitor Argo CD sync** and verify component removal

### Complete Rollback

If major issues occur, revert to Terraform management:

1. Disable all platform components in values files
2. Re-enable components in Terraform configuration
3. Run Terraform apply to restore previous state
4. Investigate issues before attempting migration again

## Troubleshooting

### Common Issues

#### IRSA Configuration
- **Problem**: Pods cannot access AWS APIs
- **Solution**: Verify IAM role ARN in service account annotations
- **Check**: `kubectl describe serviceaccount -n <namespace> <sa-name>`

#### Resource Conflicts
- **Problem**: Resources already exist from Terraform
- **Solution**: Import existing resources or remove from Terraform first
- **Check**: Compare Terraform state with Kubernetes resources

#### Version Compatibility
- **Problem**: Helm chart version incompatible with Kubernetes version
- **Solution**: Update chart versions in values files
- **Check**: Review chart documentation for compatibility matrix

### Debug Commands

```bash
# Check Argo CD Application status
kubectl get application -n argocd cluckn-bell-platform-addons

# View Argo CD Application details
kubectl describe application -n argocd cluckn-bell-platform-addons

# Check Helm release status
helm list -A

# View Helm release details
helm status <release-name> -n <namespace>

# Debug failed deployments
kubectl get events --sort-by=.metadata.creationTimestamp
```

## Next Steps

After successful migration of all platform components:

1. **Phase 3**: Remove legacy `k8s/` directories
2. **Phase 4**: Consolidate IAM roles and update workflows
3. **Phase 5**: Implement Argo CD Image Updater
4. **Phase 6**: Migrate from Cluster Autoscaler to Karpenter

## References

- [GitOps Restructure Documentation](GITOPS_RESTRUCTURE.md)
- [AWS Load Balancer Controller Documentation](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [ExternalDNS Documentation](https://kubernetes-sigs.github.io/external-dns/)
- [cert-manager Documentation](https://cert-manager.io/docs/)
- [kube-prometheus-stack Documentation](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)