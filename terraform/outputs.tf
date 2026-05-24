output "resource_group_name" {
  value = azurerm_resource_group.this.name
}

output "storage_account_name" {
  value = azurerm_storage_account.backups.name
}

output "backup_container_name" {
  value = azurerm_storage_container.backups.name
}

output "logic_app_name" {
  value = azurerm_logic_app_workflow.backup_confirmation.name
}

output "logic_app_id" {
  value = azurerm_logic_app_workflow.backup_confirmation.id
}
