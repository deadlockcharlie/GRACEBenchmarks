FROM node:18-alpine

# Install necessary packages
RUN apk add --no-cache \
    bash \
    curl \
    iproute2 \
    iptables \
    iputils

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy application code
COPY . .

# Expose default ports
EXPOSE 3000 9090 5000

# Run the application
CMD ["node", "index.js"]
