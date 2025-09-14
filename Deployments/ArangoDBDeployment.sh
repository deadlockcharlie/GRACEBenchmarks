#!/bin/bash
set -e

COMPOSE_FILE="./Dockerfiles/ArangoDB1Replica"

# Step 1: Start containers
echo "🚀 Starting ArangoDB cluster..."
docker compose -f $COMPOSE_FILE up -d

# Step 2: Wait for coordinator to be ready
echo "⏳ Waiting for Arangodb to be ready..."
until curl -s http://localhost:8529/_api/version | grep version >/dev/null; do
  echo "Waiting..."
  sleep 2
done

echo "🎉 ArangoDB is ready."
