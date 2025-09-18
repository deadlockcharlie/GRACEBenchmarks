#!/bin/bash
set -e

COMPOSE_FILE="./Dockerfiles/ArangoDB3Replicas"

# Step 1: Start containers
echo "🚀 Starting ArangoDB cluster..."
docker compose -f $COMPOSE_FILE up -d

# Step 2: Wait for coordinator to be ready
echo "⏳ Waiting for Coordinator to be ready..."
until curl -s http://localhost:8529/_api/version | grep version >/dev/null; do
  echo "Waiting..."
  sleep 2
done

echo "✅ Coordinator is up."

# Step 3: Create a test database and a quorum-replicated collection
echo "📦 Creating database and collection with replicationFactor=3..."


docker exec coordinator1 arangosh \
  --server.endpoint tcp://coordinator1:8529 \
  --javascript.execute-string '
if (!db._databases().includes("testdb")) {
  db._createDatabase("testdb");
}
db._useDatabase("testdb");
if (!db._collection("testCollection")) {
  db._create("testCollection", { replicationFactor: 3 });
  print("Collection testCollection created with replicationFactor=3");
} else {
  print("Collection testCollection already exists");
}
'




echo "🎉 ArangoDB cluster is ready with quorum writes enabled."
