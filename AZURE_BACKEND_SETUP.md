# Azure Backend State Setup

This guide will help you set up Azure Storage as a backend for storing your OpenTofu/Terraform state files.

## Overview

Storing state in Azure provides:
- **Team collaboration**: Multiple team members can work with the same state
- **State locking**: Prevents concurrent modifications
- **Security**: State is encrypted at rest in Azure Storage
- **Versioning**: Azure Blob Storage supports versioning for state recovery

## Prerequisites

Before running the setup script, ensure you have:

1. **Azure CLI** installed and authenticated
   ```bash
   az login
   ```

2. **Appropriate permissions** in your Azure subscription:
   - Ability to create Resource Groups
   - Ability to create Storage Accounts
   - Ability to assign roles (for state locking)

3. **Select the correct subscription** (if you have multiple):
   ```bash
   # List all subscriptions
   az account list --output table
   
   # Set the subscription you want to use
   az account set --subscription "YOUR_SUBSCRIPTION_NAME_OR_ID"
   ```

## Setup Instructions

### Option 1: Automated Setup (Recommended)

Run the provided setup script:

```bash
chmod +x scripts/setup-azure-backend.sh
./scripts/setup-azure-backend.sh
```

The script will:
1. Create a dedicated resource group for state storage
2. Create a storage account with secure settings
3. Create a blob container for state files
4. Enable versioning and soft delete for protection
5. Generate a `backend-config.tfvars` file with the configuration
6. Output the backend configuration for your use

### Option 2: Manual Setup

If you prefer to set up manually, follow these steps:

#### 1. Set Variables

```bash
# Configuration variables
RESOURCE_GROUP_NAME="rg-tfstate-prod"
STORAGE_ACCOUNT_NAME="tfstate$(date +%s)"  # Must be globally unique
CONTAINER_NAME="tfstate"
LOCATION="westeurope"
```

#### 2. Create Resource Group

```bash
az group create \
  --name $RESOURCE_GROUP_NAME \
  --location $LOCATION \
  --tags "Purpose=TerraformState" "Environment=Production"
```

#### 3. Create Storage Account

```bash
az storage account create \
  --name $STORAGE_ACCOUNT_NAME \
  --resource-group $RESOURCE_GROUP_NAME \
  --location $LOCATION \
  --sku Standard_LRS \
  --kind StorageV2 \
  --encryption-services blob \
  --https-only true \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false \
  --tags "Purpose=TerraformState" "Environment=Production"
```

#### 4. Create Blob Container

```bash
az storage container create \
  --name $CONTAINER_NAME \
  --account-name $STORAGE_ACCOUNT_NAME \
  --auth-mode login
```

#### 5. Enable Versioning and Soft Delete (Optional but Recommended)

```bash
# Enable blob versioning
az storage account blob-service-properties update \
  --account-name $STORAGE_ACCOUNT_NAME \
  --resource-group $RESOURCE_GROUP_NAME \
  --enable-versioning true

# Enable soft delete for blobs (30 days retention)
az storage account blob-service-properties update \
  --account-name $STORAGE_ACCOUNT_NAME \
  --resource-group $RESOURCE_GROUP_NAME \
  --enable-delete-retention true \
  --delete-retention-days 30
```

#### 6. Get Storage Account Key

```bash
ACCOUNT_KEY=$(az storage account keys list \
  --resource-group $RESOURCE_GROUP_NAME \
  --account-name $STORAGE_ACCOUNT_NAME \
  --query '[0].value' -o tsv)

echo "Storage Account Name: $STORAGE_ACCOUNT_NAME"
echo "Storage Account Key: $ACCOUNT_KEY"
```

#### 7. Create Backend Configuration File

Create a file named `backend-config.tfvars` with the following content:

```hcl
resource_group_name  = "rg-tfstate-prod"
storage_account_name = "YOUR_STORAGE_ACCOUNT_NAME"
container_name       = "tfstate"
key                  = "idp.tfstate"
```

