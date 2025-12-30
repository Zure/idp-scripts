# OpenTofu/Terraform version and provider requirements
# Note: OpenTofu uses the same "terraform" block syntax for compatibility

terraform {
  required_version = ">= 1.0"
  
  backend "azurerm" {
  }
  
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
