#!/bin/bash
set -e


echo "Starting MongoDB replica set..."
docker compose -f $COMPOSE_FILE up -d

echo "Waiting for MongoDB containers to start..."
sleep 10

# Initialize the replica set based on the number of replicas

replicaset=""

if [ $i -gt 1 ]; then
  
for (( j=1; j<=$i; j++ ))
do
  if [ $j -eq 1 ]; then
    replicaset+="{ _id: 0, host: \"mongo1:27017\", \"priority\": 10 },"
    continue
  fi
  replicaset+="{ _id: $((j-1)), host: \"mongo$j:27017\", priority:0 },"
done
replicaset=${replicaset%,} # Remove trailing comma

echo "Initializing replica set..." $replicaset
docker exec mongo1 mongosh --eval '
rs.initiate({
  _id: "rs0",
  members: [
    '"$replicaset"'
  ]
})
'

echo "Setting mongo1 as preferred primary..."
docker exec mongo1 mongosh --eval '
cfg = rs.conf();
cfg.members[0].priority = 10; // mongo1
'


# 🔑 Wait until mongo1 is elected PRIMARY
echo "Waiting for mongo1 to become PRIMARY..."
until docker exec mongo1 mongosh --quiet --eval 'db.hello().isWritablePrimary' | grep true >/dev/null; do
  sleep 2
done



echo "Configuring majority write concern..."
docker exec mongo1 mongosh --eval "
db.adminCommand({
 setDefaultRWConcern: {level:'local'},
 defaultWriteConcern: { w: 'majority' , wtimeout: 5000000}
})
"
fi



echo "✅ MongoDB replica set is ready with quorum writes, mongo1 preferred as primary."
