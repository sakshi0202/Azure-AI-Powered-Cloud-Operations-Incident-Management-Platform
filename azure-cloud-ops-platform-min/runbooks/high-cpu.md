# High CPU Runbook

## Symptoms
- CPU remains above the configured threshold.
- Request latency increases.

## Investigation
1. Check traffic volume.
2. Check replica count.
3. Check application logs for expensive operations.
4. Compare with deployment history.

## Approved remediation
- Scale out within the configured maximum.
- Investigate code or dependency regressions if the condition persists.
