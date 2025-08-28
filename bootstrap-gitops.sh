#!/bin/bash

# Cluckin Bell GitOps Bootstrap Script
# This script deploys Argo CD and the app-of-apps pattern after Terraform infrastructure is ready

set -euo pipefail

ENVIRONMENT=${1:-"nonprod"}

if [[ "$ENVIRONMENT" != "nonprod" && "$ENVIRONMENT" != "prod" ]]; then
    echo "Usage: $0 [nonprod|prod]"
    echo "Default: nonprod"
    exit 1
fi

echo "🚀 Bootstrapping GitOps for Cluckin Bell ($ENVIRONMENT environment)"

# Set cluster context based on environment
if [[ "$ENVIRONMENT" == "nonprod" ]]; then
    CLUSTER_NAME="cluckn-bell-nonprod"
    ACCOUNT_ID="264765154707"
    echo "📡 Updating kubeconfig for nonprod cluster..."
else
    CLUSTER_NAME="cluckn-bell-prod"
    ACCOUNT_ID="346746763840"
    echo "📡 Updating kubeconfig for prod cluster..."
fi

# Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name "$CLUSTER_NAME"

echo "✅ Connected to cluster: $CLUSTER_NAME"

# Deploy Argo CD namespace
echo "🔧 Creating Argo CD namespace..."
kubectl apply -f argocd/namespace.yaml

# Deploy Argo CD installation
echo "🚀 Installing Argo CD..."
kubectl apply -f "argocd/$ENVIRONMENT/argocd-installation.yaml"

# Wait for Argo CD to be ready
echo "⏳ Waiting for Argo CD to be ready..."
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

echo "✅ Argo CD is ready!"

# Deploy app-of-apps pattern
echo "🎯 Deploying app-of-apps pattern..."
kubectl apply -f "argocd/$ENVIRONMENT/app-of-apps.yaml"

echo "✅ GitOps bootstrap complete!"
echo ""
echo "🎉 Next steps:"
echo "1. Get Argo CD admin password:"
echo "   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d"
echo ""
echo "2. Port-forward to access Argo CD UI:"
echo "   kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo ""
echo "3. Access Argo CD at https://localhost:8080"
echo "   Username: admin"
echo "   Password: (from step 1)"
echo ""
echo "🔄 Applications will be automatically synced via GitOps!"