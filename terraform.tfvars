# Example terraform.tfvars file
# Copy this file to terraform.tfvars and customize the values

# Azure Configuration
resource_group_name = "rg-idp-dev"
location            = "West Europe"
environment         = "dev"
project_name        = "internal-developer-platform"

# GitHub Configuration
github_repo_name        = "idp-demo"
github_repo_description = "internal developer Platform demo"
github_repo_visibility  = "private"
