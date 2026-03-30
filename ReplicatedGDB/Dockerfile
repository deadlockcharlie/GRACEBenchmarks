# Build stage
FROM node:24-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./
COPY tsconfig.json ./

# Install dependencies (including devDependencies for build)
RUN npm ci

# Copy source code
COPY src ./src

# Build the application
RUN npm run build

# Production stage
FROM node:22-bullseye

WORKDIR /app

# Install netcat for database readiness check
RUN apt-get update && apt-get install -y netcat && rm -rf /var/lib/apt/lists/*

# Copy package files
COPY package*.json ./

RUN npm ci

# Copy built application from builder
COPY --from=builder /app/dist ./dist

# Copy startup script
COPY scripts/wait-for-db.sh /app/wait-for-db.sh
RUN chmod +x /app/wait-for-db.sh

# Create directory for data import (if needed)
# RUN mkdir -p /var/lib/grace/import

# Expose port (default 8080, changed from 3000 to avoid conflict with Memgraph Lab)
EXPOSE 8080

# Wait for database then run the application
CMD ["/bin/sh", "-c", "/app/wait-for-db.sh && node --max-old-space-size=32767 dist/app.js"]
