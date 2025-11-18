# Task 2: Configuration Management and Scalable Production Deployment

## Overview
This task implements automated configuration management using Ansible to provision and configure multiple production servers simultaneously. The solution emphasizes idempotency, security, scalability, and role-based organization.

## Architecture

### Control Node
- Ansible control node running on local machine or dedicated server
- SSH access to all target nodes configured with key-based authentication
- Ansible 2.9+ installed with required collections

### Target Nodes
**Production Environment:**
- **Web Servers**: 3 servers (web1, web2, web3) running Nginx
- **Database Servers**: 2 servers (db1, db2) with PostgreSQL
- **Application Servers**: 2 servers (app1, app2) for backend APIs

**Total Infrastructure**: 7 production servers

### Network Architecture
```
Control Node (Ansible)
        |
        | SSH (Port 22)
        |
    [Firewall]
        |
        ├─── Web Servers (192.168.1.10-12)
        ├─── Database Servers (192.168.1.20-21)  
        └─── Application Servers (192.168.1.30-31)
```

See `architecture-diagram.png` for detailed visual architecture.

## Design Decisions

### 1. Idempotency
All playbooks and tasks are designed to be idempotent - running them multiple times produces the same result without unwanted side effects.

**Implementation:**
- Use of Ansible modules that check state before making changes
- `apt`/`yum` modules verify package installation status
- `template` module compares checksums before copying
- `service` module checks current state before modifications
- `user` module verifies user existence before creation

### 2. Role-Based Organization
Tasks are organized into reusable roles for better maintainability and reusability.

**Roles Structure:**
- `common`: Base system configuration for all servers
- `security`: Security hardening and firewall rules
- `webserver`: Nginx web server configuration
- `database`: PostgreSQL database setup
- `application`: Application server deployment

### 3. Inventory Management
Static inventory with support for dynamic inventory plugins for cloud environments.

**Features:**
- Group-based organization (webservers, dbservers, appservers)
- Group variables for server-type specific configurations
- Environment-specific variables (production)

### 4. Security
Security-first approach with multiple layers of protection.

**Security Features:**
- SSH key-based authentication only (no passwords)
- Ansible Vault for encrypting sensitive variables
- Limited sudo privileges configured via sudoers
- Firewall rules (UFW) with only necessary ports open
- Fail2ban for intrusion prevention
- Disabled root login via SSH

### 5. Scaling
Built for scalability with parallel execution and async operations.

**Scaling Features:**
- Parallel execution with configurable forks (10 concurrent hosts)
- Async tasks for long-running operations
- Dynamic inventory support for cloud providers
- Batching with `serial` keyword for rolling updates
- SSH connection pooling for performance

## Directory Structure

```
task2-infrastructure/
├── README.md                          # This file
├── architecture-diagram.png           # Architecture visualization
├── ansible/
│   ├── ansible.cfg                    # Ansible configuration
│   ├── site.yml                       # Main playbook
│   ├── inventory/
│   │   ├── hosts                      # Server inventory
│   │   └── group_vars/
│   │       ├── all.yml                # Global variables
│   │       ├── webservers.yml         # Web server variables
│   │       ├── dbservers.yml          # Database variables
│   │       └── appservers.yml         # Application variables
│   └── roles/
│       ├── common/                    # Base configuration
│       │   ├── tasks/main.yml
│       │   ├── handlers/main.yml
│       │   └── defaults/main.yml
│       ├── security/                  # Security hardening
│       │   ├── tasks/main.yml
│       │   ├── handlers/main.yml
│       │   └── defaults/main.yml
│       ├── webserver/                 # Nginx setup
│       │   ├── tasks/main.yml
│       │   ├── handlers/main.yml
│       │   └── defaults/main.yml
│       ├── database/                  # PostgreSQL setup
│       │   ├── tasks/main.yml
│       │   └── defaults/main.yml
│       └── application/               # App deployment
│           ├── tasks/main.yml
│           └── defaults/main.yml
```

## Prerequisites

### Control Node Requirements
- Ansible 2.9 or higher
- Python 3.6+
- SSH client
- Network connectivity to target nodes

### Target Node Requirements
- Supported OS: Ubuntu 20.04/22.04, CentOS 7/8, Debian 10/11
- Python 3.x installed
- SSH server running and accessible
- Sudo privileges configured for deployment user

### Installation

```bash
# Install Ansible on control node (Ubuntu/Debian)
sudo apt update
sudo apt install ansible -y

# Install Ansible (macOS)
brew install ansible

# Install Ansible (pip)
pip3 install ansible

# Verify installation
ansible --version

# Install required collections
ansible-galaxy collection install community.general
ansible-galaxy collection install ansible.posix
```

## Configuration

### 1. Update Inventory
Edit `ansible/inventory/hosts` with your actual server IPs:

```ini
[webservers]
web1 ansible_host=YOUR_WEB1_IP
web2 ansible_host=YOUR_WEB2_IP
web3 ansible_host=YOUR_WEB3_IP
```

