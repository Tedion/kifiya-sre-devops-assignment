#!/bin/bash

# Restore Script for Disaster Recovery
# Usage: ./restore.sh [database|filesystem|config] --backup-date YYYY-MM-DD [options]

set -euo pipefail

# Configuration
RESTORE_TYPE="${1:-database}"
S3_BUCKET="${S3_BUCKET:-backups-prod}"
S3_REGION="${S3_REGION:-us-east-1}"
BACKUP_DATE="${BACKUP_DATE:-}"
TARGET_HOST="${TARGET_HOST:-localhost}"
TARGET_PATH="${TARGET_PATH:-}"
LOG_FILE="/var/log/restore.log"
ENCRYPTION_KEY="${ENCRYPTION_KEY:-}"

# Logging function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Error handling
error_exit() {
    log "ERROR: $1"
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --backup-date)
            BACKUP_DATE="$2"
            shift 2
            ;;
        --target-host)
            TARGET_HOST="$2"
            shift 2
            ;;
        --target-path)
            TARGET_PATH="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

if [ -z "$BACKUP_DATE" ]; then
    error_exit "Backup date is required (--backup-date YYYY-MM-DD)"
fi

# Find backup file
find_backup() {
    local backup_pattern="${RESTORE_TYPE}_${BACKUP_DATE//-/_}*"
    log "Searching for backup: $backup_pattern"
    
    BACKUP_FILE=$(aws s3 ls "s3://${S3_BUCKET}/${RESTORE_TYPE}/" --region "$S3_REGION" | \
        grep "$backup_pattern" | \
        sort -r | \
        head -1 | \
        awk '{print $4}')
    
    if [ -z "$BACKUP_FILE" ]; then
        error_exit "Backup not found for date: $BACKUP_DATE"
    fi
    
    log "Found backup: $BACKUP_FILE"
    echo "$BACKUP_FILE"
}

# Download from S3
download_backup() {
    local backup_file="$1"
    local local_path="/tmp/$(basename "$backup_file")"
    
    log "Downloading backup from S3"
    aws s3 cp "s3://${S3_BUCKET}/${RESTORE_TYPE}/$backup_file" "$local_path" \
        --region "$S3_REGION" || error_exit "Download failed"
    
    echo "$local_path"
}

# Decrypt backup
decrypt_backup() {
    local backup_file="$1"
    
    if [[ "$backup_file" == *.gpg ]] && [ -n "$ENCRYPTION_KEY" ]; then
        log "Decrypting backup"
        DECRYPTED_FILE="${backup_file%.gpg}"
        gpg --decrypt --batch --passphrase "$ENCRYPTION_KEY" "$backup_file" > "$DECRYPTED_FILE" || error_exit "Decryption failed"
        rm "$backup_file"
        echo "$DECRYPTED_FILE"
    else
        echo "$backup_file"
    fi
}

# Restore database
restore_database() {
    local backup_file="$1"
    local db_type="${DB_TYPE:-postgresql}"
    local db_name="${DB_NAME:-mydb}"
    local db_user="${DB_USER:-postgres}"
    local db_host="${TARGET_HOST:-localhost}"
    
    log "Restoring database: $db_name"
    
    # Stop application services (prevent connections)
    log "Stopping application services"
    # systemctl stop myapp || true
    
    if [ "$db_type" == "postgresql" ]; then
        if [[ "$backup_file" == *.dump ]]; then
            # Custom format restore
            pg_restore -h "$db_host" -U "$db_user" -d "$db_name" -c "$backup_file" || error_exit "Database restore failed"
        elif [[ "$backup_file" == *.tar.gz ]]; then
            # Base backup restore
            TEMP_DIR=$(mktemp -d)
            tar -xzf "$backup_file" -C "$TEMP_DIR" || error_exit "Extraction failed"
            # Restore base backup (requires PostgreSQL setup)
            log "Base backup restore requires manual intervention"
        else
            # SQL file restore
            psql -h "$db_host" -U "$db_user" -d "$db_name" < "$backup_file" || error_exit "Database restore failed"
        fi
    elif [ "$db_type" == "mysql" ]; then
        gunzip -c "$backup_file" | mysql -h "$db_host" -u "$db_user" -p"${DB_PASSWORD}" "$db_name" || error_exit "MySQL restore failed"
    fi
    
    log "Database restore completed"
    
    # Start application services
    log "Starting application services"
    # systemctl start myapp || true
}

# Restore filesystem
restore_filesystem() {
    local backup_file="$1"
    local target_path="${TARGET_PATH:-/var/www}"
    
    log "Restoring filesystem to: $target_path"
    
    # Create target directory
    mkdir -p "$target_path"
    
    # Extract backup
    tar -xzf "$backup_file" -C "$(dirname "$target_path")" || error_exit "Filesystem restore failed"
    
    # Set permissions
    chown -R www-data:www-data "$target_path" || true
    chmod -R 755 "$target_path" || true
    
    log "Filesystem restore completed"
}

# Restore config
restore_config() {
    local backup_file="$1"
    
    log "Restoring configuration files"
    
    # Backup current config
    CONFIG_BACKUP="/tmp/config_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    tar -czf "$CONFIG_BACKUP" /etc/nginx /etc/ansible 2>/dev/null || true
    log "Current config backed up to: $CONFIG_BACKUP"
    
    # Extract config
    tar -xzf "$backup_file" -C / || error_exit "Config restore failed"
    
    log "Config restore completed"
    log "Please review and restart services as needed"
}

# Verify restore
verify_restore() {
    log "Verifying restore"
    
    case "$RESTORE_TYPE" in
        database)
            # Run database verification queries
            psql -h "$TARGET_HOST" -U "${DB_USER:-postgres}" -d "${DB_NAME:-mydb}" -c "SELECT count(*) FROM information_schema.tables;" || error_exit "Database verification failed"
            ;;
        filesystem)
            # Check if files exist
            if [ -n "$TARGET_PATH" ] && [ ! -d "$TARGET_PATH" ]; then
                error_exit "Target path does not exist: $TARGET_PATH"
            fi
            ;;
    esac
    
    log "Restore verification passed"
}

# Main execution
main() {
    log "=== Restore started: $RESTORE_TYPE ==="
    log "Backup date: $BACKUP_DATE"
    log "Target: $TARGET_HOST"
    
    # Find backup
    BACKUP_FILE=$(find_backup)
    
    # Download backup
    LOCAL_BACKUP=$(download_backup "$BACKUP_FILE")
    
    # Decrypt if needed
    LOCAL_BACKUP=$(decrypt_backup "$LOCAL_BACKUP")
    
    # Perform restore
    case "$RESTORE_TYPE" in
        database)
            restore_database "$LOCAL_BACKUP"
            ;;
        filesystem)
            restore_filesystem "$LOCAL_BACKUP"
            ;;
        config)
            restore_config "$LOCAL_BACKUP"
            ;;
        *)
            error_exit "Unknown restore type: $RESTORE_TYPE"
            ;;
    esac
    
    # Verify restore
    verify_restore
    
    # Cleanup
    rm -f "$LOCAL_BACKUP"
    
    log "=== Restore completed successfully ==="
    
    exit 0
}

main "$@"

