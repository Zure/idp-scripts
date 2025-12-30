# Terranetes Setup Summary

This document summarizes the complete Terranetes setup for deploying your Terraform/OpenTofu module.

## 📚 What Has Been Created

### Documentation Files

1. **TERRANETES_GUIDE.md** - Comprehensive step-by-step guide covering:
   - Creating a Kind cluster
   - Installing Terranetes in the cluster
   - Installing Terranetes CLI locally
   - Generating CloudResources from your TF module
   - Deploying the module in the cluster
   - Troubleshooting and cleanup

2. **TERRANETES_QUICK_REFERENCE.md** - Quick command reference for:
   - Common operations
   - Monitoring commands
   - Debugging tips
   - Useful aliases and workflows

### Kubernetes Manifests (terranetes/)

3. **provider-azure.yaml** - Azure provider configuration
   - References `azure-credentials` secret
   - Version: ~> 4.0

4. **provider-github.yaml** - GitHub provider configuration
   - References `github-credentials` secret
   - Version: ~> 6.0

5. **configuration.yaml** - Terraform module configuration
   - Contains inline module definition
   - Defines all variables from your TF module
   - Includes provider and authentication references

6. **cloudresource.yaml** - CloudResource deployment instance
   - References the configuration
   - Overrides variables for environment
   - Configures auto-approval settings
   - Specifies output secret

7. **kind-config.yaml** - Kind cluster configuration
   - Configures port mappings
   - Sets up control plane node

### Helper Scripts (terranetes/)

8. **create-secrets.sh** - Interactive script to create Kubernetes secrets
   - Creates `azure-credentials` secret
   - Creates `github-credentials` secret
   - Prompts for all required credentials

9. **deploy.sh** - Quick deployment script
   - Applies all Terranetes manifests in order
   - Checks prerequisites
   - Provides deployment monitoring instructions

10. **setup-complete.sh** - Complete automated setup
    - Checks all prerequisites (kind, kubectl, helm, docker)
    - Creates Kind cluster
    - Installs Terranetes controller
    - Installs Terranetes CLI (tnctl)
    - Creates secrets
    - Provides next steps

11. **README.md** - Terranetes directory documentation
    - Files overview
    - Quick start guide
    - Manual deployment steps
    - Customization options

## 🚀 Quick Start

### Fastest Way to Get Started

```bash
cd terranetes
./setup-complete.sh
./deploy.sh
```

This will:
1. ✅ Create a Kind cluster
2. ✅ Install Terranetes controller
3. ✅ Install tnctl CLI
4. ✅ Create required secrets
5. ✅ Deploy your infrastructure

### Step-by-Step Approach

If you prefer more control, follow the [TERRANETES_GUIDE.md](TERRANETES_GUIDE.md):

1. **Create Kind cluster**
   ```bash
   kind create cluster --config terranetes/kind-config.yaml
   ```

2. **Install Terranetes**
   ```bash
   helm repo add appvia https://terranetes-controller.appvia.io
   helm repo update
   kubectl create namespace terranetes-system
   helm install terranetes-controller appvia/terranetes-controller \
     --namespace terranetes-system
   ```

3. **Install tnctl**
   ```bash
   curl -L https://github.com/appvia/terranetes-controller/releases/latest/download/tnctl-darwin-amd64 -o tnctl
   chmod +x tnctl
   sudo mv tnctl /usr/local/bin/
   ```

4. **Create secrets**
   ```bash
   cd terranetes
   ./create-secrets.sh
   ```

5. **Deploy**
   ```bash
   ./deploy.sh
   ```

## 📊 Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     Kind Cluster                             │
│  ┌───────────────────────────────────────────────────────┐  │
│  │          Terranetes System Namespace                  │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │      Terranetes Controller                       │  │  │
│  │  │  - Watches CloudResources                        │  │  │
│  │  │  - Creates Terraform Jobs                        │  │  │
│  │  │  - Manages State                                 │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌───────────────────────────────────────────────────────┐  │
│  │          Default Namespace                            │  │
│  │  ┌─────────────────┐  ┌──────────────────────────┐   │  │
│  │  │  Providers      │  │  Configuration           │   │  │
│  │  │  - azurerm      │  │  - idp-module            │   │  │
│  │  │  - github       │  │  - Variables             │   │  │
│  │  └─────────────────┘  │  - Auth                  │   │  │
│  │                       └──────────────────────────┘   │  │
│  │                                                        │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │  CloudResource: idp-dev-resources              │  │  │
│  │  │  - References configuration                     │  │  │
│  │  │  - Overrides variables                          │  │  │
│  │  │  - Triggers Terraform execution                 │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  │                                                        │  │
│  │  ┌─────────────────┐  ┌──────────────────────────┐   │  │
│  │  │  Secrets        │  │  Terraform Jobs          │   │  │
│  │  │  - azure-creds  │  │  - Plan jobs             │   │  │
│  │  │  - github-creds │  │  - Apply jobs            │   │  │
│  │  └─────────────────┘  └──────────────────────────┘   │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                           │
                           │ Provisions
                           ▼
        ┌──────────────────────────────────────┐
        │          Cloud Resources              │
        │  ┌──────────────┐  ┌───────────────┐ │
        │  │    Azure     │  │    GitHub     │ │
        │  │  - RG        │  │  - Repo       │ │
        │  └──────────────┘  └───────────────┘ │
        └──────────────────────────────────────┘
