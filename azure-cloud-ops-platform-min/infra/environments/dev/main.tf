data "azurerm_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

locals {
  name = "${var.project_name}-${var.environment}-${random_string.suffix.result}"
}

resource "azurerm_resource_group" "this" {
  name     = "rg-${var.project_name}-${var.environment}"
  location = var.location
  tags     = var.tags
}

resource "azurerm_log_analytics_workspace" "this" {
  name                = "law-${local.name}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

resource "azurerm_virtual_network" "this" {
  name                = "vnet-${local.name}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = ["10.40.0.0/16"]
  tags                = var.tags
}

resource "azurerm_subnet" "app" {
  name                 = "snet-app"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.40.1.0/24"]
}

resource "azurerm_subnet" "private_endpoints" {
  name                 = "snet-private-endpoints"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.40.2.0/24"]
  private_endpoint_network_policies = "Disabled"
}

resource "azurerm_network_security_group" "app" {
  name                = "nsg-${local.name}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags
}

resource "azurerm_subnet_network_security_group_association" "app" {
  subnet_id                 = azurerm_subnet.app.id
  network_security_group_id = azurerm_network_security_group.app.id
}


resource "azurerm_subnet" "postgres" {
  name                 = "snet-postgres"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.40.3.0/24"]
  delegation {
    name = "postgres-delegation"
    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"
    }
  }
}

resource "azurerm_private_dns_zone" "postgres" {
  name                = "private.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.this.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  name                  = "postgres-dns-link"
  private_dns_zone_name = azurerm_private_dns_zone.postgres.name
  virtual_network_id    = azurerm_virtual_network.this.id
  resource_group_name   = azurerm_resource_group.this.name
}

resource "random_password" "postgres" {
  length  = 24
  special = true
}

resource "azurerm_postgresql_flexible_server" "this" {
  name                          = "pg-${local.name}"
  resource_group_name           = azurerm_resource_group.this.name
  location                      = azurerm_resource_group.this.location
  version                       = "16"
  delegated_subnet_id           = azurerm_subnet.postgres.id
  private_dns_zone_id            = azurerm_private_dns_zone.postgres.id
  public_network_access_enabled = false
  administrator_login            = "cloudopsadmin"
  administrator_password         = random_password.postgres.result
  storage_mb                    = 32768
  sku_name                      = "B_Standard_B1ms"
  backup_retention_days         = 7
  tags                          = var.tags
  depends_on                    = [azurerm_private_dns_zone_virtual_network_link.postgres]
}

resource "azurerm_postgresql_flexible_server_database" "app" {
  name      = "cloudops"
  server_id = azurerm_postgresql_flexible_server.this.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

resource "azurerm_storage_account" "documents" {
  name                     = "st${replace(local.name, "-", "")}docs"
  resource_group_name      = azurerm_resource_group.this.name
  location                 = azurerm_resource_group.this.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
  public_network_access_enabled = true
  tags                     = var.tags
}

resource "azurerm_storage_container" "documents" {
  name                  = "knowledge-base"
  storage_account_id    = azurerm_storage_account.documents.id
  container_access_type = "private"
}

resource "azurerm_key_vault" "this" {
  name                       = "kv-${replace(local.name, "-", "")}"
  location                   = azurerm_resource_group.this.location
  resource_group_name        = azurerm_resource_group.this.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  enable_rbac_authorization  = true
  tags                       = var.tags
}

resource "azurerm_key_vault_secret" "postgres_password" {
  name         = "postgres-admin-password"
  value        = random_password.postgres.result
  key_vault_id = azurerm_key_vault.this.id
}

resource "azurerm_role_assignment" "app_keyvault_secrets_user" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
}

resource "azurerm_role_assignment" "function_keyvault_secrets_user" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_function_app.worker.identity[0].principal_id
}

resource "azurerm_container_registry" "this" {
  name                = "acr${replace(local.name, "-", "")}" 
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  sku                 = "Basic"
  admin_enabled       = false
  tags                = var.tags
}

