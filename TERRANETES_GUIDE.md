# Terranetes Deployment Guide

This guide walks you through deploying your Terraform/OpenTofu module using Terranetes in a Kubernetes cluster.

## Table of Contents
- [Prerequisites](#prerequisites)
- [Step 1: Create a Kind Cluster](#step-1-create-a-kind-cluster)
- [Step 2: Install Terranetes in the Cluster](#step-2-install-terranetes-in-the-cluster)
- [Step 3: Install Terranetes CLI Locally](#step-3-install-terranetes-cli-locally)
- [Step 4: Prepare Your Module for Terranetes](#step-4-prepare-your-module-for-terranetes)
- [Step 5: Generate CloudResource from the TF Module](#step-5-generate-cloudresource-from-the-tf-module)
- [Step 6: Deploy the Module in the Cluster](#step-6-deploy-the-module-in-the-cluster)
- [Troubleshooting](#troubleshooting)
- [Cleanup](#cleanup)

## Prerequisites

Before starting, ensure you have the following installed:

- **Docker Desktop** (required for Kind)
- **kubectl** - Kubernetes command-line tool
- **Helm** - Kubernetes package manager
- **Kind** (Kubernetes in Docker)

### Install Prerequisites (macOS)

```bash
# Install kubectl
brew install kubectl

# Install Helm
brew install helm

# Install Kind
brew install kind
```

## Step 1: Create a Kind Cluster

Create a local Kubernetes cluster using Kind:

```bash
# Create a cluster named 'terranetes'
kind create cluster --name terranetes

# Verify the cluster is running
kubectl cluster-info --context kind-terranetes

# Check nodes
kubectl get nodes
```

### Optional: Create with Custom Configuration

For more control, create a Kind configuration file:

```yaml
# kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: terranetes
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30000
    hostPort: 30000
    protocol: TCP
```

Then create the cluster:

```bash
kind create cluster --config kind-config.yaml
```

## Step 2: Install Terranetes in the Cluster

Terranetes is installed using Helm charts.

### Add Terranetes Helm Repository

```bash
# Add the Terranetes Helm repository
helm repo add appvia https://terranetes-controller.appvia.io

# Update Helm repositories
helm repo update
```

### Install Terranetes Controller

```bash
# Create a namespace for Terranetes
kubectl create namespace terranetes-system

# Install the Terranetes controller
helm install terranetes-controller appvia/terranetes-controller \
  --namespace terranetes-system \
  --set controller.costs.enabled=false

# Verify the installation
kubectl get pods -n terranetes-system

# Wait for the controller to be ready
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=terranetes-controller \
  -n terranetes-system \
  --timeout=300s
```

### Verify CRDs are Installed

```bash
# Check that Terranetes Custom Resource Definitions are installed
kubectl get crds | grep terraform
```

You should see CRDs like:
- `cloudresources.terraform.appvia.io`
- `configurations.terraform.appvia.io`
- `plans.terraform.appvia.io`
- `policies.terraform.appvia.io`
- `providers.terraform.appvia.io`

## Step 3: Install Terranetes CLI Locally

The Terranetes CLI (`tnctl`) helps manage Terraform resources in Kubernetes.

### Install tnctl (macOS)

```bash
# Download the latest release for macOS
curl -L https://github.com/appvia/terranetes-controller/releases/latest/download/tnctl-darwin-arm64 -o tnctl

# Make it executable
chmod +x tnctl

# Move to PATH
sudo mv tnctl /usr/local/bin/

# Verify installation
tnctl --version
```

## Step 4: Prepare Your Module for Terranetes

### Create a Git Repository (if not already done)

Terranetes can reference modules from Git repositories or use inline modules.

```bash
# Initialize git if not already done
git init

# Add all files
git add .

# Commit
git commit -m "Initial commit"

# Push to GitHub (update with your repo URL)
git remote add origin https://github.com/geertvdc/idp-infrastructure.git
git push -u origin main
```

### Create Kubernetes Secrets for Provider Credentials

Terranetes needs credentials to provision Azure resources.

#### Azure Credentials

```bash
# Create a service principal for Azure (if you don't have one)
az ad sp create-for-rbac \
  --name "terranetes-sp" \
  --role Contributor \
  --scopes /subscriptions/<YOUR_SUBSCRIPTION_ID>

# This will output:
# {
#   "appId": "xxx",
#   "displayName": "terranetes-sp",
#   "password": "xxx",
#   "tenant": "xxx"
# }

# Create Kubernetes secret with Azure credentials in terranetes-system namespace
kubectl create secret generic azure-credentials \
  --namespace terranetes-system \
  --from-literal=ARM_CLIENT_ID=<appId> \
  --from-literal=ARM_CLIENT_SECRET=<password> \
  --from-literal=ARM_SUBSCRIPTION_ID=<subscription-id> \
  --from-literal=ARM_TENANT_ID=<tenant>
```

#### GitHub Credentials

```bash
# Create a GitHub personal access token
# Go to: https://github.com/settings/tokens
# Generate a token with 'repo' scope

# Best practice: Create the secret in terranetes-system for centralized secret management
kubectl create secret generic github-credentials \
  --namespace terranetes-system \
  --from-literal=GITHUB_TOKEN=<your-github-token>

# Verify the secret was created
kubectl get secret github-credentials -n terranetes-system
```

#### Important Namespace Rules

- **Provider secrets** (`secretRef`) → Must be in `terranetes-system` namespace (where controller runs)
- **Configuration secrets** (`valueFrom`) → Can be in ANY namespace (specify with `namespace` field)
  - If `namespace` is omitted, defaults to same namespace as the Configuration

**Recommended approach for centralized secret management:**
- Create ALL secrets in `terranetes-system` namespace
- Reference them from Configurations using the `namespace` field

This provides:
- ✅ Centralized secret management
- ✅ Single source of truth for credentials
- ✅ Easier secret rotation and auditing

## Step 5: Understanding Terranetes Resource Model

Terranetes supports two approaches for provisioning cloud resources:

### Approach 1: Direct Configuration (Simple)
- **Configuration** - Defines the Terraform module directly
- One-to-one mapping to Terraform module
- Full access to all module variables

### Approach 2: CloudResource + Revision (Managed - Platform Team Recommended)
- **Revision** - Template that defines what users can customize
- **Plan** - Collection of Revisions (versions), automatically created
- **CloudResource** - User-facing resource instance
- **Configuration** - Auto-created by Terranetes behind the scenes

The **CloudResource approach is recommended for platform teams** because it:
- Hides complexity from end users
- Enforces organizational defaults
- Provides version control over infrastructure templates
- Allows selective exposure of variables

**We'll use Approach 1 (Direct Configuration) in this guide** for simplicity, but see the [Advanced: CloudResource](#advanced-using-cloudresource-and-revisions) section to learn the platform team approach.

## Step 5: Generate Terranetes Manifests

Now we'll create Kubernetes manifests for Terranetes.

### Create Provider Configuration

First, create a Provider resource for Azure:

```yaml
# terranetes/provider-azure.yaml
apiVersion: terraform.appvia.io/v1alpha1
kind: Provider
metadata:
  name: azure
spec:
  provider: azurerm
  source: secret
  secretRef:
    name: azure-credentials
    namespace: terranetes-system
  summary: Azure credentials for Terranetes
```

Create a Provider resource for GitHub:

```yaml
# terranetes/provider-github.yaml
apiVersion: terraform.appvia.io/v1alpha1
kind: Provider
metadata:
  name: github
spec:
  provider: github
  source: secret
  secretRef:
    name: github-credentials
    namespace: terranetes-system
  summary: GitHub credentials for Terranetes
```

**Important:** In Terranetes, the `Provider` resource defines **credential sources**, not Terraform provider versions. The Terraform provider versions (like `hashicorp/azurerm ~> 4.0`) are defined in the `Configuration` resource's module code or Terraform files.

### Create Configuration for Module

Create a Configuration that contains your Terraform module inline:

```yaml
# terranetes/configuration.yaml
apiVersion: terraform.appvia.io/v1alpha1
kind: Configuration
metadata:
  name: idp-module
spec:
  # Inline Terraform module code
  module: |
    resource "azurerm_resource_group" "main" {
      name     = var.resource_group_name
      location = var.location
      
      tags = {
        Environment = var.environment
        Project     = var.project_name
      }
    }

    resource "github_repository" "main" {
      name        = var.github_repo_name
      description = var.github_repo_description
      visibility  = var.github_repo_visibility
      auto_init   = true

      has_issues      = true
      has_projects    = false
      has_wiki        = false
      has_downloads   = true
      has_discussions = false
    }

    variable "resource_group_name" {
      type = string
      description = "Name of the Azure Resource Group"
    }
    
    variable "location" {
      type = string
      description = "Azure region for the Resource Group"
    }
    
    variable "environment" {
      type = string
      description = "Environment tag for resources"
    }
    
    variable "project_name" {
      type = string
      description = "Project name for tagging and naming resources"
    }
    
    variable "github_repo_name" {
      type = string
      description = "Name of the GitHub repository"
    }
    
    variable "github_repo_description" {
      type = string
      description = "Description of the GitHub repository"
    }
    
    variable "github_repo_visibility" {
      type = string
      description = "Visibility of the GitHub repository"
    }

  providerRef:
    name: azure

  # Inject GitHub credentials as environment variables
  # NOTE: This secret must be in the SAME namespace as this Configuration (default)
  valueFrom:
    - secret: github-credentials
      name: GITHUB_TOKEN
      key: GITHUB_TOKEN
```

**Note:** The `providerRef` points to the Provider resource we created (named `azure`), which handles Azure credentials from the `terranetes-system` namespace. For GitHub, we inject the credentials as environment variables using `valueFrom`, referencing the secret in `terranetes-system` using the `namespace` field.

### Alternative: Use Git Repository as Source

Instead of inline code, you can reference a Git repository:

```yaml
# terranetes/configuration-git.yaml
apiVersion: terraform.appvia.io/v1alpha1
kind: Configuration
metadata:
  name: idp-module-git
spec:
  # Reference your Git repository
  module: https://github.com/geertvdc/idp-scripts.git?ref=main
  
  # Provide variable values
  variables:
    resource_group_name: "rg-idp-dev"
    location: "West Europe"
    environment: "dev"
    project_name: "identity-platform"
    github_repo_name: "idp-infrastructure"
    github_repo_description: "Identity Platform Infrastructure and Configuration"
    github_repo_visibility: "private"
  
  providerRef:
    name: azure

  valueFrom:
    - secret: github-credentials
      namespace: terranetes-system  # Reference secret from terranetes-system namespace
      name: GITHUB_TOKEN
      key: GITHUB_TOKEN
```

### Create CloudResource Instance

Create a CloudResource that uses the Configuration:

```yaml
# terranetes/cloudresource.yaml
apiVersion: terraform.appvia.io/v1alpha1
kind: CloudResource
metadata:
  name: idp-dev-resources
spec:
  # Reference the configuration
  configurationRef:
    name: idp-module
  
  # Override variables
  variables:
    resource_group_name: "rg-idp-terranetes-dev"
    location: "West Europe"
    environment: "dev"
    project_name: "identity-platform"
    github_repo_name: "idp-infrastructure-terranetes"
    github_repo_description: "Identity Platform Infrastructure deployed via Terranetes"
    github_repo_visibility: "private"
  
  # Terraform execution settings
  enableAutoApproval: false  # Set to true to auto-approve plans
  
  # Write connection details to a secret (optional)
  writeConnectionSecretToRef:
    name: idp-connection-details
```

## Step 6: Deploy Using Direct Configuration

In this section, we'll deploy using the direct Configuration approach (the simpler method).

### Apply Provider Configurations

```bash
# Create the terranetes directory if not exists
mkdir -p terranetes

# Apply the providers
kubectl apply -f terranetes/provider-azure.yaml
kubectl apply -f terranetes/provider-github.yaml

# Verify providers
kubectl get providers
```

### Apply Configuration

```bash
# Apply the configuration
kubectl apply -f terranetes/configuration.yaml

# Verify configuration
kubectl get configurations

# Monitor the deployment
kubectl describe configuration idp-module
```

The Configuration will automatically:
1. Create a Terraform workspace
2. Initialize Terraform with the specified module
3. Generate a plan
4. Wait for approval (if `enableAutoApproval` is false)

### Monitor the Deployment

```bash
# Check the status of your Configuration
kubectl describe configuration idp-module

# View the Terraform plan
kubectl get jobs -l terraform.appvia.io/configuration=idp-module

# View the logs of the Terraform job
kubectl logs -l terraform.appvia.io/configuration=idp-module -f

# Check if the Configuration is ready
kubectl get configurations
```

### Approve the Plan (if auto-approval is disabled)

If you set `enableAutoApproval: false` in the Configuration, you'll need to manually approve:

```bash
# Approve using tnctl
tnctl approve configuration idp-module

# Or approve using kubectl
kubectl patch configuration idp-module \
  --type merge \
  -p '{"spec":{"enableAutoApproval":true}}'
```

### Check the Outputs

```bash
# Once applied, check the configuration status
kubectl get configuration idp-module -o yaml

# Check if outputs are stored (if writeConnectionSecretToRef is configured)
kubectl get secret idp-connection-details -o yaml
```

## Advanced: Using CloudResource and Revisions

The **CloudResource + Revision approach is recommended for platform teams** who want to provide managed infrastructure templates to end users.

### Understanding the Model

When using CloudResources:

1. **Revision** - A curated template created by platform team
   - Contains the Terraform module reference
   - Defines platform defaults
   - Specifies which variables users can override
   - Versioned using SemVer

2. **Plan** - Automatically created by grouping Revisions
   - All Revisions with same `spec.plan.name` form a Plan
   - Plans track versions using SemVer
   - Users can reference specific versions or "latest"

3. **CloudResource** - User-facing resource instance
   - References a Revision (or Plan for latest version)
   - Users only see exposed variables
   - Platform defaults are enforced

4. **Configuration** - Created automatically in the background
   - Terranetes creates this from Revision + CloudResource
   - Users don't interact with it directly

### Step 1: Create a Revision

Use `tnctl` to create a Revision from your Terraform module:

```bash
# Create a Revision from your local module
tnctl create revision . \
  --name database \
  --revision v1.0.0 \
  --description "PostgreSQL database for applications" \
  --provider azure \
  --file terranetes/revision-database-v1.yaml

# Or from a Git repository
tnctl create revision https://github.com/terraform-aws-modules/terraform-aws-rds?ref=v5.9.0 \
  --name rds-database \
  --revision v5.9.0 \
  --provider aws \
  --file terranetes/revision-rds-v5.yaml
```

This command:
- Analyzes your Terraform module
- Extracts all variables
- Creates a Revision CRD with all inputs exposed
- Saves it to a file for you to customize

### Step 2: Customize the Revision

Edit the generated Revision to:
- Set platform defaults
- Hide sensitive/complex variables from users
- Add categories and better descriptions

```yaml
# terranetes/revision-database-v1.yaml
apiVersion: terraform.appvia.io/v1alpha1
kind: Revision
metadata:
  name: database-v1-0-0
spec:
  # Plan metadata
  plan:
    name: database           # Groups all versions together
    revision: v1.0.0         # SemVer version
    description: "Managed PostgreSQL database with backups"
    categories: [database, postgresql, azure]
  
  # Variables users CAN customize
  inputs:
    - key: database_name
      description: "Name of the database"
      required: true
    
    - key: database_size
      description: "Database size tier"
      required: false
      default:
        value: "small"  # Platform default
    
    - key: backup_retention_days
      description: "Number of days to retain backups"
      required: false
      default:
        value: "7"  # Platform default
  
  # Terraform module and defaults
  configuration:
    module: https://github.com/your-org/terraform-azure-database.git?ref=v1.0.0
    
    providerRef:
      name: azure
    
    # Platform-enforced defaults (users cannot override)
    variables:
      enable_ssl: "true"
      enable_backups: "true"
      backup_geo_replication: "true"
      min_tls_version: "TLS1_2"
    
    writeConnectionSecretToRef:
      name: database-connection
```

### Step 3: Apply the Revision

```bash
# Apply the Revision
kubectl apply -f terranetes/revision-database-v1.yaml

# Verify the Revision
kubectl get revisions

# Check if a Plan was created automatically
kubectl get plans

# View the Plan details
kubectl describe plan database
```

The Plan is automatically created by Terranetes and groups all Revisions with `spec.plan.name: database`.

### Step 4: Create a CloudResource

End users now create CloudResources that reference the Revision or Plan:

```yaml
# user-database.yaml
apiVersion: terraform.appvia.io/v1alpha1
kind: CloudResource
metadata:
  name: my-app-database
spec:
  # Reference the plan (gets latest version)
  plan:
    name: database
  
  # Or reference a specific revision
  # revision: v1.0.0
  
  # Users only provide the exposed inputs
  variables:
    database_name: "myapp-prod-db"
    database_size: "large"
    backup_retention_days: "30"
```

### Step 5: Deploy the CloudResource

```bash
# User applies their CloudResource
kubectl apply -f user-database.yaml

# Monitor the CloudResource
kubectl get cloudresources

kubectl describe cloudresource my-app-database

# Approve if needed
tnctl approve cloudresource my-app-database
```

Behind the scenes, Terranetes:
1. Looks up the Plan "database"
2. Finds the latest Revision (v1.0.0)
3. Merges user variables with platform defaults
4. Creates a managed Configuration
5. Runs Terraform

### Benefits of CloudResource Approach

**For Platform Teams:**
- Enforce organizational standards
- Control what users can modify
- Version infrastructure templates
- Validate inputs before deployment

**For End Users:**
- Simple, curated interface
- No need to understand complex Terraform
- Self-service infrastructure provisioning
- Clear documentation of what can be customized

### Version Management

Create new versions as your infrastructure evolves:

```bash
# Create v1.1.0 with new features
tnctl create revision https://github.com/your-org/terraform-azure-database.git?ref=v1.1.0 \
  --name database \
  --revision v1.1.0 \
  --provider azure \
  --file terranetes/revision-database-v1.1.yaml

# Apply the new Revision
kubectl apply -f terranetes/revision-database-v1.1.yaml

# Users can now upgrade by changing their CloudResource
# Either reference specific version:
#   revision: v1.1.0
# Or keep using latest:
#   plan: { name: database }  # automatically uses v1.1.0 now
```

### Validate Revisions

Use `tnctl` to validate Revisions before deploying:

```bash
# Validate a Revision
tnctl verify revision terranetes/revision-database-v1.yaml

# With actual credentials to test Terraform plan
export ARM_CLIENT_ID=xxx
export ARM_CLIENT_SECRET=xxx
tnctl verify revision terranetes/revision-database-v1.yaml --use-terraform-plan
```

## Troubleshooting

### Check Controller Logs

```bash
# View Terranetes controller logs
kubectl logs -n terranetes-system -l app.kubernetes.io/name=terranetes-controller -f
```

### Check Job Pods

```bash
# List all jobs created by Terranetes
kubectl get jobs

# Check pod status
kubectl get pods

# View logs from a specific job
kubectl logs job/<job-name>
```

### Common Issues

1. **Provider Authentication Failures**
   - Verify secrets are created correctly: `kubectl get secrets -n terranetes-system`
   - Check secret contents: `kubectl describe secret -n terranetes-system azure-credentials`

2. **Plan Not Generating**
   - Check Configuration status: `kubectl describe configuration idp-module`
   - Verify provider references are correct

3. **Module Source Issues**
   - Ensure Git repository is accessible
   - For private repos, add SSH keys or tokens

### Debugging with tnctl

For **Configuration** approach:

```bash
# Get detailed status
tnctl describe configuration idp-module

# View logs
tnctl logs configuration idp-module

# Force a reconciliation
kubectl annotate configuration idp-module terraform.appvia.io/reconcile="$(date +%s)"
```

For **CloudResource** approach:

```bash
# Get detailed status
tnctl describe cloudresource my-app-database

# View logs
tnctl logs cloudresource my-app-database

# Verify the Revision
tnctl verify revision terranetes/revision-database-v1.yaml

# Force a reconciliation
kubectl annotate cloudresource my-app-database terraform.appvia.io/reconcile="$(date +%s)"
```

## Cleanup

### For Direct Configuration Approach

```bash
# Delete the Configuration (this will destroy the Terraform resources)
kubectl delete configuration idp-module

# Monitor deletion
kubectl get configurations -w
```

### For CloudResource Approach

```bash
# Delete the CloudResource (this will destroy the Terraform resources)
kubectl delete cloudresource my-app-database

# Monitor deletion
kubectl get cloudresources -w

# Optionally delete Revisions and Plans
kubectl delete revision database-v1-0-0
kubectl get plans  # Plans are auto-deleted when all Revisions are removed
```

### Delete Providers and Secrets

```bash
kubectl delete provider azure
kubectl delete provider github

kubectl delete secret -n terranetes-system azure-credentials
kubectl delete secret -n terranetes-system github-credentials
```

### Uninstall Terranetes

```bash
# Uninstall the Helm release
helm uninstall terranetes-controller -n terranetes-system

# Delete the namespace
kubectl delete namespace terranetes-system
```

### Delete Kind Cluster

```bash
# Delete the entire cluster
kind delete cluster --name terranetes
```

## Next Steps

- **GitOps Integration**: Integrate with ArgoCD or Flux for GitOps workflows
- **Policy Management**: Use Terranetes Policies to enforce compliance
- **Cost Management**: Enable cost estimation features
- **Multi-Environment**: Create separate CloudResources for dev/staging/prod
- **CI/CD Integration**: Automate deployments with GitHub Actions or Jenkins

## Additional Resources

- [Terranetes Documentation](https://terranetes-controller.appvia.io/)
- [Terranetes GitHub Repository](https://github.com/appvia/terranetes-controller)
- [Kind Documentation](https://kind.sigs.k8s.io/)
- [Kubernetes Documentation](https://kubernetes.io/docs/home/)

## Notes

- The module uses both Azure and GitHub providers, requiring credentials for both
- Terranetes runs Terraform in Kubernetes Jobs, providing isolation and scalability
- State is stored in Kubernetes ConfigMaps by default (can be configured to use remote backends)
- CloudResources can be managed via GitOps tools for declarative infrastructure management
