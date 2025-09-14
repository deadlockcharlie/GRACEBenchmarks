#!/bin/bash
set -e

COMPOSE_FILE="./Dockerfiles/Mongodb3Replicas"

echo "Starting MongoDB replica set..."
docker compose -f $COMPOSE_FILE up -d

echo "Waiting for MongoDB containers to start..."
sleep 10

echo "Initializing replica set..."
docker exec mongo1 mongosh --eval '
rs.initiate({
  _id: "rs0",
  members: [
    { _id: 0, host: "mongo1:27017" },
    { _id: 1, host: "mongo2:27017" },
    { _id: 2, host: "mongo3:27017" }
  ]
})
'

# 🔑 Wait until mongo1 is elected PRIMARY
echo "Waiting for mongo1 to become PRIMARY..."
until docker exec mongo1 mongosh --quiet --eval 'db.hello().isWritablePrimary' | grep true >/dev/null; do
  sleep 2
done

echo "Configuring majority write concern..."
docker exec mongo1 mongosh --eval '
db.adminCommand({
  setDefaultRWConcern: 1,
  defaultWriteConcern: { w: "majority" }
})
'

echo "Setting mongo1 as preferred primary..."
docker exec mongo1 mongosh --eval '
cfg = rs.conf();
cfg.members[0].priority = 2; // mongo1
cfg.members[1].priority = 1; // mongo2
cfg.m
'


# mongo1 → mongo2 = 50ms, mongo1 → mongo3 = 100ms
docker exec -it mongo1-netem sh -c "/usr/local/bin/setup-latency.sh mongo1 mongo2 50 mongo3 100"

# mongo2 → mongo1 = 50ms, mongo2 → mongo3 = 75ms
docker exec -it mongo2-netem sh -c "/usr/local/bin/setup-latency.sh mongo2 mongo1 50 mongo3 75"

# mongo3 → mongo1 = 100ms, mongo3 → mongo2 = 75ms
docker exec -it mongo3-netem sh -c "/usr/local/bin/setup-latency.sh mongo3 mongo1 100 mongo2 75"


echo "✅ MongoDB replica set is ready with quorum writes, mongo1 preferred as primary."
