# Task 1: Monitoring, Observability, and Alerting System

## Overview

This task implements a comprehensive monitoring and alerting system using Prometheus, Grafana, and Alertmanager. The solution provides actionable insights through metrics collection, visualization, and proactive issue detection.

## Table of Contents

- [Architecture](#architecture)
- [Components](#components)
- [Quick Start](#quick-start)
- [Configuration Details](#configuration-details)
- [Key Metrics](#key-metrics)
- [Alert Thresholds](#alert-thresholds)
- [Escalation Logic](#escalation-logic)
- [Design Decisions](#design-decisions)
- [Operational Runbook](#operational-runbook)
- [Troubleshooting](#troubleshooting)

## Architecture

The monitoring stack follows a layered architecture:

1. **Collection Layer**: Exporters expose metrics from infrastructure and applications
2. **Storage Layer**: Prometheus stores time-series data and evaluates alert rules
3. **Alerting Layer**: Alertmanager routes and delivers notifications
4. **Visualization Layer**: Grafana provides dashboards and insights

See [architecture_diagram.md](./architecture_diagram.md) for detailed architecture visualization.

## Components

### Core Stack

| Component | Version | Port | Purpose |
|-----------|---------|------|---------|
| Prometheus | 2.45+ | 9090 | Time-series database and alert engine |
| Alertmanager | 0.26+ | 9093 | Alert routing and notification |
| Grafana | 10.0+ | 3000 | Visualization and dashboards |

### Exporters

| Exporter | Port | Metrics |
|----------|------|---------|
| Node Exporter | 9100 | System metrics (CPU, RAM, disk, network) |
| Blackbox Exporter | 9115 | Endpoint availability (HTTP, TCP, ICMP) |
| PostgreSQL Exporter | 9187 | Database metrics |
| Redis Exporter | 9121 | Cache metrics |
| Nginx Exporter | 9113 | Web server metrics |
| RabbitMQ Exporter | 9419 | Message queue metrics |

## Quick Start

### Prerequisites

- Docker and Docker Compose (recommended)
- OR: Linux server with systemd
- Minimum 4GB RAM, 2 CPU cores
- Open firewall ports: 9090, 9093, 3000

### Docker Compose Setup

```bash
# Clone the repository
git clone <repository-url>
cd task1-monitoring

# Create docker-compose.yml
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./configs/prometheus.yml:/etc/prometheus/prometheus.yml
      - ./configs/alert-rules.yml:/etc/prometheus/alert-rules.yml
      - prometheus-data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=15d'
      - '--web.console.libraries=/usr/share/prometheus/console_libraries'
      - '--web.console.templates=/usr/share/prometheus/consoles'
    restart: unless-stopped
    networks:
      - monitoring

  alertmanager:
    image: prom/alertmanager:latest
    container_name: alertmanager
    ports:
      - "9093:9093"
    volumes:
      - ./configs/alertmanager.yml:/etc/alertmanager/alertmanager.yml
      - alertmanager-data:/alertmanager
    command:
      - '--config.file=/etc/alertmanager/alertmanager.yml'
      - '--storage.path=/alertmanager'
    restart: unless-stopped
    networks:
      - monitoring

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=admin123
      - GF_INSTALL_PLUGINS=grafana-piechart-panel
    volumes:
      - ./configs/grafana-datasource.yml:/etc/grafana/provisioning/datasources/datasource.yml
      - grafana-data:/var/lib/grafana
    restart: unless-stopped
    networks:
      - monitoring

  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    ports:
      - "9100:9100"
    command:
      - '--path.rootfs=/host'
    volumes:
      - '/:/host:ro,rslave'
    restart: unless-stopped
    networks:
      - monitoring

  blackbox-exporter:
    image: prom/blackbox-exporter:latest
    container_name: blackbox-exporter
    ports:
      - "9115:9115"
    volumes:
      - ./configs/blackbox.yml:/etc/blackbox_exporter/config.yml
    restart: unless-stopped
    networks:
      - monitoring

networks:
  monitoring:
    driver: bridge

volumes:
  prometheus-data:
  alertmanager-data:
  grafana-data:
EOF

# Start the stack
docker-compose up -d

# Verify services are running
docker-compose ps

# Check logs
docker-compose logs -f prometheus
```

### Access the Services

- **Prometheus**: http://localhost:9090
- **Alertmanager**: http://localhost:9093
- **Grafana**: http://localhost:3000 (admin/admin123)

### Initial Configuration Steps

1. **Access Grafana**
   ```
   URL: http://localhost:3000
   Username: admin
   Password: admin123
   ```

2. **Verify Data Source**
   - Go to Configuration → Data Sources
   - Prometheus should be pre-configured
   - Test connection

3. **Import Dashboards**
   ```bash
   # Import popular dashboards
   Node Exporter Full: Dashboard ID 1860
   Prometheus Stats: Dashboard ID 3662
   Alertmanager: Dashboard ID 9578
   ```

4. **Test Alerting**
   ```bash
   # Trigger a test alert
   docker-compose stop node-exporter
   
   # Wait 2 minutes, check Alertmanager
   curl http://localhost:9093/api/v2/alerts
   
   # Restart exporter
   docker-compose start node-exporter
   ```

## Configuration Details

### Prometheus Configuration

Located in `configs/prometheus.yml`:

**Key Settings:**
- **Scrape Interval**: 15s (adjustable per job)
- **Evaluation Interval**: 15s (for alert rules)
- **Retention**: 15 days (local storage)
- **External Labels**: cluster, environment, region

**Service Discovery:**
- Static configs for exporters
- Kubernetes SD for dynamic pod discovery
- Relabeling for metadata enrichment

### Alert Rules Configuration

Located in `configs/alert-rules.yml`:

**Alert Groups:**
1. **infrastructure_alerts**: System-level metrics
2. **application_alerts**: Service-level metrics
3. **database_alerts**: Database performance
4. **kubernetes_alerts**: Container orchestration
5. **business_alerts**: Business logic metrics

### Alertmanager Configuration

Located in `configs/alertmanager.yml`:

**Routing Strategy:**
- Group by: alertname, cluster, service
- Group wait: 30s (first notification)
- Group interval: 5m (new alerts in group)
- Repeat interval: 4h (warnings), 30m (critical)

**Receivers:**
- PagerDuty: Critical infrastructure alerts
- Slack: Team-specific channels
- Email: Distribution lists
- Webhooks: Custom integrations

### Grafana Data Source

Located in `configs/grafana-datasource.yml`:

**Configured Data Sources:**
- Prometheus (primary, default)
- Alertmanager (for alert dashboard)
- Prometheus Long-term (Thanos/Cortex)
- Loki (optional, for logs)
- Tempo (optional, for traces)

## Key Metrics

### Infrastructure Metrics (Node Exporter)

#### CPU Metrics
```promql
# CPU Usage Percentage
100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# CPU Load Average
node_load1
node_load5
node_load15
```

#### Memory Metrics
```promql
# Memory Usage Percentage
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Available Memory
node_memory_MemAvailable_bytes / 1024 / 1024 / 1024  # in GB

# Swap Usage
(node_memory_SwapTotal_bytes - node_memory_SwapFree_bytes) / node_memory_SwapTotal_bytes * 100
```

#### Disk Metrics
```promql
# Disk Space Usage
(node_filesystem_size_bytes - node_filesystem_avail_bytes) / node_filesystem_size_bytes * 100

# Disk I/O Utilization
rate(node_disk_io_time_seconds_total[5m])

# Read/Write Throughput
rate(node_disk_read_bytes_total[5m])
rate(node_disk_written_bytes_total[5m])
```

#### Network Metrics
```promql
# Network Receive Rate
rate(node_network_receive_bytes_total[5m]) * 8 / 1000 / 1000  # Mbps

# Network Transmit Rate
rate(node_network_transmit_bytes_total[5m]) * 8 / 1000 / 1000  # Mbps

# Network Errors
rate(node_network_receive_errs_total[5m])
rate(node_network_transmit_errs_total[5m])
```

### Application Metrics (Custom)

#### RED Metrics (Rate, Errors, Duration)
```promql
# Request Rate
rate(http_requests_total[5m])

# Error Rate
rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m]) * 100

# Duration (Latency Percentiles)
histogram_quantile(0.50, rate(http_request_duration_seconds_bucket[5m]))  # p50
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))  # p95
histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))  # p99
```

#### USE Metrics (Utilization, Saturation, Errors)
```promql
# Utilization
avg(rate(process_cpu_seconds_total[5m])) * 100

# Saturation
http_active_connections
queue_depth

# Errors
rate(http_errors_total[5m])
```

### Database Metrics (PostgreSQL)

```promql
# Connection Usage
pg_stat_database_numbackends / pg_settings_max_connections * 100

# Transaction Rate
rate(pg_stat_database_xact_commit[5m])
rate(pg_stat_database_xact_rollback[5m])

# Replication Lag
pg_replication_lag

# Slow Queries
pg_stat_activity_max_tx_duration{state="active"}

# Cache Hit Ratio
rate(pg_stat_database_blks_hit[5m]) / (rate(pg_stat_database_blks_hit[5m]) + rate(pg_stat_database_blks_read[5m])) * 100
```

## Alert Thresholds

### Critical Alerts (P0 - Page Immediately)

| Alert | Condition | Duration | Impact | MTTR Target |
|-------|-----------|----------|--------|-------------|
| NodeDown | up{job="node-exporter"} == 0 | 2 min | Complete node failure | 5 min |
| ServiceDown | up{job=~"web-api\|backend"} == 0 | 2 min | Service unavailable | 5 min |
| CriticalCPUUsage | CPU > 95% | 2 min | Performance degradation | 10 min |
| CriticalMemoryUsage | Memory > 95% | 2 min | OOM kill risk | 10 min |
| DiskSpaceCritical | Disk < 10% | 2 min | Write failures imminent | 15 min |
| CriticalHTTPErrorRate | 5xx rate > 10% | 2 min | User-facing errors | 10 min |
| DatabaseDown | pg_up == 0 | 2 min | Data layer failure | 5 min |
| APIEndpointDown | probe_success == 0 | 2 min | External access broken | 5 min |
| HighPaymentFailureRate | Payment fails > 5% | 5 min | Revenue impact | 15 min |

### Warning Alerts (P1 - Investigate Soon)

| Alert | Condition | Duration | Impact | MTTR Target |
|-------|-----------|----------|--------|-------------|
| HighCPUUsage | CPU > 80% | 5 min | Degraded performance | 1 hour |
| HighMemoryUsage | Memory > 85% | 5 min | Memory pressure | 1 hour |
| DiskSpaceLow | Disk < 20% | 5 min | Capacity planning needed | 4 hours |
| HighHTTPErrorRate | 5xx rate > 5% | 5 min | Partial degradation | 30 min |
| HighLatency | p95 > 1s | 5 min | Slow responses | 1 hour |
| HighDiskIO | Disk I/O > 80% | 10 min | I/O bottleneck | 2 hours |
| HighDatabaseConnections | Conn > 80% | 5 min | Connection exhaustion risk | 1 hour |
| ReplicationLag | Lag > 30s | 5 min | Stale read data | 30 min |
| SlowQueries | Slow queries detected | 5 min | Performance impact | 1 hour |
| PodCrashLooping | Pod restart rate > 0 | 5 min | Application instability | 30 min |

### Alert Rationale

**Why These Thresholds?**

1. **CPU > 80%/95%**: 
   - 80% gives headroom for traffic spikes
   - 95% indicates saturation, immediate action needed
   
2. **Memory > 85%/95%**:
   - Linux uses free memory for cache
   - <5% free risks OOM killer
   
3. **Disk < 20%/10%**:
   - 20% allows time for cleanup/expansion
   - 10% is critical - writes may fail
   
4. **5xx > 5%/10%**:
   - 5% indicates partial issues
   - 10% is severe customer impact
   
5. **Latency p95 > 1s**:
   - Most users expect <1s response time
   - p95 catches tail latency issues

## Escalation Logic

### Alert Flow Diagram

```
Alert Condition Met
       │
       ▼
Prometheus Evaluates (every 15s)
       │
       ▼
Duration Threshold Passed?
       │
       ├─ No → Continue monitoring
       │
       └─ Yes → Send to Alertmanager
                     │
                     ▼
              Alertmanager Processing
              • Group similar alerts (30s)
              • Apply routing rules
              • Check silences
              • Check inhibition rules
                     │
                     ▼
              ┌──────┴──────┐
              │             │
          Critical      Warning
              │             │
              ▼             ▼
       ┌─────────────┐ ┌─────────────┐
       │  PagerDuty  │ │   Slack     │
       │  (Immediate)│ │  (#alerts)  │
       └──────┬──────┘ └──────┬──────┘
              │               │
              ▼               ▼
       ┌─────────────┐ ┌─────────────┐
       │   Slack     │ │   Email     │
       │ (#critical) │ │ (team@)     │
       └──────┬──────┘ └──────┬──────┘
              │               │
              ▼               ▼
       ┌─────────────┐ ┌─────────────┐
       │   Email     │ │   Repeat    │
       │  (oncall@)  │ │  every 4h   │
       └──────┬──────┘ └─────────────┘
              │
              ▼
       ┌─────────────┐
       │   Repeat    │
       │  every 15m  │
       └──────┬──────┘
              │
              ▼
       Acknowledged or Resolved?
              │
              ├─ Acknowledged → Stop repeat
              │
              └─ Not Ack (45 min) → Escalate to manager
```

### Escalation Tiers

#### Tier 1: On-Call Engineer (0-15 minutes)
- **Channels**: PagerDuty, Slack #alerts-critical, Email
- **Response Time**: <5 minutes acknowledge, <15 minutes engage
- **Actions**: 
  - Acknowledge alert
  - Initial investigation
  - Apply immediate fixes if known issue
  - Update incident channel

#### Tier 2: Team Lead (15-30 minutes)
- **Trigger**: No acknowledgment after 15 minutes OR escalation requested
- **Channels**: PagerDuty escalation, Direct call
- **Actions**:
  - Verify engineer is engaged
  - Provide technical guidance
  - Authorize emergency changes
  - Coordinate with other teams

#### Tier 3: Engineering Manager (30-45 minutes)
- **Trigger**: Unresolved after 30 minutes OR major incident
- **Channels**: Direct call, Executive war room
- **Actions**:
  - Activate incident commander role
  - Pull in additional resources
  - Communications to stakeholders
  - Make business decisions (rollback, etc.)

#### Tier 4: VP Engineering / CTO (45+ minutes)
- **Trigger**: Prolonged outage OR P0 with revenue impact
- **Actions**:
  - Executive decision making
  - External communications
  - Post-incident review leadership

### Notification Matrix

| Severity | Immediate | 15 min | 30 min | 45 min | Repeat Interval |
|----------|-----------|--------|--------|--------|-----------------|
| Critical | PagerDuty + Slack + Email | Page Backup | Escalate Lead | Escalate Manager | 15 min |
| Warning | Slack + Email | - | - | - | 4 hours |
| Info | Slack only | - | - | - | 12 hours |

### On-Call Rotation

**Primary On-Call**:
- Weekdays: 8 AM - 8 PM (business hours)
- After hours: 8 PM - 8 AM + weekends
- Shift length: 1 week
- Handoff: Monday 8 AM

**Backup On-Call**:
- Escalation point for primary
- Covers primary's off-time
- Same rotation schedule (offset 1 week)

## Design Decisions

### 1. Pull vs Push Model

**Decision**: Pull-based metrics collection (Prometheus scrapes exporters)

**Rationale**:
- **Network resilience**: Prometheus controls retry logic
- **Service discovery**: Easy to add/remove targets
- **Security**: Exporters don't need credentials to push
- **Debugging**: Can manually scrape endpoints for troubleshooting

**Tradeoff**: Short-lived jobs need pushgateway (not ideal for all use cases)

### 2. Local Storage vs Remote Write

**Decision**: Local 15-day retention + optional remote write to Thanos

**Rationale**:
- **Performance**: Local storage is fast for recent data queries
- **Cost**: 15 days is sufficient for most operational needs
- **Scalability**: Thanos/Cortex for long-term historical analysis
- **Simplicity**: Start simple, add remote write as needed

**Tradeoff**: Limited historical data without remote storage

### 3. Alert Grouping Strategy

**Decision**: Group by [alertname, cluster, service]

**Rationale**:
- **Reduces noise**: Similar alerts combined into single notification
- **Context**: Grouped alerts show broader patterns
- **Actionability**: Team sees scope of issue immediately

**Tradeoff**: May delay notification by group_wait duration (30s)

### 4. Scrape Intervals

**Decision**: 
- Default: 15s
- Infrastructure: 30s
- Slow-changing metrics: 60s

**Rationale**:
- **Accuracy**: 15s balances granularity with overhead
- **Resource usage**: Longer intervals for slow-changing metrics
- **Alert latency**: 15s eval + 2 min duration = <2.5 min to alert

**Tradeoff**: Higher scrape frequency = more CPU/memory/storage

### 5. Multi-Channel Notifications

**Decision**: Critical alerts go to PagerDuty + Slack + Email

**Rationale**:
- **Redundancy**: Multiple channels ensure notification delivery
- **Visibility**: Team sees alerts even if not on-call
- **Context**: Chat provides collaboration space
- **Audit trail**: Email creates permanent record

**Tradeoff**: Potential for notification fatigue

### 6. Alert Inhibition

**Decision**: NodeDown inhibits all other node alerts

**Rationale**:
- **Noise reduction**: Don't alert on symptoms if cause is known
- **Focus**: Engineers focus on root cause (node down)
- **Clarity**: Fewer simultaneous alerts = clearer picture

**Tradeoff**: May hide related but independent issues

### 7. Retention Period

**Decision**: 15 days local, unlimited with remote storage

**Rationale**:
- **Operational needs**: 15 days covers most debugging scenarios
- **Disk usage**: Predictable storage requirements
- **Performance**: Recent data queries stay fast
- **Compliance**: Long-term data in remote storage with retention policies

**Tradeoff**: Need additional setup for historical analysis beyond 15 days

## Operational Runbook

### Daily Operations

#### Morning Checks (5 minutes)
```bash
# 1. Check Prometheus targets
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.health != "up")'

# 2. Check for active alerts
curl -s http://localhost:9093/api/v2/alerts | jq '.[] | select(.status.state == "active")'

# 3. Verify data ingestion
curl -s 'http://localhost:9090/api/v1/query?query=up' | jq '.data.result | length'

# 4. Check Grafana dashboards
# Open browser to http://localhost:3000 and spot-check main dashboards
```

#### Weekly Maintenance (30 minutes)
1. **Review alert effectiveness**
   - Check alert history
   - Identify noisy alerts
   - Tune thresholds if needed

2. **Capacity planning**
   - Review disk usage trends
   - Check query performance
   - Plan for scaling if needed

3. **Dashboard updates**
   - Add new services to dashboards
   - Remove deprecated metrics
   - Update team preferences

4. **On-call rotation**
   - Update PagerDuty schedule
   - Verify contact information
   - Brief incoming on-call engineer

### Common Operations

#### Adding a New Service to Monitoring

1. **Add exporter to service**
   ```yaml
   # In application deployment
   - name: myapp
     image: myapp:latest
     ports:
       - containerPort: 8080  # Application
       - containerPort: 8081  # Metrics endpoint
   ```

2. **Add scrape config to Prometheus**
   ```yaml
   # configs/prometheus.yml
   - job_name: 'my-new-service'
     scrape_interval: 15s
     static_configs:
       - targets:
           - myapp-01:8081
           - myapp-02:8081
         labels:
           service: 'my-new-service'
           environment: 'production'
   ```

3. **Reload Prometheus config**
   ```bash
   # Docker Compose
   docker-compose exec prometheus kill -HUP 1
   
   # OR send reload signal
   curl -X POST http://localhost:9090/-/reload
   ```

4. **Verify target appears**
   ```bash
   curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.labels.job == "my-new-service")'
   ```

5. **Create alert rules** (optional)
   ```yaml
   # configs/alert-rules.yml
   - alert: MyNewServiceDown
     expr: up{job="my-new-service"} == 0
     for: 2m
     labels:
       severity: critical
       service: my-new-service
     annotations:
       summary: "My New Service is down"
       description: "Service {{ $labels.instance }} has been down for 2 minutes"
   ```

6. **Create Grafana dashboard**
   - Import template or create custom
   - Add panels for key metrics
   - Set up dashboard alerts (optional)

#### Silencing Alerts During Maintenance

1. **Via Alertmanager UI**
   ```
   http://localhost:9093/#/silences
   Click "New Silence"
   Add matchers (e.g., instance=~"server-01")
   Set duration
   Add comment explaining reason
   Create
   ```

2. **Via API**
   ```bash
   # Create silence for 2 hours
   cat > silence.json << EOF
   {
     "matchers": [
       {
         "name": "instance",
         "value": "server-01",
         "isRegex": false
       }
     ],
     "startsAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
     "endsAt": "$(date -u -d '+2 hours' +%Y-%m-%dT%H:%M:%SZ)",
     "createdBy": "ops-team",
     "comment": "Scheduled maintenance - database migration"
   }
   EOF
   
   curl -X POST -H "Content-Type: application/json" \
     -d @silence.json \
     http://localhost:9093/api/v2/silences
   ```

3. **Via amtool CLI**
   ```bash
   amtool silence add instance=server-01 --duration=2h --comment="Maintenance"
   ```

#### Investigating High CPU Alert

1. **Check alert details**
   ```bash
   curl http://localhost:9093/api/v2/alerts | jq '.[] | select(.labels.alertname == "HighCPUUsage")'
   ```

2. **Query current CPU usage**
   ```bash
   curl -G 'http://localhost:9090/api/v1/query' \
     --data-urlencode 'query=100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)' | jq
   ```

3. **Check CPU breakdown by mode**
   ```promql
   # In Prometheus UI or Grafana
   irate(node_cpu_seconds_total[5m]) * 100
   ```

4. **Identify top processes** (if node_exporter has process metrics)
   ```promql
   topk(10, rate(node_cpu_seconds_total{mode!="idle"}[5m]))
   ```

5. **Check related metrics**
   - Load average: `node_load1`, `node_load5`
   - Context switches: `rate(node_context_switches_total[5m])`
   - Interrupts: `rate(node_intr_total[5m])`

6. **SSH to server for detailed analysis**
   ```bash
   ssh server-01
   top -b -n 1 | head -20
   ps aux --sort=-%cpu | head -10
   uptime
   ```

#### Backup and Restore

**Backup Prometheus Data**
```bash
# Stop Prometheus
docker-compose stop prometheus

# Backup data directory
tar -czf prometheus-backup-$(date +%Y%m%d).tar.gz ./prometheus-data/

# Start Prometheus
docker-compose start prometheus

# Optional: Snapshot API (if Prometheus is running)
curl -X POST http://localhost:9090/api/v1/admin/tsdb/snapshot
```

**Restore Prometheus Data**
```bash
# Stop Prometheus
docker-compose stop prometheus

# Restore data
tar -xzf prometheus-backup-20241118.tar.gz -C ./

# Start Prometheus
docker-compose start prometheus
```

### Performance Tuning

#### Optimizing Query Performance

1. **Use recording rules for expensive queries**
   ```yaml
   # configs/recording-rules.yml
   groups:
     - name: instance_metrics
       interval: 30s
       rules:
         - record: instance:node_cpu:avg_utilization
           expr: 100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
   ```

2. **Limit query range and step**
   ```promql
   # Instead of querying 30 days
   rate(metric[5m])[7d:5m]  # Query last 7 days with 5min resolution
   ```

3. **Use efficient aggregations**
   ```promql
   # Good - aggregate before calculation
   avg(rate(metric[5m]))
   
   # Bad - calculate then aggregate (slower)
   avg(metric) / avg(other_metric)
   ```

#### Reducing Cardinality

1. **Avoid high-cardinality labels**
   ```yaml
   # Bad - unique IDs create millions of series
   labels:
     user_id: "12345"
   
   # Good - use fixed categories
   labels:
     user_type: "premium"
   ```

2. **Use metric_relabel_configs to drop unnecessary labels**
   ```yaml
   metric_relabel_configs:
     - source_labels: [__name__]
       regex: 'go_.*'
       action: drop  # Drop Go runtime metrics if not needed
   ```

## Troubleshooting

### Issue: Prometheus Not Scraping Targets

**Symptoms:**
- Targets show as "DOWN" in Prometheus UI
- No data in Grafana dashboards

**Diagnosis:**
```bash
# Check target status
curl http://localhost:9090/api/v1/targets

# Check Prometheus logs
docker-compose logs prometheus | grep -i error

# Test scraping manually
curl http://node-exporter:9100/metrics
```

**Common Causes & Solutions:**

1. **Network connectivity**
   ```bash
   # Test from Prometheus container
   docker-compose exec prometheus wget -O- http://node-exporter:9100/metrics
   ```

2. **Firewall blocking ports**
   ```bash
   # Check if port is open
   telnet node-exporter 9100
   ```

3. **Wrong target configuration**
   ```bash
   # Verify config syntax
   docker-compose exec prometheus promtool check config /etc/prometheus/prometheus.yml
   ```

4. **Exporter not running**
   ```bash
   docker-compose ps node-exporter
   ```

### Issue: Alerts Not Firing

**Symptoms:**
- Conditions are met but no alert
- Alertmanager shows no active alerts

**Diagnosis:**
```bash
# Check alert rules
docker-compose exec prometheus promtool check rules /etc/prometheus/alert-rules.yml

# Query alert expression manually
curl -G 'http://localhost:9090/api/v1/query' \
  --data-urlencode 'query=up{job="node-exporter"} == 0'

# Check alerts in Prometheus
curl http://localhost:9090/api/v1/alerts | jq

# Check Alertmanager logs
docker-compose logs alertmanager
```

**Common Causes & Solutions:**

1. **Alert expression always false**
   - Test query in Prometheus UI
   - Verify labels match scrape config

2. **Duration threshold not met**
   - Check `for: 2m` in alert rule
   - Alert must be true for entire duration

3. **Alertmanager not receiving alerts**
   ```bash
   # Check Prometheus config
   grep -A 5 "alertmanagers:" configs/prometheus.yml
   
   # Test Alertmanager connectivity
   curl http://alertmanager:9093/-/healthy
   ```

### Issue: Too Many Alerts (Alert Fatigue)

**Symptoms:**
- Team ignoring alerts
- Alert channels flooded with notifications

**Diagnosis:**
```bash
# Count alerts by severity
curl -s http://localhost:9093/api/v2/alerts | jq 'group_by(.labels.severity) | map({severity: .[0].labels.severity, count: length})'

# Find most frequent alerts
curl -s http://localhost:9093/api/v2/alerts | jq 'group_by(.labels.alertname) | map({alert: .[0].labels.alertname, count: length}) | sort_by(.count) | reverse | .[:10]'
```

**Solutions:**

1. **Adjust thresholds**
   - Increase threshold (80% → 85%)
   - Increase duration (2m → 5m)

2. **Add inhibition rules**
   ```yaml
   # configs/alertmanager.yml
   inhibit_rules:
     - source_match:
         severity: critical
       target_match:
         severity: warning
       equal: [alertname, instance]
   ```

3. **Improve alert grouping**
   ```yaml
   route:
     group_by: [alertname, cluster, service]
     group_wait: 1m  # Increase from 30s
   ```

4. **Remove noisy alerts**
   - Delete unnecessary alert rules
   - Convert to recording rules for dashboards instead

### Issue: High Prometheus Memory Usage

**Symptoms:**
- Prometheus container using >4GB RAM
- OOMKilled by Docker

**Diagnosis:**
```bash
# Check memory usage
docker stats prometheus

# Check number of time series
curl http://localhost:9090/api/v1/status/tsdb | jq

# Check cardinality by metric
curl http://localhost:9090/api/v1/label/__name__/values | jq '.data[]' | while read metric; do
  echo -n "$metric: "
  curl -s -G 'http://localhost:9090/api/v1/query' --data-urlencode "query=count($metric)" | jq -r '.data.result[0].value[1]'
done | sort -t: -k2 -nr | head -20
```

**Solutions:**

1. **Reduce retention**
   ```yaml
   # docker-compose.yml
   command:
     - '--storage.tsdb.retention.time=7d'  # Reduce from 15d
   ```

2. **Increase memory limit**
   ```yaml
   # docker-compose.yml
   prometheus:
     deploy:
       resources:
         limits:
           memory: 8G
   ```

3. **Drop unnecessary metrics**
   ```yaml
   # configs/prometheus.yml
   metric_relabel_configs:
     - source_labels: [__name__]
       regex: 'unused_metric_.*'
       action: drop
   ```

4. **Enable remote write and reduce local retention**
   ```yaml
   remote_write:
     - url: http://thanos-receiver:19291/api/v1/receive
   ```

### Issue: Grafana Dashboard Not Loading

**Symptoms:**
- "No data" in panels
- Slow dashboard load times

**Diagnosis:**
```bash
# Check Grafana logs
docker-compose logs grafana | grep -i error

# Test data source from Grafana container
docker-compose exec grafana curl http://prometheus:9090/-/healthy

# Check query performance in Prometheus
curl -G 'http://localhost:9090/api/v1/query' \
  --data-urlencode 'query=rate(http_requests_total[5m])' \
  -w "\nTime: %{time_total}s\n"
```

**Solutions:**

1. **Verify data source configuration**
   - Go to Configuration → Data Sources
   - Test and Save

2. **Optimize queries**
   - Reduce time range
   - Increase step interval
   - Use recording rules

3. **Check for browser issues**
   - Clear browser cache
   - Try incognito mode
   - Check browser console for errors

### Getting Help

**Resources:**
- Prometheus Documentation: https://prometheus.io/docs/
- Grafana Documentation: https://grafana.com/docs/
- Alertmanager Documentation: https://prometheus.io/docs/alerting/latest/alertmanager/

**Support Channels:**
- Internal: #monitoring-support (Slack)
- On-call: PagerDuty
- Email: devops-team@example.com

---

## Appendix

### Useful PromQL Queries

```promql
# Top 10 metrics by cardinality
topk(10, count by (__name__)({__name__=~".+"}))

# Scrape duration percentiles
histogram_quantile(0.99, rate(prometheus_target_interval_length_seconds_bucket[5m]))

# Memory usage by job
sum by (job) (up * process_resident_memory_bytes)

# Alert firing rate
rate(alertmanager_alerts_received_total[5m])
```

### Grafana Dashboard IDs

Recommended dashboards from https://grafana.com/grafana/dashboards/

- **1860**: Node Exporter Full
- **3662**: Prometheus 2.0 Stats
- **9578**: Alertmanager
- **7587**: Kubernetes Cluster Monitoring
- **6417**: Kubernetes Deployment Stats
- **9628**: PostgreSQL Database
- **11835**: Redis Dashboard

### Prometheus Exporters

Additional exporters to consider:

- **MySQL Exporter**: https://github.com/prometheus/mysqld_exporter
- **MongoDB Exporter**: https://github.com/percona/mongodb_exporter
- **Elasticsearch Exporter**: https://github.com/prometheus-community/elasticsearch_exporter
- **Kafka Exporter**: https://github.com/danielqsj/kafka_exporter
- **HAProxy Exporter**: https://github.com/prometheus/haproxy_exporter
- **SNMP Exporter**: https://github.com/prometheus/snmp_exporter

---

**Last Updated**: November 2024  
**Maintainer**: DevOps Team  
**Contact**: devops@example.com