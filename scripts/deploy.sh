#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_step() {
    echo ""
    echo -e "${BLUE}==>${NC} ${GREEN}$1${NC}"
    echo ""
}

# Banner
echo ""
echo "========================================="
echo "  OpenTofu Deployment Script"
echo "========================================="
echo ""

# Check prerequisites
print_step "Step 1: Checking Prerequisites"

# Check if tofu is installed
if command -v tofu &> /dev/null; then
    TERRAFORM_CMD="tofu"
    print_success "OpenTofu is installed"
else
    print_error "OpenTofu is not installed"
    echo "Install OpenTofu with: brew install opentofu"
    exit 1
fi

# Check if Azure CLI is installed and authenticated
if ! command -v az &> /dev/null; then
    print_error "Azure CLI is not installed"
    echo "Install with: brew install azure-cli"
    exit 1
fi

if ! az account show &> /dev/null; then
    print_error "Not logged in to Azure. Please run 'az login' first"
    exit 1
fi

print_success "Azure CLI is installed and authenticated"

# Check GitHub authentication
if command -v gh &> /dev/null && gh auth status &> /dev/null; then
    print_success "GitHub CLI is authenticated"
elif [ ! -z "$GITHUB_TOKEN" ]; then
    print_success "GITHUB_TOKEN environment variable is set"
else
    print_warning "GitHub authentication not detected"
    echo "  Please either:"
    echo "  1. Run 'gh auth login', or"
    echo "  2. Set GITHUB_TOKEN environment variable"
    read -p "Continue anyway? [y/N]: " CONFIRM
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

# Display current Azure context
SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
print_info "Azure Subscription: ${GREEN}$SUBSCRIPTION_NAME${NC} ($SUBSCRIPTION_ID)"

echo ""
read -p "Continue with deployment? [y/N]: " PROCEED
if [[ ! "$PROCEED" =~ ^[Yy]$ ]]; then
    print_warning "Deployment cancelled"
    exit 0
fi

# Initialize
print_step "Step 2: Initializing OpenTofu/Terraform"

# Check if backend config exists
if [ -f "backend-config.tfvars" ]; then
    print_info "Backend configuration found, initializing with Azure backend..."
    $TERRAFORM_CMD init -backend-config=backend-config.tfvars
else
    print_warning "No backend-config.tfvars found, initializing with local backend..."
    print_info "To use Azure backend, run ./scripts/setup-azure-backend.sh first"
    $TERRAFORM_CMD init
fi

print_success "Initialization complete"

# Validate
print_step "Step 3: Validating Configuration"

if $TERRAFORM_CMD validate; then
    print_success "Configuration is valid"
else
    print_error "Configuration validation failed"
    exit 1
fi

# Format check
print_info "Checking code formatting..."
if $TERRAFORM_CMD fmt -check -recursive; then
    print_success "Code is properly formatted"
else
    print_warning "Code formatting issues found. Auto-formatting..."
    $TERRAFORM_CMD fmt -recursive
    print_success "Code formatted"
fi

# Plan
print_step "Step 4: Planning Deployment"

print_info "Generating execution plan..."
if [ -f "terraform.tfvars" ]; then
    print_info "Using terraform.tfvars for variable values"
    PLAN_OUTPUT=$($TERRAFORM_CMD plan -out=tfplan -detailed-exitcode 2>&1) || PLAN_EXIT=$?
else
    print_warning "No terraform.tfvars found, using default values"
    echo "  Copy terraform.tfvars.example to terraform.tfvars to customize"
    PLAN_OUTPUT=$($TERRAFORM_CMD plan -out=tfplan -detailed-exitcode 2>&1) || PLAN_EXIT=$?
fi

# Check plan exit code
# 0 = No changes, 1 = Error, 2 = Changes present
if [ "${PLAN_EXIT:-0}" -eq 1 ]; then
    print_error "Planning failed"
    echo "$PLAN_OUTPUT"
    exit 1
elif [ "${PLAN_EXIT:-0}" -eq 0 ]; then
    print_success "No changes detected - infrastructure is up to date"
    echo ""
    read -p "Exit now? [Y/n]: " EXIT_NOW
    if [[ ! "$EXIT_NOW" =~ ^[Nn]$ ]]; then
        rm -f tfplan
        exit 0
    fi
else
    print_success "Plan generated successfully"
    echo ""
    echo "$PLAN_OUTPUT"
fi

echo ""
print_warning "Review the plan above carefully before applying!"
echo ""

# Apply
print_step "Step 5: Applying Changes"

read -p "Do you want to apply these changes? [y/N]: " APPLY_CONFIRM
if [[ ! "$APPLY_CONFIRM" =~ ^[Yy]$ ]]; then
    print_warning "Deployment cancelled"
    rm -f tfplan
    exit 0
fi

print_info "Applying changes..."
if $TERRAFORM_CMD apply tfplan; then
    print_success "Deployment successful!"
else
    print_error "Deployment failed"
    rm -f tfplan
    exit 1
fi

# Clean up plan file
rm -f tfplan

# Show outputs
print_step "Step 6: Deployment Summary"

print_info "Deployment outputs:"
echo ""
$TERRAFORM_CMD output

echo ""
print_success "========================================="
print_success "  Deployment Complete!"
print_success "========================================="
echo ""

# Get resource group info if available
RG_NAME=$($TERRAFORM_CMD output -raw resource_group_name 2>/dev/null || echo "")
if [ ! -z "$RG_NAME" ]; then
    print_info "View your resources in the Azure Portal:"
    PORTAL_URL=$($TERRAFORM_CMD output -raw azure_portal_url 2>/dev/null || echo "")
    if [ ! -z "$PORTAL_URL" ]; then
        echo "  ${GREEN}$PORTAL_URL${NC}"
    fi
fi

# Get GitHub repo info if available
REPO_URL=$($TERRAFORM_CMD output -raw github_repo_url 2>/dev/null || echo "")
if [ ! -z "$REPO_URL" ]; then
    echo ""
    print_info "View your GitHub repository:"
    echo "  ${GREEN}$REPO_URL${NC}"
fi

echo ""
print_info "Next steps:"
echo "  • Review your resources in Azure Portal"
echo "  • Check your GitHub repository"
echo "  • Make changes to *.tf files as needed"
echo "  • Run this script again to apply updates"
echo ""
print_warning "To destroy all resources, run: ${TERRAFORM_CMD} destroy"
echo ""
