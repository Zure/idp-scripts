# Identity Platform Infrastructure

This repository contains OpenTofu (Terraform) configuration for creating and managing infrastructure for an Identity Platform, including both Azure and GitHub resources.

## Overview

This configuration creates:
- **Azure Resource Group**: A logical container for Azure resources
- **GitHub Repository**: A repository for storing code and documentation

The state is stored remotely in Azure Storage for team collaboration and state locking.

## Deployment Options

This repository supports multiple deployment methods:

1. **Traditional Terraform/OpenTofu** - Direct deployment using CLI
2. **Terranetes** - Kubernetes-native Terraform controller for GitOps workflows

Choose the method that best fits your workflow:
- Use **Traditional** for simple, direct deployments
- Use **Terranetes** for Kubernetes-based environments, GitOps, and platform engineering

## Quick Start

### Option A: Terranetes Deployment (Kubernetes-Native)

Deploy your infrastructure using Terranetes in a Kubernetes cluster for GitOps workflows and platform engineering.

**📚 [Complete Terranetes Guide](TERRANETES_GUIDE.md)** - Comprehensive step-by-step guide

**Quick Setup:**
```bash
cd terranetes
./setup-complete.sh  # Sets up Kind cluster, Terranetes, and CLI
./deploy.sh          # Deploys the infrastructure
```

**What you get:**
- Kubernetes-native infrastructure management
- GitOps-ready deployments
- Multi-tenant resource provisioning
- Policy enforcement and compliance
- State management in Kubernetes

See the [Terranetes Guide](TERRANETES_GUIDE.md) for detailed instructions.

---

### Option B: Traditional Terraform/OpenTofu Deployment

#### Prerequisites

1. **OpenTofu or Terraform**: Install one of these tools
   ```bash
   # macOS
   brew install opentofu
   ```

2. **Azure CLI**: Install and authenticate
   ```bash
   # macOS
   brew install azure-cli
   
   # Login to Azure
   az login
   
   az account set --subscription "YOUR_SUBSCRIPTION_NAME_OR_ID"
   ```

3. **GitHub Authentication**: Choose one method
   ```bash
   # Option 1: GitHub CLI (Recommended)
   brew install gh
   gh auth login
   
   # Option 2: Personal Access Token
   export GITHUB_TOKEN="your_github_token_here"
   ```

### Setup and Deployment

#### Option 1: Automated Deployment (Recommended)

1. **Set up Azure backend for state storage**:
   ```bash
   chmod +x scripts/setup-azure-backend.sh
   ./scripts/setup-azure-backend.sh
   ```
   
   This creates:
   - Resource group for state storage
   - Storage account with encryption and HTTPS
   - Blob container for state files
   - Versioning and soft delete enabled
   - `backend-config.tfvars` file

2. **Configure your variables**:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your values
   ```

3. **Deploy everything**:
   ```bash
   chmod +x scripts/deploy.sh
   ./scripts/deploy.sh
   ```
   
   The script will:
   - ✓ Check all prerequisites
   - ✓ Initialize with Azure backend
   - ✓ Validate configuration
   - ✓ Format code
   - ✓ Generate and show plan
   - ✓ Apply changes (with confirmation)
   - ✓ Display outputs with portal links

#### Option 2: Manual Step-by-Step

1. **Set up Azure backend** (See [AZURE_BACKEND_SETUP.md](AZURE_BACKEND_SETUP.md) for detailed instructions):
   ```bash
   # Set variables
   RESOURCE_GROUP_NAME="rg-tfstate-prod"
   STORAGE_ACCOUNT_NAME="tfstate$(date +%s)"
   CONTAINER_NAME="tfstate"
   LOCATION="westeurope"
   
   # Create resource group
   az group create \
     --name $RESOURCE_GROUP_NAME \
     --location $LOCATION \
     --tags "Purpose=TerraformState"
   
   # Create storage account
   az storage account create \
     --name $STORAGE_ACCOUNT_NAME \
     --resource-group $RESOURCE_GROUP_NAME \
     --location $LOCATION \
     --sku Standard_LRS \
     --encryption-services blob \
     --https-only true \
     --min-tls-version TLS1_2 \
     --allow-blob-public-access false
   
   # Create container
   az storage container create \
     --name $CONTAINER_NAME \
     --account-name $STORAGE_ACCOUNT_NAME \
     --auth-mode login
   
   # Enable versioning (recommended)
   az storage account blob-service-properties update \
     --account-name $STORAGE_ACCOUNT_NAME \
     --resource-group $RESOURCE_GROUP_NAME \
     --enable-versioning true
   
   # Enable soft delete (recommended)
   az storage account blob-service-properties update \
     --account-name $STORAGE_ACCOUNT_NAME \
     --resource-group $RESOURCE_GROUP_NAME \
     --enable-delete-retention true \
     --delete-retention-days 30
   
   # Create backend config file
   cat > backend-config.tfvars <<EOF
   resource_group_name  = "$RESOURCE_GROUP_NAME"
   storage_account_name = "$STORAGE_ACCOUNT_NAME"
   container_name       = "$CONTAINER_NAME"
   key                  = "idp.tfstate"
   EOF
   ```

2. **Configure variables**:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your preferred editor
   ```

