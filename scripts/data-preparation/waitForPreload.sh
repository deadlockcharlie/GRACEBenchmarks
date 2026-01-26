#!/bin/bash
# Wait for all existing preload containers (preload1, preload2, ...) to finish

# Find all containers whose name starts with "preload"
containers=$(docker ps -a --filter "name=^preload" --format "{{.Names}}")

if [ -z "$containers" ]; then
    echo "No preload containers found."
    exit 0
fi

for c in $containers; do
    echo "Waiting for container $c to finish..."
    docker wait "$c" >/dev/null
    exit_code=$(docker inspect -f '{{.State.ExitCode}}' "$c")
    echo "Container $c exited with code $exit_code"
done

echo "All preload containers finished."
