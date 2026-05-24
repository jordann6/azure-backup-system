locals {
  project     = "backup"
  environment = var.environment
  location    = var.location

  common_tags = {
    project     = local.project
    environment = local.environment
    owner       = "jordann6"
    managed_by  = "terraform"
  }
}

# --- Resource Group -----------------------------------------------------------

resource "azurerm_resource_group" "this" {
  name     = "rg-${local.project}-${local.environment}"
  location = local.location
  tags     = local.common_tags
}

# --- Storage Account ----------------------------------------------------------

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "azurerm_storage_account" "backups" {
  name                            = "stbackup${local.environment}${random_string.suffix.result}"
  resource_group_name             = azurerm_resource_group.this.name
  location                        = azurerm_resource_group.this.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = var.soft_delete_retention_days
    }

    container_delete_retention_policy {
      days = var.soft_delete_retention_days
    }
  }

  tags = local.common_tags
}

resource "azurerm_storage_container" "backups" {
  name                  = "backups"
  storage_account_name  = azurerm_storage_account.backups.name
  container_access_type = "private"
}

# --- Lifecycle Management Policy ----------------------------------------------
# Hot → Cool → Archive → Delete

resource "azurerm_storage_management_policy" "lifecycle" {
  storage_account_id = azurerm_storage_account.backups.id

  rule {
    name    = "backup-tiering"
    enabled = true

    filters {
      blob_types = ["blockBlob"]
    }

    actions {
      base_blob {
        tier_to_cool_after_days_since_modification_greater_than    = var.cool_tier_after_days
        tier_to_archive_after_days_since_modification_greater_than = var.archive_tier_after_days
        delete_after_days_since_modification_greater_than          = var.delete_after_days
      }
      # Versions move to Archive faster — they're recovery points, not primary access
      version {
        change_tier_to_archive_after_days_since_creation = 7
        delete_after_days_since_creation                 = 90
      }
    }
  }
}

# --- Logic App ----------------------------------------------------------------

resource "azurerm_logic_app_workflow" "backup_confirmation" {
  name                = "logic-${local.project}-confirmation-${local.environment}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  identity {
    type = "SystemAssigned"
  }

  tags = local.common_tags
}

# Grant Logic App read access to blob data via managed identity
resource "azurerm_role_assignment" "logic_storage_reader" {
  scope                = azurerm_storage_account.backups.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_logic_app_workflow.backup_confirmation.identity[0].principal_id
}

# Daily recurrence trigger at 08:00 UTC
resource "azurerm_logic_app_trigger_recurrence" "daily" {
  name         = "daily-backup-check"
  logic_app_id = azurerm_logic_app_workflow.backup_confirmation.id
  frequency    = "Day"
  interval     = 1
  start_time   = "2024-01-01T08:00:00Z"
  time_zone    = "UTC"
}

# Action 1: List blobs in the backup container (managed identity auth)
resource "azurerm_logic_app_action_custom" "list_blobs" {
  name         = "list-backup-blobs"
  logic_app_id = azurerm_logic_app_workflow.backup_confirmation.id

  body = jsonencode({
    type = "Http"
    inputs = {
      method = "GET"
      uri    = "https://${azurerm_storage_account.backups.name}.blob.core.windows.net/${azurerm_storage_container.backups.name}?restype=container&comp=list&include=versions"
      headers = {
        "x-ms-version" = "2020-10-02"
      }
      authentication = {
        type     = "ManagedServiceIdentity"
        audience = "https://storage.azure.com/"
      }
    }
    runAfter = {}
  })
}

# Action 2: Send daily confirmation email via SendGrid (only if API key provided)
resource "azurerm_logic_app_action_custom" "send_confirmation" {
  count        = var.sendgrid_api_key != "" ? 1 : 0
  name         = "send-backup-confirmation"
  logic_app_id = azurerm_logic_app_workflow.backup_confirmation.id

  body = jsonencode({
    type = "Http"
    inputs = {
      method = "POST"
      uri    = "https://api.sendgrid.com/v3/mail/send"
      headers = {
        "Authorization" = "Bearer ${var.sendgrid_api_key}"
        "Content-Type"  = "application/json"
      }
      body = {
        personalizations = [{
          to = [{ email = var.alert_email }]
        }]
        from = {
          email = "backup-alerts@jordandesigns.io"
          name  = "Azure Backup Monitor"
        }
        subject = "@{concat('[Backup Confirmed] Daily check ', formatDateTime(utcNow(), 'yyyy-MM-dd'))}"
        content = [{
          type  = "text/plain"
          value = "@{concat('Daily backup verification completed.\\n\\nStorage account: ${azurerm_storage_account.backups.name}\\nContainer: backups\\nCheck time (UTC): ', utcNow(), '\\n\\nVersioning: enabled  |  Soft delete: ${var.soft_delete_retention_days} days  |  Lifecycle: Cool @ ${var.cool_tier_after_days}d  ·  Archive @ ${var.archive_tier_after_days}d  ·  Delete @ ${var.delete_after_days}d')}"
        }]
      }
    }
    runAfter = {
      "list-backup-blobs" = ["Succeeded"]
    }
  })
}
