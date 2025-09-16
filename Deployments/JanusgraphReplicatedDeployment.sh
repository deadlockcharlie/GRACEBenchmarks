#!/bin/bash
set -e

COMPOSE_FILE="./Dockerfiles/JanusgraphCassandra3Replicas"

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


docker exec cassandra1 cqlsh -e "
CREATE KEYSPACE janusgraph
WITH REPLICATION = {'class':'NetworkTopologyStrategy','replication_factor':3}
"

docker run -d \
  --name janusgraph \
  --network dockerfiles_janus-net \
  -p 8182:8182 \
  -e JANUSGRAPH_STORAGE_BACKEND=cql \
  -e JANUSGRAPH_STORAGE_HOSTS=cassandra1 \
  janusgraph/janusgraph:latest

echo "✅ Cassandra cluster is ready."


# cassandra1 → cassandra2 = 50ms, cassandra1 → cassandra3 = 100ms
 docker exec -it cassandra1-netem sh -c "/usr/local/bin/setup-latency.sh cassandra1 cassandra2 50 cassandra3 50"

# cassandra2 → cassandra1 = 50ms, cassandra2 → cassandra3 = 75ms
docker exec -it cassandra2-netem sh -c "/usr/local/bin/setup-latency.sh cassandra2 cassandra1 50 cassandra3 75"

# cassandra3 → cassandra1 = 100ms, cassandra3 → cassandra2 = 75ms
docker exec -it cassandra3-netem sh -c "/usr/local/bin/setup-latency.sh cassandra3 cassandra1 100 cassandra2 75"



echo "🎉 JanusGraph cluster with replication is ready!"
