# Observability and SLO Monitoring

This document describes the Service Level Objectives (SLOs), monitoring configuration, and alert routing for the Cluckn' Bell platform.

## Overview

We use a combination of synthetic monitoring (blackbox-exporter), SLO-based alerting (PrometheusRule), and comprehensive dashboards (Grafana) to ensure site reliability and performance.

## SLO Targets

### Production Environment

| Metric | Target | Error Budget | Notes |
|--------|--------|--------------|-------|
| **Availability** | 99.9% | 0.1% (43.2 min/month) | Measured via HTTP probe success |
| **p95 Latency** | 500ms | - | Warning threshold; 1s critical |

### Nonprod Environments (dev, qa, cm, qacm, devcm)

| Metric | Target | Error Budget | Notes |
|--------|--------|--------------|-------|
| **Availability** | 99.0% | 1.0% (7.2 hours/month) | Measured via HTTP probe success |
| **p95 Latency** | 800ms | - | Warning threshold; 1.5s critical |

## What's Being Measured

### Availability
- **Metric Source**: `probe_success` from blackbox-exporter
- **Measurement**: HTTP probes every 30 seconds to all site URLs
- **Success Criteria**: HTTP 2xx response codes (200, 201, 202, 204)
- **Windows**: 5m, 1h, 6h, 30d rolling windows

### Latency
- **Metric Source**: `probe_http_duration_seconds_bucket` from blackbox-exporter
- **Measurement**: End-to-end HTTP request duration
- **Percentile**: p95 (95th percentile)
- **Evaluation**: 5-minute rolling average

### Error Budget Burn Rate
- **Multi-window alerting**: Fast and slow burn rate detection
  - **Fast burn** (critical): 5m and 1h windows below SLO
  - **Slow burn** (warning): 30m and 6h windows below SLO
- **Calculation**: `(1 - SLO_target) - (1 - actual_availability)`

## Sites Being Monitored

### Nonprod Cluster (account 264765154707)
- `https://dev.cluckn-bell.com`
- `https://dev.cluckn-bell.com/api`
- `https://qa.cluckn-bell.com`
- `https://qa.cluckn-bell.com/api`
- `https://cm.cluckn-bell.com`
- `https://qacm.cluckn-bell.com`
- `https://devcm.cluckn-bell.com`

### Prod Cluster (account 346746763840)
- `https://cluckn-bell.com`
- `https://cluckn-bell.com/api`

## Alerting

### Alert Rules

#### Availability Alerts
- **SiteDown** (Critical): Site returns probe failure for 1+ minute
- **HighErrorBudgetBurnRate** (Critical): Burning error budget rapidly (5m + 1h windows)
- **ModerateErrorBudgetBurnRate** (Warning): Burning error budget moderately (30m + 6h windows)

#### Latency Alerts
- **HighLatency** (Warning): p95 > threshold for 5 minutes
  - Prod: 500ms threshold
  - Nonprod: 800ms threshold
- **CriticalLatency** (Critical): p95 > critical threshold for 2 minutes
  - Prod: 1s threshold
  - Nonprod: 1.5s threshold

### Alert Routing

Alerts are routed through Alertmanager to multiple channels:

1. **Slack**
   - Nonprod: `#alerts-nonprod`
   - Prod: `#alerts-prod`
   - Configured via webhook URL (from Secret)

2. **Email**
   - Nonprod: `oncall@cluckn-bell.com`
   - Prod: `oncall@cluckn-bell.com,sre-team@cluckn-bell.com`
   - SMTP configuration via Secret

3. **SMS** (Critical alerts only)
   - Via webhook to SNS endpoint
   - Nonprod: `https://sns-webhook.cluckn-bell.com/nonprod/sms`
   - Prod: `https://sns-webhook.cluckn-bell.com/prod/sms`
   - Endpoint provided by infra team

### Alert Inhibition
- Warning alerts are inhibited when critical alerts fire for the same instance
- Latency alerts (prod only) are inhibited when site is down