resource "azurerm_container_app_environment" "this" {
  name                       = "cae-${local.name}"
  location                   = azurerm_resource_group.this.location
  resource_group_name        = azurerm_resource_group.this.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id
  tags                       = var.tags
}

resource "azurerm_user_assigned_identity" "app" {
  name                = "id-app-${local.name}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags
}

resource "azurerm_container_app" "api" {
  name                         = "ca-api-${local.name}"
  container_app_environment_id = azurerm_container_app_environment.this.id
  resource_group_name          = azurerm_resource_group.this.name
  revision_mode                = "Single"
  tags                         = var.tags

  identity { type = "UserAssigned" identity_ids = [azurerm_user_assigned_identity.app.id] }

  ingress {
    external_enabled = true
    target_port      = 8080
    transport        = "auto"
    traffic_weight { percentage = 100 latest_revision = true }
  }

  registry {
    server   = azurerm_container_registry.this.login_server
    identity = azurerm_user_assigned_identity.app.id
  }

  template {
    container {
      name   = "api"
      image  = var.container_image
      cpu    = 0.5
      memory = "1Gi"
      env { name = "APP_VERSION" value = "1.0.0" }
      env { name = "POSTGRES_HOST" value = azurerm_postgresql_flexible_server.this.fqdn }
      env { name = "POSTGRES_DB" value = azurerm_postgresql_flexible_server_database.app.name }
      env { name = "POSTGRES_USER" value = azurerm_postgresql_flexible_server.this.administrator_login }
      env { name = "DOCUMENTS_CONTAINER" value = azurerm_storage_container.documents.name }
      env { name = "AZURE_SEARCH_ENDPOINT" value = var.enable_ai ? azurerm_search_service.ai[0].query_endpoint : "" }
      env { name = "AZURE_SEARCH_INDEX" value = "cloudops-runbooks" }
      env { name = "AZURE_OPENAI_ENDPOINT" value = var.enable_ai ? azurerm_cognitive_account.ai[0].endpoint : "" }
      env { name = "AZURE_OPENAI_CHAT_DEPLOYMENT" value = var.enable_ai ? azurerm_cognitive_deployment.chat[0].name : "" }
      env { name = "AZURE_OPENAI_EMBEDDING_DEPLOYMENT" value = var.enable_ai ? azurerm_cognitive_deployment.embedding[0].name : "" }
      liveness_probe { transport = "HTTP" port = 8080 path = "/health" initial_delay = 10 interval_seconds = 30 }
      readiness_probe { transport = "HTTP" port = 8080 path = "/health" initial_delay = 5 interval_seconds = 15 }
    }
    min_replicas = 1
    max_replicas = 3
  }
}

resource "azurerm_storage_account" "function" {
  name                     = "st${replace(local.name, "-", "")}fn"
  resource_group_name      = azurerm_resource_group.this.name
  location                 = azurerm_resource_group.this.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
  shared_access_key_enabled = true
  tags                     = var.tags
}

resource "azurerm_service_plan" "function" {
  name                = "asp-${local.name}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  os_type             = "Linux"
  sku_name            = "Y1"
  tags                = var.tags
}

resource "azurerm_eventgrid_topic" "incidents" {
  name                = "egt-${local.name}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  input_schema        = "CloudEventSchemaV1_0"
  tags                = var.tags
}

resource "azurerm_servicebus_namespace" "this" {
  name                = "sb-${local.name}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "Standard"
  minimum_tls_version = "1.2"
  tags                = var.tags
}

resource "azurerm_servicebus_queue" "remediation" {
  name         = "remediation-events"
  namespace_id = azurerm_servicebus_namespace.this.id
  max_delivery_count = 5
  lock_duration       = "PT1M"
  dead_lettering_on_message_expiration = true
}

