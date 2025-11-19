# Task 1: Monitoring & Alerting

Prometheus, Grafana, Alertmanager and exporters packaged as a ready-to-run observability stack for the Kifiya SRE/DevOps assignment. The design favors fast setup, opinionated alerting, and simple day‑2 operations. Architecture and data flow: [architecture-diagram.png](./architecture-diagram.png).

## Stack At A Glance

- `Prometheus` (9090) + recording/alert rules for infra + app SLOs
- `Grafana` (3000) with auto-provisioned datasources/dashboards
- `Alertmanager` (9093) with severity-based routes and inhibitions
- `Node Exporter` (9100) and `Blackbox Exporter` (9115) targets
- Sample app (8080) to demo HTTP metrics + synthetic probes

## Run It

| Action | Command |
| --- | --- |
| Start stack (validation + health checks) | `./start.sh start` |
| Status + URLs | `./start.sh status` |
| Tail logs (all or service) | `./start.sh logs [name]` |
| Import curated dashboards | `./start.sh dashboards` |
| Backup data volumes | `./start.sh backup` |
| Stop / restart / nuke | `./start.sh stop|restart|cleanup` |

Direct Docker Compose alternative:
```bash
docker-compose up -d
docker-compose ps
docker-compose down
```

## URLs & Defaults

| Service | URL | Notes |
| --- | --- | --- |
| Prometheus | http://localhost:9090 | reload via `/-/reload` |
| Grafana | http://localhost:3000 | `admin / admin123` (change in prod) |
| Alertmanager | http://localhost:9093 | webhook secrets live in `.env` |
| Node Exporter | http://localhost:9100/metrics | host stats |
| Blackbox Exporter | http://localhost:9115 | HTTP/TCP/ICMP probes |

## Key Config Highlights (`configs/`)

- `prometheus.yml`: 15s scrape + evaluation, 15‑day retention, env labels, static + blackbox targets.
- `alertrules.yml`: 25 rules split into Critical (NodeDown, APIEndpointDown, DiskSpaceCritical, etc.) vs Warning (HighCPUUsage, Latency, ReplicationLag).
- `recordingrules.yml`: 40+ rollups for CPU, memory, disk, network plus SLI/SLO helpers.
- `alertmanager.yml`: severity routes, cluster/service grouping, 15‑min Critical + 60‑min Warning repeats, inhibition to avoid storms.
- `grafanadatasource.yml` & `blackbox.yml`: auto-datasources plus HTTP/TCP/ICMP probe templates.

## Grafana Dashboards

Scripted import grabs these IDs from Grafana.com and wires datasources automatically: `1860` Node Exporter Full, `3662` Prometheus Stats, `9578` Alertmanager, `7587` Blackbox. Run `./start.sh dashboards` or import manually through the UI.

## Daily Ops Cheat Sheet

- Check health: `./start.sh status`
- Prometheus API quick checks: `curl http://localhost:9090/api/v1/{targets,alerts,rules}`
- Alert noise test: `./start.sh test-alerts`
- Reload configs: `curl -XPOST http://localhost:9090/-/reload`
- Reset environment: `./start.sh cleanup && ./start.sh start`

## Troubleshooting Fast Path

| Symptom | What to try |
| --- | --- |
| Containers won’t start | `docker info`, `./start.sh logs`, ensure ports 3000/9090/9093/9100/9115 free |
| Alerts missing | `curl http://localhost:9090/api/v1/rules`, check Alertmanager `/api/v2/alerts` |
| Metrics absent | Inspect Prometheus `/targets`, verify scrape configs, confirm exporter container |
| Grafana blank | `./start.sh dashboards`, list datasources via `/api/datasources` |

## Notes

- Default creds and webhook secrets must be rotated for real environments.
- All config mounts are read-only and run on an isolated Docker network.
- Resource profile: Prometheus ~200 MB RAM, Grafana ~100 MB, rest <60 MB each.
- Created by the Kifiya SRE/DevOps team, updated November 2025.
