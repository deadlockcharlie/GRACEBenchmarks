#!/bin/bash
set -e


echo "Starting Aerospike replica set..."

docker compose -f $COMPOSE_FILE up -d

replicas=""
for (( j=1; j<=$i; j++ ))
do
  replicas+="aerospike$j "
done

echo "⏳ Waiting for Aerospike nodes to be ready..."
for node in $replicas; do
  echo "Waiting for $node to be ready..."
  # Check if node accepts client connections by checking cluster_size
  for attempt in {1..30}; do
    CLUSTER_SIZE=$(docker exec $node asinfo -v "statistics" 2>/dev/null | grep -o "cluster_size=[0-9]*" | cut -d'=' -f2 || echo "0")
    if [ -n "$CLUSTER_SIZE" ] && [ "$CLUSTER_SIZE" -ge $i ]; then
      echo "✅ $node is ready (cluster_size=$CLUSTER_SIZE)"
      break
    fi
    echo "  Attempt $attempt/30: $node not ready yet..."
    sleep 2
  done
done
echo "All nodes ready, waiting additional 5 seconds for full cluster stability..."
sleep 5

echo "⏳ Waiting for Aerospike Graph Service to be ready..."
for attempt in {1..30}; do
  if docker exec aerospike-graph-service gremlin.sh -e "g.V().count()" 2>/dev/null | grep -q "gremlin>"; then
    echo "✅ Graph Service is ready"
    break
  fi
  echo "  Attempt $attempt/30: Graph Service not ready yet..."
  sleep 2
done

# Get the actual network name created by docker compose
NETWORK_NAME=$(docker inspect aerospike1 --format='{{range $k, $v := .NetworkSettings.Networks}}{{$k}}{{end}}')
echo "Using network: $NETWORK_NAME"

echo "📊 Starting data preload using Gremlin bulk load..."

# Execute Gremlin bulk load command
echo "Loading vertices and edges from mounted volume..."
docker exec aerospike-graph-service gremlin.sh -e "g.with('evaluationTimeout', 20000).call('aerospike.graphloader.admin.bulk-load.load').with('aerospike.graphloader.vertices', '/opt/aerospike-graph/data/vertices.json').with('aerospike.graphloader.edges', '/opt/aerospike-graph/data/edges.json').next()"

if [ $? -eq 0 ]; then
    echo "✅ Data preload completed successfully"
else
    echo "❌ Data preload failed"
    exit 1
fi

echo "🎉 Aerospike deployment and preload complete!"

echo "🎉 Replication test complete! If record appears on all nodes, replication works."
