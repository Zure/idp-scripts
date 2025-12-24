# Azure Resource Group Outputs
output "resource_group_name" {
  description = "Name of the created Azure Resource Group"
  value       = azurerm_resource_group.main.name
}

output "resource_group_id" {
  description = "ID of the created Azure Resource Group"
  value       = azurerm_resource_group.main.id
}

output "resource_group_location" {
  description = "Location of the Azure Resource Group"
  value       = azurerm_resource_group.main.location
}

output "azure_portal_url" {
  description = "Direct link to the Resource Group in Azure Portal"
  value       = "https://portal.azure.com/#@/resource${azurerm_resource_group.main.id}"
}

# GitHub Repository Outputs
output "github_repo_name" {
  description = "Name of the created GitHub repository"
  value       = github_repository.main.name
}

output "github_repo_full_name" {
  description = "Full name of the GitHub repository (owner/repo)"
  value       = github_repository.main.full_name
}

output "github_repo_url" {
  description = "URL of the GitHub repository"
  value       = github_repository.main.html_url
}

output "github_repo_clone_url" {
  description = "Clone URL for the GitHub repository"
  value       = github_repository.main.clone_url
}

output "github_repo_ssh_clone_url" {
  description = "SSH clone URL for the GitHub repository"
  value       = github_repository.main.ssh_clone_url
}
