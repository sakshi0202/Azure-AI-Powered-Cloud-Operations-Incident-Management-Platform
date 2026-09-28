# Container Crash Loop Runbook

## Symptoms
- Container restarts repeatedly.
- Readiness probe fails.
- Application logs show startup errors.

## Investigation
1. Inspect the active revision and image tag.
2. Inspect startup logs.
3. Check environment variables and secret references.
4. Compare with the previous revision.

## Approved remediation
- Roll back to the last known-good revision.
- Restart only after confirming the failure is transient.
