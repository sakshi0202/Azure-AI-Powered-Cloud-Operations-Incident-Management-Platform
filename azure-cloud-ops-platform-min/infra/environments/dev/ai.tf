resource "azurerm_cognitive_deployment" "chat" {
  count                = var.enable_ai ? 1 : 0
  name                 = "chat"
  cognitive_account_id = azurerm_cognitive_account.ai[0].id
  rai_policy_name      = "Microsoft.Default"

  model {
    format  = "OpenAI"
    name    = var.azure_openai_model
    version = var.azure_openai_model_version
  }

  sku {
    name     = "Standard"
    capacity = 10
  }
}

resource "azurerm_cognitive_deployment" "embedding" {
  count                = var.enable_ai ? 1 : 0
  name                 = "embedding"
  cognitive_account_id = azurerm_cognitive_account.ai[0].id
  rai_policy_name      = "Microsoft.Default"

  model {
    format  = "OpenAI"
    name    = "text-embedding-3-small"
    version = "1"
  }

  sku {
    name     = "Standard"
    capacity = 10
  }
}
