#!/bin/bash
set -e

echo "Starting JanusGraph replica set..."

docker compose -f $COMPOSE_FILE up -d

replicas=""
for (( j=1; j<=$i; j++ ))
do
  replicas+="scylla$j "
done

# Step 1: Wait for scylla nodes to be ready
echo "⏳ Waiting for scylla cluster to be ready..."
for node in $replicas; do
  until docker exec $node cqlsh -e "DESCRIBE KEYSPACES;" >/dev/null 2>&1; do
    echo "Waiting for $node..."
    sleep 5
  done
done

# Set replication factor to 3
docker exec scylla1 cqlsh -e " CREATE KEYSPACE janusgraph WITH REPLICATION = {'class':'NetworkTopologyStrategy','replication_factor':$i}" || exit 1

echo "⏳ Waiting for JanusGraph to be ready..."
while ! docker logs janusgraph 2>&1 | grep -q "Channel started at port 8182"; do
    echo "Waiting for JanusGraph to start..."
    sleep 5
done


echo "🎉 JanusGraph cluster with replication is ready!"
