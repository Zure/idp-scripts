# Terranetes Deployment Guide

This guide walks you through deploying your OpenTofu/Terraform module using Terranetes in a Kubernetes cluster.

## Table of Contents
- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Manual Setup](#manual-setup)
  - [Step 1: Create Kind Cluster](#step-1-create-kind-cluster)
  - [Step 2: Install Terranetes](#step-2-install-terranetes)
  - [Step 3: Install Terranetes CLI](#step-3-install-terranetes-cli)
  - [Step 4: Create Secrets](#step-4-create-secrets)
  - [Step 5: Deploy with Revision + CloudResource](#step-5-deploy-with-revision--cloudresource)
- [Understanding the Setup](#understanding-the-setup)
- [Important: Provider and Backend Configuration](#important-provider-and-backend-configuration)
- [Monitoring and Troubleshooting](#monitoring-and-troubleshooting)
- [Cleanup](#cleanup)

## Overview

This repository contains OpenTofu/Terraform code that provisions:
- **Azure Resource Group** - For organizing Azure resources
- **GitHub Repository** - For infrastructure code

The deployment uses **Terranetes**, a Kubernetes operator that runs Terraform/OpenTofu in a GitOps-friendly way.

## Prerequisites

Before starting, ensure you have installed:

- **Docker Desktop** (required for Kind)
- **kubectl** - Kubernetes command-line tool
- **Helm** - Kubernetes package manager
- **Kind** (Kubernetes in Docker)

### Install Prerequisites (macOS)

```bash
brew install kubectl helm kind
```

## Quick Start

The fastest way to get started is using the automated setup script:

```bash
cd terranetes
./setup-complete.sh
```

This script will:
1. ✅ Create a Kind cluster named 'terranetes'
2. ✅ Install Terranetes controller
3. ✅ Install Terranetes CLI (tnctl)
4. ✅ Prompt you to create Azure and GitHub credentials

After setup completes, deploy your infrastructure:

```bash
./deploy.sh
```

That's it! Skip to [Monitoring and Troubleshooting](#monitoring-and-troubleshooting) section.

---

## Manual Setup

If you prefer to understand each step or the automated script fails, follow these manual steps.

### Step 1: Create Kind Cluster

Create a local Kubernetes cluster using Kind with the provided configuration:

```bash
# Create cluster using the provided configuration
kind create cluster --config terranetes/kind-config.yaml

# Verify the cluster is running
kubectl cluster-info --context kind-terranetes

# Check nodes
kubectl get nodes
```

The `kind-config.yaml` configures:
- Cluster name: `terranetes`
- Exposed ports: 30000-30001 for services
- Node labels for ingress support

### Step 2: Install Terranetes

Install the Terranetes controller using Helm:

```bash
# Add Terranetes Helm repository
helm repo add appvia https://terranetes-controller.appvia.io
helm repo update

# Create namespace for Terranetes
kubectl create namespace terranetes-system

# Install Terranetes controller
helm install terranetes-controller appvia/terranetes-controller \
  --namespace terranetes-system \
  --set controller.costs.enabled=false

# Wait for controller to be ready
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=terranetes-controller \
  -n terranetes-system \
  --timeout=300s
```

Verify CRDs are installed:

```bash
kubectl get crds | grep terraform.appvia.io
```

You should see:
- `cloudresources.terraform.appvia.io`
- `configurations.terraform.appvia.io`
- `plans.terraform.appvia.io`
- `policies.terraform.appvia.io`
- `providers.terraform.appvia.io`
- `revisions.terraform.appvia.io`

### Step 3: Install Terranetes CLI

The Terranetes CLI (`tnctl`) helps manage and troubleshoot deployments:

```bash
# Detect architecture
if [[ $(uname -m) == "arm64" ]]; then
    ARCH="arm64"
else
    ARCH="amd64"
fi

# Download latest release
TNCTL_VERSION=$(curl -s https://api.github.com/repos/appvia/terranetes-controller/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')

curl -L "https://github.com/appvia/terranetes-controller/releases/download/${TNCTL_VERSION}/tnctl-darwin-${ARCH}" -o tnctl

# Install
chmod +x tnctl
sudo mv tnctl /usr/local/bin/

# Verify
tnctl version
```

### Step 4: Create Secrets

Terranetes needs credentials for Azure and GitHub. Secrets must be created in the `terranetes-system` namespace.

#### Azure Credentials

```bash
az ad sp create-for-rbac \
  --name "terranetes-sp" \
  --role Contributor \
  --scopes /subscriptions/<YOUR_SUBSCRIPTION_ID>


kubectl create secret generic azure-credentials \
  --namespace terranetes-system \
  --from-literal=ARM_CLIENT_ID=<your-client-id> \
  --from-literal=ARM_CLIENT_SECRET=<your-client-secret> \
  --from-literal=ARM_SUBSCRIPTION_ID=<your-subscription-id> \
  --from-literal=ARM_TENANT_ID=<your-tenant-id>

```

#### GitHub Credentials

```bash
# Create a GitHub Personal Access Token at:
# https://github.com/settings/tokens
# Required scopes: 'repo' (full control of private repositories)

kubectl create secret generic github-credentials \
  --namespace terranetes-system \
  --from-literal=GITHUB_TOKEN=<your-github-token>
```

#### Verify Secrets

```bash
kubectl get secrets -n terranetes-system
```

### Step 5: Deploy with Revision + CloudResource

This repository uses the **Revision + CloudResource** pattern, which is the recommended approach for platform teams.

#### Understanding the Deployment Model

1. **Revision** (`test-idp.yaml`) - A versioned template created by the platform team
   - Contains the Terraform module reference
   - Defines which variables users can customize
   - Sets platform defaults
   - Version: `v0.0.1`

2. **Plan** - Automatically created by grouping Revisions
   - All Revisions with `spec.plan.name: test-idp` form a Plan
   - Users reference the Plan to get the latest version

3. **Provider** (`provider-azure.yaml`) - Credentials for Azure
   - References the `azure-credentials` secret

4. **CloudResource** (`cloudresource.yaml`) - The actual deployment instance
   - References the Plan and Revision
   - Provides user-customizable values
   - Creates Azure Resource Group and GitHub Repository

5. **Configuration** - Created automatically by Terranetes
   - You don't manage this directly

#### Deploy the Resources

```bash
cd terranetes

# 1. Apply the Azure provider
kubectl apply -f provider-azure.yaml

# 2. Apply the Revision (this creates the Plan automatically)
kubectl apply -f test-idp.yaml

# 3. Apply the Policy (for GitHub credentials injection)
kubectl apply -f gh-policy.yaml

# 4. Apply the CloudResource
kubectl apply -f cloudresource.yaml
```

#### Monitor Deployment

```bash
# Check CloudResource status
kubectl get cloudresources

# Detailed status
kubectl describe cloudresource idp-dev-resources -n apps

# View Terraform plan/apply logs
kubectl get pods
kubectl logs <pod-name> -f
```

#### Approve the Plan

Since `enableAutoApproval: false` in the CloudResource, you need to approve manually:

```bash
# Option 1: Using tnctl
tnctl approve cloudresource idp-dev-resources

# Option 2: Using kubectl
kubectl patch cloudresource idp-dev-resources \
  --type merge \
  -p '{"spec":{"enableAutoApproval":true}}'
```

## Understanding the Setup

### What Gets Deployed?

The CloudResource provisions:

1. **Azure Resource Group**
   - Name: Customizable via `resource_group_name` variable
   - Location: Customizable via `location` variable

2. **GitHub Repository**
   - Name: Customizable via `github_repo_name` variable
   - Description: Set in Revision as default
   - Visibility: Set in Revision as `private`
   - Topics: `terraform`, `opentofu`, `azure`, `infrastructure`, `iac`

### Revision Structure

The `test-idp.yaml` Revision exposes these inputs to users:

| Variable | Description | Default |
|----------|-------------|---------|
| `resource_group_name` | Azure RG name | `rg-idp-dev` |
| `location` | Azure region | `West Europe` |
| `environment` | Environment tag | `dev` |
| `github_repo_name` | GitHub repo name | `idp-infrastructure` |

The Revision also sets **platform defaults** that users cannot override:
- `github_repo_description`: "Identity Platform Infrastructure and Configuration"
- `github_repo_visibility`: `private`
- `github_repo_topics`: Array of relevant topics
- `project_name`: `identity-platform`

### GitHub Credentials Injection

The `gh-policy.yaml` Policy automatically injects GitHub credentials into Terraform runs:

```yaml
spec:
  defaults:
    - selector:
        modules:
          - github.com/Zure/.*
        namespace:
          matchLabels:
            terranetes.appvia.io/github-token: "true"
      secrets:
        - github-credentials
```

This means:
- Modules from `github.com/Zure/*` get GitHub credentials automatically
- Only namespaces with the label `terranetes.appvia.io/github-token: "true"` get credentials
- The `github-credentials` secret is injected as environment variables

**Important:** To use this, label your namespace:

```bash
kubectl label namespace default terranetes.appvia.io/github-token=true
```

## Important: Provider and Backend Configuration

When using Terranetes, you **MUST NOT** define `provider` blocks or `backend` blocks in your Terraform code.

### ❌ WRONG - Do Not Include These

```hcl
# DON'T include this in providers.tf
provider "azurerm" {
  features {}
}

# DON'T include this in versions.tf
terraform {
  backend "azurerm" {
    # ...
  }
}
```

### ✅ CORRECT - What You Should Have

Your `providers.tf` should only have providers that are NOT managed by Terranetes Provider resources:

```hcl
# Configure the GitHub Provider
# GitHub credentials come from Policy injection
provider "github" {
  # Token is automatically set via GITHUB_TOKEN environment variable
}
```

Your `versions.tf` should have **NO backend block**:

```hcl
terraform {
  required_version = ">= 1.0"
  
  # NO backend configuration - Terranetes uses Kubernetes backend
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}
```

### Why?

Terranetes automatically:
1. **Injects the provider configuration** via `provider.tf.json` using credentials from the Provider resource
2. **Configures the backend** via `backend.tf.json` to store state in Kubernetes secrets

If you define these blocks, you'll get errors:
- `Error: Duplicate provider configuration`
- `Error: Duplicate backend configuration`

## Monitoring and Troubleshooting

### Check CloudResource Status

```bash
# List all CloudResources
kubectl get cloudresources -n apps

# Get detailed status
kubectl describe cloudresource idp-dev-resources -n apps

# Watch for changes
kubectl get cloudresources -w
```

### View Terraform Logs

```bash
# List pods
kubectl get pods

# Find the Terraform job pod
kubectl get pods -l terraform.appvia.io/configuration

# View logs
kubectl logs -l terraform.appvia.io/configuration -f
```

### Check Terranetes Controller Logs

```bash
kubectl logs -n terranetes-system -l app.kubernetes.io/name=terranetes-controller -f
```

### Common Issues

#### 1. Provider Authentication Failures

**Symptoms:**
- Terraform fails with "Error: building account" or authentication errors

**Solution:**
```bash
# Verify secrets exist
kubectl get secret -n terranetes-system azure-credentials
kubectl get secret -n terranetes-system github-credentials

# Check secret contents (base64 encoded)
kubectl get secret -n terranetes-system azure-credentials -o yaml

# Recreate secrets if incorrect
kubectl delete secret -n terranetes-system azure-credentials
kubectl create secret generic azure-credentials \
  --namespace terranetes-system \
  --from-literal=ARM_CLIENT_ID=<correct-value> \
  # ... other values
```

#### 2. Duplicate Provider Configuration

**Symptoms:**
```
Error: Duplicate provider configuration
  on providers.tf line 4:
   4: provider "azurerm" {
```

**Solution:**
Remove the `provider "azurerm"` block from your `providers.tf` file. Terranetes injects this automatically.

#### 3. Provider Version Mismatch

**Symptoms:**
```
Error: Failed to resolve provider packages
  locked provider registry.opentofu.org/hashicorp/azurerm 3.117.1 does not match configured version constraint ~> 4.0
```

**Solution:**
```bash
# Update the lock file
cd /path/to/terraform-code
tofu init -upgrade -reconfigure
git add .terraform.lock.hcl
git commit -m "Update provider lock file"
git push
```

#### 4. Module Not Found

**Symptoms:**
- Error: "Failed to download module"

**Solution:**
- Ensure your Git repository URL in the Revision is correct
- Verify the repository is public OR credentials are properly configured
- Check the repository reference (branch/tag) exists

#### 5. Plan Not Generating

**Symptoms:**
- CloudResource stays in "Pending" state

**Solution:**
```bash
# Check CloudResource events
kubectl describe cloudresource idp-dev-resources

# Check if Revision exists
kubectl get revisions

# Check if Plan was created
kubectl get plans

# Force reconciliation
kubectl annotate cloudresource idp-dev-resources \
  terraform.appvia.io/reconcile="$(date +%s)"
```

### Using tnctl for Debugging

```bash
# Get detailed CloudResource info
tnctl describe cloudresource idp-dev-resources

# View logs
tnctl logs cloudresource idp-dev-resources

# Approve plan
tnctl approve cloudresource idp-dev-resources

# Verify a Revision
tnctl verify revision terranetes/test-idp.yaml
```

## Cleanup

### Delete CloudResource (Destroys Infrastructure)

```bash
# This will run 'terraform destroy' on your resources
kubectl delete cloudresource idp-dev-resources

# Monitor deletion
kubectl get cloudresources -w
```

### Delete Terranetes Resources

```bash
cd terranetes

# Delete in reverse order
kubectl delete -f cloudresource.yaml
kubectl delete -f test-idp.yaml
kubectl delete -f gh-policy.yaml
kubectl delete -f provider-azure.yaml
```

### Delete Secrets

```bash
kubectl delete secret -n terranetes-system azure-credentials
kubectl delete secret -n terranetes-system github-credentials
```

### Uninstall Terranetes

```bash
# Uninstall Helm release
helm uninstall terranetes-controller -n terranetes-system

# Delete namespace
kubectl delete namespace terranetes-system
```

### Delete Kind Cluster

```bash
# Delete entire cluster
kind delete cluster --name terranetes
```

## Advanced Topics

### Updating the Revision

To make changes to the infrastructure template:

1. Edit `terranetes/test-idp.yaml`
2. Increment the version (e.g., `v0.0.1` → `v0.0.2`)
3. Apply the new Revision:

```bash
kubectl apply -f terranetes/test-idp.yaml
```

4. Update CloudResources to use the new version:

```yaml
spec:
  plan:
    name: test-idp
    revision: v0.0.2  # Specify new version
```

### Creating a New Revision from Scratch

Use `tnctl` to generate a Revision from your Terraform module:

```bash
# From local directory
tnctl create revision . \
  --name test-idp \
  --revision v0.1.0 \
  --description "IDP Infrastructure" \
  --provider azure \
  --file terranetes/test-idp-v0.1.0.yaml

# From Git repository
tnctl create revision https://github.com/geertvdc/idp-scripts \
  --name test-idp \
  --revision v0.1.0 \
  --provider azure \
  --file terranetes/test-idp-v0.1.0.yaml
```

This will analyze your Terraform module and generate a Revision with all variables as inputs.

### GitOps Integration

Terranetes works great with GitOps tools like ArgoCD or Flux:

1. Store your Terranetes manifests in Git
2. Configure ArgoCD/Flux to sync the `terranetes/` directory
3. Changes to CloudResources trigger automatic Terraform runs
4. Use `enableAutoApproval: true` for fully automated deployments

### Multi-Environment Deployments

Create separate CloudResources for each environment:

```bash
# terranetes/cloudresource-dev.yaml
apiVersion: terraform.appvia.io/v1alpha1
kind: CloudResource
metadata:
  name: idp-dev-resources
spec:
  plan:
    name: test-idp
    revision: v0.0.1
  variables:
    resource_group_name: "rg-idp-dev"
    environment: "dev"

# terranetes/cloudresource-prod.yaml
apiVersion: terraform.appvia.io/v1alpha1
kind: CloudResource
metadata:
  name: idp-prod-resources
spec:
  plan:
    name: test-idp
    revision: v0.0.1  # Or a stable version
  variables:
    resource_group_name: "rg-idp-prod"
    environment: "prod"
  enableAutoApproval: false  # Require manual approval for prod
```

## Additional Resources

- [Terranetes Documentation](https://terranetes-controller.appvia.io/)
- [Terranetes GitHub](https://github.com/appvia/terranetes-controller)
- [Kind Documentation](https://kind.sigs.k8s.io/)
- [OpenTofu Documentation](https://opentofu.org/)

## Summary

This guide covered:
- ✅ Setting up a Kind cluster with Terranetes
- ✅ Creating and managing credentials
- ✅ Using the Revision + CloudResource pattern
- ✅ Understanding provider and backend configuration requirements
- ✅ Troubleshooting common issues
- ✅ Cleaning up resources

For quick deployments, use the automated scripts in the `terranetes/` directory!
