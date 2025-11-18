#!/bin/bash

# Backup Script with Rotation and S3 Upload
# Usage: ./backup.sh [database|filesystem|config] [options]

set -euo pipefail

# Configuration
BACKUP_TYPE="${1:-database}"
S3_BUCKET="${S3_BUCKET:-backups-prod}"
S3_REGION="${S3_REGION:-us-east-1}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"
RETENTION_WEEKS="${RETENTION_WEEKS:-12}"
RETENTION_MONTHS="${RETENTION_MONTHS:-12}"
BACKUP_DIR="/var/backups"
LOG_FILE="/var/log/backup.log"
ENCRYPTION_KEY="${ENCRYPTION_KEY:-}"

# Logging function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Error handling
error_exit() {
    log "ERROR: $1"
    # Send alert (configure your alerting system)
    # curl -X POST https://hooks.slack.com/services/YOUR/WEBHOOK/URL -d "{\"text\":\"Backup failed: $1\"}"
    exit 1
}

# Cleanup function
cleanup() {
    if [ -n "${TEMP_DIR:-}" ] && [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}
trap cleanup EXIT

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Database backup function
backup_database() {
    local db_type="${DB_TYPE:-postgresql}"
    local db_name="${DB_NAME:-mydb}"
    local db_user="${DB_USER:-postgres}"
    local db_host="${DB_HOST:-localhost}"
    local full_backup="${FULL_BACKUP:-false}"
    
    TEMP_DIR=$(mktemp -d)
    TIMESTAMP=$(date +'%Y%m%d_%H%M%S')
    BACKUP_FILE="$TEMP_DIR/${db_name}_${TIMESTAMP}.sql"
    
    log "Starting database backup: $db_name"
    
    if [ "$db_type" == "postgresql" ]; then
        if [ "$full_backup" == "true" ]; then
            pg_dump -h "$db_host" -U "$db_user" -F c -f "${BACKUP_FILE}.dump" "$db_name" || error_exit "Database dump failed"
            BACKUP_FILE="${BACKUP_FILE}.dump"
        else
            # Incremental backup using WAL archiving (requires pg_basebackup setup)
            pg_basebackup -h "$db_host" -U "$db_user" -D "$TEMP_DIR/basebackup" -Ft -z -P || error_exit "Incremental backup failed"
            tar -czf "$BACKUP_FILE.tar.gz" -C "$TEMP_DIR" basebackup || error_exit "Compression failed"
            BACKUP_FILE="$BACKUP_FILE.tar.gz"
        fi
    elif [ "$db_type" == "mysql" ]; then
        mysqldump -h "$db_host" -u "$db_user" -p"${DB_PASSWORD}" "$db_name" > "$BACKUP_FILE" || error_exit "MySQL dump failed"
        gzip "$BACKUP_FILE" || error_exit "Compression failed"
        BACKUP_FILE="$BACKUP_FILE.gz"
    fi
    
    echo "$BACKUP_FILE"
}

# Filesystem backup function
backup_filesystem() {
    local source_path="${2:-/var/www}"
    local exclude_patterns="${EXCLUDE_PATTERNS:-*.log,*.tmp}"
    
    TEMP_DIR=$(mktemp -d)
    TIMESTAMP=$(date +'%Y%m%d_%H%M%S')
    BACKUP_NAME=$(basename "$source_path")
    BACKUP_FILE="$TEMP_DIR/${BACKUP_NAME}_${TIMESTAMP}.tar.gz"
    
    log "Starting filesystem backup: $source_path"
    
    # Create tar with exclusions
    IFS=',' read -ra EXCLUDES <<< "$exclude_patterns"
    EXCLUDE_ARGS=""
    for exclude in "${EXCLUDES[@]}"; do
        EXCLUDE_ARGS="$EXCLUDE_ARGS --exclude=$exclude"
    done
    
    tar -czf "$BACKUP_FILE" $EXCLUDE_ARGS -C "$(dirname "$source_path")" "$(basename "$source_path")" || error_exit "Filesystem backup failed"
    
    echo "$BACKUP_FILE"
}

# Config backup function
backup_config() {
    local config_paths="${CONFIG_PATHS:-/etc/nginx,/etc/ansible}"
    
    TEMP_DIR=$(mktemp -d)
    TIMESTAMP=$(date +'%Y%m%d_%H%M%S')
    BACKUP_FILE="$TEMP_DIR/config_${TIMESTAMP}.tar.gz"
    
    log "Starting config backup"
    
    IFS=',' read -ra PATHS <<< "$config_paths"
    tar -czf "$BACKUP_FILE" "${PATHS[@]}" || error_exit "Config backup failed"
    
    echo "$BACKUP_FILE"
}

# Encrypt backup
encrypt_backup() {
    local backup_file="$1"
    
    if [ -n "$ENCRYPTION_KEY" ]; then
        log "Encrypting backup"
        gpg --symmetric --cipher-algo AES256 --batch --passphrase "$ENCRYPTION_KEY" "$backup_file" || error_exit "Encryption failed"
        rm "$backup_file"
        echo "${backup_file}.gpg"
    else
        echo "$backup_file"
    fi
}

# Upload to S3
upload_to_s3() {
    local backup_file="$1"
    local s3_path="s3://${S3_BUCKET}/${BACKUP_TYPE}/$(basename "$backup_file")"
    
    log "Uploading to S3: $s3_path"
    
    aws s3 cp "$backup_file" "$s3_path" \
        --region "$S3_REGION" \
        --storage-class STANDARD_IA \
        --server-side-encryption AES256 \
        --metadata "backup-type=${BACKUP_TYPE},timestamp=$(date +%s)" || error_exit "S3 upload failed"
    
    log "Upload completed: $s3_path"
    echo "$s3_path"
}

# Rotate backups
rotate_backups() {
    log "Rotating old backups"
    
    # Delete backups older than retention period
    aws s3 ls "s3://${S3_BUCKET}/${BACKUP_TYPE}/" --region "$S3_REGION" | while read -r line; do
        backup_date=$(echo "$line" | awk '{print $1" "$2}')
        backup_name=$(echo "$line" | awk '{print $4}')
        
        if [ -n "$backup_name" ]; then
            backup_epoch=$(date -d "$backup_date" +%s 2>/dev/null || date -j -f "%Y-%m-%d %H:%M:%S" "$backup_date" +%s 2>/dev/null || echo "0")
            current_epoch=$(date +%s)
            age_days=$(( (current_epoch - backup_epoch) / 86400 ))
            
            # Apply retention policy based on backup type and age
            if [[ "$backup_name" == *"_daily_"* ]] && [ $age_days -gt $RETENTION_DAYS ]; then
                log "Deleting old daily backup: $backup_name (age: ${age_days} days)"
                aws s3 rm "s3://${S3_BUCKET}/${BACKUP_TYPE}/$backup_name" --region "$S3_REGION"
            elif [[ "$backup_name" == *"_weekly_"* ]] && [ $age_days -gt $((RETENTION_WEEKS * 7)) ]; then
                log "Deleting old weekly backup: $backup_name (age: ${age_days} days)"
                aws s3 rm "s3://${S3_BUCKET}/${BACKUP_TYPE}/$backup_name" --region "$S3_REGION"
            elif [[ "$backup_name" == *"_monthly_"* ]] && [ $age_days -gt $((RETENTION_MONTHS * 30)) ]; then
                log "Deleting old monthly backup: $backup_name (age: ${age_days} days)"
                aws s3 rm "s3://${S3_BUCKET}/${BACKUP_TYPE}/$backup_name" --region "$S3_REGION"
            fi
        fi
    done
    
    log "Backup rotation completed"
}

# Main execution
main() {
    log "=== Backup started: $BACKUP_TYPE ==="
    
    # Parse options
    FULL_BACKUP="false"
    while [[ $# -gt 0 ]]; do
        case $1 in
            --full)
                FULL_BACKUP="true"
                shift
                ;;
            *)
                shift
                ;;
        esac
    done
    
    # Perform backup based on type
    case "$BACKUP_TYPE" in
        database)
            BACKUP_FILE=$(backup_database)
            ;;
        filesystem)
            BACKUP_FILE=$(backup_filesystem "$@")
            ;;
        config)
            BACKUP_FILE=$(backup_config)
            ;;
        *)
            error_exit "Unknown backup type: $BACKUP_TYPE"
            ;;
    esac
    
    # Encrypt if key provided
    BACKUP_FILE=$(encrypt_backup "$BACKUP_FILE")
    
    # Upload to S3
    S3_PATH=$(upload_to_s3 "$BACKUP_FILE")
    
    # Rotate old backups
    rotate_backups
    
    # Calculate backup size
    BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    log "Backup size: $BACKUP_SIZE"
    
    log "=== Backup completed successfully ==="
    log "Backup location: $S3_PATH"
    
    # Send success notification (optional)
    # curl -X POST https://hooks.slack.com/services/YOUR/WEBHOOK/URL -d "{\"text\":\"Backup completed: $S3_PATH\"}"
    
    exit 0
}

main "$@"

