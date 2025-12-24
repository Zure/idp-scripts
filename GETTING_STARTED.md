# Getting Started - Step by Step Guide

Welcome! This guide will walk you through deploying your first infrastructure with OpenTofu and Azure.

## 🚀 Quick Start (5 minutes)

### Step 1: Install Prerequisites

```bash
# Install OpenTofu (or Terraform)
brew install opentofu

# Install Azure CLI
brew install azure-cli

# Install GitHub CLI (optional but recommended)
brew install gh
```

### Step 2: Authenticate

```bash
# Login to Azure
az login

# Login to GitHub (choose one method)
gh auth login
# OR
export GITHUB_TOKEN="your_github_personal_access_token"
```

### Step 3: Set Up Azure Backend for State

```bash
# Run the automated setup script
./scripts/setup-azure-backend.sh
```

**What this does:**
- Creates a resource group for storing Terraform state
- Creates a secure storage account
- Creates a blob container
- Enables versioning and soft delete for protection
- Generates `backend-config.tfvars` file

### Step 4: Configure Your Variables

```bash
# Copy the example file
cp terraform.tfvars.example terraform.tfvars

# Edit with your preferred values
nano terraform.tfvars  # or use vim, code, etc.
```

**Customize these values:**
```hcl
resource_group_name = "rg-myproject-dev"        # Your resource group name
location           = "West Europe"               # Your preferred Azure region
environment        = "dev"                       # dev, staging, or prod
project_name       = "my-project"               # Your project name

github_repo_name        = "my-infrastructure"   # Your GitHub repo name
github_repo_description = "My Infrastructure"   # Description
github_repo_visibility  = "private"             # public or private
```

### Step 5: Deploy Everything

```bash
# Run the automated deployment script
./scripts/deploy.sh
```

**What this does:**
- ✅ Checks all prerequisites
- ✅ Initializes OpenTofu with Azure backend
- ✅ Validates your configuration
- ✅ Formats your code
- ✅ Shows you the execution plan
- ✅ Asks for confirmation
- ✅ Applies the changes
- ✅ Shows you the outputs with direct links

### Step 6: Verify Your Resources

After deployment completes, you'll see output like:

```
azure_portal_url = "https://portal.azure.com/#@/resource/subscriptions/..."
github_repo_url  = "https://github.com/yourusername/my-infrastructure"
resource_group_name = "rg-myproject-dev"
```

Click the links to view your resources!