# Platform Add-ons Migration

## Step 1 – Migrate AWS Load Balancer Controller (Nonprod)

### Goal
Move the AWS Load Balancer Controller for the shared nonprod cluster (`cluckn-bell-nonprod`) from Terraform to the GitOps-managed platform-addons Helm chart.

### Prerequisites
- Infra repo has created IRSA role:
  - `arn:aws:iam::264765154707:role/cluckn-bell-nonprod-aws-load-balancer-controller`
- EKS OIDC provider enabled.
- Argo CD managing `cluckn-bell-platform-addons-nonprod`.

### Disable Terraform-managed Controller
In infra repo (`cluckin-bell-infra`) dev/qa stack:
1. Edit `terraform/clusters/devqa/main.tf`
2. Comment/remove the `module "aws_load_balancer_controller_devqa"` block.
3. Apply:
   ```bash
   cd terraform/clusters/devqa
   terraform apply
   ```
4. Verify removal:
   ```bash
   kubectl -n kube-system get deployment aws-load-balancer-controller
   ```
   If still present (leftover):
   ```bash
   kubectl -n kube-system delete deployment aws-load-balancer-controller
   ```

### Helm Enablement
`values/platform/nonprod.yaml` enables:
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

### Validation
```bash
# Local render sanity check
helm template platform-addons charts/platform-addons -f values/platform/nonprod.yaml | grep -i aws-load-balancer-controller

# After Argo CD sync
kubectl -n kube-system get deployment aws-load-balancer-controller
kubectl -n kube-system logs deploy/aws-load-balancer-controller | head
kubectl -n kube-system get sa aws-load-balancer-controller -o yaml | grep -i role-arn
```

Expected:
- Deployment Available
- Logs include: `Starting AWS Load Balancer Controller`
- ServiceAccount shows correct IRSA annotation.

### Optional ALB Functional Test (Manual – Not committed)
```yaml
# test-ingress.yaml (delete after)
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: alb-test
  namespace: cluckn-bell-dev
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
spec:
  rules:
  - host: test.dev.cluckn-bell.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: some-service
            port:
              number: 80
```
Apply, confirm ALB creation, then:
```bash
kubectl delete -f test-ingress.yaml
```

### Rollback
Set `platformAddons.awsLoadBalancerController.enabled: false` in `values/platform/nonprod.yaml` and sync Argo CD.

### Next Steps (Future PRs)
1. Step 2 – ExternalDNS (zone filters for dev/qa)
2. Step 3 – cert-manager
3. Step 4 – Monitoring stack
4. Step 5 – metrics-server (quick enable)

---
## Production Status (Deferred)
Prod values are normalized but `awsLoadBalancerController.enabled` remains `false`. Enable only after nonprod validation is complete.
