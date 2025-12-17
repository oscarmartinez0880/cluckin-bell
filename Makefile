.PHONY: help lint render-dev render-qa render-prod argocd-refresh

help: ## Display this help message
	@echo "Cluckin Bell GitOps Makefile"
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

lint: ## Run helm lint on all charts
	@echo "Linting Helm charts..."
	@helm lint charts/app-frontend
	@helm lint charts/app-wingman-api
	@helm lint charts/platform-addons
	@helm lint charts/karpenter
	@echo "✓ All charts passed lint checks"

render-dev: ## Render Helm templates for dev environment
	@echo "Rendering templates for dev environment..."
	@echo "\n=== app-frontend (dev) ==="
	@helm template frontend charts/app-frontend -f values/env/dev.yaml
	@echo "\n=== app-wingman-api (dev) ==="
	@helm template wingman-api charts/app-wingman-api -f values/env/dev.yaml

render-qa: ## Render Helm templates for qa environment
	@echo "Rendering templates for qa environment..."
	@echo "\n=== app-frontend (qa) ==="
	@helm template frontend charts/app-frontend -f values/env/qa.yaml
	@echo "\n=== app-wingman-api (qa) ==="
	@helm template wingman-api charts/app-wingman-api -f values/env/qa.yaml

render-prod: ## Render Helm templates for prod environment
	@echo "Rendering templates for prod environment..."
	@echo "\n=== app-frontend (prod) ==="
	@helm template frontend charts/app-frontend -f values/env/prod.yaml
	@echo "\n=== app-wingman-api (prod) ==="
	@helm template wingman-api charts/app-wingman-api -f values/env/prod.yaml

argocd-refresh: ## Refresh ArgoCD applications (requires ARGOCD_SERVER and ARGOCD_TOKEN env vars)
	@if [ -z "$$ARGOCD_SERVER" ]; then \
		echo "Error: ARGOCD_SERVER environment variable is not set"; \
		echo "Example: export ARGOCD_SERVER=argocd.example.com"; \
		exit 1; \
	fi
	@if [ -z "$$ARGOCD_TOKEN" ]; then \
		echo "Error: ARGOCD_TOKEN environment variable is not set"; \
		echo "Example: export ARGOCD_TOKEN=your-token-here"; \
		exit 1; \
	fi
	@echo "Refreshing ArgoCD applications on $$ARGOCD_SERVER..."
	@curl -sSL -X POST \
		-H "Authorization: Bearer $$ARGOCD_TOKEN" \
		-H "Content-Type: application/json" \
		https://$$ARGOCD_SERVER/api/v1/applications/*/sync \
		-d '{"prune": false, "dryRun": false}' || \
		echo "Note: Use ArgoCD CLI for more control: argocd app sync <app-name>"
	@echo "✓ Refresh request sent to ArgoCD"
