# App CI/CD Workflows

## Required Secrets

Secrets required (repository > Settings > Secrets and variables > Actions):
- AWS_ECR_ROLE_ARN: IAM Role ARN trusted by GitHub OIDC with permissions to push images to ECR and deploy to EKS clusters.

## Workflows

### App Release (release.yml)

Automatically triggered on push to develop/staging/main branches.

Branch mapping:
- develop/staging/main triggers builds and pushes to ECR, tagging images with both SHA and branch name.

If no Dockerfile exists at repo root, workflows skip.

### Deploy to Environment (deploy.yaml)

Manual deployment workflow that supports environment-specific image strategies.

**Trigger**: Manual via GitHub Actions UI (workflow_dispatch)

**Inputs**:
- `environment`: Target environment (dev/qa/prod) - **Required**
- `web_image_tag`: Web image tag for QA deployments (e.g., sha-abc123) - Optional for dev/prod, **Required for QA**
- `web_image_digest`: Web image digest for prod deployments (e.g., sha256:...) - **Required for prod**
- `api_image_tag`: API image tag for QA deployments - Optional
- `api_image_digest`: API image digest for prod deployments - Optional

**Environment-Specific Behavior**:

- **Development**: 
  - Applies K8s manifests from `k8s/dev/` using `kubectl apply`
  - Uses default images specified in manifests
  - AWS Account: 264765154707

- **QA**: 
  - Applies K8s manifests from `k8s/qa/` using `kubectl apply`
  - Patches deployment images using `kubectl set image` with specific tags
  - Requires `web_image_tag` for immutability
  - AWS Account: 264765154707

- **Production**: 
  - Applies K8s manifests from `k8s/prod/` using `kubectl apply`
  - Patches deployment images using `kubectl set image` with specific digests
  - Requires `web_image_digest` for immutability and security
  - AWS Account: 346746763840

**Usage Examples**:

```bash
# Deploy to dev (uses manifest defaults)
# Trigger via GitHub UI with environment: dev

# Deploy specific image to QA
# Trigger via GitHub UI with:
# - environment: qa
# - web_image_tag: sha-1a2b3c4d
# - api_image_tag: sha-5e6f7g8h (optional)

# Deploy to production with digests
# Trigger via GitHub UI with:
# - environment: prod  
# - web_image_digest: sha256:abcd1234...
# - api_image_digest: sha256:efgh5678... (optional)
```