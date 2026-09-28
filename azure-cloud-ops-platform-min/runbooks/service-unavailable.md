# Service Unavailable Runbook

## Symptoms
- `/health` returns 503.
- Requests fail at the ingress layer.

## Investigation
1. Check Container Apps revision health.
2. Check dependency connectivity.
3. Check Azure Service Health.
4. Check recent deployment activity.

## Approved remediation
- Restart or roll back the application revision after approval.
