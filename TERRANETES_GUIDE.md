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

# Create Kubernetes secret with Azure credentials
kubectl create secret generic azure-credentials \
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

# Create Kubernetes secret with GitHub token
kubectl create secret generic github-credentials \
  --from-literal=GITHUB_TOKEN=<your-github-token>
```

## Step 5: Generate CloudResource from the TF Module

Now we'll create Kubernetes manifests for Terranetes.

### Create Provider Configuration

First, create a Provider resource for Azure:

```yaml
# terranetes/provider-azure.yaml
apiVersion: terraform.appvia.io/v1alpha1
kind: Provider
metadata:
  name: azurerm
spec:
  source: hashicorp/azurerm
  version: "~> 4.0"
  preloadSecrets:
    - azure-credentials
```

Create a Provider resource for GitHub:

```yaml
# terranetes/provider-github.yaml
apiVersion: terraform.appvia.io/v1alpha1
kind: Provider
metadata:
  name: github
spec:
  source: integrations/github
  version: "~> 6.0"
  preloadSecrets:
    - github-credentials
```

### Create Configuration for Module Source

Create a Configuration that points to your module:

```yaml
# terranetes/configuration.yaml
apiVersion: terraform.appvia.io/v1alpha1
kind: Configuration
metadata:
  name: idp-module
spec:
  # Option 1: Use local module (for testing)
  module: |
    resource "azurerm_resource_group" "main" {
      name     = var.resource_group_name
      location = var.location
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
  
  # Define variables
  variables:
    resource_group_name:
      description: "Name of the Azure Resource Group"
      type: string
      default: "rg-idp-dev"
    
    location:
      description: "Azure region for the Resource Group"
      type: string
      default: "West Europe"
    
    environment:
      description: "Environment tag for resources"
      type: string
      default: "dev"
    
    project_name:
      description: "Project name for tagging and naming resources"
      type: string
      default: "identity-platform"
    
    github_repo_name:
      description: "Name of the GitHub repository"
      type: string
      default: "idp-infrastructure"
    
    github_repo_description:
      description: "Description of the GitHub repository"
      type: string
      default: "Identity Platform Infrastructure and Configuration"
    
    github_repo_visibility:
      description: "Visibility of the GitHub repository"
      type: string
      default: "private"

  providerRef:
    name: azurerm

  # Authentication
  auth:
    - secret:
        name: azure-credentials
    - secret:
        name: github-credentials
```

### Alternative: Use Git Repository as Source

```yaml
# terranetes/configuration-git.yaml
apiVersion: terraform.appvia.io/v1alpha1
kind: Configuration
metadata:
  name: idp-module-git
spec:
  # Reference your Git repository
  module: https://github.com/geertvdc/idp-infrastructure.git
  
  # Variables are passed via CloudResource
  
  providerRef:
    name: azurerm

  auth:
    - secret:
        name: azure-credentials
    - secret:
        name: github-credentials
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

### Use tnctl to Generate Resources

You can also use the CLI to help generate resources:

```bash
# Create a directory for Terranetes manifests
mkdir -p terranetes

# Generate a basic CloudResource template
tnctl generate cloudresource \
  --name idp-dev-resources \
  --module . \
  > terranetes/cloudresource.yaml
```

## Step 6: Deploy the Module in the Cluster

Now deploy your resources to the Kubernetes cluster.

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
```

### Apply CloudResource

```bash
# Apply the CloudResource
kubectl apply -f terranetes/cloudresource.yaml

# Watch the resource being created
kubectl get cloudresources -w
```

### Monitor the Deployment

```bash
# Check the status of your CloudResource
kubectl describe cloudresource idp-dev-resources

# View the Terraform plan
kubectl get plans

# View the logs of the Terraform job
kubectl logs -l terraform.appvia.io/configuration=idp-module -f

# Check if resources are ready
kubectl get cloudresources
```

### Approve the Plan (if auto-approval is disabled)

```bash
# View the plan
kubectl describe plan <plan-name>

# Approve the plan using tnctl
tnctl approve cloudresource idp-dev-resources

# Or patch the plan directly
kubectl patch cloudresource idp-dev-resources \
  --type merge \
  -p '{"spec":{"enableAutoApproval":true}}'
```

### Check the Output

```bash
# Once applied, check the outputs
kubectl get cloudresource idp-dev-resources -o yaml

# Connection details are stored in the secret
kubectl get secret idp-connection-details -o yaml
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
   - Verify secrets are created correctly: `kubectl get secrets`
   - Check secret contents: `kubectl describe secret azure-credentials`

2. **Plan Not Generating**
   - Check Configuration status: `kubectl describe configuration idp-module`
   - Verify provider references are correct

3. **Module Source Issues**
   - Ensure Git repository is accessible
   - For private repos, add SSH keys or tokens

### Debugging with tnctl

```bash
# Get detailed status
tnctl describe cloudresource idp-dev-resources

# Verify configuration
tnctl verify configuration idp-module

# Force a reconciliation
kubectl annotate cloudresource idp-dev-resources terraform.appvia.io/reconcile="$(date +%s)"
```

## Cleanup

### Delete CloudResource

```bash
# Delete the CloudResource (this will destroy the Terraform resources)
kubectl delete cloudresource idp-dev-resources

# Monitor deletion
kubectl get cloudresources -w
```

### Delete Configuration and Providers

```bash
kubectl delete configuration idp-module
kubectl delete provider azurerm
kubectl delete provider github
```

### Delete Secrets

```bash
kubectl delete secret azure-credentials
kubectl delete secret github-credentials
kubectl delete secret idp-connection-details
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
