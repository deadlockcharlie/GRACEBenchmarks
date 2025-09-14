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


# agent1 → agent2 = 50ms, agent1 → agent3 = 100ms
docker exec -it agent1-netem sh -c "/usr/local/bin/setup-latency.sh agent1 agent2 50 agent3 100"

# agent2 → agent1 = 50ms, agent2 → agent3 = 75ms
docker exec -it agent2-netem sh -c "/usr/local/bin/setup-latency.sh agent2 agent1 50 agent3 75"

# agent3 → agent1 = 100ms, agent3 → agent2 = 75ms
docker exec -it agent3-netem sh -c "/usr/local/bin/setup-latency.sh agent3 agent1 100 agent2 75"


# dbsserver1 → dbsserver2 = 50ms, dbsserver1 → dbsserver3 = 100ms
docker exec -it dbsserver1-netem sh -c "/usr/local/bin/setup-latency.sh dbsserver1 dbsserver2 50 dbsserver3 100"

# dbsserver2 → dbsserver1 = 50ms, dbsserver2 → dbsserver3 = 75ms
docker exec -it dbsserver2-netem sh -c "/usr/local/bin/setup-latency.sh dbsserver2 dbsserver1 50 dbsserver3 75"

# dbsserver3 → dbsserver1 = 100ms, dbsserver3 → dbsserver2 = 75ms
docker exec -it dbsserver3-netem sh -c "/usr/local/bin/setup-latency.sh dbsserver3 agent1 100 dbsserver2 75"




echo "🎉 ArangoDB cluster is ready with quorum writes enabled."
