# Platform Add-ons Migration Guide

## Overview

This document outlines the step-by-step migration of platform components from Terraform-managed deployment to Helm-based GitOps deployment using the `platform-addons` chart.

## Migration Steps

### Step 1 – Enable AWS Load Balancer Controller (Nonprod)

**Objective**: Enable the AWS Load Balancer Controller in the nonprod (shared dev/qa) cluster using the existing IRSA role.

**Prerequisites**:
- Infrastructure repo has provisioned IRSA role: `cluckn-bell-nonprod-aws-load-balancer-controller` in account 264765154707
- IRSA role is bound to ServiceAccount `aws-load-balancer-controller` in namespace `kube-system`
- EKS cluster `cluckn-bell-nonprod` is operational

**Changes Made**:
1. Created `values/platform/nonprod.yaml` with ALB controller enabled
2. Created `values/platform/prod.yaml` with ALB controller disabled  
3. Updated `platform-addons` chart with ALB controller template
4. Configured ALB controller to use existing IRSA role

**Configuration Details**:
- **Namespace**: `kube-system` (to align with existing IRSA role)
- **ServiceAccount**: Use existing `aws-load-balancer-controller` with IRSA annotation
- **IRSA Role**: `arn:aws:iam::264765154707:role/cluckn-bell-nonprod-aws-load-balancer-controller`
- **Cluster Name**: `cluckn-bell-nonprod`

**Validation Commands**:

1. **Verify Helm Template Rendering**:
   ```bash
   # Test that the ALB controller manifests are generated
   helm template charts/platform-addons -f values/platform/nonprod.yaml | grep -i aws-load-balancer-controller
   
   # Should show ALB controller Application manifest
   helm template charts/platform-addons -f values/platform/nonprod.yaml
   ```

2. **After Merge & Argo CD Sync** (once cluster exists):
   ```bash
   # Check ALB controller deployment
   kubectl -n kube-system get deployment aws-load-balancer-controller
   
   # Check pod status
   kubectl -n kube-system get pods -l app.kubernetes.io/name=aws-load-balancer-controller
   
   # Check logs
   kubectl -n kube-system logs deploy/aws-load-balancer-controller | head -20
   
   # Verify service account has correct IRSA annotation
   kubectl -n kube-system get serviceaccount aws-load-balancer-controller -o yaml
   ```

3. **ALB Creation Test**:
   Create a test Ingress to verify ALB controller functionality:
   
   ```yaml
   # /tmp/test-alb-ingress.yaml
   apiVersion: networking.k8s.io/v1
   kind: Ingress
   metadata:
     name: test-alb
     namespace: cluckn-bell-dev
     annotations:
       alb.ingress.kubernetes.io/scheme: internet-facing
       alb.ingress.kubernetes.io/target-type: ip
       alb.ingress.kubernetes.io/tags: Environment=nonprod,ManagedBy=aws-load-balancer-controller
   spec:
     ingressClassName: alb
     rules:
     - host: test.dev.cluckn-bell.com
       http:
         paths:
         - path: /
           pathType: Prefix
           backend:
             service:
               name: test-service
               port:
                 number: 80
   ```
   
   **Apply and verify**:
   ```bash
   # Apply test ingress
   kubectl apply -f /tmp/test-alb-ingress.yaml
   
   # Check ingress status
   kubectl -n cluckn-bell-dev describe ingress test-alb
   
   # Verify ALB is created in AWS Console
   # Check that ALB has proper tags including cluster name
   
   # Clean up test
   kubectl delete -f /tmp/test-alb-ingress.yaml
   ```

**Expected Results**:
- Helm template renders ALB controller Application manifest
- ALB controller deploys successfully to `kube-system` namespace
- ServiceAccount uses existing IRSA role (no new ServiceAccount created)
- Test Ingress creates ALB in AWS with proper cluster tags
- ALB controller logs show successful startup and webhook registration

**Rollback Procedure**:
If issues arise:
1. Set `platformAddons.awsLoadBalancerController.enabled: false` in `values/platform/nonprod.yaml`
2. Commit and push changes
3. Argo CD will automatically prune the ALB controller resources

**Next Steps**:
- Step 2: Enable ExternalDNS (separate PR)
- Step 3: Enable cert-manager (separate PR)
- Step 4: Enable monitoring stack (separate PR)

## Future Steps (Not Implemented Yet)

### Step 2 – Enable ExternalDNS (Nonprod)
- TBD in subsequent PR

### Step 3 – Enable cert-manager (Nonprod)  
- TBD in subsequent PR

### Step 4 – Enable Monitoring Stack (Nonprod)
- TBD in subsequent PR

### Step 5 – Enable Production Environment
- TBD after nonprod validation complete