# GitOps Branching Strategy

## Overview

This document describes the GitOps branching and promotion model for the Cluckin' Bell Kubernetes infrastructure repository. We use **Option 2: Branch-based promotion** where different environments track different Git branches.

## Branching Model

### Branch → Environment Mapping

| Environment | Git Branch | Purpose |
|-------------|------------|---------|
| **dev** | `develop` | Development environment for active feature development |
| **qa** | `develop` | QA/staging environment for testing features from develop |
| **prod** | `main` | Production environment for stable, tested releases |

### Key Principles

- **Development Environments** (dev, qa) track the `develop` branch
- **Production Environment** (prod) tracks the `main` branch  
- Changes flow: `develop` → `main` via pull requests
- Production deployments only occur from validated `main` branch commits

## Implementation Details

### ApplicationSet Configuration

The Argo CD ApplicationSet (`apps/applicationset-apps.yaml`) implements explicit revision mapping:

```yaml
generators:
  - list:
      elements:
        - environment: dev
          revision: develop
        - environment: qa  
          revision: develop
        - environment: prod
          revision: main
```

### Promotion Workflow

1. **Feature Development**
   - Create feature branches from `develop`
   - Deploy and test in `dev` environment (automatically tracks `develop`)
   - Create PR to merge feature branch → `develop`

2. **QA Validation** 
   - Merged changes automatically deploy to `qa` environment
   - QA team validates features in `qa` environment
   - Both `dev` and `qa` track `develop` for consistent testing

3. **Production Promotion**
   - Create PR from `develop` → `main` 
   - Include production readiness checklist and approvals
   - Merge triggers automatic deployment to `prod` environment

## Branch Protection and Policies

### Recommended Branch Protection Rules

#### `develop` branch:
- Require pull request reviews (1+ approvers)
- Require status checks (helm-lint workflow)
- Allow merge commits and squash merging

#### `main` branch:
- Require pull request reviews (2+ approvers) 
- Require status checks (helm-lint workflow)
- Require branches to be up to date before merging
- Include CODEOWNERS for critical path reviews

## Environment-Specific Behavior

### Development (`dev`)
- **Branch**: `develop`
- **Auto-sync**: Enabled with prune/self-heal
- **Purpose**: Active development and immediate feedback
- **Image Tags**: `dev`

### QA (`qa`) 
- **Branch**: `develop`
- **Auto-sync**: Enabled with prune/self-heal  
- **Purpose**: Integration testing and QA validation
- **Image Tags**: `qa`

### Production (`prod`)
- **Branch**: `main`
- **Auto-sync**: Enabled with prune/self-heal
- **Purpose**: Live production workloads
- **Image Tags**: `prod`

## CI/CD Integration

### Application Images
Application images are built and tagged separately via CI/CD pipelines in application repositories:
- App builds trigger on branch pushes
- Images tagged with environment names (`dev`, `qa`, `prod`)
- GitOps repository references stable image tags in environment values

### Infrastructure Changes
Helm charts and Kubernetes manifests are validated via the `helm-lint` workflow:
- Runs on pushes to `develop` and `main`
- Validates Helm chart syntax and template rendering
- Ensures ApplicationSet configuration is valid

## Rollback Procedures

### Quick Rollback (Emergency)
```bash
# Revert problematic commit in the target branch
git revert <commit-hash>
git push origin <branch>
```

### Controlled Rollback
1. Identify last known good commit in target branch
2. Create revert PR with proper testing
3. Follow normal approval process for the branch

### Manual Override (Emergency Only)
- Temporarily disable ApplicationSet auto-sync
- Use `kubectl` for immediate manual intervention
- Re-enable auto-sync after resolution

## Monitoring and Observability

### Argo CD Dashboard
- Monitor sync status across environments
- Track deployment drift and health
- View application dependencies and relationships

### Branch Alignment Checks
```bash
# Check current branch alignment
git log --oneline develop ^main  # Changes in develop not in main
git log --oneline main ^develop  # Changes in main not in develop (should be empty)
```

## Future Enhancements

### Planned Phase 2+ Features
- **Production Path Validation**: Enforce that prod changes only come from `main`
- **Automated Image Updates**: Image Updater to sync application tags
- **Release Tagging**: Semantic versioning for production releases  
- **Environment Promotion Automation**: Automated PR creation for promote workflows

### Monitoring Integration
- Slack/Teams notifications for production deployments
- Deployment success/failure alerts
- Sync drift detection and alerts

## Troubleshooting

### Common Issues

#### Sync Failures
```bash
# Check ApplicationSet status
kubectl get applicationset -n argocd cluckn-bell-apps -o yaml

# Check generated Applications  
kubectl get applications -n argocd -l applicationset=cluckn-bell-apps
```

#### Branch Misalignment
```bash
# Verify current revision mapping
kubectl get applications -n argocd -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.source.targetRevision}{"\n"}{end}'
```

#### Helm Template Issues
```bash
# Test template rendering locally
helm template <release> charts/<chart> -f values/env/<env>.yaml

# Debug with verbose output
helm template <release> charts/<chart> -f values/env/<env>.yaml --debug
```

## References

- [Argo CD ApplicationSets Documentation](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/)
- [GitOps Restructure Documentation](GITOPS_RESTRUCTURE.md)
- [Cluckin Bell Infrastructure Repository](https://github.com/oscarmartinez0880/cluckin-bell-infra)