⚠️ **Important**: Add `backend-config.tfvars` to your `.gitignore` if it contains sensitive information.

## Using the Backend

### Initialize with Backend

After setting up the backend, initialize OpenTofu/Terraform with:

```bash
tofu init -backend-config=backend-config.tfvars
# or for Terraform:
# terraform init -backend-config=backend-config.tfvars
```

### Migrate Existing State

If you already have a local state file, OpenTofu/Terraform will detect it and ask if you want to migrate:

```bash
tofu init -backend-config=backend-config.tfvars -migrate-state
```

## Backend Configuration in Code

Alternatively, you can configure the backend directly in your `versions.tf`:

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfstate-prod"
    storage_account_name = "tfstateXXXXXXXXXX"
    container_name       = "tfstate"
    key                  = "idp.tfstate"
  }
}
```

## Security Best Practices

### 1. Use Managed Identity (Recommended for CI/CD)

For automated pipelines, use Managed Identity instead of access keys:

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfstate-prod"
    storage_account_name = "tfstateXXXXXXXXXX"
    container_name       = "tfstate"
    key                  = "idp.tfstate"
    use_msi              = true
  }
}
```

### 2. Use Azure AD Authentication

For local development with Azure CLI authentication:

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfstate-prod"
    storage_account_name = "tfstateXXXXXXXXXX"
    container_name       = "tfstate"
    key                  = "idp.tfstate"
    use_azuread_auth     = true
  }
}
```

### 3. Restrict Network Access

Limit access to the storage account:

```bash
# Allow access only from specific IP addresses
az storage account update \
  --name $STORAGE_ACCOUNT_NAME \
  --resource-group $RESOURCE_GROUP_NAME \
  --default-action Deny

# Add your IP address
az storage account network-rule add \
  --account-name $STORAGE_ACCOUNT_NAME \
  --resource-group $RESOURCE_GROUP_NAME \
  --ip-address YOUR_IP_ADDRESS
```

### 4. Enable State Locking

State locking is automatically enabled when using Azure Storage as a backend. No additional configuration needed!

## Verification

Verify your backend setup:

```bash
# Check if storage account exists
az storage account show \
  --name $STORAGE_ACCOUNT_NAME \
  --resource-group $RESOURCE_GROUP_NAME

# Check if container exists
az storage container show \
  --name $CONTAINER_NAME \
  --account-name $STORAGE_ACCOUNT_NAME \
  --auth-mode login

# List blobs in the container (after first apply)
az storage blob list \
  --container-name $CONTAINER_NAME \
  --account-name $STORAGE_ACCOUNT_NAME \
  --auth-mode login \
  --output table
```

## Troubleshooting

### Issue: "StorageAccountNotFound"
- Verify the storage account name is correct
- Ensure you're authenticated with Azure CLI: `az login`
- Check that the storage account exists: `az storage account list`

### Issue: "ContainerNotFound"
- Verify the container name is correct
- Create the container if it doesn't exist

### Issue: "AuthorizationFailed"
- Ensure you have proper permissions on the storage account
- Try using `use_azuread_auth = true` in backend configuration
- Check your Azure CLI authentication: `az account show`

### Issue: State Locking Errors
- Check if another process is holding the lock
- If stuck, you can force-unlock (use with caution):
  ```bash
  tofu force-unlock LOCK_ID
  ```

## Clean Up

To remove the backend infrastructure (⚠️ **This will delete your state files!**):

```bash
# Delete the entire resource group
az group delete --name rg-tfstate-prod --yes --no-wait
```

## Additional Resources

- [OpenTofu Backend Configuration](https://opentofu.org/docs/language/settings/backends/configuration/)
- [Azure Storage Backend](https://opentofu.org/docs/language/settings/backends/azurerm/)
- [Azure Storage Account Documentation](https://docs.microsoft.com/azure/storage/)
