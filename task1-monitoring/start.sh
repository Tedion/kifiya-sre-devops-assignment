# Task 1: Monitoring & Alerting System

## Overview

Complete production-ready monitoring stack using Prometheus, Grafana, and Alertmanager for infrastructure and application monitoring with automated alerting and comprehensive observability.

## Architecture

See [architecture-diagram.png](./architecture-diagram.png) for complete system architecture and data flow.

## Components

- **Prometheus** (9090): Metrics collection, storage, and alerting engine
- **Grafana** (3000): Visualization dashboards and analytics
- **Alertmanager** (9093): Alert routing, grouping, and notifications
- **Node Exporter** (9100): System-level metrics (CPU, memory, disk, network)
- **Blackbox Exporter** (9115): Endpoint availability and response time monitoring
- **Sample Application** (8080): Demo application for testing monitoring

## Quick Start

### Option 1: Using Management Script (Recommended)
```bash
# Start the entire monitoring stack
./start.sh start

# View service status and URLs
./start.sh status

# Import Grafana dashboards automatically
./start.sh dashboards

# View logs
./start.sh logs

# Stop services
./start.sh stop
```

### Option 2: Using Docker Compose Directly
```bash
# Start all services
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

## Access Services

| Service | URL | Credentials |
|---------|-----|-------------|
| Prometheus | http://localhost:9090 | None |
| Grafana | http://localhost:3000 | admin / admin123 |
| Alertmanager | http://localhost:9093 | None |
| Node Exporter | http://localhost:9100/metrics | None |
| Blackbox Exporter | http://localhost:9115 | None |

## Management Script Commands

The `start.sh` script provides comprehensive stack management:

| Command | Description |
|---------|-------------|
| `./start.sh start` | Start all services with configuration validation |
| `./start.sh stop` | Stop all services |
| `./start.sh restart` | Restart all running services |
| `./start.sh status` | Display service status and access URLs |
| `./start.sh logs [service]` | View logs (all services or specific service) |
| `./start.sh backup` | Backup Prometheus and Grafana data |
| `./start.sh dashboards` | Auto-import recommended Grafana dashboards |
| `./start.sh test-alerts` | Test alerting system (triggers NodeDown alert) |
| `./start.sh cleanup` | Remove all containers, networks, and volumes |
| `./start.sh help` | Display help information |

### Usage Examples
```bash
# Start with automatic validation
./start.sh start

# View Prometheus logs
./start.sh logs prometheus

# View Grafana logs
./start.sh logs grafana

# Check everything is running
./start.sh status

# Backup all monitoring data
./start.sh backup

