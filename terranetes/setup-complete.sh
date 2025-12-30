#!/bin/bash
# Complete setup script for Terranetes on Kind
# This script sets up everything from scratch

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Terranetes Complete Setup Script              ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════╝${NC}"
echo ""

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
echo -e "${YELLOW}🔍 Checking prerequisites...${NC}"

MISSING_DEPS=0

if ! command_exists kind; then
    echo -e "${RED}❌ kind is not installed${NC}"
    echo "   Install with: brew install kind"
    MISSING_DEPS=1
fi

if ! command_exists kubectl; then
    echo -e "${RED}❌ kubectl is not installed${NC}"
    echo "   Install with: brew install kubectl"
    MISSING_DEPS=1
fi

if ! command_exists helm; then
    echo -e "${RED}❌ helm is not installed${NC}"
    echo "   Install with: brew install helm"
    MISSING_DEPS=1
fi

if ! command_exists docker; then
    echo -e "${RED}❌ docker is not installed or not running${NC}"
    echo "   Install Docker Desktop from: https://www.docker.com/products/docker-desktop"
    MISSING_DEPS=1
fi

if [ $MISSING_DEPS -eq 1 ]; then
    echo ""
    echo -e "${RED}Please install missing dependencies and run this script again.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ All prerequisites installed${NC}"
echo ""

# Step 1: Create Kind cluster
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}📦 Step 1/5: Creating Kind cluster...${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if kind get clusters | grep -q "^terranetes$"; then
    echo -e "${YELLOW}⚠️  Cluster 'terranetes' already exists${NC}"
    read -p "Do you want to delete and recreate it? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        kind delete cluster --name terranetes
        kind create cluster --config kind-config.yaml
    else
        echo "Using existing cluster"
    fi
else
    kind create cluster --config kind-config.yaml
fi

echo -e "${GREEN}✅ Kind cluster ready${NC}"
echo ""

# Step 2: Install Terranetes
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}📦 Step 2/5: Installing Terranetes controller...${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Add Helm repository
helm repo add appvia https://terranetes-controller.appvia.io || true
helm repo update

# Create namespace
kubectl create namespace terranetes-system --dry-run=client -o yaml | kubectl apply -f -

# Install Terranetes
helm upgrade --install terranetes-controller appvia/terranetes-controller \
  --namespace terranetes-system \
  --set controller.costs.enabled=false \
  --wait

echo -e "${GREEN}✅ Terranetes controller installed${NC}"
echo ""

# Verify installation
echo "Waiting for Terranetes controller to be ready..."
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=terranetes-controller \
  -n terranetes-system \
  --timeout=300s

echo ""
echo "Terranetes CRDs installed:"
kubectl get crds | grep terraform.appvia.io
echo ""

# Step 3: Install Terranetes CLI
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}📦 Step 3/5: Installing Terranetes CLI (tnctl)...${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if command_exists tnctl; then
    echo -e "${GREEN}✅ tnctl already installed${NC}"
    tnctl version
else
    echo "Downloading tnctl..."
    
    # Detect architecture
    if [[ $(uname -m) == "arm64" ]]; then
        ARCH="arm64"
    else
        ARCH="amd64"
    fi
    
    TNCTL_VERSION=$(curl -s https://api.github.com/repos/appvia/terranetes-controller/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
    
    curl -L "https://github.com/appvia/terranetes-controller/releases/download/${TNCTL_VERSION}/tnctl-darwin-${ARCH}" -o /tmp/tnctl
    chmod +x /tmp/tnctl
    sudo mv /tmp/tnctl /usr/local/bin/
    
    echo -e "${GREEN}✅ tnctl installed${NC}"
    tnctl version
fi

echo ""

# Step 4: Create secrets
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}📦 Step 4/5: Creating secrets...${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Check if secrets already exist
if kubectl get secret azure-credentials &> /dev/null && kubectl get secret github-credentials &> /dev/null; then
    echo -e "${YELLOW}⚠️  Secrets already exist${NC}"
    read -p "Do you want to recreate them? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ./create-secrets.sh
    else
        echo "Using existing secrets"
    fi
else
    ./create-secrets.sh
fi

echo ""

# Step 5: Summary
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}🎉 Setup Complete!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "✅ Kind cluster created: terranetes"
echo "✅ Terranetes controller installed"
echo "✅ Terranetes CLI (tnctl) installed"
echo "✅ Kubernetes secrets created"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo ""
echo "1. Deploy your infrastructure:"
echo -e "   ${GREEN}./deploy.sh${NC}"
echo ""
echo "2. Or deploy manually:"
echo -e "   ${GREEN}kubectl apply -f provider-azure.yaml${NC}"
echo -e "   ${GREEN}kubectl apply -f provider-github.yaml${NC}"
echo -e "   ${GREEN}kubectl apply -f configuration.yaml${NC}"
echo -e "   ${GREEN}kubectl apply -f cloudresource.yaml${NC}"
echo ""
echo "3. Monitor deployment:"
echo -e "   ${GREEN}kubectl get cloudresources -w${NC}"
echo ""
echo "4. View detailed status:"
echo -e "   ${GREEN}kubectl describe cloudresource idp-dev-resources${NC}"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "For more information, see: ../TERRANETES_GUIDE.md"
echo ""
