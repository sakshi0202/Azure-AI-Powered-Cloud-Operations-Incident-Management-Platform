# Azure AI-Powered Cloud Operations & Incident Management Platform

**Portfolio project for Sakshi — Cloud Engineer / DevOps / AI Services**

A production-style Azure platform that detects application and infrastructure incidents, routes them through an event-driven pipeline, retrieves operational runbooks with RAG, uses an Azure-hosted LLM for evidence-grounded incident analysis, and executes only approved, allow-listed remediation actions.

This project is intentionally designed around Sakshi's existing GCP/DevOps background: GCP production concepts are mapped to Azure while the implementation uses Azure-native services.

## What makes this project different

This is not a generic chatbot and not a one-line self-healing demo.

It combines:

- Azure Container Apps for a real containerized workload
- Azure Database for PostgreSQL for application state
- Azure Blob Storage for knowledge-base documents
- Azure Monitor / Log Analytics for telemetry
- Azure Monitor Common Alert Schema ingestion
- Event Grid for event routing
- Service Bus for durable asynchronous incident processing
- Azure Functions for event ingestion and controlled remediation
- Azure AI Search for vector retrieval
- Azure-hosted model deployments for grounded incident analysis
- Managed Identity + RBAC + Key Vault
- Terraform for infrastructure as code
- GitHub Actions + OIDC for secure CI/CD
- failure injection and health verification
- retries, dead-letter handling and idempotency design

## Target architecture

```text
                         Engineer
                            |
                            v
                    +----------------+
                    | CloudOps API   |
                    | Container Apps |
                    +-------+--------+
                            |
                   incident/analyze
                            |
            +---------------+----------------+
            |                                |
            v                                v
     Azure Monitor                    AI Incident Agent
            |                                |
     Common Alert Schema                    +---- Azure AI Search
            |                                |
            v                                +---- Runbooks
      Function Ingress                      |
            |                                +---- Live telemetry
            v                                |
       Event Grid                            v
            |                          Azure-hosted LLM
            v                                |
       Service Bus                           v
            |                         Grounded diagnosis
            v                                |
   Remediation Function             Human approval required
            |                                |
            +---------------+----------------+
                            |
                            v
                     Approved action
                            |
                            v
                     Azure resource
                            |
                            v
                     Health verification
                            |
                            v
                     Log Analytics
```

## GCP mental model

| Azure in this project | GCP concept you already know |
|---|---|
| Container Apps | Cloud Run |
| PostgreSQL Flexible Server | Cloud SQL PostgreSQL |
| Blob Storage | Cloud Storage |
| Service Bus | Pub/Sub-style asynchronous messaging |
| Azure Functions | Cloud Run functions |
| Azure Monitor / Log Analytics | Cloud Monitoring / Cloud Logging |
| Key Vault | Secret Manager |
| Entra ID / Azure RBAC | Cloud Identity / IAM |
| AI Search | Vertex AI Search / Vector Search patterns |
| Azure-hosted LLM | Vertex AI / Gemini pattern |
| Event Grid | Eventarc-style event routing |
| Terraform | Terraform |
| GitHub Actions OIDC | GitHub Actions workload identity federation |

## Repository layout

```text
app/                         FastAPI workload + failure injection + incident API
agent/                       Read-only RAG incident analyst
functions/remediation/       Monitor ingress + Service Bus remediation worker
infra/environments/dev/      Terraform environment
runbooks/                    Ground-truth operational knowledge
scripts/ingest/              Vector index creation and runbook ingestion
docs/                        Architecture, deployment and interview material
.github/workflows/           Terraform, application and Function CI/CD
tests/                       Application tests
```

## Phase-by-phase build

### Phase 1 — Deploy the base platform

1. Azure Resource Group
2. VNet + subnets + NSG
3. Log Analytics
4. Container Apps environment
5. ACR
6. Container App
7. PostgreSQL Flexible Server (private access)
8. Storage + private knowledge-base container
9. Key Vault
10. Service Bus queue
11. Event Grid topic
12. Function App

