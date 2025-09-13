#!/bin/bash
set -e

COMPOSE_FILE="./Dockerfiles/Mongodb1Replica"

echo "Starting MongoDB replica set..."
docker compose -f $COMPOSE_FILE up -d

echo "Waiting for MongoDB container to start..."

while true; do
  # Try ping via mongosh
  if docker exec mongo1 mongosh --quiet --eval "db.adminCommand('ping')" >/dev/null 2>&1; then
    echo "MongoDB is up!"
    break
  else 
    sleep 2
  fi
done


echo "✅ MongoDB replica is up."
