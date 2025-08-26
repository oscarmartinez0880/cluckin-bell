# Sitecore Migration to Kubernetes (cfacom-sitecore)

This repository contains the complete, production-grade Kubernetes and monitoring setup for Sitecore 10.4 XP Scaled on AWS EKS, supporting dev, qa, and prod environments. It is designed to be paired with a modular Terraform infrastructure repository (see migration guide for details).

---

## Structure

- `k8s/{dev,qa,prod}/`: All Kubernetes manifests for each environment.
- `helm/`: Helm values per environment and role.
- `k8s-monitoring/`: Full Prometheus+Grafana monitoring stack and dashboards.

---

## Quickstart

1. Apply infra with [sitecore-infra-terraform](https://github.com/your-org/sitecore-infra-terraform).
2. Update secrets and values files with your actual endpoints, ARNs, etc.
3. Deploy manifests & Helm releases per environment.
4. Set up monitoring and dashboards.

See this README for step-by-step instructions and rollback plans.