# Terranetes Quick Reference

Quick reference for common Terranetes operations.

## Prerequisites Check

```bash
# Check if tools are installed
kind --version
kubectl version --client
helm version
tnctl version

# Verify cluster is running
kubectl cluster-info
kubectl get nodes
```

## Setup Commands

```bash
# Create Kind cluster
kind create cluster --name terranetes --config terranetes/kind-config.yaml

# Install Terranetes via Helm
helm repo add appvia https://terranetes-controller.appvia.io
helm repo update
kubectl create namespace terranetes-system
helm install terranetes-controller appvia/terranetes-controller \
  --namespace terranetes-system \
  --set controller.costs.enabled=false

# Complete automated setup
cd terranetes
./setup-complete.sh
```

## Deployment Commands

```bash
# Create secrets
cd terranetes
./create-secrets.sh

# Deploy all resources
./deploy.sh

# Or deploy manually step-by-step
kubectl apply -f provider-azure.yaml
kubectl apply -f provider-github.yaml
kubectl apply -f configuration.yaml
kubectl apply -f cloudresource.yaml
```

## Monitoring Commands

```bash
# Watch CloudResource status
kubectl get cloudresources -w

# Get detailed status
kubectl describe cloudresource idp-dev-resources

# View all Terranetes resources
kubectl get providers,configurations,revisions,cloudresources

# Check Terranetes controller logs
kubectl logs -n terranetes-system -l app.kubernetes.io/name=terranetes-controller -f

# View Terraform execution logs
kubectl logs -l terraform.appvia.io/configuration=idp-module -f

# List all jobs (Terraform runs)
kubectl get jobs

# View specific job logs
kubectl logs job/<job-name>

# Check revisions
kubectl get revisions
kubectl describe revision <revision-name>
```

## Management Commands

```bash
# Approve a plan
tnctl approve cloudresource idp-dev-resources

# Or enable auto-approval
kubectl patch cloudresource idp-dev-resources \
  --type merge \
  -p '{"spec":{"enableAutoApproval":true}}'

# Force reconciliation
kubectl annotate cloudresource idp-dev-resources \
  terraform.appvia.io/reconcile="$(date +%s)"

# View outputs
kubectl get secret idp-connection-details -o yaml

# Decode specific output
kubectl get secret idp-connection-details \
  -o jsonpath='{.data.resource_group_name}' | base64 -d
```

## Debugging Commands

```bash
# Check CRDs
kubectl get crds | grep terraform

# Verify providers
kubectl get providers
kubectl describe provider azurerm
kubectl describe provider github

# Check configurations
kubectl get configurations
kubectl describe configuration idp-module

# Verify secrets exist
kubectl get secrets -n terranetes-system azure-credentials github-credentials

# Check secret contents
kubectl describe secret -n terranetes-system azure-credentials
kubectl describe secret -n terranetes-system github-credentials

# Get CloudResource YAML
kubectl get cloudresource idp-dev-resources -o yaml

# Check events
kubectl get events --sort-by='.lastTimestamp'
```

## Update Commands

```bash
# Update CloudResource variables
kubectl edit cloudresource idp-dev-resources

# Update Configuration
kubectl edit configuration idp-module

# Reapply changes
kubectl apply -f cloudresource.yaml

# Restart Terranetes controller
kubectl rollout restart deployment/terranetes-controller -n terranetes-system
```

## Cleanup Commands

```bash
# Delete CloudResource (destroys infrastructure)
kubectl delete cloudresource idp-dev-resources

# Watch deletion
kubectl get cloudresources -w

# Delete Configuration
kubectl delete configuration idp-module

# Delete Providers
kubectl delete provider azurerm github

# Delete secrets
kubectl delete secret -n terranetes-system azure-credentials github-credentials idp-connection-details

# Uninstall Terranetes
helm uninstall terranetes-controller -n terranetes-system
kubectl delete namespace terranetes-system

# Delete Kind cluster
kind delete cluster --name terranetes
```

## tnctl CLI Commands

```bash
# Show version
tnctl version

# List available commands
tnctl --help

# Describe CloudResource
tnctl describe cloudresource idp-dev-resources

# Verify Configuration
tnctl verify configuration idp-module

# Create a new revision from a Configuration
tnctl create revision idp-module

# Approve a CloudResource (to proceed with apply)
tnctl approve cloudresource idp-dev-resources

# Search for configurations
tnctl search configuration

# View logs from a CloudResource
tnctl logs cloudresource idp-dev-resources
```

## Useful Aliases

Add these to your `~/.zshrc` or `~/.bashrc`:

```bash
# Terranetes aliases
alias k='kubectl'
alias kcr='kubectl get cloudresources'
alias kcrw='kubectl get cloudresources -w'
alias kdcr='kubectl describe cloudresource'
alias klogs='kubectl logs -l terraform.appvia.io/configuration=idp-module -f'
alias tctl='tnctl'

# Kind aliases
alias kc-list='kind get clusters'
alias kc-switch='kubectl config use-context'
```

## Environment Variables

```bash
# Azure authentication
export ARM_CLIENT_ID="xxx"
export ARM_CLIENT_SECRET="xxx"
export ARM_SUBSCRIPTION_ID="xxx"
export ARM_TENANT_ID="xxx"

# GitHub authentication
export GITHUB_TOKEN="xxx"

# Kubeconfig
export KUBECONFIG=~/.kube/config
```

## Common Workflows

### Deploy New Changes

```bash
# Edit the configuration
vim terranetes/cloudresource.yaml

# Apply changes
kubectl apply -f terranetes/cloudresource.yaml

# Monitor deployment
kubectl get cloudresources -w
```

### View Infrastructure Outputs

```bash
# Get all outputs
kubectl get secret idp-connection-details -o yaml

# Get specific output
kubectl get secret idp-connection-details \
  -o jsonpath='{.data.resource_group_name}' | base64 -d && echo
```

### Rollback Changes

```bash
# View CloudResource history
kubectl rollout history cloudresource/idp-dev-resources

# Restore previous version
kubectl rollout undo cloudresource/idp-dev-resources
```

### Multi-Environment Setup

```bash
# Create different CloudResources for each environment
cp cloudresource.yaml cloudresource-dev.yaml
cp cloudresource.yaml cloudresource-staging.yaml
cp cloudresource.yaml cloudresource-prod.yaml

# Edit each file with environment-specific values
# Deploy each environment
kubectl apply -f cloudresource-dev.yaml
kubectl apply -f cloudresource-staging.yaml
kubectl apply -f cloudresource-prod.yaml
```

## Troubleshooting Tips

### Provider Not Ready

```bash
kubectl get providers
kubectl describe provider azurerm
kubectl logs -n terranetes-system -l app.kubernetes.io/name=terranetes-controller
```

### Plan Not Generating

```bash
kubectl describe cloudresource idp-dev-resources
kubectl get jobs
kubectl logs job/<job-name>
```

### Authentication Failures

```bash
kubectl get secrets
kubectl describe secret azure-credentials
kubectl describe secret github-credentials
```

### Stuck Resources

```bash
# Remove finalizers if needed (use with caution)
kubectl patch cloudresource idp-dev-resources \
  -p '{"metadata":{"finalizers":null}}' \
  --type=merge
```

## Links

- [Full Terranetes Guide](../TERRANETES_GUIDE.md)
- [Terranetes Documentation](https://terranetes-controller.appvia.io/)
- [Terranetes GitHub](https://github.com/appvia/terranetes-controller)
- [Kind Documentation](https://kind.sigs.k8s.io/)
