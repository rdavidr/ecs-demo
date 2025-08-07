#!/usr/bin/env node

const http = require('http');

const options = {
  hostname: 'localhost',
  port: 3000,
  path: '/health',
  method: 'GET',
  timeout: 2000
};

const req = http.request(options, (res) => {
  if (res.statusCode === 200) {
    process.exit(0); // Success
  } else {
    process.exit(1); // Failure
  }
});

req.on('error', () => {
  process.exit(1); // Failure
});

req.on('timeout', () => {
  req.destroy();
  process.exit(1); // Failure
});

req.end();