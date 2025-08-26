# Kubernetes Deployment

This repository uses Kustomize for environment-specific Kubernetes deployments with separate overlays for each environment.

## Structure

```
k8s/
└── overlays/
    ├── dev/
    │   ├── namespace.yaml (cluckin-bell-dev)
    │   └── kustomization.yaml
    ├── qa/
    │   ├── namespace.yaml (cluckin-bell-qa)
    │   └── kustomization.yaml
    └── prod/
        ├── namespace.yaml (cluckin-bell-prod)
        └── kustomization.yaml
```

## Environments

Each environment has its own namespace and overlay:

- **dev**: `cluckin-bell-dev` namespace
- **qa**: `cluckin-bell-qa` namespace  
- **prod**: `cluckin-bell-prod` namespace

## Deployment

Use the Deploy to Kubernetes workflow via GitHub Actions:

1. Go to Actions > Deploy to Kubernetes
2. Click "Run workflow"
3. Select the target environment (dev/qa/prod)
4. Click "Run workflow"

## Local Testing

To test the kustomize overlays locally:

```bash
# Validate and preview dev environment
kustomize build k8s/overlays/dev

# Validate and preview qa environment  
kustomize build k8s/overlays/qa

# Validate and preview prod environment
kustomize build k8s/overlays/prod
```

## Adding Resources

To add resources to an environment:

1. Add the resource YAML file to the appropriate overlay directory
2. Update the `resources:` section in the `kustomization.yaml` file
3. Test with `kustomize build k8s/overlays/<environment>`