# Platform Stack Automation - Complete GitOps Implementation

This document describes the fully automated platform stack deployment using Helm and Argo CD GitOps.

## Overview

The platform stack is now fully automated and deploys immediately after cluster creation via eksctl. All components are managed through Helm charts and Argo CD with proper dependency ordering using sync waves.

## Architecture

### Sync Wave Ordering

The platform components deploy in the following order to ensure proper dependencies:

1. **Wave 0** (Foundation): Base monitoring infrastructure
   - metrics-server
   - kube-prometheus-stack (Prometheus, Alertmanager, Grafana)

2. **Wave 1** (Infrastructure Controllers): Core platform services
   - AWS Load Balancer Controller
   - ExternalDNS
   - cert-manager

3. **Wave 2** (Certificate Infrastructure): ACME configuration
   - ClusterIssuers (Let's Encrypt staging and production)

4. **Wave 3** (Application Ingress): Public-facing endpoints
   - Argo CD UI Ingress
   - Grafana Ingress
   - Prometheus Ingress

## Enabled Components

### Nonprod Environment (cluckn-bell-nonprod)

All platform components are **enabled** in `values/platform/nonprod.yaml`:

| Component | Status | Namespace | IRSA Role |
|-----------|--------|-----------|-----------|
| AWS Load Balancer Controller | ✅ Enabled | kube-system | `arn:aws:iam::264765154707:role/cluckn-bell-nonprod-aws-load-balancer-controller` |
| ExternalDNS | ✅ Enabled | external-dns | `arn:aws:iam::264765154707:role/cluckn-bell-nonprod-external-dns` |
| cert-manager | ✅ Enabled | cert-manager | HTTP-01 only (no IRSA) |
| metrics-server | ✅ Enabled | kube-system | N/A |
| kube-prometheus-stack | ✅ Enabled | monitoring | N/A |

**Domain Configuration:**
- Argo CD: `argocd.dev.cluckn-bell.com`
- Grafana: `grafana.dev.cluckn-bell.com`
- Prometheus: `prometheus.dev.cluckn-bell.com`

**Managed DNS Zones:**
- `dev.cluckn-bell.com`
- `qa.cluckn-bell.com`
- `internal.dev.cluckn-bell.com`

### Prod Environment (cluckn-bell-prod)

All platform components are **enabled** in `values/platform/prod.yaml`:

| Component | Status | Namespace | IRSA Role |
|-----------|--------|-----------|-----------|
| AWS Load Balancer Controller | ✅ Enabled | kube-system | `arn:aws:iam::346746763840:role/cluckn-bell-prod-aws-load-balancer-controller` |
| ExternalDNS | ✅ Enabled | external-dns | `arn:aws:iam::346746763840:role/cluckn-bell-prod-external-dns` |
| cert-manager | ✅ Enabled | cert-manager | HTTP-01 only (no IRSA) |
| metrics-server | ✅ Enabled | kube-system | N/A |
| kube-prometheus-stack | ✅ Enabled | monitoring | N/A |

**Domain Configuration:**
- Argo CD: `argocd.cluckn-bell.com`
- Grafana: `grafana.cluckn-bell.com`
- Prometheus: `prometheus.cluckn-bell.com`

**Managed DNS Zones:**
- `cluckn-bell.com`
- `internal.prod.cluckn-bell.com`

## Certificate Management

### ClusterIssuers

Each environment has two Let's Encrypt ClusterIssuers:

1. **cluster-issuer-staging**: For testing certificate issuance
   - Server: `https://acme-staging-v02.api.letsencrypt.org/directory`
   - Use for testing to avoid rate limits

2. **cluster-issuer-prod**: For production certificates
   - Server: `https://acme-v02.api.letsencrypt.org/directory`
   - Use for real TLS certificates

### ACME Challenge Methods

**HTTP-01 (Enabled by Default)**
- Uses ALB Ingress Controller
- Suitable for individual domain certificates
- No additional IAM permissions required
- Configured in all ClusterIssuers

**DNS-01 (Optional, Commented)**
- Uses Route53 for validation
- Required for wildcard certificates (*.domain.com)
- Requires IRSA role with Route53 permissions
- Placeholder configurations included in values files with TODO comments

To enable DNS-01:
1. Uncomment DNS-01 solver sections in ClusterIssuer configuration
2. Replace placeholder zone IDs (ZDEVPUBLIC123, etc.) with actual Route53 hosted zone IDs
3. Add IRSA role annotation to cert-manager serviceAccount
4. Create IAM role in cluckin-bell-infra Terraform with Route53 permissions

## Ingress Configuration

All Ingress resources use:
- **TLS**: Automatic certificate provisioning via cert-manager
- **ALB Annotations**: Internet-facing, IP target type, SSL redirect
- **Health Checks**: Service-specific health check paths
- **Shared ALB**: Group name per environment (cluckn-bell-nonprod / cluckn-bell-prod)

### Argo CD UI Ingress

- **Path**: `/`
- **Backend**: argocd-server service on port 80
- **Health Check**: `/healthz`
- **TLS Secret**: argocd-tls
- **ClusterIssuer**: cluster-issuer-prod

### Grafana Ingress

- **Path**: `/`
- **Backend**: kube-prometheus-stack-grafana service on port 80
- **Health Check**: `/api/health`
- **TLS Secret**: grafana-tls
- **ClusterIssuer**: cluster-issuer-prod

### Prometheus Ingress

- **Path**: `/`
- **Backend**: kube-prometheus-stack-prometheus service on port 9090
- **Health Check**: `/-/healthy`
- **TLS Secret**: prometheus-tls
- **ClusterIssuer**: cluster-issuer-prod

## Deployment Process

### Initial Cluster Setup

After running `eksctl create cluster`:

1. **Bootstrap Argo CD** (manual, one-time):
   ```bash
   kubectl apply -f argocd/namespace.yaml
   kubectl apply -f argocd/<env>/argocd-installation.yaml
   kubectl apply -f argocd/<env>/app-of-apps.yaml
   ```

2. **Argo CD Syncs Platform Add-ons** (automatic):
   - Platform add-ons Application syncs from Git
   - Components deploy in sync wave order (0 → 1 → 2 → 3)
   - Total deployment time: ~5-10 minutes

3. **Platform Stack Ready**:
   - ALB provisioned and configured
   - DNS records created automatically
   - TLS certificates issued via Let's Encrypt
   - Monitoring dashboards available
   - All services accessible via HTTPS

### Validation

```bash
# Check all Argo CD Applications
kubectl get applications -n argocd

# Verify platform components
kubectl get pods -n kube-system | grep -E "(aws-load-balancer|metrics-server)"
kubectl get pods -n external-dns
kubectl get pods -n cert-manager
kubectl get pods -n monitoring

# Verify ClusterIssuers
kubectl get clusterissuer

# Check Ingress resources
kubectl get ingress -A

# View certificates
kubectl get certificate -A

# Check ALB creation
kubectl get svc -A | grep LoadBalancer

# Verify DNS records (requires AWS CLI)
aws route53 list-resource-record-sets --hosted-zone-id <zone-id>
```

## Observability

### Grafana Dashboard

The wingman-api dashboard is automatically loaded via ConfigMap:
- **Location**: `k8s/nonprod/monitoring/wingman-api-dashboard.yaml` and `k8s/prod/monitoring/wingman-api-dashboard.yaml`
- **Label**: `grafana_dashboard: "1"`
- **Metrics**: Request rate, error rate, latency quantiles, in-progress requests

### ServiceMonitors

Pre-configured for wingman-api:
- **Namespaces**: dev, qa, prod
- **Endpoint**: `/metrics` on port 8080
- **Interval**: 30s

### Accessing Monitoring

**Via LoadBalancer (Initial Setup):**
```bash
# Grafana
kubectl get svc -n monitoring kube-prometheus-stack-grafana

# Prometheus (internal only)
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
```

**Via Ingress (After Full Stack Deployment):**
- Grafana: https://grafana.{env}.cluckn-bell.com
- Prometheus: https://prometheus.{env}.cluckn-bell.com

## Rollback Procedures

To disable any component:

1. Set `enabled: false` in `values/platform/{env}.yaml`
2. Commit and push changes
3. Argo CD automatically syncs and removes resources
4. For complete removal of cert-manager or monitoring, also clean up CRDs and PVCs

Example:
```yaml
platformAddons:
  certManager:
    enabled: false  # Disables cert-manager
```

## Security Considerations

### IRSA Roles

All AWS service integrations use IAM Roles for Service Accounts (IRSA):
- Least privilege access
- No long-lived credentials
- Roles created in cluckin-bell-infra Terraform
- Annotations applied in Helm values

### TLS Certificates

- Let's Encrypt production certificates for all public endpoints
- Automatic renewal (cert-manager handles lifecycle)
- Staging ClusterIssuer available for testing
- Certificates stored as Kubernetes secrets

### Ingress Security

- SSL redirect enabled (HTTP → HTTPS)
- ALB security groups managed by AWS Load Balancer Controller
- Internet-facing ALBs only for intended public services
- Backend protocol HTTP (TLS termination at ALB)

## Troubleshooting

### cert-manager Certificate Issues

```bash
# Check certificate status
kubectl get certificate -A
kubectl describe certificate <name> -n <namespace>

# View cert-manager logs
kubectl logs -n cert-manager deploy/cert-manager

# Check certificate requests
kubectl get certificaterequest -A
kubectl describe certificaterequest <name> -n <namespace>

# Verify ClusterIssuer
kubectl describe clusterissuer cluster-issuer-prod
```

### ALB Not Creating

```bash
# Check ALB controller logs
kubectl logs -n kube-system deploy/aws-load-balancer-controller

# Verify IRSA annotation
kubectl get sa aws-load-balancer-controller -n kube-system -o yaml

# Check Ingress events
kubectl describe ingress <name> -n <namespace>
```

### DNS Records Not Created

```bash
# Check ExternalDNS logs
kubectl logs -n external-dns deploy/external-dns

# Verify IRSA annotation
kubectl get sa external-dns -n external-dns -o yaml

# Check service annotations
kubectl get svc <name> -n <namespace> -o yaml
```

### Monitoring Not Accessible

```bash
# Check monitoring pods
kubectl get pods -n monitoring

# Verify Grafana service
kubectl get svc -n monitoring kube-prometheus-stack-grafana

# Check Prometheus targets
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Then visit http://localhost:9090/targets
```

## Future Enhancements

### Planned

1. **DNS-01 Validation**: Enable Route53 DNS-01 for wildcard certificates
2. **Alert Rules**: Configure Prometheus alerting rules
3. **Grafana Dashboards**: Add more pre-configured dashboards
4. **ServiceMonitors**: Add monitoring for platform components (ALB Controller, ExternalDNS)
5. **Network Policies**: Add network segmentation

### Under Consideration

1. **Private Ingress**: Internal ALBs for private services
2. **WAF Integration**: AWS WAF on ALB
3. **Backup/Restore**: Velero for disaster recovery
4. **Cost Optimization**: Karpenter for node autoscaling
5. **Service Mesh**: Istio or Linkerd evaluation

## References

- [GITOPS_RESTRUCTURE.md](./GITOPS_RESTRUCTURE.md): Phase 1 implementation details
- [PLATFORM_ADDONS_MIGRATION.md](./PLATFORM_ADDONS_MIGRATION.md): Step-by-step migration guide
- [Argo CD Bootstrap README](../argocd/README.md): Initial setup instructions
- [cluckin-bell-infra](https://github.com/oscarmartinez0880/cluckin-bell-infra): Terraform infrastructure

## Support

For issues or questions:
1. Check Argo CD UI for Application sync status
2. Review component logs (see Troubleshooting section)
3. Consult documentation above
4. Review Git history for recent changes
