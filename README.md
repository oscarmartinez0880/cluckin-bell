# Cluckn' Bell Kubernetes

This repo contains Kubernetes resources and GitHub Actions deploy workflows for the Cluckn' Bell platform.

Environments and clusters
- dev and qa share a single EKS 1.30 cluster in AWS account 264765154707
  - Namespaces: cluckn-bell-dev, cluckn-bell-qa
- prod runs on its own EKS 1.30 cluster in AWS account 346746763840
  - Namespace: cluckn-bell-prod

Domains (hosted in prod; dev/qa delegated to the dev/qa account)
- Frontend:
  - dev: dev.cluckn-bell.com
  - qa: qa.cluckn-bell.com
  - prod: cluckn-bell.com
- API:
  - dev: api.dev.cluckn-bell.com
  - qa: api.qa.cluckn-bell.com
  - prod: api.cluckn-bell.com

Images
- Frontend (from cluckin-bell-app repo):
  - Dev/QA account: 264765154707.dkr.ecr.us-east-1.amazonaws.com/cluckin-bell-app:latest
  - Prod account:    346746763840.dkr.ecr.us-east-1.amazonaws.com/cluckin-bell-app:latest
- API (wingman-api):
  - Dev/QA account: 264765154707.dkr.ecr.us-east-1.amazonaws.com/wingman-api:latest
  - Prod account:    346746763840.dkr.ecr.us-east-1.amazonaws.com/wingman-api:latest

Ingress
- We standardize on AWS Load Balancer Controller (ALB). ExternalDNS manages Route53 records. Both are installed/managed by Terraform in cluckin-bell-infra.

Deployments
- GitHub Actions in this repo assume OIDC and minimal roles created by cluckin-bell-infra.
- Per-environment deploys pick the right cluster and namespace.

Structure
k8s/
  dev/
    namespace.yaml
    serviceaccounts.yaml
    configmap.yaml
    deployments.yaml
    services.yaml
    ingress.yaml
  qa/
  prod/

Notes
- IRSA is only required if pods need AWS APIs; image pulls are handled by node IAM roles.
- TLS: add ACM certificates and ALB annotations when ready (see ingress.yaml TODOs).

See .github/workflows/deploy.yaml for CI/CD deployment automation.
