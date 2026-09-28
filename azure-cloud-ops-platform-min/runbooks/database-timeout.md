# Database Timeout Runbook

## Symptoms
- API reports database connection timeout.
- Latency increases sharply.
- Application logs contain connection-pool or timeout errors.

## Investigation
1. Check PostgreSQL availability and connection count.
2. Check application connection pool configuration.
3. Check private DNS and network path.
4. Check recent schema or deployment changes.

## Approved remediation
- Scale the application if connection demand is legitimate.
- Roll back a known-bad application revision.
- Do not modify database configuration automatically without approval.

## Verification
- Database connections succeed.
- API latency returns to baseline.
- Error rate remains below the alert threshold for the observation window.
