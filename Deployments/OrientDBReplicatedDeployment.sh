#!/bin/bash
set -e
COMPOSE_FILE="./Deployments/Dockerfiles/OrientDB3Replicas"


echo "🚀 Starting OrientDB cluster..."
docker compose -f $COMPOSE_FILE up -d

# Wait for nodes to initialize
echo "⏳ Waiting for OrientDB nodes..."
for node in orientdb1 orientdb2 orientdb3; do
  until docker exec $node curl -s http://localhost:2480 >/dev/null 2>&1; do
    echo "Waiting for $node..."
    sleep 5
  done
done
echo "✅ OrientDB nodes are ready."

# Optional: Create a database if not already created
echo "📦 Creating demo database on primary node..."
docker exec orientdb1 bash -c 'echo "CREATE DATABASE remote:localhost/demo root rootpwd plocal;" | /orientdb/bin/console.sh'

echo "🎉 OrientDB distributed cluster is ready!"
echo "Access the web console at http://localhost:2480 (user: root, password: rootpwd)"
