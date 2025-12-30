#!/bin/bash
# Script to create Kubernetes secrets for Azure and GitHub credentials
# Usage: ./create-secrets.sh

set -e

echo "🔐 Creating Kubernetes secrets for Terranetes..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running in Kubernetes context
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}❌ Not connected to a Kubernetes cluster${NC}"
    echo "Please ensure your Kind cluster is running: kind create cluster --name terranetes"
    exit 1
fi

echo -e "${YELLOW}📝 This script will create secrets for Azure and GitHub credentials${NC}"
echo ""

# Azure Credentials
echo "=== Azure Credentials ==="
echo "You need Azure Service Principal credentials."
echo "Run this command to create one if needed:"
echo "  az ad sp create-for-rbac --name terranetes-sp --role Contributor --scopes /subscriptions/<SUBSCRIPTION_ID>"
echo ""

read -p "Enter ARM_CLIENT_ID (Azure App ID): " ARM_CLIENT_ID
read -sp "Enter ARM_CLIENT_SECRET (Azure Password): " ARM_CLIENT_SECRET
echo ""
read -p "Enter ARM_SUBSCRIPTION_ID: " ARM_SUBSCRIPTION_ID
read -p "Enter ARM_TENANT_ID: " ARM_TENANT_ID
echo ""

# GitHub Credentials
echo "=== GitHub Credentials ==="
echo "You need a GitHub Personal Access Token with 'repo' scope."
echo "Create one at: https://github.com/settings/tokens"
echo ""

read -sp "Enter GITHUB_TOKEN: " GITHUB_TOKEN
echo ""
echo ""

# Create Azure credentials secret
echo -e "${YELLOW}Creating azure-credentials secret...${NC}"
kubectl create secret generic azure-credentials \
  --from-literal=ARM_CLIENT_ID="$ARM_CLIENT_ID" \
  --from-literal=ARM_CLIENT_SECRET="$ARM_CLIENT_SECRET" \
  --from-literal=ARM_SUBSCRIPTION_ID="$ARM_SUBSCRIPTION_ID" \
  --from-literal=ARM_TENANT_ID="$ARM_TENANT_ID" \
  --dry-run=client -o yaml | kubectl apply -f -

echo -e "${GREEN}✅ azure-credentials secret created${NC}"

# Create GitHub credentials secret
echo -e "${YELLOW}Creating github-credentials secret...${NC}"
kubectl create secret generic github-credentials \
  --from-literal=GITHUB_TOKEN="$GITHUB_TOKEN" \
  --dry-run=client -o yaml | kubectl apply -f -

echo -e "${GREEN}✅ github-credentials secret created${NC}"

# Verify secrets
echo ""
echo -e "${GREEN}🎉 Secrets created successfully!${NC}"
echo ""
echo "Verify with:"
echo "  kubectl get secrets azure-credentials github-credentials"
echo ""
echo "Next steps:"
echo "  1. kubectl apply -f terranetes/provider-azure.yaml"
echo "  2. kubectl apply -f terranetes/provider-github.yaml"
echo "  3. kubectl apply -f terranetes/configuration.yaml"
echo "  4. kubectl apply -f terranetes/cloudresource.yaml"
