# Architecture Diagram Instructions

Please create an architecture diagram file named `containersecurityarchitecture.png` showing:

## Components to Include:
- **CI/CD Pipeline Stages**:
  - Build
  - Security Scan (Trivy)
  - Policy Check
  - Sign Image
  - Push to Registry
  - Deploy
- **Security Scanning**: Trivy execution points
- **Policy Enforcement**: Block/allow decision points
- **Image Registry**: Docker registry with signed images
- **Deployment**: Kubernetes/container orchestration

## Flow to Show:
1. Code commit triggers pipeline
2. Docker image build
3. Vulnerability scanning (Trivy)
4. Policy validation (base image, root user, etc.)
5. Image signing (if passed)
6. Push to registry
7. Deployment (if all checks pass)

## Tools for Creating:
- draw.io (https://app.diagrams.net/)
- Lucidchart
- Excalidraw
- PlantUML
- Visio

## Diagram Style:
- Show failure points (where pipeline can be blocked)
- Indicate reporting mechanisms (Slack, dashboards)
- Display security boundaries
- Include feedback loops (scan results → developer)

