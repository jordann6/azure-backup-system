variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "eastus"
}

variable "environment" {
  description = "Deployment environment label (dev / prod)."
  type        = string
  default     = "dev"
}

variable "alert_email" {
  description = "Email address that receives daily backup confirmation."
  type        = string
}

variable "sendgrid_api_key" {
  description = "SendGrid API key for outbound email. Leave empty to disable email notifications."
  type        = string
  sensitive   = true
  default     = ""
}

variable "soft_delete_retention_days" {
  description = "Days to retain soft-deleted blobs and containers."
  type        = number
  default     = 7
}

variable "cool_tier_after_days" {
  description = "Days since last modification before a blob is moved to Cool tier."
  type        = number
  default     = 30
}

variable "archive_tier_after_days" {
  description = "Days since last modification before a blob is moved to Archive tier."
  type        = number
  default     = 90
}

variable "delete_after_days" {
  description = "Days since last modification before a blob is permanently deleted."
  type        = number
  default     = 365
}
