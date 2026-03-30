#!/bin/sh
# Wait for Memgraph to be ready before starting the Node.js app

echo "=== Waiting for Memgraph on localhost:7687 ==="
echo "DATABASE_URI: ${DATABASE_URI}"
echo "Checking if netcat is available: $(which nc)"

max_attempts=60
attempt=0

while [ $attempt -lt $max_attempts ]; do
  # Try to connect to port 7687
  if command -v nc >/dev/null 2>&1; then
    if nc -z localhost 7687 2>/dev/null; then
      echo "✓ Memgraph is ready on port 7687!"
      exit 0
    fi
  elif command -v timeout >/dev/null 2>&1; then
    # Alternative check using timeout
    if timeout 1 bash -c 'cat < /dev/null > /dev/tcp/localhost/7687' 2>/dev/null; then
      echo "✓ Memgraph is ready on port 7687!"
      exit 0
    fi
  fi
  
  attempt=$((attempt + 1))
  echo "Attempt $attempt/$max_attempts: Memgraph not ready yet, waiting..."
  
  # Every 10 attempts, show more diagnostic info
  if [ $((attempt % 10)) -eq 0 ]; then
    echo "--- Diagnostics ---"
    echo "Processes listening:"
    netstat -tln 2>/dev/null || ss -tln 2>/dev/null || echo "netstat/ss not available"
    echo "---"
  fi
  
  sleep 2
done

echo "ERROR: Memgraph did not become ready in time (waited ${max_attempts} attempts)"
echo "This might indicate a problem with the Memgraph container."
exit 1
