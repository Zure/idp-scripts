#!/bin/bash
# Quick deployment script for Terranetes resources
# This script applies all Terranetes manifests in the correct order

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Deploying IDP Infrastructure with Terranetes${NC}"
echo ""

# Check if running in Kubernetes context
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}❌ Not connected to a Kubernetes cluster${NC}"
    echo "Please ensure your Kind cluster is running: kind create cluster --name terranetes"
    exit 1
fi

# Check if Terranetes is installed
if ! kubectl get namespace terranetes-system &> /dev/null; then
    echo -e "${YELLOW}⚠️  Terranetes system namespace not found${NC}"
    echo "Please install Terranetes first. See ../TERRANETES_GUIDE.md"
    exit 1
fi

# Check if secrets exist
if ! kubectl get secret azure-credentials &> /dev/null; then
    echo -e "${YELLOW}⚠️  Secret 'azure-credentials' not found${NC}"
    echo "Run ./create-secrets.sh to create required secrets"
    exit 1
fi

if ! kubectl get secret github-credentials &> /dev/null; then
    echo -e "${YELLOW}⚠️  Secret 'github-credentials' not found${NC}"
    echo "Run ./create-secrets.sh to create required secrets"
    exit 1
fi

echo -e "${GREEN}✅ Prerequisites check passed${NC}"
echo ""

# Deploy providers
echo -e "${YELLOW}📦 Step 1/4: Deploying providers...${NC}"
kubectl apply -f provider-azure.yaml
kubectl apply -f provider-github.yaml
echo -e "${GREEN}✅ Providers deployed${NC}"
echo ""

# Wait for providers to be ready
echo -e "${YELLOW}⏳ Waiting for providers to be ready...${NC}"
sleep 5

# Deploy configuration
echo -e "${YELLOW}📦 Step 2/4: Deploying configuration...${NC}"
kubectl apply -f configuration.yaml
echo -e "${GREEN}✅ Configuration deployed${NC}"
echo ""

# Wait for configuration to be processed
echo -e "${YELLOW}⏳ Waiting for configuration to be processed...${NC}"
sleep 5

# Deploy CloudResource
echo -e "${YELLOW}📦 Step 3/4: Deploying CloudResource...${NC}"
kubectl apply -f cloudresource.yaml
echo -e "${GREEN}✅ CloudResource deployed${NC}"
echo ""

# Monitor deployment
echo -e "${YELLOW}📊 Step 4/4: Monitoring deployment...${NC}"
echo ""
echo "CloudResource status:"
kubectl get cloudresource idp-dev-resources
echo ""

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}🎉 Deployment initiated successfully!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Next steps:"
echo ""
echo "1. Monitor the deployment:"
echo -e "   ${YELLOW}kubectl get cloudresources -w${NC}"
echo ""
echo "2. Check detailed status:"
echo -e "   ${YELLOW}kubectl describe cloudresource idp-dev-resources${NC}"
echo ""
echo "3. View Terraform logs:"
echo -e "   ${YELLOW}kubectl logs -l terraform.appvia.io/configuration=idp-module -f${NC}"
echo ""
echo "4. If auto-approval is disabled, approve the plan:"
echo -e "   ${YELLOW}kubectl patch cloudresource idp-dev-resources --type merge -p '{\"spec\":{\"enableAutoApproval\":true}}'${NC}"
echo ""
echo "5. View outputs after deployment:"
echo -e "   ${YELLOW}kubectl get secret idp-connection-details -o yaml${NC}"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
