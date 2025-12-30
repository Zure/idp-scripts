# OpenTofu/Terraform version and provider requirements
# Note: OpenTofu uses the same "terraform" block syntax for compatibility
# When using Terranetes, the backend is automatically configured to use Kubernetes
# Do not add a backend block here as it will cause conflicts

terraform {
  required_version = ">= 1.0"
  
  # Backend configuration removed - Terranetes uses Kubernetes backend
  
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
