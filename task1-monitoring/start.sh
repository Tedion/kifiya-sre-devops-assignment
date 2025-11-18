#!/bin/bash

# Monitoring Stack Quick Start Script
# This script sets up and manages the monitoring infrastructure

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_header() {
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}================================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        exit 1
    fi
    print_success "Docker is installed"
    
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        print_error "Docker Compose is not installed"
        exit 1
    fi
    print_success "Docker Compose is installed"
    
    # Check if ports are available
    for port in 9090 9093 3000 9100 9115; do
        if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
            print_warning "Port $port is already in use"
        else
            print_success "Port $port is available"
        fi
    done
}

create_env_file() {
    if [ ! -f .env ]; then
        print_header "Creating .env file"
        cat > .env << 'EOF'
# Grafana Configuration
GRAFANA_ADMIN_PASSWORD=admin123

# Alertmanager Configuration
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/WEBHOOK/URL
PAGERDUTY_SERVICE_KEY=your_pagerduty_key_here
EMAIL_FROM=alerts@example.com
EMAIL_TO=devops-team@example.com
SMTP_HOST=smtp.example.com
SMTP_PORT=587
SMTP_USERNAME=alerts@example.com
SMTP_PASSWORD=your_smtp_password_here

# Environment
ENVIRONMENT=production
CLUSTER_NAME=main-cluster
EOF
        print_success "Created .env file (please update with actual credentials)"
    else
        print_warning ".env file already exists"
    fi
}

start_stack() {
    print_header "Starting Monitoring Stack"
    
    # Validate configurations
    print_warning "Validating Prometheus configuration..."
    docker run --rm -v $(pwd)/configs/prometheus.yml:/prometheus.yml prom/prometheus:latest \
        promtool check config /prometheus.yml
    
    print_warning "Validating alert rules..."
    docker run --rm -v $(pwd)/configs/alert-rules.yml:/alert-rules.yml prom/prometheus:latest \
        promtool check rules /alert-rules.yml
    
    # Start services
    print_success "Configuration validated!"
    docker-compose up -d
    
    print_success "Monitoring stack is starting..."
    sleep 5
    
    # Check health
    print_warning "Checking service health..."
    docker-compose ps
}

stop_stack() {
    print_header "Stopping Monitoring Stack"
    docker-compose down
    print_success "Stack stopped"
}

restart_stack() {
    print_header "Restarting Monitoring Stack"
    docker-compose restart
    print_success "Stack restarted"
}

view_logs() {
    print_header "Viewing Logs"
    docker-compose logs -f $1
}

show_status() {
    print_header "Monitoring Stack Status"
    docker-compose ps
    echo ""
    print_header "Service URLs"
    echo -e "Prometheus:    ${GREEN}http://localhost:9090${NC}"
    echo -e "Alertmanager:  ${GREEN}http://localhost:9093${NC}"
    echo -e "Grafana:       ${GREEN}http://localhost:3000${NC} (admin/admin123)"
    echo -e "Node Exporter: ${GREEN}http://localhost:9100/metrics${NC}"
    echo -e "Blackbox:      ${GREEN}http://localhost:9115${NC}"
}

backup_data() {
    print_header "Backing up Monitoring Data"
    BACKUP_DIR="backups/$(date +%Y%m%d_%H%M%S)"
    mkdir -p $BACKUP_DIR
    
    docker-compose exec -T prometheus tar czf - /prometheus > $BACKUP_DIR/prometheus-data.tar.gz
    docker-compose exec -T grafana tar czf - /var/lib/grafana > $BACKUP_DIR/grafana-data.tar.gz
    
    print_success "Backup created in $BACKUP_DIR"
}

import_dashboards() {
    print_header "Importing Grafana Dashboards"
    
    # Wait for Grafana to be ready
    until curl -s http://localhost:3000/api/health > /dev/null; do
        echo "Waiting for Grafana..."
        sleep 2
    done
    
    # Import recommended dashboards
    DASHBOARDS=(1860 3662 9578 7587)
    for dashboard_id in "${DASHBOARDS[@]}"; do
        echo "Importing dashboard $dashboard_id..."
        curl -X POST http://admin:admin123@localhost:3000/api/dashboards/import \
            -H "Content-Type: application/json" \
            -d "{\"dashboard\":{\"id\":$dashboard_id,\"version\":1},\"overwrite\":true}" \
            2>/dev/null && print_success "Dashboard $dashboard_id imported" || print_warning "Failed to import $dashboard_id"
    done
}

test_alerts() {
    print_header "Testing Alerting System"
    
    # Stop node-exporter to trigger NodeDown alert
    print_warning "Stopping node-exporter to trigger alert..."
    docker-compose stop node-exporter
    
    echo "Wait 2-3 minutes and check:"
    echo "1. Prometheus: http://localhost:9090/alerts"
    echo "2. Alertmanager: http://localhost:9093"
    echo ""
    read -p "Press Enter to restart node-exporter..."
    
    docker-compose start node-exporter
    print_success "Node exporter restarted"
}

cleanup() {
    print_header "Cleaning Up"
    read -p "This will remove all containers and volumes. Continue? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker-compose down -v
        print_success "Cleanup complete"
    else
        print_warning "Cleanup cancelled"
    fi
}

show_help() {
    cat << EOF
Monitoring Stack Management Script

Usage: $0 [COMMAND]

Commands:
    start           Start the monitoring stack
    stop            Stop the monitoring stack
    restart         Restart the monitoring stack
    status          Show status and service URLs
    logs [service]  View logs (optional: specify service)
    backup          Backup Prometheus and Grafana data
    dashboards      Import recommended Grafana dashboards
    test-alerts     Test the alerting system
    cleanup         Remove all containers and volumes
    help            Show this help message

Examples:
    $0 start                 # Start all services
    $0 logs prometheus       # View Prometheus logs
    $0 test-alerts          # Test alerting workflow
    $0 status               # Show service status

EOF
}

# Main script
main() {
    case "${1:-help}" in
        start)
            check_prerequisites
            create_env_file
            start_stack
            show_status
            ;;
        stop)
            stop_stack
            ;;
        restart)
            restart_stack
            ;;
        status)
            show_status
            ;;
        logs)
            view_logs $2
            ;;
        backup)
            backup_data
            ;;
        dashboards)
            import_dashboards
            ;;
        test-alerts)
            test_alerts
            ;;
        cleanup)
            cleanup
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_error "Unknown command: $1"
            show_help
            exit 1
            ;;
    esac
}

main "$@"