# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ECS demonstration project with:
- OpenTofu infrastructure (VPC, ECS Cluster, ALB, ECR)
- Node.js demo application
- GitHub Actions CI/CD with OIDC authentication
- Deployed to AWS us-east-2

## Development Commands

```bash
# Deploy infrastructure
tofu init
tofu apply

# Build and test app locally
cd app
docker build -t ecs-demo-app .
docker run -p 3000:3000 ecs-demo-app

# View logs
aws logs tail /ecs/ecs-demo-dev --follow --profile rdavidr --region us-east-2

# Destroy infrastructure
tofu destroy
```

## Architecture

- **Infrastructure**: OpenTofu manages VPC, ECS, ALB, ECR in us-east-2
- **Application**: Node.js app in `/app` folder with Dockerfile
- **CI/CD**: GitHub Actions builds Docker images, pushes to ECR, deploys to ECS
- **Authentication**: OIDC for GitHub Actions (no stored AWS keys)

## GitHub Actions

- Triggers on changes to `/app/**` or manual dispatch
- Dynamically generates ECS task definitions
- Creates or updates ECS services automatically
- Service URL: Check ALB DNS name from `tofu output`

## Important Notes

- NEVER include Claude attribution in commits or code
- Keep commits focused on the technical changes only