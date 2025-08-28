# CMS Private Infrastructure

This document describes the CMS private infrastructure components added to provide secure, internal-only access to CMS applications.

## Overview

The CMS infrastructure is now private by default, accessible only through internal ALBs and private hosted zones. Network access is restricted using NetworkPolicies, and CI/CD privileges are scoped to namespace level.

## Components

### 1. Internal ALB Ingress

Each environment has an internal ALB configuration:

- **Dev**: `cms.internal.dev.cluckn-bell.com` → `cluckn-bell-dev` namespace
- **QA**: `cms-qa.internal.dev.cluckn-bell.com` → `cluckn-bell-qa` namespace
- **Prod**: `cms.internal.cluckn-bell.com` → `cluckn-bell-prod` namespace

**Files**: `k8s/{env}/cms/ingress-internal.yaml`

**Key Features**:
- Internal ALB scheme (not internet-facing)
- ExternalDNS integration for private hosted zones
- Targets placeholder service `cms-svc` on port 80
- Unique ALB group names per environment

### 2. NetworkPolicies

Default deny policies with specific allow rules for:
- ALB controller traffic from `kube-system` namespace
- DNS resolution to VPC DNS servers
- Egress to cluster services

**Files**: `k8s/{env}/cms/networkpolicies.yaml`

**Applied to**: Pods with label `app: cms`

### 3. Namespace-scoped RBAC

Environment-specific permissions:

- **Dev/QA**: `namespace-admin` role with full resource management
- **Prod**: `namespace-deployer` role with limited permissions (no delete operations)

**Files**: `k8s/{env}/rbac-deployer.yaml`

**IAM Role Bindings**:
- Dev: `arn:aws:iam::264765154707:role/cb-eks-deploy-dev`
- QA: `arn:aws:iam::264765154707:role/cb-eks-deploy-qa`
- Prod: `arn:aws:iam::346746763840:role/cb-eks-deploy-prod`

## Deployment Instructions

### Prerequisites

1. Infrastructure repo must provide private hosted zones:
   - `internal.dev.cluckn-bell.com` (for dev/qa)
   - `internal.cluckn-bell.com` (for prod)
2. ALB Controller must be installed and configured
3. ExternalDNS must be configured to manage private zones

### CMS Application Requirements

Your CMS application must:

1. **Service Name**: Create a service named `cms-svc`
2. **Service Port**: Expose port 80
3. **Pod Labels**: Include label `app: cms` for NetworkPolicy targeting

Example CMS service:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: cms-svc
  namespace: cluckn-bell-{env}
spec:
  selector:
    app: cms
  ports:
    - port: 80
      targetPort: 8080  # or your app port
```

### Apply Manifests

For each environment, apply the manifests:

```bash
# Apply RBAC first
kubectl apply -f k8s/{env}/rbac-deployer.yaml

# Apply CMS infrastructure
kubectl apply -f k8s/{env}/cms/

# Apply your CMS application manifests
kubectl apply -f k8s/{env}/your-cms-deployment.yaml
```

## Security Features

### Network Isolation

1. **Default Deny**: All ingress and egress traffic is denied by default
2. **ALB Access**: Only ALB controller can reach CMS pods on ports 80/8080
3. **DNS Resolution**: Pods can resolve DNS via VPC DNS servers
4. **Cluster Services**: Limited egress to cluster services on ports 80/443

### Access Control

1. **Prod Environment**: CI/CD can only create/update/patch resources, cannot delete
2. **Dev/QA Environments**: Full namespace administration permissions
3. **Namespace Scoped**: No cluster-wide permissions

## Troubleshooting

### DNS Resolution

If CMS pods cannot resolve hostnames:
```bash
# Check if DNS egress is working
kubectl exec -n cluckn-bell-{env} {cms-pod} -- nslookup kubernetes.default.svc.cluster.local
```

### ALB Controller Access

If ALB cannot reach CMS pods:
```bash
# Check NetworkPolicy
kubectl get networkpolicy -n cluckn-bell-{env}
kubectl describe networkpolicy cms-allow-alb-controller -n cluckn-bell-{env}
```

### ExternalDNS Records

Check if private DNS records are created:
```bash
# Check ExternalDNS logs
kubectl logs -n kube-system -l app.kubernetes.io/name=external-dns
```

## Future Enhancements

### EKS API CIDR Allowlists

When infrastructure exposes CIDR variables, update ingress annotations:

```yaml
# In ingress-internal.yaml files, uncomment and update:
alb.ingress.kubernetes.io/inbound-cidrs: "10.0.0.0/16"
```

### NetworkPolicy CIDR Updates

Update NetworkPolicy egress rules when cluster CIDR is available:

```yaml
# In networkpolicies.yaml files, update:
- to:
  - ipBlock:
      cidr: 10.0.0.0/16  # Replace with actual cluster CIDR
```

## Monitoring

Monitor ALB and DNS integration:

1. **ALB Status**: Check AWS Console or ALB Controller logs
2. **DNS Records**: Verify records in Route53 private hosted zones
3. **NetworkPolicy**: Monitor denied connections in CNI logs
4. **RBAC**: Check for permission denied errors in CI/CD logs