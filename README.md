# Cluckin Bell - GitOps with Argo CD

This repository contains the complete GitOps setup for Cluckin Bell's Kubernetes infrastructure using Argo CD. It manages platform components and WordPress applications across dev, qa, and prod environments.

## Repository Structure

```
├── platform/
│   └── argocd/
│       ├── bootstrap/          # Argo CD installation manifests
│       └── apps/               # App-of-apps pattern
├── overlays/
│   ├── nonprod/
│   │   ├── platform/           # Platform component values for nonprod
│   │   └── apps/
│   │       ├── dev/           # WordPress dev environment
│   │       └── qa/            # WordPress qa environment
│   └── prod/
│       └── platform/          # Platform component values for prod
└── k8s/                       # Legacy application manifests (preserved)
```

## Environment Overview

### Nonprod Cluster (`cluckin-bell-nonprod`)
- **Account**: 264765154707
- **Region**: us-east-1
- **Namespaces**: argocd, external-dns, monitoring, logging, dev, qa
- **Applications**:
  - WordPress Dev: dev.cluckin-bell.com
  - WordPress QA: qa.cluckin-bell.com
  - Argo CD: argocd.dev.cluckin-bell.com
  - Grafana: grafana.dev.cluckin-bell.com

### Prod Cluster (`cluckin-bell-prod`)
- **Account**: 346746763840
- **Region**: us-east-1
- **Status**: Platform only (apps to be enabled on main branch)

## Platform Components

- **aws-load-balancer-controller**: Manages ALB for ingress
- **external-dns**: Automatic DNS management for Route53
- **metrics-server**: Cluster metrics collection
- **cluster-autoscaler**: Automatic node scaling
- **kube-prometheus-stack**: Monitoring with Prometheus/Grafana (24h retention nonprod, 30d prod)
- **aws-for-fluent-bit**: Log shipping to CloudWatch (24h retention nonprod, 30d prod)
- **external-secrets**: AWS Secrets Manager integration

## Bootstrap Instructions

### Phase 1: Initial Deployment (Current - HTTP Only)

1. **Prerequisites**:
   - EKS cluster running: `cluckin-bell-nonprod`
   - kubectl configured for the cluster
   - Required IAM roles created by infrastructure team
   - Secrets created in AWS Secrets Manager

2. **Deploy Argo CD**:
   ```bash
   kubectl apply -f platform/argocd/bootstrap/
   ```

3. **Deploy Platform and Apps**:
   ```bash
   kubectl apply -f platform/argocd/bootstrap/app-of-apps.yaml
   ```

4. **Access Argo CD**:
   - URL: http://argocd.dev.cluckin-bell.com
   - Username: admin
   - Password: admin123

### Phase 2: Enable TLS and Cognito Authentication

After infrastructure team provides ACM certificate and Cognito ARNs:

1. **Update Ingress Annotations** (to be implemented):
   ```yaml
   # Add to all ingress resources
   annotations:
     alb.ingress.kubernetes.io/certificate-arn: "arn:aws:acm:us-east-1:264765154707:certificate/YOUR-CERT-ARN"
     alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS":443}]'
     alb.ingress.kubernetes.io/redirect-config: '{"Type": "redirect", "RedirectConfig": { "Protocol": "HTTPS", "Port": "443", "StatusCode": "HTTP_301"}}'
     alb.ingress.kubernetes.io/auth-type: cognito
     alb.ingress.kubernetes.io/auth-idp-cognito: '{"userPoolArn":"arn:aws:cognito-idp:us-east-1:264765154707:userpool/YOUR-USER-POOL","userPoolClientId":"YOUR-CLIENT-ID","userPoolDomain":"YOUR-DOMAIN"}'
   ```

2. **Update URLs**:
   - Change all hosts from HTTP to HTTPS
   - Update Argo CD and Grafana URLs accordingly

## Node Affinity and Scheduling

- **Dev workloads**: Scheduled on nodes with label `env=dev`
- **QA workloads**: Scheduled on nodes with label `env=qa`
- **Platform components**: No node restrictions (schedulable on all nodes)

## Secrets Management

All secrets are managed via External Secrets Operator and sourced from AWS Secrets Manager:

### Required Secrets in AWS Secrets Manager

**Dev Environment**:
- `cluckin-bell/dev/wordpress/admin` - WordPress admin password
- `cluckin-bell/dev/mariadb/root` - MariaDB root password
- `cluckin-bell/dev/mariadb/user` - MariaDB user password

**QA Environment**:
- `cluckin-bell/qa/wordpress/admin` - WordPress admin password
- `cluckin-bell/qa/mariadb/root` - MariaDB root password
- `cluckin-bell/qa/mariadb/user` - MariaDB user password

## ALB and Ingress Configuration

All applications share a single ALB using ingress grouping:
- **Group name**: `cluckin-bell-nonprod`
- **Scheme**: internet-facing
- **Target type**: ip
- **Current**: HTTP only (Phase 1)
- **Future**: HTTPS with ACM certificates (Phase 2)

## Monitoring and Logging

### Monitoring
- **Prometheus**: 24h retention (nonprod), 30d retention (prod)
- **Grafana**: Available at grafana.dev.cluckin-bell.com
- **Alert Manager**: Configured with basic alerting rules

### Logging
- **Fluent Bit**: Ships logs to CloudWatch
- **Log Groups**: 
  - `/eks/nonprod/apps` (nonprod)
  - `/eks/prod/apps` (prod)
- **Retention**: 24h (nonprod), 30d (prod)

## Troubleshooting

### Check Argo CD Application Status
```bash
kubectl get applications -n argocd
kubectl describe application platform-apps -n argocd
```

### Check Platform Components
```bash
kubectl get pods -n kube-system
kubectl get pods -n monitoring
kubectl get pods -n external-dns
kubectl get pods -n logging
```

### Check WordPress Applications
```bash
kubectl get pods -n dev
kubectl get pods -n qa
kubectl get ingress -n dev
kubectl get ingress -n qa
```

### Check External Secrets
```bash
kubectl get externalsecrets -n dev
kubectl get externalsecrets -n qa
kubectl get secrets -n dev
kubectl get secrets -n qa
```

## Production Deployment

Production deployment is configured but not enabled until the main branch. To enable:

1. Merge to main branch
2. Platform components will be deployed to prod cluster
3. Application deployments to prod require separate enablement

---

For infrastructure setup and IAM role creation, see the companion Terraform repository.
