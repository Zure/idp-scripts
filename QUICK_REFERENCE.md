# Quick Reference Guide

This is a quick reference for common operations with this OpenTofu/Terraform project.

## Initial Setup

```bash
# 1. Set up Azure backend (one-time setup)
./scripts/setup-azure-backend.sh

# 2. Copy and edit configuration
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# 3. Deploy
./scripts/deploy.sh
```

## Common Commands

### Using Scripts (Recommended)

```bash
# Full deployment with all checks
./scripts/deploy.sh

# Set up Azure backend
./scripts/setup-azure-backend.sh
```

### Manual Commands

```bash
# Initialize (with Azure backend)
tofu init -backend-config=backend-config.tfvars

# Initialize (local state)
tofu init

# Validate configuration
tofu validate

# Format code
tofu fmt -recursive

# Plan changes
tofu plan

# Plan and save to file
tofu plan -out=tfplan

# Apply saved plan
tofu apply tfplan

# Apply with auto-approval (use with caution!)
tofu apply -auto-approve

# Show outputs
tofu output

# Show specific output
tofu output resource_group_name

# Show current state
tofu show

# List resources in state
tofu state list

# Destroy all resources
tofu destroy
```

## Azure CLI Commands

### Authentication

```bash
# Login to Azure
az login

# List subscriptions
az account list --output table

# Set active subscription
az account set --subscription "SUBSCRIPTION_NAME_OR_ID"

# Show current account
az account show
```

### Backend State Storage

```bash
# List resource groups
az group list --output table

# Show storage account
az storage account show \
  --name STORAGE_ACCOUNT_NAME \
  --resource-group RESOURCE_GROUP_NAME

# List state files
az storage blob list \
  --container-name tfstate \
  --account-name STORAGE_ACCOUNT_NAME \
  --auth-mode login \
  --output table
```

## GitHub CLI Commands

```bash
# Login to GitHub
gh auth login

# Check authentication status
gh auth status

# Logout
gh auth logout
```

## State Management

### Migrate to Azure Backend

```bash
# Migrate existing local state to Azure
tofu init -backend-config=backend-config.tfvars -migrate-state
```

### Workspaces (Multiple Environments)

```bash
# List workspaces
tofu workspace list

# Create new workspace
tofu workspace new dev

# Switch workspace
tofu workspace select dev

# Delete workspace
tofu workspace delete dev
```

### Import Existing Resources

```bash
# Import Azure Resource Group
tofu import azurerm_resource_group.main /subscriptions/{subscription-id}/resourceGroups/{rg-name}

# Import GitHub Repository
tofu import github_repository.main {owner}/{repo-name}
```

### State Operations

```bash
# Show state
tofu state list

# Show specific resource
tofu state show azurerm_resource_group.main

# Remove resource from state (doesn't delete resource)
tofu state rm azurerm_resource_group.main

# Move resource in state
tofu state mv azurerm_resource_group.main azurerm_resource_group.new_name

# Pull remote state
tofu state pull > state.json

# Force unlock state (if stuck)
tofu force-unlock LOCK_ID
```

## Troubleshooting

### Common Issues

```bash
# Refresh state from Azure
tofu refresh

# Recreate a specific resource
tofu taint azurerm_resource_group.main
tofu apply

# Untaint a resource
tofu untaint azurerm_resource_group.main

# View detailed logs
TF_LOG=DEBUG tofu plan
TF_LOG=TRACE tofu apply

# Clear cache and reinitialize
rm -rf .terraform .terraform.lock.hcl
tofu init -backend-config=backend-config.tfvars
```

### Azure Authentication Issues

```bash
# Clear Azure CLI cache
az account clear
az login

# Get access token
az account get-access-token

# Set subscription
az account set --subscription "SUBSCRIPTION_ID"
```

### GitHub Authentication Issues

```bash
# Re-authenticate with GitHub CLI
gh auth logout
gh auth login

# Or set token
export GITHUB_TOKEN="your_token_here"
```

## Environment Variables

### Set GitHub Token

```bash
# Temporary (current session)
export GITHUB_TOKEN="ghp_xxxxxxxxxxxxx"

# Permanent (add to ~/.zshrc or ~/.bashrc)
echo 'export GITHUB_TOKEN="ghp_xxxxxxxxxxxxx"' >> ~/.zshrc
source ~/.zshrc
```

### Enable Debug Logging

```bash
# OpenTofu/Terraform debug levels: TRACE, DEBUG, INFO, WARN, ERROR
export TF_LOG=DEBUG
export TF_LOG_PATH=./terraform.log

# Run commands
tofu plan

# Disable logging
unset TF_LOG
unset TF_LOG_PATH
```

## File Locations

```
Project Files:
  ├── main.tf                    - Main resources
  ├── providers.tf               - Provider configurations
  ├── versions.tf                - Version requirements
  ├── variables.tf               - Input variables
  ├── outputs.tf                 - Output values
  ├── terraform.tfvars           - Your values (not committed)
  └── backend-config.tfvars      - Backend config (not committed)

Generated Files:
  ├── .terraform/                - Provider plugins
  ├── .terraform.lock.hcl        - Dependency lock file
  ├── tfplan                     - Saved execution plan
  └── terraform.tfstate          - Local state (if not using backend)

Scripts:
  ├── scripts/setup-azure-backend.sh
  └── scripts/deploy.sh
```

## Links

- [OpenTofu Documentation](https://opentofu.org/docs/)
- [Terraform Documentation](https://www.terraform.io/docs)
- [Azure Provider Documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [GitHub Provider Documentation](https://registry.terraform.io/providers/integrations/github/latest/docs)
- [Azure CLI Documentation](https://docs.microsoft.com/cli/azure/)
- [GitHub CLI Documentation](https://cli.github.com/manual/)

## Tips

1. **Always review the plan** before applying changes
2. **Use version control** for your `.tf` files
3. **Never commit** `terraform.tfvars` or `backend-config.tfvars` with sensitive data
4. **Use workspaces** or separate state files for different environments
5. **Enable state locking** to prevent concurrent modifications
6. **Regular backups** of your state files (Azure backend handles this)
7. **Use modules** for reusable infrastructure components
8. **Tag your resources** for better organization and cost tracking
9. **Use variables** instead of hardcoding values
10. **Document** your infrastructure decisions