## Grafana Dashboards

Per-site dashboards show:
- **Availability** (5m and 1h rolling)
- **p95 Latency** with SLO thresholds
- **Error Budget Remaining** (30d)
- **SRE Golden Signals**:
  - CPU usage (avg per namespace)
  - Memory usage (avg per namespace)
  - Healthy nodes
  - Running pods
- **Trends**: Time-series graphs for availability and latency

### Available Dashboards
- **Dev Site SLO Dashboard** (`uid: dev-site-slo`)
- **QA Site SLO Dashboard** (`uid: qa-site-slo`)
- **CMS Sites SLO Dashboard** (`uid: cm-sites-slo`) - All CMS hosts
- **Production Site SLO Dashboard** (`uid: prod-site-slo`)

## HTTPS and Certificates

All sites use HTTPS with TLS certificates issued by cert-manager:
- **Issuer**: ClusterIssuer `letsencrypt-prod` (installed by infra)
- **Challenge**: DNS-01 via Route53
- **Certificate resources**: One per hostname or group of hostnames
- **Secrets**: TLS secrets referenced by Ingress resources

### Certificate Locations
- Nonprod: `k8s/nonprod/certs/`
  - `cert-dev.yaml` - dev.cluckn-bell.com
  - `cert-qa.yaml` - qa.cluckn-bell.com
  - `cert-cm.yaml` - cm, qacm, devcm hosts
- Prod: `k8s/prod/certs/`
  - `cert-prod.yaml` - cluckn-bell.com

## Architecture

```
┌─────────────────┐
│  External User  │
└────────┬────────┘
         │ HTTPS
         ▼
┌─────────────────────┐
│  ALB (Ingress)      │
│  + TLS termination  │
└────────┬────────────┘
         │
         ▼
┌──────────────────────┐       ┌────────────────────┐
│  Application Pods    │◄──────│ blackbox-exporter  │
│  (dev/qa/prod)       │       │  (HTTP probes)     │
└──────────────────────┘       └────────┬───────────┘
                                        │
                                        ▼
                               ┌────────────────────┐
                               │   Prometheus       │
                               │  (metrics + rules) │
                               └────────┬───────────┘
                                        │
                    ┌───────────────────┼───────────────────┐
                    ▼                   ▼                   ▼
            ┌───────────────┐  ┌──────────────┐  ┌─────────────────┐
            │   Grafana     │  │ Alertmanager │  │  Recording      │
            │ (dashboards)  │  │  (routing)   │  │  Rules (SLO)    │
            └───────────────┘  └──────┬───────┘  └─────────────────┘
                                      │
                      ┌───────────────┼───────────────┐
                      ▼               ▼               ▼
                ┌─────────┐    ┌──────────┐    ┌─────────┐
                │  Slack  │    │  Email   │    │   SMS   │
                └─────────┘    └──────────┘    └─────────┘
```

## How to Add a New Site

### 1. Add Certificate
Create a Certificate resource in the appropriate environment:

```yaml
# k8s/{nonprod|prod}/certs/cert-{name}.yaml
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: {site-name}-cert
  namespace: {namespace}
spec:
  secretName: {site-name}-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
    group: cert-manager.io
  dnsNames:
    - {hostname}.cluckn-bell.com
```

### 2. Add or Update Ingress
Add a rule to the appropriate ingress resource:

```yaml
# k8s/{nonprod|prod}/ingress/ingress-{env}.yaml
spec:
  tls:
    - hosts:
        - {hostname}.cluckn-bell.com
      secretName: {site-name}-tls
  rules:
    - host: {hostname}.cluckn-bell.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: {service-name}
                port:
                  number: 80
```

### 3. Add to Probe Targets
Update the blackbox-exporter Probe resource:

```yaml
# k8s/{nonprod|prod}/monitoring/blackbox-exporter.yaml
spec:
  targets:
    staticConfig:
      static:
        - https://{hostname}.cluckn-bell.com
        - https://{hostname}.cluckn-bell.com/api  # if applicable
```

