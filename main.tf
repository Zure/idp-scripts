# OpenTofu configuration for creating Azure Resource Group and GitHub Repository
# This configuration uses both AzureRM and GitHub providers
# Provider configurations are in providers.tf
# Version requirements are in versions.tf

# Create Azure Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    Environment = var.environment
    Project     = var.project_name
    CreatedDate = timestamp()
  }
}

# Create GitHub Repository
resource "github_repository" "main" {
  name         = var.github_repo_name
  description  = var.github_repo_description
  visibility   = var.github_repo_visibility
  auto_init    = true

  # Repository settings
  has_issues      = true
  has_projects    = false
  has_wiki        = false
  has_downloads   = true
  has_discussions = false

}
