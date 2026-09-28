output "resource_group_name" { value = azurerm_resource_group.this.name }
output "api_url" { value = "https://${azurerm_container_app.api.latest_revision_fqdn}" }
output "acr_name" { value = azurerm_container_registry.this.name }
output "function_app_name" { value = azurerm_linux_function_app.worker.name }
output "servicebus_namespace" { value = azurerm_servicebus_namespace.this.name }
output "eventgrid_endpoint" { value = azurerm_eventgrid_topic.incidents.endpoint }
output "search_endpoint" { value = try(azurerm_search_service.ai[0].query_endpoint, null) }
output "ai_endpoint" { value = try(azurerm_cognitive_account.ai[0].endpoint, null) }

output "postgres_fqdn" { value = azurerm_postgresql_flexible_server.this.fqdn }
output "documents_storage_account" { value = azurerm_storage_account.documents.name }
output "key_vault_uri" { value = azurerm_key_vault.this.vault_uri }