### 4. Create or Update Dashboard
Either:
- **Option A**: Create a new dashboard ConfigMap (copy existing template)
- **Option B**: Update an existing dashboard to include the new site

Dashboards automatically pick up new metrics based on label selectors (e.g., `instance=~"https://{hostname}.*"`).

### 5. Deploy
The resources are managed by Argo CD Applications:
- **Nonprod**: `observability-nonprod` (watches `k8s/nonprod/monitoring`)
- **Prod**: `observability-prod` (watches `k8s/prod/monitoring`)

Changes are auto-synced when merged to the appropriate branch (develop for nonprod, main for prod).

## Accessing Monitoring Tools

All monitoring tools are accessed via port-forward (no public exposure):

### Grafana
```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
# Access: http://localhost:3000
# Username: admin
# Password: kubectl get secret -n monitoring kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 -d
```

### Prometheus
```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Access: http://localhost:9090
```

### Alertmanager
```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093
# Access: http://localhost:9093
```

## Secret Management

### Current State
Secrets are managed as Kubernetes Secret resources with placeholder values:
- `k8s/nonprod/monitoring/alertmanager-config.yaml`
- `k8s/prod/monitoring/alertmanager-config.yaml`

Replace `REPLACE_WITH_*` placeholders with actual values.

### Future State (TODO)
Use External Secrets Operator to sync from AWS Secrets Manager:
- Slack webhook URLs
- SMTP credentials
- SMS webhook authentication

See commented `ExternalSecret` definitions in the alertmanager-config files.

## Maintenance

### Adjusting SLO Targets
Edit the PrometheusRule resources:
- Nonprod: `k8s/nonprod/monitoring/prometheusrules-slo.yaml`
- Prod: `k8s/prod/monitoring/prometheusrules-slo.yaml`

Update thresholds in the `expr` fields of the alert rules.

### Updating Alert Routes
Edit the Alertmanager Secret:
- Nonprod: `k8s/nonprod/monitoring/alertmanager-config.yaml`
- Prod: `k8s/prod/monitoring/alertmanager-config.yaml`

Modify the `route` and `receivers` sections as needed.

### Dashboard Modifications
Edit the dashboard ConfigMaps:
- Nonprod: `k8s/nonprod/monitoring/grafana-dashboard-*.yaml`
- Prod: `k8s/prod/monitoring/grafana-dashboard-*.yaml`

Update the JSON in the `data` section. You can also edit dashboards in the Grafana UI and export the JSON.

## Troubleshooting

### Certificate Not Issued
```bash
kubectl describe certificate {cert-name} -n {namespace}
kubectl get certificaterequest -n {namespace}
kubectl logs -n cert-manager deploy/cert-manager
```

### Probe Failures
```bash
kubectl logs -n monitoring deploy/blackbox-exporter
kubectl port-forward -n monitoring svc/blackbox-exporter 9115:9115
curl "http://localhost:9115/probe?target=https://dev.cluckn-bell.com&module=http_2xx"
```

### Alerts Not Firing
```bash
# Check Prometheus rules
kubectl get prometheusrule -n monitoring
# Check alert state in Prometheus UI
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Visit http://localhost:9090/alerts
```

### Alerts Not Routing
```bash
# Check Alertmanager config
kubectl get secret alertmanager-config -n monitoring -o jsonpath='{.data.alertmanager\.yaml}' | base64 -d
# Check Alertmanager status
kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093
# Visit http://localhost:9093/#/status
```

## References

- [SLO Definition Best Practices](https://sre.google/workbook/implementing-slos/)
- [Multi-Window, Multi-Burn-Rate Alerts](https://sre.google/workbook/alerting-on-slos/)
- [Prometheus Blackbox Exporter](https://github.com/prometheus/blackbox_exporter)
- [cert-manager Documentation](https://cert-manager.io/docs/)
- [Alertmanager Configuration](https://prometheus.io/docs/alerting/latest/configuration/)
