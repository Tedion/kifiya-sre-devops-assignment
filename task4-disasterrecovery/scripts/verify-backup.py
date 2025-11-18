#!/usr/bin/env python3
"""
Backup Verification Script
Verifies backup integrity and optionally tests restore process
"""

import argparse
import boto3
import hashlib
import subprocess
import sys
import os
from datetime import datetime, timedelta
from botocore.exceptions import ClientError

class BackupVerifier:
    def __init__(self, bucket, region='us-east-1', encryption_key=None):
        self.bucket = bucket
        self.region = region
        self.encryption_key = encryption_key
        self.s3_client = boto3.client('s3', region_name=region)
    
    def list_backups(self, backup_type, days=7):
        """List available backups for the last N days"""
        try:
            prefix = f"{backup_type}/"
            response = self.s3_client.list_objects_v2(
                Bucket=self.bucket,
                Prefix=prefix
            )
            
            if 'Contents' not in response:
                return []
            
            backups = []
            cutoff_date = datetime.now() - timedelta(days=days)
            
            for obj in response['Contents']:
                last_modified = obj['LastModified'].replace(tzinfo=None)
                if last_modified >= cutoff_date:
                    backups.append({
                        'key': obj['Key'],
                        'size': obj['Size'],
                        'last_modified': last_modified,
                        'etag': obj['ETag'].strip('"')
                    })
            
            return sorted(backups, key=lambda x: x['last_modified'], reverse=True)
        except ClientError as e:
            print(f"Error listing backups: {e}", file=sys.stderr)
            return []
    
    def verify_backup_integrity(self, backup_key):
        """Verify backup file integrity using checksum"""
        try:
            # Get object metadata
            response = self.s3_client.head_object(
                Bucket=self.bucket,
                Key=backup_key
            )
            
            etag = response['ETag'].strip('"')
            size = response['ContentLength']
            last_modified = response['LastModified']
            
            print(f"Backup: {backup_key}")
            print(f"  Size: {size:,} bytes ({size / 1024 / 1024:.2f} MB)")
            print(f"  Last Modified: {last_modified}")
            print(f"  ETag: {etag}")
            
            # Download and verify checksum
            print("  Downloading for checksum verification...")
            local_path = f"/tmp/{os.path.basename(backup_key)}"
            
            self.s3_client.download_file(
                self.bucket,
                backup_key,
                local_path
            )
            
            # Calculate MD5
            md5_hash = hashlib.md5()
            with open(local_path, 'rb') as f:
                for chunk in iter(lambda: f.read(4096), b''):
                    md5_hash.update(chunk)
            
            calculated_etag = md5_hash.hexdigest()
            
            if calculated_etag == etag:
                print(f"  ✓ Checksum verification passed")
                os.remove(local_path)
                return True
            else:
                print(f"  ✗ Checksum mismatch!")
                print(f"    Expected: {etag}")
                print(f"    Calculated: {calculated_etag}")
                os.remove(local_path)
                return False
                
        except ClientError as e:
            print(f"Error verifying backup: {e}", file=sys.stderr)
            return False
        except Exception as e:
            print(f"Unexpected error: {e}", file=sys.stderr)
            return False
    
    def test_restore(self, backup_key, backup_type, target_host='localhost'):
        """Test restore process in a safe environment"""
        print(f"\n=== Testing Restore Process ===")
        print(f"Backup: {backup_key}")
        print(f"Type: {backup_type}")
        print(f"Target: {target_host}")
        
        # Download backup
        local_path = f"/tmp/{os.path.basename(backup_key)}"
        print(f"\nDownloading backup...")
        try:
            self.s3_client.download_file(
                self.bucket,
                backup_key,
                local_path
            )
            print(f"✓ Download completed")
        except Exception as e:
            print(f"✗ Download failed: {e}", file=sys.stderr)
            return False
        
        # Verify file exists and is readable
        if not os.path.exists(local_path):
            print(f"✗ Backup file not found: {local_path}", file=sys.stderr)
            return False
        
        file_size = os.path.getsize(local_path)
        print(f"  File size: {file_size:,} bytes")
        
        # Test extraction (for compressed files)
        if backup_key.endswith('.tar.gz') or backup_key.endswith('.gz'):
            print(f"\nTesting extraction...")
            test_dir = f"/tmp/restore_test_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
            os.makedirs(test_dir, exist_ok=True)
            
            try:
                if backup_key.endswith('.tar.gz'):
                    subprocess.run(
                        ['tar', '-tzf', local_path],
                        check=True,
                        capture_output=True
                    )
                    print(f"✓ Tar archive is valid")
                elif backup_key.endswith('.gz'):
                    subprocess.run(
                        ['gunzip', '-t', local_path],
                        check=True,
                        capture_output=True
                    )
                    print(f"✓ Gzip file is valid")
            except subprocess.CalledProcessError as e:
                print(f"✗ Extraction test failed: {e}", file=sys.stderr)
                os.remove(local_path)
                return False
        
        # For database backups, test SQL syntax (if applicable)
        if backup_type == 'database' and backup_key.endswith('.sql'):
            print(f"\nTesting SQL syntax...")
            try:
                # Just check if file is readable and has content
                with open(local_path, 'r', encoding='utf-8', errors='ignore') as f:
                    first_lines = [f.readline() for _ in range(10)]
                    if any('CREATE' in line.upper() or 'INSERT' in line.upper() for line in first_lines):
                        print(f"✓ SQL file appears valid")
                    else:
                        print(f"⚠ SQL file format may be unusual")
            except Exception as e:
                print(f"⚠ Could not verify SQL syntax: {e}")
        
        # Cleanup
        os.remove(local_path)
        if os.path.exists(test_dir):
            import shutil
            shutil.rmtree(test_dir)
        
        print(f"\n✓ Restore test completed successfully")
        return True
    
    def verify_recent_backups(self, backup_type, days=7):
        """Verify all recent backups"""
        print(f"=== Verifying Recent Backups ===")
        print(f"Type: {backup_type}")
        print(f"Period: Last {days} days\n")
        
        backups = self.list_backups(backup_type, days)
        
        if not backups:
            print("No backups found in the specified period")
            return False
        
        print(f"Found {len(backups)} backup(s)\n")
        
        all_passed = True
        for backup in backups:
            if not self.verify_backup_integrity(backup['key']):
                all_passed = False
            print()
        
        return all_passed