### 2. Configure SSH Keys
```bash
# Generate SSH key if not exists
ssh-keygen -t rsa -b 4096

# Copy key to all servers
ssh-copy-id ansible@web1
ssh-copy-id ansible@db1
# ... repeat for all servers
```

### 3. Set Variables
Update `ansible/inventory/group_vars/all.yml` with environment-specific values.

### 4. Encrypt Sensitive Data
```bash
# Encrypt secrets file
ansible-vault create ansible/inventory/group_vars/secrets.yml

# Edit encrypted file
ansible-vault edit ansible/inventory/group_vars/secrets.yml
```

## Running Playbooks

### Test Connectivity
```bash
cd ansible
ansible all -i inventory/hosts -m ping
```

### Run Full Deployment
```bash
ansible-playbook -i inventory/hosts site.yml
```

### Run with Check Mode (Dry Run)
```bash
ansible-playbook -i inventory/hosts site.yml --check
```

### Deploy Specific Role
```bash
ansible-playbook -i inventory/hosts site.yml --tags webserver
```

### Limit to Specific Hosts
```bash
ansible-playbook -i inventory/hosts site.yml --limit web1
```

### Run with Parallel Execution
```bash
ansible-playbook -i inventory/hosts site.yml -f 10
```

### Using Vault Password
```bash
ansible-playbook -i inventory/hosts site.yml --ask-vault-pass
```

## Security Considerations

### Authentication
- SSH key-based authentication enforced
- No password authentication allowed
- Root login disabled

### Data Protection
- Sensitive variables encrypted with Ansible Vault
- Secrets never stored in plain text
- Private keys secured with proper permissions (600)

### Access Control
- Limited sudo privileges (only necessary commands)
- User-based access control
- Firewall rules restrict network access

### Network Security
- Only necessary ports opened (22, 80, 443)
- Fail2ban monitors authentication attempts
- UFW firewall configured on all servers

## Idempotency Details

### Package Installation
```yaml
- package:
    name: nginx
    state: present
```
Checks if package is already installed before attempting installation.

### File Management
```yaml
- template:
    src: config.j2
    dest: /etc/config
```
Compares file checksums; only copies if content differs.

### Service Management
```yaml
- service:
    name: nginx
    state: started
```
Checks if service is already running before starting.

### User Creation
```yaml
- user:
    name: ansible
    state: present
```
Verifies user exists before attempting creation.

## Scaling Considerations

### 1. Parallel Execution
Configure forks in `ansible.cfg`:
```ini
forks = 10
```
Runs tasks on 10 hosts simultaneously.

### 2. Async Tasks
For long-running operations:
```yaml
- shell: /long/running/script.sh
  async: 3600
  poll: 0
```

### 3. Dynamic Inventory
Supports cloud providers:
- AWS EC2
- Google Cloud Platform
- Microsoft Azure
- OpenStack

### 4. Batching
Update servers in batches:
```yaml
- hosts: webservers
  serial: 2
```
Updates 2 servers at a time for zero-downtime deployments.

### 5. Connection Pooling
SSH connection reuse configured in `ansible.cfg`:
```ini
ssh_args = -o ControlMaster=auto -o ControlPersist=60s
pipelining = True
```

## Assumptions

1. **SSH Access**: All target servers have SSH access configured and accessible from control node
2. **Python**: Python 3.x is installed on all target nodes
3. **Network**: Stable network connectivity between control and target nodes
4. **Privileges**: Ansible user has sudo privileges on target nodes
5. **DNS**: Hostnames in inventory are resolvable (or use IP addresses)
6. **Firewall**: SSH port (22) is accessible through any network firewalls
7. **OS**: Servers run supported Linux distributions (Ubuntu/Debian/CentOS)

## Troubleshooting

### Connection Issues
```bash
# Test SSH connectivity
ssh ansible@web1

# Check Ansible connectivity
ansible web1 -m ping

# Verbose output
ansible-playbook site.yml -vvv
```

### Permission Issues
```bash
# Verify sudo access
ansible all -m shell -a "sudo whoami" --become

# Check SSH key permissions
ls -la ~/.ssh/id_rsa  # Should be 600
```

### Playbook Issues
```bash
# Syntax check
ansible-playbook site.yml --syntax-check

# Dry run
ansible-playbook site.yml --check --diff
```

## Best Practices

1. **Version Control**: Keep all Ansible code in version control (Git)
2. **Testing**: Always run with `--check` before actual deployment
3. **Backup**: Backup configurations before making changes
4. **Documentation**: Document all custom variables and configurations
5. **Security**: Regularly rotate SSH keys and vault passwords
6. **Monitoring**: Monitor playbook execution and results
7. **Incremental**: Make incremental changes, test frequently

## Maintenance

### Regular Tasks
- Update package repositories
- Apply security patches
- Review and update firewall rules
- Rotate SSH keys and passwords
- Review and prune old logs

### Updates
```bash
# Update all packages
ansible all -m apt -a "upgrade=dist" --become
```

---

**Created for**: Kifiya SRE/DevOps Assignment  
**Task**: Configuration Management and Scalable Production Deployment  
**Technology**: Ansible 2.9+
