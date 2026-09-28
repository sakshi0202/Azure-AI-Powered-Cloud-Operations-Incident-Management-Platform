variable "subscription_id" { type = string }
variable "location" { type = string default = "centralindia" }
variable "environment" { type = string default = "dev" }
variable "project_name" { type = string default = "cloudops" }
variable "container_image" { type = string default = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest" }
variable "enable_ai" { type = bool default = false }
variable "azure_openai_model" { type = string default = "gpt-4o-mini" }
variable "azure_openai_model_version" { type = string default = "2024-07-18" }
variable "tags" { type = map(string) default = { project = "azure-ai-cloudops", owner = "sakshi", environment = "dev" } }