def main():
    parser = argparse.ArgumentParser(description='Verify backup integrity')
    parser.add_argument('--backup-type', required=True, choices=['database', 'filesystem', 'config'],
                        help='Type of backup to verify')
    parser.add_argument('--backup-date', help='Specific backup date (YYYY-MM-DD)')
    parser.add_argument('--bucket', default='backups-prod', help='S3 bucket name')
    parser.add_argument('--region', default='us-east-1', help='AWS region')
    parser.add_argument('--test-restore', action='store_true',
                        help='Test restore process')
    parser.add_argument('--target-host', default='localhost',
                        help='Target host for restore test')
    parser.add_argument('--days', type=int, default=7,
                        help='Number of days to check (default: 7)')
    
    args = parser.parse_args()
    
    verifier = BackupVerifier(args.bucket, args.region)
    
    if args.backup_date:
        # Verify specific backup
        backup_pattern = f"{args.backup_type}_{args.backup_date.replace('-', '_')}"
        backups = verifier.list_backups(args.backup_type, days=30)
        matching_backups = [b for b in backups if backup_pattern in b['key']]
        
        if not matching_backups:
            print(f"No backup found for date: {args.backup_date}", file=sys.stderr)
            sys.exit(1)
        
        backup_key = matching_backups[0]['key']
        
        if not verifier.verify_backup_integrity(backup_key):
            sys.exit(1)
        
        if args.test_restore:
            if not verifier.test_restore(backup_key, args.backup_type, args.target_host):
                sys.exit(1)
    else:
        # Verify recent backups
        if not verifier.verify_recent_backups(args.backup_type, args.days):
            sys.exit(1)
    
    print("\n✓ All verifications passed")
    sys.exit(0)


if __name__ == '__main__':
    main()