Start with `enable_ai=false`.

### Phase 2 — Deploy the application

The FastAPI app exposes:

- `GET /health`
- `GET /api/orders`
- `GET /api/version`
- `POST /simulate/failure`
- `POST /api/incidents/analyze`

Failure injection example:

```json
POST /simulate/failure
{"mode":"error"}
```

The `/health` endpoint will return HTTP 503 until the failure is cleared:

```json
POST /simulate/failure
{"mode":"clear"}
```

### Phase 3 — Add observability

Use Azure Monitor and Log Analytics to collect application and platform telemetry.

The project should eventually have alerts for:

- elevated 5xx responses
- failed health checks
- high CPU / latency
- container restarts
- Service Bus backlog

### Phase 4 — Event pipeline

Azure Monitor alerts are consumed through the Common Alert Schema by the Function HTTP ingress. The Function normalizes the alert to a CloudEvent and publishes it to Event Grid. Event Grid routes the event to Service Bus.

This keeps the components decoupled:

```text
Monitor = detect
Event Grid = route
Service Bus = buffer/retry
Function = process
```

### Phase 5 — RAG

Runbooks are embedded and indexed in Azure AI Search.

```text
Markdown runbook
      |
      v
embedding model
      |
      v
Azure AI Search vector field
```

The incident agent retrieves relevant runbooks before asking the LLM to analyze the incident.

### Phase 6 — AI investigation

The agent is deliberately read-only.

Tools are conceptually:

```text
search_runbooks()
get_recent_logs()
get_metrics()
get_service_health()
get_deployment_history()
get_incident_history()
```

The agent produces:

- summary
- evidence
- probable cause
- recommended action
- confidence
- whether human approval is required

### Phase 7 — Controlled remediation

Only the Function has mutation permissions.

Allowed actions are explicit:

```text
restart_container_app
scale_container_app
```

No free-form Azure commands are accepted from the LLM.

### Phase 8 — Verification

After an action, the system should check:

1. revision state
2. `/health`
3. error rate
4. latency
5. recent logs

If recovery fails, the incident is retried or escalated instead of being marked resolved.

## Deployment

See `docs/deployment-runbook.md`.

## GitHub Actions secrets

Configure:

```text
AZURE_CLIENT_ID
AZURE_TENANT_ID
AZURE_SUBSCRIPTION_ID
TFSTATE_STORAGE_ACCOUNT
```

Use GitHub OIDC rather than an Azure client secret.

## Important implementation note

Some Azure AI model names/versions and AI Search capabilities depend on the region, quota and current service availability. The Terraform variables intentionally expose the model name/version rather than hiding an assumed model behind the code.

## Interview story

A concise explanation:

> I built an Azure-native Cloud Operations platform around a containerized application. Azure Monitor detects operational conditions and sends a normalized alert to a Function ingress. The Function converts it into a CloudEvent and publishes it through Event Grid to Service Bus, giving us decoupling and durable asynchronous processing. For investigation, a read-only AI agent retrieves relevant runbooks from Azure AI Search and combines that context with current telemetry before generating a grounded diagnosis. Any mutation requires explicit approval and is executed by a separate Function with narrowly scoped managed-identity permissions. Terraform provisions the platform, while GitHub Actions authenticates through OIDC. The system then verifies whether remediation actually recovered the service.

## Why this is useful for a GCP engineer learning Azure

The architecture deliberately lets you explain both clouds:

- Cloud Run -> Container Apps
- Cloud SQL -> Azure PostgreSQL
- Pub/Sub -> Service Bus
- Cloud Monitoring -> Azure Monitor
- Cloud Logging -> Log Analytics
- Secret Manager -> Key Vault
- IAM -> Azure RBAC
- Vertex AI / Search -> Azure AI / Search

The implementation is Azure-native; the GCP comparison is for architectural reasoning and interview preparation.
