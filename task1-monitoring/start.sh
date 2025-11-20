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
    
    # Check if Docker daemon is running
    if ! docker info > /dev/null 2>&1; then
        print_error "Docker daemon is not running"
        exit 1
    fi
    print_success "Docker daemon is running"
    
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

    # Validate with all files mounted
    print_warning "Validating Prometheus configuration..."
    docker run --rm --entrypoint promtool \
        -v $(pwd)/configs/prometheus.yml:/etc/prometheus/prometheus.yml:ro \
        -v $(pwd)/configs/alertrules.yml:/etc/prometheus/alertrules.yml:ro \
        -v $(pwd)/configs/recordingrules.yml:/etc/prometheus/recordingrules.yml:ro \
        prom/prometheus:latest \
        check config /etc/prometheus/prometheus.yml
    
    # Start services
    print_success "Configuration validated!"
    echo ""
    print_warning "Starting services..."
    docker-compose up -d
    
    print_success "Monitoring stack is starting..."
    sleep 10
    
    # Check health
    echo ""
    print_warning "Checking service health..."
    docker-compose ps
    
    echo ""
    print_success "All services started successfully!"
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
    echo ""
    
    # Check Grafana datasources
    print_warning "Checking Grafana datasources..."
    sleep 2
    datasource_count=$(curl -s -u admin:admin123 http://localhost:3000/api/datasources 2>/dev/null | jq '. | length' 2>/dev/null || echo "0")
    if [ "$datasource_count" -gt 0 ]; then
        print_success "Grafana datasources configured: $datasource_count"
    else
        print_warning "Grafana datasources not detected (may still be starting)"
    fi
}

backup_data() {
    print_header "Backing up Monitoring Data"
    BACKUP_DIR="backups/$(date +%Y%m%d_%H%M%S)"
    mkdir -p $BACKUP_DIR
    
    print_warning "Backing up Prometheus data..."
    docker-compose exec -T prometheus tar czf - /prometheus > $BACKUP_DIR/prometheus-data.tar.gz
    
    print_warning "Backing up Grafana data..."
    docker-compose exec -T grafana tar czf - /var/lib/grafana > $BACKUP_DIR/grafana-data.tar.gz
    
    print_success "Backup created in $BACKUP_DIR"
    ls -lh $BACKUP_DIR
}

import_dashboards() {
    print_header "Importing Grafana Dashboards"
    
    # Wait for Grafana to be ready
    print_warning "Waiting for Grafana to be ready..."
    until curl -s http://localhost:3000/api/health > /dev/null 2>&1; do
        echo "  Waiting..."
        sleep 2
    done
    print_success "Grafana is ready!"
    
    echo ""
    
    # Get Prometheus datasource UID
    print_warning "Getting Prometheus datasource UID..."
    DATASOURCE_UID=$(curl -s -u admin:admin123 http://localhost:3000/api/datasources/name/Prometheus 2>/dev/null | jq -r '.uid' 2>/dev/null)
    
    if [ -z "$DATASOURCE_UID" ] || [ "$DATASOURCE_UID" == "null" ]; then
        print_error "Could not find Prometheus datasource"
        echo "Please ensure Grafana is fully started and datasources are provisioned"
        echo "You can import dashboards manually at: http://localhost:3000"
        return 1
    fi
    print_success "Found Prometheus datasource UID: $DATASOURCE_UID"
    
    echo ""
    print_warning "Importing dashboards from Grafana.com..."
    
    # Dashboard IDs and names
    declare -A DASHBOARDS=(
        ["1860"]="Node Exporter Full"
        ["3662"]="Prometheus 2.0 Stats"
        ["9578"]="Alertmanager"
        ["7587"]="Blackbox Exporter"
    )
    
    for dashboard_id in "${!DASHBOARDS[@]}"; do
        dashboard_name="${DASHBOARDS[$dashboard_id]}"
        echo ""
        echo "Importing: $dashboard_name (ID: $dashboard_id)"
        
        # Download dashboard JSON from Grafana.com
        print_warning "  Downloading..."
        dashboard_json=$(curl -s "https://grafana.com/api/dashboards/${dashboard_id}/revisions/latest/download" 2>/dev/null)
        
        if [ -z "$dashboard_json" ] || [ "$dashboard_json" == "null" ]; then
            print_error "  Failed to download"
            continue
        fi
        
        # Replace ALL datasource references with our Prometheus UID
        # This ensures it connects to our Prometheus, not Thanos or any other datasource
        dashboard_json=$(echo "$dashboard_json" | \
            sed "s/\${DS_PROMETHEUS}/$DATASOURCE_UID/g" | \
            sed "s/\${DS_THANOS}/$DATASOURCE_UID/g" | \
            sed "s/\"datasource\":\s*\"Prometheus\"/\"datasource\":\"$DATASOURCE_UID\"/g" | \
            sed "s/\"uid\":\s*\"prometheus\"/\"uid\":\"$DATASOURCE_UID\"/g" | \
            sed "s/\"uid\":\s*\"Prometheus\"/\"uid\":\"$DATASOURCE_UID\"/g")
        
        # Import to Grafana using correct API endpoint
        print_warning "  Importing..."
        response=$(curl -s -X POST \
            -H "Content-Type: application/json" \
            -u admin:admin123 \
            -d "{\"dashboard\":$dashboard_json,\"overwrite\":true,\"folderId\":0}" \
            http://localhost:3000/api/dashboards/db 2>&1)
        
        if echo "$response" | grep -q '"status":"success"'; then
            print_success "  ✓ Imported: $dashboard_name"
        else
            print_error "  ✗ Failed: $dashboard_name"
            # Show first 150 chars of error for debugging
            echo "  $(echo $response | head -c 150)"
        fi
    done
    
    echo ""
    print_success "Dashboard import completed!"
    echo ""
    echo "View dashboards: ${GREEN}http://localhost:3000/dashboards${NC}"
}

test_alerts() {
    print_header "Testing Alerting System"
    
    # Stop node-exporter to trigger NodeDown alert
    print_warning "Stopping node-exporter to trigger alert..."
    docker-compose stop node-exporter
    
    echo ""
    echo "Wait 2-3 minutes and check:"
    echo "1. Prometheus: ${GREEN}http://localhost:9090/alerts${NC}"
    echo "2. Alertmanager: ${GREEN}http://localhost:9093${NC}"
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
    $0 dashboards           # Import dashboards from Grafana.com
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
