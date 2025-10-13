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
    sleep 10
  done
done

MAJORITY=$((i / 2 +1))
# Set replication factor to 3
docker exec scylla1 cqlsh -e " CREATE KEYSPACE IF NOT EXISTS janusgraph WITH REPLICATION = {'class':'NetworkTopologyStrategy','replication_factor':$MAJORITY}" || exit 1
    
rm -rf $JANUSGRAPH_DIRECTORY/janusgraph-full-1.1.0
unzip -qq $JANUSGRAPH_DIRECTORY/janusgraph-full-1.1.0.zip -d $JANUSGRAPH_DIRECTORY 
cd $JANUSGRAPH_DIRECTORY/janusgraph-full-1.1.0
cp $ROOT_DIRECTORY/conf/janusgraph-scylla.properties $JANUSGRAPH_DIRECTORY/janusgraph-full-1.1.0/conf
./bin/janusgraph-server.sh start $ROOT_DIRECTORY/conf/janusgraph-server.yaml   
echo "⏳ Waiting for JanusGraph to be ready..."



while true; do
  if curl -s http://localhost:8182 2>&1 | grep -q "no gremlin script supplied"; then
    echo "✅ JanusGraph is ready!"
    break
  fi
  echo "Waiting for JanusGraph to start..."
  sleep 5
done
echo "✅ JanusGraph is ready and accepting connections!"


echo "🎉 JanusGraph cluster with replication is ready!"