# Test the alerting workflow
./start.sh test-alerts
```

## Configuration Files

### configs/prometheus.yml
Main Prometheus configuration with:
- **Scrape interval:** 15s (default), 30s (infrastructure)
- **Evaluation interval:** 15s for alert rules
- **Data retention:** 15 days
- **External labels:** cluster, environment, region
- **Scrape targets:** prometheus, node-exporter, blackbox-http, and more

### configs/alertrules.yml
Production-ready alert rules:
- **25 alert rules** covering infrastructure and application monitoring
- **Critical (P0):** NodeDown, CriticalCPUUsage, CriticalMemoryUsage, DiskSpaceCritical, ServiceDown, APIEndpointDown
- **Warning (P1):** HighCPUUsage, HighMemoryUsage, DiskSpaceLow, HighLatency, ReplicationLag

### configs/recordingrules.yml
Pre-computed metrics for performance:
- **42 recording rules** for faster queries and dashboard performance
- Aggregated metrics for CPU, memory, disk, and network
- Application-level SLI/SLO calculations

### configs/alertmanager.yml
Alert routing configuration:
- Severity-based routing (Critical vs Warning)
- Alert grouping by cluster and service
- Configurable repeat intervals
- Inhibition rules to prevent alert storms
- **Critical alerts:** 15-minute repeat interval
- **Warning alerts:** 1-hour repeat interval

### configs/grafanadatasource.yml
Auto-provisioned datasources:
- Prometheus datasource (default)
- Alertmanager datasource for alert visualization
- Configured on Grafana startup

### configs/blackbox.yml
Endpoint monitoring configuration:
- HTTP/HTTPS probes (http_2xx module)
- TCP connectivity checks
- ICMP ping tests
- Configurable timeouts and validation

## Alert Thresholds

| Alert | Threshold | Duration | Severity |
|-------|-----------|----------|----------|
| NodeDown | up == 0 | 2 min | Critical |
| CriticalCPUUsage | >95% | 2 min | Critical |
| HighCPUUsage | >80% | 5 min | Warning |
| CriticalMemoryUsage | >95% | 2 min | Critical |
| HighMemoryUsage | >85% | 5 min | Warning |
| DiskSpaceCritical | <10% free | 2 min | Critical |
| DiskSpaceLow | <20% free | 5 min | Warning |
| APIEndpointDown | probe_success == 0 | 2 min | Critical |

## Grafana Dashboards

Datasources are automatically provisioned on startup. Import recommended community dashboards:

| Dashboard ID | Name | Description |
|--------------|------|-------------|
| 1860 | Node Exporter Full | Comprehensive system metrics and resource utilization |
| 3662 | Prometheus 2.0 Stats | Prometheus performance and internal metrics |
| 9578 | Alertmanager | Alert overview and notification status |
| 7587 | Blackbox Exporter | Endpoint monitoring and availability metrics |

### Auto-Import Using Script
```bash
./start.sh dashboards
```

The script will:
1. Wait for Grafana to be ready
2. Get the Prometheus datasource UID
3. Download dashboards from Grafana.com
4. Configure datasource mappings
5. Import all dashboards automatically

### Manual Import

1. Navigate to http://localhost:3000
2. Go to **Dashboards → Import**
3. Enter Dashboard ID (e.g., `1860`)
4. Click **Load**
5. Select **Prometheus** as datasource
6. Click **Import**

## Design Decisions

### Architecture Choices

**Pull-Based Monitoring:** Prometheus scrapes metrics from targets, providing better control, security, and resilience compared to push-based systems.

**Multi-Layer Alerting:** Dual severity levels (Critical/Warning) with different notification strategies ensure appropriate response times.

**Service Mesh Ready:** Configuration supports both static targets and Kubernetes service discovery for scalability.

### Performance Tuning

**Scrape Intervals:**
- 15s for application metrics (sub-minute alerting)
- 30s for infrastructure metrics (resource optimization)
- Balances data granularity with storage efficiency

**Data Retention:**
- 15 days local storage for recent data
- Configurable remote write for long-term storage
- TSDB compression for efficient storage

### Threshold Rationale

**CPU Thresholds:**
- Warning at 80%: Provides 15-20% headroom for traffic spikes
- Critical at 95%: Immediate intervention required

**Memory Thresholds:**
- Warning at 85%: Accounts for Linux filesystem cache
- Critical at 95%: Prevents OOM conditions

**Disk Space:**
- Warning at 20%: Time for capacity planning
- Critical at 10%: Immediate action required

## Common Operations

### Service Management
```bash
# Start everything
./start.sh start

# Check service health
./start.sh status

# View all logs in real-time
./start.sh logs

# View specific service logs
./start.sh logs prometheus
./start.sh logs grafana
./start.sh logs alertmanager

# Restart all services
./start.sh restart

# Stop all services
./start.sh stop
```

### Prometheus Operations
```bash
# Reload configuration without restart
curl -X POST http://localhost:9090/-/reload

# Check configuration status
curl http://localhost:9090/api/v1/status/config

# View all targets
curl http://localhost:9090/api/v1/targets

# Check active alerts
curl http://localhost:9090/api/v1/alerts

# Query metrics
curl 'http://localhost:9090/api/v1/query?query=up'
```

### Alertmanager Operations
```bash
# View all active alerts
curl http://localhost:9093/api/v2/alerts

# Check Alertmanager status
curl http://localhost:9093/api/v2/status

# Silence an alert (example)
curl -X POST http://localhost:9093/api/v2/silences \
  -H "Content-Type: application/json" \
  -d '{"matchers":[{"name":"alertname","value":"HighCPUUsage","isRegex":false}],"startsAt":"2024-11-19T00:00:00Z","endsAt":"2024-11-20T00:00:00Z","createdBy":"admin","comment":"Planned maintenance"}'
```

### Grafana Operations
```bash
# Check datasources
curl -s -u admin:admin123 http://localhost:3000/api/datasources | jq

# List all dashboards
curl -s -u admin:admin123 http://localhost:3000/api/search | jq

# Check Grafana health
curl http://localhost:3000/api/health
```

### Data Backup
```bash
# Backup Prometheus and Grafana data
./start.sh backup

# Backups are stored in: backups/YYYYMMDD_HHMMSS/
# - prometheus-data.tar.gz
# - grafana-data.tar.gz
```

## Troubleshooting

### Services Won't Start
```bash
# Check port availability
./start.sh start
# Script automatically checks ports 9090, 9093, 3000, 9100, 9115

# View service logs for errors
./start.sh logs

# Check Docker daemon
docker info

# Restart services
./start.sh restart
```

### Configuration Errors
```bash
# Validate Prometheus config manually
docker run --rm -v $(pwd)/configs/prometheus.yml:/prometheus.yml \
  prom/prometheus:latest \
  promtool check config /prometheus.yml

