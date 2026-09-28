# Incident Agent

This service is intentionally **read-only**. It retrieves runbooks from Azure AI Search and uses an Azure-hosted model to produce a grounded incident analysis.

Remediation is separated into the Azure Function. The agent never receives broad Azure write permissions.

Required environment variables:
- `AZURE_SEARCH_ENDPOINT`
- `AZURE_SEARCH_INDEX`
- `AZURE_OPENAI_ENDPOINT`
- `AZURE_OPENAI_DEPLOYMENT`
- `AZURE_OPENAI_API_VERSION` (optional)

Authentication uses `DefaultAzureCredential`, so local Azure CLI credentials can be used during development and Managed Identity can be used in Azure.
