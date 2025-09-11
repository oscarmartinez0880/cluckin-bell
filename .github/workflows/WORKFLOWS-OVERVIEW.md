# Workflows Overview

This document describes the GitHub Actions workflows for GitOps deployments in the Cluckin' Bell repository.

## 02 - GitOps Promote

**File:** `.github/workflows/02-gitops-promote.yml`

### Purpose
Provides single-click promotions for deploying specific image tags to QA and Production environments.

### How to Use
1. Navigate to the **Actions** tab in GitHub
2. Select "02 - GitOps Promote" from the workflow list
3. Click "Run workflow"
4. Choose your parameters:
   - **Environment**: Select `qa` or `prod`
   - **Image Tag** (optional): Specify a tag (e.g., `sha-abc123`) or leave empty for auto-resolution

### Tag Resolution
When `image_tag` is left empty, the workflow automatically resolves the latest `sha-*` tag from ECR:
- **QA**: Reads from ECR account `264765154707` 
- **PROD**: Reads from ECR account `346746763840`

If ECR access is not available, you must provide the `image_tag` manually.

### Behavior by Environment

#### QA Environment (`environment=qa`)
- **Target branch**: `develop`
- **Action**: Direct commit to develop branch
- **Manifests updated**: `k8s/qa/**`
- **Deployment**: Argo CD auto-syncs QA environment immediately

#### PROD Environment (`environment=prod`)  
- **Target branch**: `main`
- **Action**: Creates a Pull Request against main
- **Manifests updated**: `k8s/prod/**`
- **Deployment**: Argo CD syncs after PR approval and merge

### "Buttons" UX
The workflow is designed to feel like a "Promote" button in the GitHub UI:
- Clear workflow names and run titles
- Rich commit messages with deployment details
- Comprehensive summary outputs
- Automatic branch naming for production PRs

## 04 - GitOps Email Notification

**File:** `.github/workflows/04-gitops-email.yml`

### Purpose
Automatically sends email notifications when the GitOps Promote workflow completes successfully.

### Trigger
Runs automatically when "02 - GitOps Promote" workflow completes with `conclusion=success`.

### Email Content
The notification includes:
- Environment deployed to
- Image tag deployed
- Action taken (direct deployment vs PR creation)
- User who triggered the deployment
- Links to the workflow run and commit

### Required SMTP Secrets
Configure these repository secrets for email notifications:

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `SMTP_SERVER` | SMTP server hostname | `smtp.gmail.com` |
| `SMTP_PORT` | SMTP server port | `587` (default if not set) |
| `SMTP_USERNAME` | SMTP username/email | `notifications@company.com` |
| `SMTP_PASSWORD` | SMTP password/app password | `your-app-password` |
| `TO_EMAIL` | Recipient email address | `team@company.com` |

### Conditional Execution
If any required SMTP secrets are missing, the email step is automatically skipped and a log message explains what would have been sent.

## Prerequisites

### IAM Roles (Infrastructure)
The following OIDC roles must be configured for ECR access:
- **QA**: `arn:aws:iam::264765154707:role/GH_ECR_Read_cb_nonprod_use1`
- **PROD**: `arn:aws:iam::346746763840:role/GH_ECR_Read_cb_prod_use1`

If these roles are not available, users can manually specify `image_tag` when running the promote workflow.

### Database Secrets
Note: Database secrets are not configured yet. Manifests reference placeholder secret names only.

## Workflow Integration

These workflows integrate with the existing deployment infrastructure:
- Leverage existing OIDC configuration
- Use existing cluster names and namespaces  
- Work with current Argo CD setup
- Complement the existing `deploy.yaml` workflow