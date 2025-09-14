#!/bin/bash
set -e

COMPOSE_FILE="./Deployments/Dockerfiles/Aerospike3Replicas"

NETWORK_NAME="aerospike-net"

# Check if network exists
if ! docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
    echo "Creating Docker network $NETWORK_NAME..."
    docker network create "$NETWORK_NAME"
else
    echo "Docker network $NETWORK_NAME already exists. Skipping..."
fi

echo "🚀 Starting Aerospike 3-node cluster..."
docker compose -f $COMPOSE_FILE up -d


Wait until all nodes are up
echo "⏳ Waiting for nodes to start..."
for NODE in aerospike1 aerospike2 aerospike3; do
    until docker exec "$NODE" grep -q "quorum" /var/log/aerospike/aerospike.log 2>/dev/null; do
        echo "Waiting for $NODE..."
        sleep 3
    done
done
echo "✅ All nodes are up!"



# Use aerospike-tools container for AQL
TOOLS="aerospike/aerospike-tools:latest"

# Test write on node1
echo "💾 Writing test record on aerospike1..."
docker run --rm --network=$NETWORK $TOOLS \
    aql -h aerospike1 -c "INSERT INTO test.demo (PK, name) VALUES ('1', 'Ayush');"

# Test read on all nodes
for NODE in aerospike1 aerospike2 aerospike3; do
    echo "🔍 Reading test record from $NODE..."
    docker run --rm --network=$NETWORK $TOOLS \
        aql -h $NODE -c "SELECT * FROM test.demo WHERE PK='1';"
done

echo "🎉 Replication test complete! If record appears on all nodes, replication works."
