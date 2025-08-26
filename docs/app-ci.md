# App CI/CD Workflows

Secrets required (repository > Settings > Secrets and variables > Actions):
- AWS_ECR_ROLE_ARN: IAM Role ARN trusted by GitHub OIDC with permissions to push images to ECR.

Branch mapping:
- develop/staging/main triggers builds and pushes to ECR, tagging images with both SHA and branch name.

If no Dockerfile exists at repo root, workflows skip.

## Kubernetes Deployment

For Kubernetes deployments, see [kubernetes.md](kubernetes.md) for environment-specific overlay structure and deployment instructions.