resource "azurerm_eventgrid_event_subscription" "to_servicebus" {
  name  = "incident-to-servicebus"
  scope = azurerm_eventgrid_topic.incidents.id

  service_bus_queue_endpoint_id = azurerm_servicebus_queue.remediation.id
}

resource "azurerm_linux_function_app" "worker" {
  name                       = "func-${local.name}"
  location                   = azurerm_resource_group.this.location
  resource_group_name        = azurerm_resource_group.this.name
  service_plan_id            = azurerm_service_plan.function.id
  storage_account_name       = azurerm_storage_account.function.name
  storage_account_access_key = azurerm_storage_account.function.primary_access_key
  functions_extension_version = "~4"
  https_only                 = true
  tags                       = var.tags

  site_config {
    application_stack { python_version = "3.11" }
    minimum_tls_version = "1.2"
  }

  identity { type = "SystemAssigned" }

  app_settings = {
    FUNCTIONS_WORKER_RUNTIME = "python"
    WEBSITE_RUN_FROM_PACKAGE = "1"
    SERVICEBUS_CONNECTION__fullyQualifiedNamespace = "${azurerm_servicebus_namespace.this.name}.servicebus.windows.net"
    SERVICEBUS_CONNECTION__credential = "managedidentity"
    EVENTGRID_ENDPOINT = azurerm_eventgrid_topic.incidents.endpoint
    TARGET_RESOURCE_GROUP = azurerm_resource_group.this.name
    TARGET_CONTAINER_APP = azurerm_container_app.api.name
    AZURE_SUBSCRIPTION_ID = var.subscription_id
  }
}

resource "azurerm_role_assignment" "function_servicebus_receiver" {
  scope                = azurerm_servicebus_queue.remediation.id
  role_definition_name = "Azure Service Bus Data Receiver"
  principal_id         = azurerm_linux_function_app.worker.identity[0].principal_id
}

resource "azurerm_role_assignment" "function_eventgrid_sender" {
  scope                = azurerm_eventgrid_topic.incidents.id
  role_definition_name = "EventGrid Data Sender"
  principal_id         = azurerm_linux_function_app.worker.identity[0].principal_id
}

resource "azurerm_role_assignment" "app_acr_pull" {
  scope                = azurerm_container_registry.this.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
}

resource "azurerm_role_assignment" "function_containerapp_reader" {
  scope                = azurerm_container_app.api.id
  role_definition_name = "Container Apps Contributor"
  principal_id         = azurerm_linux_function_app.worker.identity[0].principal_id
}

resource "azurerm_role_assignment" "app_search_reader" {
  count                = var.enable_ai ? 1 : 0
  scope                = azurerm_search_service.ai[0].id
  role_definition_name = "Search Index Data Reader"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
}

resource "azurerm_role_assignment" "app_openai_user" {
  count                = var.enable_ai ? 1 : 0
  scope                = azurerm_cognitive_account.ai[0].id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
}

resource "azurerm_cognitive_account" "ai" {
  count                 = var.enable_ai ? 1 : 0
  name                  = "ai-${replace(local.name, "-", "")}"
  location              = azurerm_resource_group.this.location
  resource_group_name   = azurerm_resource_group.this.name
  kind                  = "AIServices"
  sku_name              = "S0"
  custom_subdomain_name = "ai-${replace(local.name, "-", "")}"
  project_management_enabled = true
  identity { type = "SystemAssigned" }
  tags = var.tags
}

resource "azurerm_cognitive_account_project" "ai" {
  count               = var.enable_ai ? 1 : 0
  name                = "cloudops"
  cognitive_account_id = azurerm_cognitive_account.ai[0].id
  location            = azurerm_resource_group.this.location
  identity { type = "SystemAssigned" }
}

resource "azurerm_search_service" "ai" {
  count               = var.enable_ai ? 1 : 0
  name                = "srch-${replace(local.name, "-", "")}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  sku                 = "basic"
  partition_count     = 1
  replica_count       = 1
  semantic_search_sku = "free"
  identity { type = "SystemAssigned" }
  tags = var.tags
}
