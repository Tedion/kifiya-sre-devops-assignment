# Runbook: Database Outage

## Scenario
Primary database server is down or unreachable, causing application failures.

## Prerequisites
- Access to database servers
- Access to application servers
- Monitoring dashboards
- Backup credentials

## Detection
- **Alert**: Database connection pool exhausted
- **Symptom**: High error rate (5xx responses)
- **Metric**: Database connection errors > 100/min

## Severity Classification
- **P0**: Complete database outage, all services affected
- **P1**: Read replica available, write operations failing
- **P2**: Performance degradation, some queries timing out

## Response Steps

### Step 1: Verify Database Status (5 minutes)
```bash
# Check database server health
ssh db-primary
systemctl status postgresql
journalctl -u postgresql -n 50

# Check connectivity
psql -h db-primary -U monitoring -c "SELECT 1;"

# Check disk space
df -h
```

**If database is down:**
- Proceed to Step 2
- Declare P0 incident if all services affected

**If database is up but slow:**
- Proceed to Step 4 (Performance Investigation)

### Step 2: Check Failover Status (5 minutes)
```bash
# Verify read replica status
ssh db-replica
systemctl status postgresql
psql -h db-replica -U monitoring -c "SELECT pg_is_in_recovery();"

# Check replication lag
psql -h db-replica -U monitoring -c "SELECT pg_last_xlog_receive_location(), pg_last_xlog_replay_location();"
```

**If replica is healthy:**
- Proceed to Step 3 (Failover)

**If replica is also down:**
- Proceed to Step 5 (Disaster Recovery)

### Step 3: Execute Failover (15 minutes)

#### 3.1 Promote Read Replica
```bash
# On replica server
sudo -u postgres pg_ctl promote -D /var/lib/postgresql/data

# Verify promotion
psql -h db-replica -U postgres -c "SELECT pg_is_in_recovery();"
# Should return: f (false)
```

#### 3.2 Update Application Configuration
```bash
# Update connection strings
ansible-playbook -i inventory update-db-config.yml \
  -e "db_host=db-replica" \
  -e "db_read_host=db-replica"

# Restart application services
ansible-playbook -i inventory restart-app.yml
```

#### 3.3 Verify Service Restoration
```bash
# Check application health
curl https://api.example.com/health

# Monitor error rates
# Check Grafana dashboard for 5xx errors
```

### Step 4: Performance Investigation (If DB is up but slow)

#### 4.1 Check Active Connections
```sql
SELECT count(*) FROM pg_stat_activity;
SELECT * FROM pg_stat_activity WHERE state = 'active';
```

#### 4.2 Check Blocking Queries
```sql
SELECT blocked_locks.pid AS blocked_pid,
       blocking_locks.pid AS blocking_pid,
       blocked_activity.usename AS blocked_user,
       blocking_activity.usename AS blocking_user,
       blocked_activity.query AS blocked_statement,
       blocking_activity.query AS blocking_statement
FROM pg_catalog.pg_locks blocked_locks
JOIN pg_catalog.pg_stat_activity blocked_activity ON blocked_activity.pid = blocked_locks.pid
JOIN pg_catalog.pg_locks blocking_locks ON blocking_locks.locktype = blocked_locks.locktype
JOIN pg_catalog.pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid
WHERE NOT blocked_locks.granted;
```

#### 4.3 Check Slow Queries
```sql
SELECT pid, now() - pg_stat_activity.query_start AS duration, query
FROM pg_stat_activity
WHERE (now() - pg_stat_activity.query_start) > interval '5 minutes';
```

#### 4.4 Kill Long-Running Queries (if necessary)
```sql
SELECT pg_terminate_backend(pid) FROM pg_stat_activity 
WHERE (now() - pg_stat_activity.query_start) > interval '10 minutes';
```

### Step 5: Disaster Recovery (If both primary and replica are down)

#### 5.1 Restore from Backup
```bash
# Identify latest backup
aws s3 ls s3://backups/database/ | sort

# Restore backup
./scripts/restore.sh --backup-date 2024-01-15 --target-host db-new

# Verify data integrity
./scripts/verifybackup.py --host db-new
```

#### 5.2 Update DNS/Configuration
```bash
# Update database host in configuration
ansible-playbook -i inventory update-db-config.yml \
  -e "db_host=db-new"
```

## Verification

### Health Checks
- [ ] Database server responding to queries
- [ ] Application health endpoint returns 200
- [ ] Error rate < 0.1%
- [ ] Response time p95 < 500ms
- [ ] No data loss detected

### Monitoring
- Monitor for 1 hour after resolution
- Check for replication lag if using replicas
- Verify backup completion

## Rollback Plan
If failover causes issues:
1. Restore primary database from backup
2. Revert application configuration
3. Rebuild replication

## Prevention
- [ ] Set up automated failover (Patroni, repmgr)
- [ ] Improve monitoring and alerting
- [ ] Regular backup verification
- [ ] Load testing to identify capacity limits
- [ ] Database connection pooling optimization

## Related Runbooks
- API Latency Spike
- Disk Space Exhaustion
- Network Partition

