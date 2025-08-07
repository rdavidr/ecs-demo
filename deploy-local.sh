#!/bin/bash
set -e

# Configuration
AWS_REGION="us-east-2"
AWS_PROFILE="rdavidr"
AWS_ACCOUNT="564044497219"
ENVIRONMENT="dev"
ECS_CLUSTER="ecs-demo-${ENVIRONMENT}"
ECR_REPOSITORY="ecs-demo-${ENVIRONMENT}-app"
APP_NAME="ecs-demo-app"
SERVICE_NAME="ecs-demo-app"

echo "🚀 Starting deployment to ECS..."

# Get ECR login token
echo "📦 Logging into ECR..."
aws ecr get-login-password --region $AWS_REGION --profile $AWS_PROFILE | \
  docker login --username AWS --password-stdin $AWS_ACCOUNT.dkr.ecr.$AWS_REGION.amazonaws.com

# Build and push Docker image
echo "🔨 Building Docker image..."
cd app
docker build -t $ECR_REPOSITORY:latest .

# Tag and push to ECR
echo "⬆️ Pushing to ECR..."
docker tag $ECR_REPOSITORY:latest $AWS_ACCOUNT.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY:latest
docker push $AWS_ACCOUNT.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY:latest
cd ..

# Create task definition
echo "📝 Creating task definition..."
cat > /tmp/task-definition.json <<EOF
{
  "family": "${APP_NAME}",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "executionRoleArn": "arn:aws:iam::${AWS_ACCOUNT}:role/ecs-demo-${ENVIRONMENT}-ecs-task-execution",
  "taskRoleArn": "arn:aws:iam::${AWS_ACCOUNT}:role/ecs-demo-${ENVIRONMENT}-ecs-task",
  "containerDefinitions": [
    {
      "name": "${APP_NAME}",
      "image": "${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY}:latest",
      "portMappings": [
        {
          "containerPort": 3000,
          "protocol": "tcp"
        }
      ],
      "essential": true,
      "environment": [
        {
          "name": "NODE_ENV",
          "value": "production"
        },
        {
          "name": "PORT",
          "value": "3000"
        },
        {
          "name": "AWS_REGION",
          "value": "${AWS_REGION}"
        },
        {
          "name": "ECS_CLUSTER",
          "value": "${ECS_CLUSTER}"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/ecs-demo-${ENVIRONMENT}",
          "awslogs-region": "${AWS_REGION}",
          "awslogs-stream-prefix": "${APP_NAME}"
        }
      }
    }
  ]
}
EOF

# Register task definition
echo "📋 Registering task definition..."
TASK_DEF_ARN=$(aws ecs register-task-definition \
  --cli-input-json file:///tmp/task-definition.json \
  --profile $AWS_PROFILE \
  --region $AWS_REGION \
  --query 'taskDefinition.taskDefinitionArn' \
  --output text)

echo "Task definition registered: $TASK_DEF_ARN"

# Check if service exists
echo "🔍 Checking if service exists..."
SERVICE_EXISTS=$(aws ecs describe-services \
  --cluster $ECS_CLUSTER \
  --services $SERVICE_NAME \
  --profile $AWS_PROFILE \
  --region $AWS_REGION \
  --query 'services[0].status' \
  --output text 2>/dev/null || echo "NONE")

if [ "$SERVICE_EXISTS" == "ACTIVE" ]; then
  echo "✅ Service exists, updating..."
  aws ecs update-service \
    --cluster $ECS_CLUSTER \
    --service $SERVICE_NAME \
    --task-definition $TASK_DEF_ARN \
    --profile $AWS_PROFILE \
    --region $AWS_REGION \
    --force-new-deployment
else
  echo "🆕 Creating new service..."
  
  # Get VPC and subnets
  VPC_ID=$(aws ec2 describe-vpcs \
    --filters "Name=tag:Name,Values=ecs-demo-${ENVIRONMENT}-vpc" \
    --profile $AWS_PROFILE \
    --region $AWS_REGION \
    --query 'Vpcs[0].VpcId' \
    --output text)
  
  SUBNETS=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Type,Values=Private" \
    --profile $AWS_PROFILE \
    --region $AWS_REGION \
    --query 'Subnets[*].SubnetId' \
    --output text | tr '\t' ',')
  
  # Get security group
  SG=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=ecs-demo-${ENVIRONMENT}-ecs-tasks" \
    --profile $AWS_PROFILE \
    --region $AWS_REGION \
    --query 'SecurityGroups[0].GroupId' \
    --output text)
  
  # Get target group ARN
  TG_ARN=$(aws elbv2 describe-target-groups \
    --names "ecs-demo-${ENVIRONMENT}" \
    --profile $AWS_PROFILE \
    --region $AWS_REGION \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text)
  
  # Create service
  aws ecs create-service \
    --cluster $ECS_CLUSTER \
    --service-name $SERVICE_NAME \
    --task-definition $TASK_DEF_ARN \
    --desired-count 2 \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[$SUBNETS],securityGroups=[$SG],assignPublicIp=DISABLED}" \
    --load-balancers "targetGroupArn=$TG_ARN,containerName=$APP_NAME,containerPort=3000" \
    --health-check-grace-period-seconds 60 \
    --profile $AWS_PROFILE \
    --region $AWS_REGION
fi

echo "⏳ Waiting for service to stabilize..."
aws ecs wait services-stable \
  --cluster $ECS_CLUSTER \
  --services $SERVICE_NAME \
  --profile $AWS_PROFILE \
  --region $AWS_REGION

# Get ALB URL
ALB_URL=$(aws elbv2 describe-load-balancers \
  --names "ecs-demo-${ENVIRONMENT}" \
  --profile $AWS_PROFILE \
  --region $AWS_REGION \
  --query 'LoadBalancers[0].DNSName' \
  --output text)

echo "✅ Deployment complete!"
echo "🌐 Service URL: http://$ALB_URL"
echo ""
echo "📊 View logs:"
echo "aws logs tail /ecs/ecs-demo-${ENVIRONMENT} --follow --profile $AWS_PROFILE --region $AWS_REGION"