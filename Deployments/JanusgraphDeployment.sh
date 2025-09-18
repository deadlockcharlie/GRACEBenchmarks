#!/bin/bash
set -e

COMPOSE_FILE="./Dockerfiles/JanusgraphScyllaDB1Replica"

echo "🚀 Starting Scylla and JanusGraph containers..."
docker compose -f $COMPOSE_FILE up -d

# Step 1: Wait for scylla nodes to be ready
echo "⏳ Waiting for Scylla cluster to be ready..."
for node in scylla1; do
  until docker exec $node cqlsh -e "DESCRIBE KEYSPACES;" >/dev/null 2>&1; do
    echo "Waiting for $node..."
    sleep 5
  done
done
echo "✅ Scylla cluster is ready."
#Wait until JanusGraph is ready
echo "⏳ Waiting for JanusGraph to be ready..."
while ! docker logs janusgraph 2>&1 | grep -q "Channel started at port 8182"; do
    echo "Waiting for JanusGraph to start..."
    sleep 5
done

echo "🎉 JanusGraph cluster with replication is ready!"
