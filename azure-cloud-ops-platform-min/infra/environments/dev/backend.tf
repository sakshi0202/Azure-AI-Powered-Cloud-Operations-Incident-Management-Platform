# Configure these values through terraform init -backend-config.
# Example:
# terraform init \
#   -backend-config="resource_group_name=rg-cloudops-tfstate" \
#   -backend-config="storage_account_name=<globally-unique-name>" \
#   -backend-config="container_name=tfstate" \
#   -backend-config="key=cloudops.dev.tfstate"
terraform {
  backend "azurerm" {
    use_azuread_auth = true
  }
}
