# Terranetes Manifests

This directory contains Kubernetes manifests for deploying the IDP infrastructure module using Terranetes.

## Files Overview

- **provider-azure.yaml** - Azure provider configuration
- **provider-github.yaml** - GitHub provider configuration
- **configuration.yaml** - Terraform module configuration (inline)
- **cloudresource.yaml** - CloudResource instance for deploying resources
- **create-secrets.sh** - Helper script to create Kubernetes secrets
- **deploy.sh** - Quick deployment script
- **README.md** - This file

## Quick Start

1. **Create Kind cluster and install Terranetes:**
   ```bash
   # See ../TERRANETES_GUIDE.md for detailed steps
   kind create cluster --name terranetes
   helm repo add appvia https://terranetes-controller.appvia.io
   helm repo update
   kubectl create namespace terranetes-system
   helm install terranetes-controller appvia/terranetes-controller \
     --namespace terranetes-system
   ```

2. **Create secrets:**
   ```bash
   ./create-secrets.sh
   ```

3. **Deploy resources:**
   ```bash
   ./deploy.sh
   ```

## Manual Deployment Steps

### 1. Create Secrets

```bash
# Create Azure credentials
kubectl create secret generic azure-credentials \
  --from-literal=ARM_CLIENT_ID=<your-client-id> \
  --from-literal=ARM_CLIENT_SECRET=<your-client-secret> \
  --from-literal=ARM_SUBSCRIPTION_ID=<your-subscription-id> \
  --from-literal=ARM_TENANT_ID=<your-tenant-id>

# Create GitHub credentials
kubectl create secret generic github-credentials \
  --from-literal=GITHUB_TOKEN=<your-github-token>
```

### 2. Apply Providers

```bash
kubectl apply -f provider-azure.yaml
kubectl apply -f provider-github.yaml
```

### 3. Apply Configuration

```bash
kubectl apply -f configuration.yaml
```

### 4. Deploy CloudResource

```bash
kubectl apply -f cloudresource.yaml
```

### 5. Monitor Deployment

```bash
# Watch CloudResource status
kubectl get cloudresources -w

# Check detailed status
kubectl describe cloudresource idp-dev-resources

# View Terraform logs
kubectl logs -l terraform.appvia.io/configuration=idp-module -f
```

### 6. Approve Plan (if auto-approval is disabled)

```bash
# Approve using kubectl
kubectl patch cloudresource idp-dev-resources \
  --type merge \
  -p '{"spec":{"enableAutoApproval":true}}'

# Or use tnctl
tnctl approve cloudresource idp-dev-resources
```

## Customization

### Using Different Environments

Create separate CloudResource files for different environments:

```bash
cp cloudresource.yaml cloudresource-staging.yaml
# Edit variables in cloudresource-staging.yaml
```

### Using Git Repository Instead of Inline Module

Edit `configuration.yaml` and replace the `module` field:

```yaml
spec:
  module: https://github.com/geertvdc/idp-infrastructure.git
  # Or with a specific ref:
  # module: https://github.com/geertvdc/idp-infrastructure.git?ref=main
```

### Enabling Auto-Approval

In `cloudresource.yaml`, set:

```yaml
spec:
  enableAutoApproval: true
```

## Outputs and Secrets

After successful deployment, outputs are stored in the connection secret:

```bash
# View the secret
kubectl get secret idp-connection-details -o yaml

# Decode specific output
kubectl get secret idp-connection-details -o jsonpath='{.data.resource_group_name}' | base64 -d
```

## Cleanup

```bash
# Delete CloudResource (will destroy infrastructure)
kubectl delete cloudresource idp-dev-resources

# Delete Configuration
kubectl delete configuration idp-module

# Delete Providers
kubectl delete provider azurerm github

# Delete Secrets
kubectl delete secret azure-credentials github-credentials idp-connection-details
```

## Troubleshooting

### View Controller Logs

```bash
kubectl logs -n terranetes-system -l app.kubernetes.io/name=terranetes-controller -f
```

### Check Job Status

```bash
kubectl get jobs
kubectl get pods
kubectl logs job/<job-name>
```

### Force Reconciliation

```bash
kubectl annotate cloudresource idp-dev-resources terraform.appvia.io/reconcile="$(date +%s)"
```

## Additional Resources

- [Main Terranetes Guide](../TERRANETES_GUIDE.md)
- [Terranetes Documentation](https://terranetes-controller.appvia.io/)
- [Terraform Module Source](../)
