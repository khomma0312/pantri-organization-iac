variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

variable "github_repository" {
  description = "GitHub repository in the format 'owner/repo'"
  type        = string
  validation {
    condition     = can(regex("^[^/]+/[^/]+$", var.github_repository))
    error_message = "The github_repository value must be in the format 'owner/repo'."
  }
}

variable "dev_account_id" {
  description = "AWS Dev Account ID"
  type        = string
  validation {
    condition     = can(regex("^[0-9]{12}$", var.dev_account_id))
    error_message = "The dev_account_id must be a 12-digit AWS account ID."
  }
}

variable "prd_account_id" {
  description = "AWS Production Account ID"
  type        = string
  validation {
    condition     = can(regex("^[0-9]{12}$", var.prd_account_id))
    error_message = "The prd_account_id must be a 12-digit AWS account ID."
  }
}

variable "external_id" {
  description = "External ID for secure cross-account access"
  type        = string
  sensitive   = true
}