```

## 🔑 Key Concepts

### CloudResource
The primary resource you'll interact with. It represents a Terraform module instance with specific variable values.

### Configuration
Defines the Terraform module source code (inline or from Git) and its variable definitions.

### Provider
Defines Terraform providers (like azurerm, github) with their versions and authentication requirements.

### Secrets
Store sensitive credentials for cloud providers. Referenced by CloudResources and Configurations.

## 📝 What Makes This Different from Traditional Terraform?

| Aspect | Traditional Terraform | Terranetes |
|--------|---------------------|------------|
| **Execution** | CLI on local machine | Kubernetes Jobs in cluster |
| **State Storage** | Local file or remote backend | Kubernetes ConfigMaps/Secrets |
| **Multi-tenancy** | Manual separation | Built-in namespace isolation |
| **GitOps** | Manual integration | Native support via ArgoCD/Flux |
| **RBAC** | External tooling | Kubernetes RBAC |
| **Audit Trail** | Separate logging | Kubernetes events & logs |
| **Scheduling** | Manual or CI/CD | Kubernetes CronJobs |
| **Secret Management** | Various tools | Kubernetes Secrets |

## 🎯 Use Cases

### 1. Platform Engineering
Enable developers to provision infrastructure through Kubernetes CRDs without direct Terraform knowledge.

### 2. GitOps Workflows
Integrate with ArgoCD or Flux for declarative infrastructure management.

### 3. Multi-Tenant Environments
Provide isolated infrastructure provisioning for different teams/namespaces.

### 4. Self-Service Infrastructure
Allow users to request infrastructure through standard Kubernetes resources.

### 5. Policy Enforcement
Apply organizational policies and compliance rules through Terranetes Policies.

## 🔄 Typical Workflow

1. **Developer** creates/updates a `CloudResource` YAML
2. **Git** commit and push to repository
3. **GitOps Tool** (ArgoCD/Flux) syncs to cluster
4. **Terranetes** detects new/updated CloudResource
5. **Terranetes** creates Terraform Plan Job
6. **Approval** (manual or automatic)
7. **Terranetes** creates Terraform Apply Job
8. **Infrastructure** is provisioned in cloud
9. **Outputs** stored in Kubernetes Secret
10. **Applications** can reference the Secret

## 📖 Next Steps

### For Development
- Modify `cloudresource.yaml` with different variable values
- Test different environments (dev, staging, prod)
- Experiment with auto-approval settings

### For Production
- Set up GitOps integration (ArgoCD or Flux)
- Configure Terranetes Policies for compliance
- Enable cost estimation features
- Set up monitoring and alerting
- Use external state backend (S3, Azure Storage)

### For Learning
- Read the [full Terranetes guide](TERRANETES_GUIDE.md)
- Explore the [Terranetes documentation](https://terranetes-controller.appvia.io/)
- Review the [quick reference](TERRANETES_QUICK_REFERENCE.md)
- Try the example workflows

## 🛠️ Customization Examples

### Using Git Repository Instead of Inline Module

Edit `configuration.yaml`:
```yaml
spec:
  module: https://github.com/geertvdc/idp-infrastructure.git?ref=main
```

### Multiple Environments

Create separate CloudResource files:
```bash
# Development
kubectl apply -f cloudresource-dev.yaml

# Staging  
kubectl apply -f cloudresource-staging.yaml

# Production
kubectl apply -f cloudresource-prod.yaml
```

### Enable Auto-Approval

In `cloudresource.yaml`:
```yaml
spec:
  enableAutoApproval: true
```

### Add Policies

Create a Policy resource:
```yaml
apiVersion: terraform.appvia.io/v1alpha1
kind: Policy
metadata:
  name: resource-naming
spec:
  constraints:
    - name: naming-convention
      policy: |
        package main
        deny[msg] {
          # OPA Rego policy here
        }
```

## 🆘 Getting Help

1. **Read the guides**:
   - [TERRANETES_GUIDE.md](TERRANETES_GUIDE.md)
   - [TERRANETES_QUICK_REFERENCE.md](TERRANETES_QUICK_REFERENCE.md)

2. **Check Terranetes resources**:
   - [Official Documentation](https://terranetes-controller.appvia.io/)
   - [GitHub Repository](https://github.com/appvia/terranetes-controller)
   - [GitHub Issues](https://github.com/appvia/terranetes-controller/issues)

3. **Debug your deployment**:
   ```bash
   kubectl logs -n terranetes-system -l app.kubernetes.io/name=terranetes-controller
   kubectl describe cloudresource idp-dev-resources
   kubectl get events
   ```

## 🎉 Success Indicators

You'll know everything is working when:

- ✅ `kubectl get cloudresources` shows `READY: true`
- ✅ `kubectl get secret idp-connection-details` exists
- ✅ Azure Resource Group is created (check Azure Portal)
- ✅ GitHub repository is created (check GitHub)
- ✅ No errors in `kubectl logs -l terraform.appvia.io/configuration=idp-module`

## 🧹 Cleanup

To remove everything:

```bash
# Delete CloudResource (destroys infrastructure)
kubectl delete cloudresource idp-dev-resources

# Delete Terranetes resources
kubectl delete configuration idp-module
kubectl delete provider azurerm github
kubectl delete secret azure-credentials github-credentials

# Uninstall Terranetes
helm uninstall terranetes-controller -n terranetes-system

# Delete Kind cluster
kind delete cluster --name terranetes
```

---

**Happy Infrastructure as Code with Terranetes! 🚀**
