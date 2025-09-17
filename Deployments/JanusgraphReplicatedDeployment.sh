#!/bin/bash
set -e

COMPOSE_FILE="./Dockerfiles/JanusgraphScyllaDB3Replicas"

echo "🚀 Starting scylla and JanusGraph containers..."
docker compose -f $COMPOSE_FILE up -d

# Step 1: Wait for scylla nodes to be ready
echo "⏳ Waiting for scylla cluster to be ready..."
for node in scylla1 scylla2 scylla3; do
  until docker exec $node cqlsh -e "DESCRIBE KEYSPACES;" >/dev/null 2>&1; do
    echo "Waiting for $node..."
    sleep 5
  done
done

# Set replication factor to 3
docker exec scylla1 cqlsh -e " CREATE KEYSPACE janusgraph WITH REPLICATION = {'class':'NetworkTopologyStrategy','replication_factor':3}" || exit 1
# # Set consistency level to QUORUM

# docker exec scylla1 cqlsh -e "CONSISTENCY QUORUM"

# until docker exec scylla1 cqlsh -e "CONSISTENCY" | grep QUORUM >/dev/null 2>&1; do
#   echo "Waiting for consistency level to be set to QUORUM..."
#   sleep 5
# done

#Wait until JanusGraph is ready
echo "⏳ Waiting for JanusGraph to be ready..."
while ! docker logs janusgraph 2>&1 | grep -q "Channel started at port 8182"; do
    echo "Waiting for JanusGraph to start..."
    sleep 5
done


echo "✅ scylla cluster is ready."


# scylla1 → scylla2 = 50ms, scylla1 → scylla3 = 100ms
 docker exec -it scylla1-netem sh -c "/usr/local/bin/setup-latency.sh scylla1 scylla2 50 scylla3 50"

# scylla2 → scylla1 = 50ms, scylla2 → scylla3 = 75ms
docker exec -it scylla2-netem sh -c "/usr/local/bin/setup-latency.sh scylla2 scylla1 50 scylla3 75"

# scylla3 → scylla1 = 100ms, scylla3 → scylla2 = 75ms
docker exec -it scylla3-netem sh -c "/usr/local/bin/setup-latency.sh scylla3 scylla1 100 scylla2 75"



echo "🎉 JanusGraph cluster with replication is ready!"
