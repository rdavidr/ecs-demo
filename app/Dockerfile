FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy application code
COPY . .

# Make healthcheck script executable
RUN chmod +x healthcheck.js

# Expose port
EXPOSE 3000

# Run the application
CMD ["node", "server.js"]