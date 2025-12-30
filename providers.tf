# Provider configurations
# Note: When using Terranetes, the Azure provider is automatically configured
# by the controller based on the providerRef in cloudresource.yaml
# Do not add a provider "azurerm" block here as it will cause conflicts

# Configure the GitHub Provider (still needed for GitHub resources)
provider "github" {
  # GitHub token should be provided via GITHUB_TOKEN environment variable
  # or through GitHub CLI authentication
}