3. **Initialize with backend**:
   ```bash
   tofu init -backend-config=backend-config.tfvars
   # or: terraform init -backend-config=backend-config.tfvars
   ```

4. **Validate configuration**:
   ```bash
   tofu validate
   ```

5. **Plan deployment**:
   ```bash
   tofu plan -out=tfplan
   ```

6. **Apply changes**:
   ```bash
   tofu apply tfplan
   ```

7. **View outputs**:
   ```bash
   tofu output
   ```

## Project Structure

```
.
├── README.md                      # This file
├── AZURE_BACKEND_SETUP.md         # Detailed backend setup guide
├── main.tf                        # Main resource definitions
├── providers.tf                   # Provider configurations
├── versions.tf                    # Version requirements
├── variables.tf                   # Variable definitions
├── outputs.tf                     # Output definitions
├── terraform.tfvars.example       # Example variables file
├── terraform.tfvars               # Your variables (not in git)
├── backend-config.tfvars          # Backend config (not in git)
└── scripts/
    ├── setup-azure-backend.sh     # Automated backend setup
    └── deploy.sh                  # Automated deployment
```

## Outputs

After successful deployment, you'll get:
- Azure Resource Group name, ID, and location
- Direct link to the Resource Group in Azure Portal
- GitHub repository name, URL, and clone URLs

## Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `resource_group_name` | Name of the Azure Resource Group | `"rg-idp-dev"` | No |
| `location` | Azure region | `"West Europe"` | No |
| `environment` | Environment tag | `"dev"` | No |
| `project_name` | Project name for tagging | `"identity-platform"` | No |
| `github_repo_name` | GitHub repository name | `"idp-infrastructure"` | No |
| `github_repo_description` | Repository description | `"Identity Platform Infrastructure and Configuration"` | No |
| `github_repo_visibility` | Repository visibility (public/private) | `"private"` | No |
| `github_repo_topics` | Repository topics/tags | `["terraform", "opentofu", "azure", "infrastructure", "iac"]` | No |

## Security Considerations

- **State Security**: State files are stored in Azure Storage with encryption at rest
- **State Locking**: Automatic state locking prevents concurrent modifications
- **Credentials**: Never commit `terraform.tfvars` or `backend-config.tfvars` with sensitive data
- **Azure AD Auth**: Use Azure AD authentication instead of storage account keys when possible
- **GitHub Tokens**: Use environment variables or GitHub CLI for authentication
- **Least Privilege**: Review and apply least-privilege access for service principals

## Advanced Configuration

### Using Azure AD Authentication for Backend

Add to your `versions.tf` or use in `backend-config.tfvars`:

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfstate-prod"
    storage_account_name = "tfstateXXXXXXXX"
    container_name       = "tfstate"
    key                  = "idp.tfstate"
    use_azuread_auth     = true
  }
}
```

### State Migration

If you need to migrate from local state to Azure backend:

```bash
tofu init -backend-config=backend-config.tfvars -migrate-state
```

### Multiple Environments

To manage multiple environments, use workspaces:

```bash
# Create workspaces
tofu workspace new dev
tofu workspace new staging
tofu workspace new prod

# Switch between workspaces
tofu workspace select dev

# List workspaces
tofu workspace list
```

Or use different state keys in your backend configuration:

```hcl
# backend-config-dev.tfvars
key = "idp-dev.tfstate"

# backend-config-prod.tfvars
key = "idp-prod.tfstate"
```

## Clean Up

To destroy the created resources:
```bash
tofu destroy
# or: terraform destroy
```

## Troubleshooting

### Common Issues

1. **Authentication Issues**:
   - Ensure you're logged in to Azure: `az login`
   - Verify GitHub authentication: `gh auth status` or check `GITHUB_TOKEN`

2. **Resource Group Already Exists**:
   - Choose a different name in `terraform.tfvars`
   - Or import existing resource group: `tofu import azurerm_resource_group.main /subscriptions/{subscription-id}/resourceGroups/{rg-name}`

3. **GitHub Repository Already Exists**:
   - Choose a different repository name
   - Or import existing repository: `tofu import github_repository.main {owner}/{repo-name}`

For Terranetes-specific troubleshooting, see the [Terranetes Guide](TERRANETES_GUIDE.md#troubleshooting).

## Documentation

- **[TERRANETES_GUIDE.md](TERRANETES_GUIDE.md)** - Complete guide for Kubernetes-native deployments with Terranetes
- **[GETTING_STARTED.md](GETTING_STARTED.md)** - Detailed getting started guide for traditional deployment
- **[AZURE_BACKEND_SETUP.md](AZURE_BACKEND_SETUP.md)** - Azure backend configuration details
- **[QUICK_REFERENCE.md](QUICK_REFERENCE.md)** - Quick command reference
- **[terranetes/README.md](terranetes/README.md)** - Terranetes manifests and deployment scripts

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test the configuration
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
