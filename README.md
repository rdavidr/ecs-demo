# ECS Demo Project

Demo project showcasing AWS ECS deployment with OpenTofu and GitHub Actions.

## Features

- 🏗️ **Infrastructure as Code**: OpenTofu for AWS resources
- 🐳 **Containerized App**: Node.js demo application
- 🔄 **CI/CD**: GitHub Actions with OIDC authentication
- 🔐 **Security**: No AWS keys stored, uses IAM roles
- 📊 **Monitoring**: CloudWatch logs and ECS insights

## Quick Start

1. **Deploy Infrastructure**:
   ```bash
   tofu init
   tofu apply
   ```

2. **Deploy Application**: 
   - Push changes to `app/` folder
   - GitHub Actions will build and deploy automatically

3. **Access Application**:
   - Get ALB URL: `tofu output alb_url`
   - Visit: `http://your-alb-dns-name`

## Architecture

```
┌─────────────────┐    ┌──────────────┐    ┌─────────────┐
│   GitHub Actions │───▶│     ECR      │───▶│     ECS     │
│   (Build & Push) │    │  (Registry)  │    │ (Containers)│
└─────────────────┘    └──────────────┘    └─────────────┘
                                                   │
                                           ┌───────▼──────┐
                                           │      ALB     │
                                           │ (Load Balancer)│
                                           └──────────────┘
```

## Costs

- **NAT Gateway**: ~$45/month ($0.045/hour)
- **ALB**: ~$18/month ($0.025/hour)
- **Fargate**: ~$13/month for 2 tasks (256 CPU, 512 MB)

**Total**: ~$76/month for always-on demo

## Cleanup

```bash
tofu destroy
```

## GitHub Actions Setup

The workflow automatically:
1. Builds Docker image from `/app/Dockerfile`
2. Pushes to ECR using OIDC (no AWS keys needed)
3. Generates ECS task definition dynamically
4. Creates/updates ECS service
5. Waits for deployment to stabilize

Trigger: Push to `main` branch with changes in `app/` folder or manual dispatch.