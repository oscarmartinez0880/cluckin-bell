# Platform Add-ons Migration

This document tracks phased migration of infrastructure-managed (Terraform / raw manifests) platform components into GitOps (Helm + Argo CD) via the `platform-addons` chart and environment-specific values.

Kubernetes Version Target: 1.30+ (upgrade path to newer minors as they GA)

---

## Step 1 – Migrate AWS Load Balancer Controller (Nonprod) (COMPLETED)

### Goal
Move AWS Load Balancer Controller for the shared nonprod cluster (`cluckn-bell-nonprod`) from Terraform to Helm/Argo CD management.

### Actions
1. Disable Terraform module (comment/remove in infra repo) for ALB controller in nonprod.
2. Enable in `values/platform/nonprod.yaml`:
   ```yaml
   platformAddons:
     awsLoadBalancerController:
       enabled: true
       namespace: kube-system
       serviceAccount:
         create: true
         annotations:
           eks.amazonaws.com/role-arn: arn:aws:iam::264765154707:role/cluckn-bell-nonprod-aws-load-balancer-controller
   ```
3. Sync Argo CD `cluckn-bell-platform-addons-nonprod` Application.
4. Validate deployment availability and IRSA annotation.

### Validation Commands
```bash
kubectl -n kube-system get deploy aws-load-balancer-controller
kubectl -n kube-system logs deploy/aws-load-balancer-controller | head
kubectl -n kube-system get sa aws-load-balancer-controller -o yaml | grep -i role-arn
```

### Rollback
Set `enabled: false` and sync Argo CD (optionally re-enable Terraform module).

---

## Step 2 – Migrate ExternalDNS (Nonprod) (IN PROGRESS)

### Goal
Migrate ExternalDNS to Helm for nonprod (dev + qa shared cluster), managing both public and private hosted zones.

### Zone & Role Standardization
- Public Zones: `dev.cluckn-bell.com`, `qa.cluckn-bell.com`
- Private Zone (nonprod internal): `internal.dev.cluckn-bell.com`
- IRSA Role: `arn:aws:iam::264765154707:role/cluckn-bell-nonprod-external-dns`

(If actual private zone differs—e.g., `internal.nonprod.cluckn-bell.com`—update values + Terraform variables accordingly.)

### Disable Previous Management
If Terraform (or manual manifests) previously deployed ExternalDNS:
```bash
kubectl -n external-dns delete deployment external-dns || true
```
(Only after removing Terraform resources.)

### Enable in Helm
To activate ExternalDNS in the nonprod cluster, set `enabled: true` in `values/platform/nonprod.yaml`:
```yaml
platformAddons:
  externalDNS:
    enabled: true
    namespace: external-dns
    serviceAccount:
      create: true
      name: external-dns
      annotations:
        eks.amazonaws.com/role-arn: arn:aws:iam::264765154707:role/cluckn-bell-nonprod-external-dns
    txtOwnerId: cluckn-bell-nonprod
    domainFilters:
      - dev.cluckn-bell.com
      - qa.cluckn-bell.com
      - internal.dev.cluckn-bell.com
    extraArgs:
      - --policy=upsert-only
      - --log-format=text
      - --txt-prefix=_extdns
      # Replace domainFilters with zone-id-filter once zone IDs confirmed:
      # - --zone-id-filter=ZDEVPUBLIC123
      # - --zone-id-filter=ZQAPUBLIC456
      # - --zone-id-filter=ZDEVPRIVATE789
```

After updating the values file, sync the `cluckn-bell-platform-addons-nonprod` Argo CD Application to deploy ExternalDNS.

### Validation
```bash
kubectl -n external-dns get pods
kubectl -n external-dns logs deploy/external-dns | head
# Trigger a record by (re)applying an Ingress:
kubectl apply -f k8s/dev/cms/ingress-internal.yaml
# Check Route53 (example):
aws route53 list-resource-record-sets --hosted-zone-id ZDEVPUBLIC123 | grep -i cms.internal.dev.cluckn-bell.com
```

Expected log snippet:
```
All records are already up to date
```

### Rollback
Set `externalDNS.enabled: false` and sync Argo CD (records remain unless you manually delete).

### Risks & Mitigations
| Risk | Mitigation |
|------|------------|
| Duplicate controllers | Disable Terraform first |
| Over-permissive DNS IAM | Use zone-id-filter instead of domainFilters |
| Ownership conflict | Unique `txtOwnerId` per cluster |

---

## Step 3 – cert-manager (Planned)

### Preview
- IRSA only if DNS-01 with Route53 is required.
- Install CRDs via chart (`installCRDs: true` already scaffolded).
- Add ClusterIssuer(s) for staging + production (Let’s Encrypt) after enabling.

---

## Step 4 – Monitoring (kube-prometheus-stack) (Planned)

### Preview
- Enable metricsServer first (or simultaneously).
- Add ServiceMonitors for ALB Controller / ExternalDNS if needed.
- Integrate Alerts later.

---

## Step 5 – metrics-server (Quick Enable)

### Preview
- Safe to enable early but deferred for sequencing clarity.

---

## General Validation Checklist After Each Step
1. Argo CD Application Healthy/Synced.
2. Pod(s) Ready, no CrashLoopBackOff.
3. IRSA annotation present on ServiceAccount.
4. Controller logs free of auth/permission errors.
5. Functional test (Ingress → ALB, DNS record creation, certificate issuance, etc.).

---

## Rollback Strategy Summary
| Component | Rollback Action | Secondary Action |
|-----------|-----------------|------------------|
| ALB Controller | Set enabled=false | Re-enable Terraform module if needed |
| ExternalDNS | Set enabled=false | Records remain (manual cleanup if desired) |
| cert-manager | Set enabled=false | Remove CRDs only if fully decommissioning |
| metrics-server | Set enabled=false | N/A |
| monitoring | Set enabled=false | Clear PVCs / CRDs only if decomposing stack |

---

## Future Cleanup
- Remove legacy raw manifests under `k8s/` once all app Helm charts + platform add-ons are stable.
- Remove legacy compatibility toggles in `values.yaml` (phase after all components migrated).

---