# Validate alert rules
docker run --rm -v $(pwd)/configs/alertrules.yml:/alertrules.yml \
  prom/prometheus:latest \
  promtool check rules /alertrules.yml
```

### Metrics Not Appearing
```bash
# Check Prometheus targets
curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'

# Verify scrape configs in Prometheus UI
open http://localhost:9090/targets

# Check service discovery
curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.health != "up")'
```

### Grafana Datasource Issues
```bash
# Verify datasources are configured
curl -s -u admin:admin123 http://localhost:3000/api/datasources | jq '.[].name'

# Test Prometheus connectivity from Grafana
curl -s -u admin:admin123 http://localhost:3000/api/datasources/proxy/1/api/v1/query?query=up

# Re-import dashboards
./start.sh dashboards
```

### Alert Not Firing
```bash
# Check alert rules are loaded
curl http://localhost:9090/api/v1/rules | jq '.data.groups[].name'

# View alert status
open http://localhost:9090/alerts

# Check Alertmanager is receiving alerts
curl http://localhost:9093/api/v2/alerts | jq
```

### Complete Reset
```bash
# Remove everything and start fresh
./start.sh cleanup
./start.sh start
./start.sh dashboards
```

## Metrics Collected

### System Metrics (Node Exporter)

- **CPU:** Usage by core, mode (user, system, idle, iowait)
- **Memory:** Total, available, used, cached, buffers
- **Disk:** Space usage, I/O operations, read/write bytes
- **Network:** Traffic (bytes in/out), packets, errors, drops
- **System:** Load average, uptime, processes, file descriptors

### Application Metrics

- **HTTP:** Request rate, latency (p50, p95, p99), status codes
- **Errors:** 4xx and 5xx error rates
- **Availability:** Service uptime and health check results
- **Custom:** Business metrics exposed via /metrics endpoint

### Endpoint Monitoring (Blackbox)

- **Availability:** HTTP/HTTPS endpoint reachability
- **Response Time:** DNS, TCP, TLS, and HTTP phases
- **SSL Certificates:** Expiry monitoring
- **Status Codes:** HTTP response validation

## Project Structure
```
task1-monitoring/
├── architecture-diagram.png         # System architecture diagram
├── configs/
│   ├── prometheus.yml              # Prometheus main configuration
│   ├── alertrules.yml              # Alert rules (25 rules)
│   ├── recordingrules.yml          # Recording rules (42 rules)
│   ├── alertmanager.yml            # Alertmanager routing config
│   ├── grafanadatasource.yml       # Grafana datasource provisioning
│   └── blackbox.yml                # Blackbox exporter config
├── docker-compose.yml              # Container orchestration
├── start.sh                        # Management script
├── .env                            # Environment variables (auto-generated)
├── .gitignore                      # Git ignore rules
└── README.md                       # This file
```

## Security Considerations

- Default Grafana credentials should be changed in production
- Alertmanager webhook URLs stored in `.env` file (not committed)
- All configuration files mounted read-only
- Network isolation via Docker bridge network
- Health checks enabled for all critical services

## Performance Metrics

### Resource Usage

- **Prometheus:** ~200MB RAM, 1-2% CPU (15s scrape interval)
- **Grafana:** ~100MB RAM, 1% CPU
- **Alertmanager:** ~50MB RAM, <1% CPU
- **Node Exporter:** ~20MB RAM, <1% CPU
- **Blackbox Exporter:** ~15MB RAM, <1% CPU

### Storage

- **TSDB Storage:** ~1GB per day (depends on cardinality)
- **Retention:** 15 days = ~15GB
- **Compression:** Prometheus TSDB automatically compresses old data

## Documentation & Resources

### Official Documentation
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [PromQL Guide](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Alertmanager Guide](https://prometheus.io/docs/alerting/latest/alertmanager/)

### Component Documentation
- [Node Exporter Metrics](https://github.com/prometheus/node_exporter)
- [Blackbox Exporter](https://github.com/prometheus/blackbox_exporter)
- [Grafana Dashboards](https://grafana.com/grafana/dashboards/)

### Best Practices
- [Prometheus Best Practices](https://prometheus.io/docs/practices/)
- [Metric and Label Naming](https://prometheus.io/docs/practices/naming/)
- [Alerting Best Practices](https://prometheus.io/docs/practices/alerting/)

## Contributing

This monitoring stack was created for the Kifiya SRE/DevOps take-home assignment. Improvements and suggestions are welcome.

---

**Status:** Production-Ready ✅  
**Technologies:** Prometheus 2.48+, Grafana 10.2+, Alertmanager 0.26+  
**Created for:** Kifiya SRE/DevOps Assignment  
**Task:** Monitoring, Observability & Alerting  
**Author:** Teddy Abera  
**Last Updated:** November 2025
