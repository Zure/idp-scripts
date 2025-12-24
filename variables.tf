# Variables for Azure Resource Group
variable "resource_group_name" {
  description = "Name of the Azure Resource Group"
  type        = string
  default     = "rg-idp-dev"
}

variable "location" {
  description = "Azure region for the Resource Group"
  type        = string
  default     = "West Europe"
}

variable "environment" {
  description = "Environment tag for resources"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "project_name" {
  description = "Project name for tagging and naming resources"
  type        = string
  default     = "identity-platform"
}

# Variables for GitHub Repository
variable "github_repo_name" {
  description = "Name of the GitHub repository"
  type        = string
  default     = "idp-infrastructure"
}

variable "github_repo_description" {
  description = "Description of the GitHub repository"
  type        = string
  default     = "Identity Platform Infrastructure and Configuration"
}

variable "github_repo_visibility" {
  description = "Visibility of the GitHub repository"
  type        = string
  default     = "private"

  validation {
    condition     = contains(["public", "private"], var.github_repo_visibility)
    error_message = "Repository visibility must be either 'public' or 'private'."
  }
}

variable "github_repo_topics" {
  description = "Topics/tags for the GitHub repository"
  type        = list(string)
  default     = ["terraform", "opentofu", "azure", "infrastructure", "iac"]
}
