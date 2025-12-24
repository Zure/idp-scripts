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

# Banner
echo ""
echo "========================================="
echo "  Azure Backend Setup for OpenTofu"
echo "========================================="
echo ""

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    print_error "Azure CLI is not installed. Please install it first."
    echo "Install with: brew install azure-cli"
    exit 1
fi

print_success "Azure CLI is installed"

# Check if user is logged in
if ! az account show &> /dev/null; then
    print_error "You are not logged in to Azure. Please run 'az login' first."
    exit 1
fi

print_success "Logged in to Azure"

# Get current subscription
SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

print_info "Current subscription: ${GREEN}$SUBSCRIPTION_NAME${NC} ($SUBSCRIPTION_ID)"
echo ""

# Configuration
print_info "Setting up configuration..."
echo ""

# Prompt for configuration or use defaults
read -p "Enter Resource Group name for state storage [zure-app-tfstate-prod]: " INPUT_RG_NAME
RESOURCE_GROUP_NAME=${INPUT_RG_NAME:-zure-app-tfstate-prod}

read -p "Enter Azure region [westeurope]: " INPUT_LOCATION
LOCATION=${INPUT_LOCATION:-westeurope}

# Generate unique storage account name
RANDOM_SUFFIX=$(date +%s | tail -c 6)
DEFAULT_SA_NAME="tfstate${RANDOM_SUFFIX}"
read -p "Enter Storage Account name [${DEFAULT_SA_NAME}]: " INPUT_SA_NAME
STORAGE_ACCOUNT_NAME=${INPUT_SA_NAME:-$DEFAULT_SA_NAME}

# Validate storage account name (3-24 chars, lowercase and numbers only)
if ! [[ "$STORAGE_ACCOUNT_NAME" =~ ^[a-z0-9]{3,24}$ ]]; then
    print_error "Storage account name must be 3-24 characters, lowercase letters and numbers only"
    exit 1
fi

read -p "Enter Container name [tfstate]: " INPUT_CONTAINER_NAME
CONTAINER_NAME=${INPUT_CONTAINER_NAME:-tfstate}

read -p "Enter state file name [idp.tfstate]: " INPUT_STATE_KEY
STATE_KEY=${INPUT_STATE_KEY:-idp.tfstate}

echo ""
print_info "Configuration Summary:"
echo "  Resource Group:    $RESOURCE_GROUP_NAME"
echo "  Location:          $LOCATION"
echo "  Storage Account:   $STORAGE_ACCOUNT_NAME"
echo "  Container:         $CONTAINER_NAME"
echo "  State Key:         $STATE_KEY"
echo ""

read -p "Proceed with these settings? [y/N]: " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    print_warning "Setup cancelled"
    exit 0
fi

echo ""
print_info "Starting Azure resource creation..."
echo ""

# Create Resource Group
print_info "Creating resource group: $RESOURCE_GROUP_NAME..."
if az group create \
    --name "$RESOURCE_GROUP_NAME" \
    --location "$LOCATION" \
    --tags "Purpose=TerraformState" "Environment=Production" "ManagedBy=Script" \
    --output none; then
    print_success "Resource group created successfully"
else
    print_error "Failed to create resource group"
    exit 1
fi

# Create Storage Account
print_info "Creating storage account: $STORAGE_ACCOUNT_NAME..."
if az storage account create \
    --name "$STORAGE_ACCOUNT_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --location "$LOCATION" \
    --sku Standard_LRS \
    --kind StorageV2 \
    --encryption-services blob \
    --https-only true \
    --min-tls-version TLS1_2 \
    --allow-blob-public-access false \
    --tags "Purpose=TerraformState" "Environment=Production" "ManagedBy=Script" \
    --output none; then
    print_success "Storage account created successfully"
else
    print_error "Failed to create storage account"
    exit 1
fi

# Wait a moment for the storage account to be fully provisioned
sleep 5

# Create Blob Container
print_info "Creating blob container: $CONTAINER_NAME..."
if az storage container create \
    --name "$CONTAINER_NAME" \
    --account-name "$STORAGE_ACCOUNT_NAME" \
    --auth-mode login \
    --output none; then
    print_success "Blob container created successfully"
else
    print_error "Failed to create blob container"
    exit 1
fi

# Enable versioning
print_info "Enabling blob versioning..."
if az storage account blob-service-properties update \
    --account-name "$STORAGE_ACCOUNT_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --enable-versioning true \
    --output none; then
    print_success "Blob versioning enabled"
else
    print_warning "Failed to enable blob versioning (optional feature)"
fi

# Enable soft delete
print_info "Enabling soft delete (30 days retention)..."
if az storage account blob-service-properties update \
    --account-name "$STORAGE_ACCOUNT_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --enable-delete-retention true \
    --delete-retention-days 30 \
    --output none; then
    print_success "Soft delete enabled"
else
    print_warning "Failed to enable soft delete (optional feature)"
fi

# Create backend configuration file
print_info "Creating backend-config.tfvars file..."
cat > backend-config.tfvars <<EOF
# Azure Backend Configuration
# Generated on $(date)
# Do not commit this file to version control if it contains sensitive information

resource_group_name  = "$RESOURCE_GROUP_NAME"
storage_account_name = "$STORAGE_ACCOUNT_NAME"
container_name       = "$CONTAINER_NAME"
key                  = "$STATE_KEY"
EOF

print_success "backend-config.tfvars created"

echo ""
print_success "========================================="
print_success "  Azure Backend Setup Complete!"
print_success "========================================="
echo ""

print_info "Backend Configuration:"
echo "  Resource Group:    $RESOURCE_GROUP_NAME"
echo "  Storage Account:   $STORAGE_ACCOUNT_NAME"
echo "  Container:         $CONTAINER_NAME"
echo "  State Key:         $STATE_KEY"
echo ""

print_info "Next Steps:"
echo ""
echo "1. Review the backend-config.tfvars file"
echo "2. Initialize OpenTofu with the backend:"
echo "   ${GREEN}tofu init -backend-config=backend-config.tfvars${NC}"
echo ""
echo "3. Or add this to your versions.tf file:"
echo ""
echo "   ${YELLOW}terraform {${NC}"
echo "     ${YELLOW}backend \"azurerm\" {${NC}"
echo "       ${YELLOW}resource_group_name  = \"$RESOURCE_GROUP_NAME\"${NC}"
echo "       ${YELLOW}storage_account_name = \"$STORAGE_ACCOUNT_NAME\"${NC}"
echo "       ${YELLOW}container_name       = \"$CONTAINER_NAME\"${NC}"
echo "       ${YELLOW}key                  = \"$STATE_KEY\"${NC}"
echo "     ${YELLOW}}${NC}"
echo "   ${YELLOW}}${NC}"
echo ""

print_warning "Remember: Keep your backend configuration secure!"
echo ""
