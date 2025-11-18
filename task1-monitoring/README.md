# Task 1: Monitoring & Alerting System

## Overview

Complete monitoring stack using Prometheus, Grafana, and Alertmanager for infrastructure and application monitoring with automated alerting.

## Architecture

See [architecturediagram.png](./architecturediagram.png) for system architecture.

## Components

- **Prometheus** (9090): Metrics collection and alerting engine
- **Grafana** (3000): Visualization and dashboards
- **Alertmanager** (9093): Alert routing and notifications
- **Node Exporter** (9100): System metrics (CPU, memory, disk)
- **Blackbox Exporter** (9115): Endpoint availability monitoring

## Quick Start
```bash
docker-compose up -d
```

**Access Services:**
- Prometheus: http://localhost:9090
- Grafana: http://localhost:3000 (admin/admin123)
- Alertmanager: http://localhost:9093

## Configuration Files

### configs/prometheus.yml
Prometheus configuration with scrape targets and evaluation rules.

### configs/grafanadatasource.yml
Auto-provisions Prometheus and Alertmanager datasources in Grafana.

### configs/alertrules.yml
Production-ready alert rules covering:
- **Critical (P0):** NodeDown, CriticalCPUUsage, CriticalMemoryUsage, DiskSpaceCritical, ServiceDown
- **Warning (P1):** HighCPUUsage, HighMemoryUsage, DiskSpaceLow, APIEndpointDown

### configs/alertmanager.yml
Alert routing configuration with severity-based escalation.

## Alert Thresholds

| Alert | Threshold | Duration | Severity |
|-------|-----------|----------|----------|
| NodeDown | up == 0 | 2 min | Critical |
| CriticalCPUUsage | >95% | 2 min | Critical |
| HighCPUUsage | >80% | 5 min | Warning |
| CriticalMemoryUsage | >95% | 2 min | Critical |
| HighMemoryUsage | >85% | 5 min | Warning |
| DiskSpaceCritical | <10% | 2 min | Critical |
| DiskSpaceLow | <20% | 5 min | Warning |
| APIEndpointDown | probe_success == 0 | 2 min | Critical |

## Grafana Dashboards

Datasources are auto-configured. Import recommended dashboards:

| ID | Name | Description |
|----|------|-------------|
| 1860 | Node Exporter Full | Comprehensive system metrics |
| 3662 | Prometheus Stats | Prometheus performance |
| 9578 | Alertmanager | Alert overview |

**Import Steps:**
1. Go to Dashboards → Import
2. Enter Dashboard ID
3. Select Prometheus datasource
4. Click Import

## Design Decisions

**Pull-based Architecture:** Prometheus scrapes metrics for better control and resilience.

**15-second Scrape Interval:** Balances granularity with resource usage, enables sub-2-minute alerting.

**Severity Levels:**
- Critical (P0): Immediate impact, requires instant action
- Warning (P1): Degraded performance, investigate soon

**Threshold Rationale:**
- CPU >80%: Provides headroom for traffic spikes
- Memory >85%: Accounts for Linux cache usage
- Disk <20%: Time for capacity planning before critical

## Common Operations
```bash
# View logs
docker-compose logs -f prometheus

# Reload Prometheus config
curl -X POST http://localhost:9090/-/reload

# Check targets
curl http://localhost:9090/api/v1/targets

# Check active alerts
curl http://localhost:9093/api/v2/alerts

# Restart services
docker-compose restart

# Stop all services
docker-compose down
```

## Documentation

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [PromQL Guide](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Alertmanager Guide](https://prometheus.io/docs/alerting/latest/alertmanager/)

---

**Status:** Production-ready  
**Technologies:** Prometheus 2.45+, Grafana 10.0+, Alertmanager 0.26+

Created for: Kifiya SRE/DevOps Assignment
Task: Monitoring, Observability & Alerting
Last Updated: November 2025
