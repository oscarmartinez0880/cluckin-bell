# App CI/CD Workflows

Authentication
- GitHub OIDC only. No long‑lived AWS keys or repository secrets are required for ECR pushes.
- Jobs target GitHub environments so IAM trust policy conditions are satisfied.

Required GitHub environments
- dev, qa, prod (add protection rules/approvals as desired)

Branch → environment mapping
- develop → dev
- staging → qa
- main → prod

Image tagging
- Primary: dev|qa|prod
- Secondary: sha-{git-sha}
- Additionally on prod: latest

AWS accounts and ECR
- Nonprod (dev/qa): 264765154707
- Prod: 346746763840
- ECR repositories: cluckin-bell-app, wingman-api (in both accounts)

IAM roles (assumed via OIDC; provisioned by cluckin-bell-infra)
- cluckin-bell-app:
  - Dev:  arn:aws:iam::264765154707:role/GH_ECR_Push_cluckin_bell_app_dev
  - QA:   arn:aws:iam::264765154707:role/GH_ECR_Push_cluckin_bell_app_qa
  - Prod: arn:aws:iam::346746763840:role/GH_ECR_Push_cluckin_bell_app_prod
- wingman-api:
  - Dev:  arn:aws:iam::264765154707:role/GH_ECR_Push_wingman_api_dev
  - QA:   arn:aws:iam::264765154707:role/GH_ECR_Push_wingman_api_qa
  - Prod: arn:aws:iam::346746763840:role/GH_ECR_Push_wingman_api_prod

Triggers
- push on develop/staging/main
- pull_request on develop/staging/main (build only, no push)
- workflow_dispatch with environment input

Notes
- If no Dockerfile exists at repo root, workflows skip.
- Replace any legacy secret-based ECR push workflows in app repos with the standardized OIDC workflow.