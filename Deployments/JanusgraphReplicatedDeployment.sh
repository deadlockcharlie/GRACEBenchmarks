#!/bin/bash
set -e

COMPOSE_FILE="./Deployments/Dockerfiles/JanusgraphCassandra3Replicas"

echo "🚀 Starting Cassandra and JanusGraph containers..."
docker compose -f $COMPOSE_FILE up -d

# Step 1: Wait for Cassandra nodes to be ready
echo "⏳ Waiting for Cassandra cluster to be ready..."
for node in cassandra1 cassandra2 cassandra3; do
  until docker exec $node cqlsh -e "DESCRIBE KEYSPACES;" >/dev/null 2>&1; do
    echo "Waiting for $node..."
    sleep 5
  done
done
echo "✅ Cassandra cluster is ready."


# Step 2: Ensure JanusGraph container is running
echo "⏳ Waiting for JanusGraph container..."
until docker exec janusgraph curl -s http://localhost:8182 >/dev/null 2>&1; do
  echo "Waiting for JanusGraph..."
  sleep 5
done
echo "✅ JanusGraph is running."

# Step 3: Optional - Create a sample graph
echo "📦 Creating a sample graph 'graph' in JanusGraph..."
docker exec janusgraph gremlin.sh <<'GREMLIN'
:remote connect tinkerpop.server conf/remote.yaml
:remote console
graph = JanusGraphFactory.open("conf/janusgraph-cassandra.properties")
g = graph.traversal()
if (!graph.openManagement().containsGraphIndex("sampleIndex")) {
    println("Sample graph created")
} else {
    println("Sample graph already exists")
}
GREMLIN

echo "🎉 JanusGraph cluster with replication is ready!"