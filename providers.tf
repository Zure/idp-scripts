# Provider configurations

# Configure the Azure Provider
provider "azurerm" {
  features {}
}

# Configure the GitHub Provider
provider "github" {
  # GitHub token should be provided via GITHUB_TOKEN environment variable
  # or through GitHub CLI authentication
}
