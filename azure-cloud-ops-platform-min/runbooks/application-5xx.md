# Application 5xx Incident Runbook

## Symptoms
- HTTP 5xx rate exceeds the alert threshold.
- Container health probe may fail.
- Request latency may increase.

## Investigation
1. Check Container Apps revision health.
2. Check recent deployment revision.
3. Query Log Analytics for errors.
4. Check dependency health (PostgreSQL, Service Bus).
5. Compare current metrics with the previous 30 minutes.

## Approved remediation
- Restart the affected revision if the failure is transient.
- Roll back to the last known-good revision if a deployment introduced the failure.

## Verification
- `/health` returns 200.
- 5xx rate returns to baseline.
- No new container restart loop appears.
