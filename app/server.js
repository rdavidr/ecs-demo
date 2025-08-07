const express = require('express');
const os = require('os');
const app = express();
const PORT = process.env.PORT || 3000;

app.get('/', (req, res) => {
  const info = {
    message: '🚀 ECS Demo App Running!',
    container: {
      hostname: os.hostname(),
      platform: os.platform(),
      arch: os.arch(),
      cpus: os.cpus().length,
      memory: `${Math.round(os.totalmem() / 1024 / 1024)} MB`,
      uptime: `${Math.round(os.uptime() / 60)} minutes`
    },
    environment: {
      node_version: process.version,
      port: PORT,
      env: process.env.NODE_ENV || 'development',
      aws_region: process.env.AWS_REGION || 'unknown',
      ecs_cluster: process.env.ECS_CLUSTER || 'unknown',
      task_arn: process.env.ECS_TASK_ARN || 'unknown'
    },
    timestamp: new Date().toISOString()
  };

  res.json(info);
});

app.get('/health', (req, res) => {
  res.json({ status: 'healthy', timestamp: new Date().toISOString() });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running on port ${PORT}`);
});