# Task 5: Container Security and Compliance Automation

## Overview
Automated container image security and compliance checks within CI/CD pipelines using Jenkins and GitLab CI.

## Architecture

### Security Scanning Flow
1. **Build Stage**: Container image is built
2. **Scan Stage**: Vulnerability scanning with Trivy/Clair
3. **Policy Check**: Compliance and policy validation
4. **Enforcement**: Block or allow based on results
5. **Reporting**: Security reports and notifications

## Tools Used

### Trivy (Primary Scanner)
- **Why**: Fast, comprehensive, supports multiple formats
- **Features**: 
  - OS package vulnerabilities
  - Application dependencies (npm, pip, etc.)
  - Misconfigurations
  - Secrets detection
- **Execution**: Early in pipeline, before image push

### OPA/Gatekeeper (Policy Enforcement)
- **Why**: Flexible policy engine, Kubernetes-native
- **Features**: Custom policies, compliance checks
- **Execution**: After scanning, before deployment

### Docker Bench Security
- **Why**: CIS Docker Benchmark compliance
- **Features**: Configuration security checks
- **Execution**: Optional, for host-level security

## Pipeline Integration

### Jenkins Pipeline
- **Stages**: Build → Scan → Policy Check → Push → Deploy
- **Failure Points**: High/Critical vulnerabilities, policy violations
- **Reporting**: JUnit XML, HTML reports, Slack notifications

### GitLab CI Pipeline
- **Stages**: Build → Test → Security Scan → Policy Check → Deploy
- **Failure Points**: Same as Jenkins
- **Reporting**: GitLab Security Dashboard, merge request comments

## Security Policies

### Vulnerability Severity
- **Critical/High**: Block pipeline, require manual override
- **Medium**: Warning, allow with approval
- **Low**: Informational, allow

### Compliance Rules
- No secrets in images
- Base images from approved registries only
- Image signing required
- No root user in containers
- Resource limits defined

## Failure Handling

### Blocking Failures
- Critical vulnerabilities → Pipeline fails
- Policy violations → Pipeline fails
- Missing signatures → Pipeline fails

### Reporting
- Security dashboard updates
- Slack/Email notifications
- Merge request comments (GitLab)
- JIRA tickets (optional)

## Setup Instructions

### Prerequisites
```bash
# Install Trivy
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
sudo apt-get update
sudo apt-get install trivy
```

### Jenkins Setup
1. Install Trivy plugin (or use shell step)
2. Configure credentials for registry access
3. Set up Slack/email notifications
4. Configure policy files

### GitLab CI Setup
1. Add Trivy to GitLab Runner
2. Configure CI variables
3. Set up security scanning templates
4. Configure merge request approvals

## Usage

### Jenkins
```groovy
// Use Jenkinsfile from ci-pipeline/jenkinsfile
```

### GitLab CI
```yaml
# Use .gitlab-ci.yml from ci-pipeline/gitlabci.yml
```

## Customization

### Policy Files
- Edit `policies/security.rego` for custom rules
- Update severity thresholds in pipeline files
- Configure allowed base images list

### Notifications
- Update webhook URLs
- Configure email recipients
- Set up JIRA integration (optional)

