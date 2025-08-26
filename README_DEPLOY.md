# Kubernetes deployment via GitHub Actions

This repository includes a minimal Kustomize layout and a workflow to deploy to an existing EKS cluster.

Required repository variables:
- `AWS_REGION`: e.g., `us-east-1`
- `EKS_CLUSTER_NAME`: your EKS cluster name
- `EKS_ASSUME_ROLE_ARN`: IAM role to assume with access to the cluster (via aws-auth)

Usage
- Manual run: Actions -> Deploy to EKS -> Run workflow (accept default overlay `k8s/overlays/prod`).
- Extend Kustomize overlays with your manifests under `k8s/overlays/<env>`.