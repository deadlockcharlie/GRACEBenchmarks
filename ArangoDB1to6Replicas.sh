#loop over 1 to 6 replicas for ArangoDB
#!/bin/bash



for i in 1 3;
do
    echo "Running benchmark with $i replicas..."
    COMPOSE_FILE="./Dockerfiles/ArangoDB${i}Replicas"

    cd $DEPLOYMENTS_DIR

    . ./ArangoDBReplicatedDeployment.sh

    cd $ROOT_DIRECTORY
    . ./waitForPreload.sh

            # Add latency between replicas if more than 1 replica
    if [ $i -gt 1 ]; then
        echo "Adding network latency between replicas..."
        echo "Using latency values: ${latencies[*]}"
        
        # Configure latencies for each container (all peers at once)
        for (( j=1; j<=i; j++ )); do
            # Build arguments for all peers of container j
            latency_args=""
            
            for (( k=1; k<=i; k++ )); do
                if [ $j -ne $k ]; then
                    # Use the same latency calculation as before
                    if [ $j -lt $k ]; then
                        latency_index=$(( (j + k - 2) % ${#latencies[@]} ))
                    else
                        latency_index=$(( (k + j - 2) % ${#latencies[@]} ))
                    fi
                    latency_value=${latencies[$latency_index]}
                    latency_args="$latency_args dbserver${k} ${latency_value}"
                    echo "  dbserver${j} -> dbserver${k}: ${latency_value}ms"
                fi
            done
            
            echo "Configuring all latencies for dbserver${j}..."
            if ! docker exec dbserver${j}-netem sh -c "/usr/local/bin/setup-latency.sh dbserver${j} $latency_args"; then
                echo "❌ Failed to configure latencies for dbserver${j}"
            else
                echo "✅ Configured latencies for dbserver${j}"
            fi
        done
        
        echo "✅ Network latency configuration completed"
    else
        echo "Only 1 replica, skipping latency configuration"
    fi


    # Switch to the YCSB directory
    cd $YCSB_DIRECTORY
    #Run the benchmark with graphdb workload
    bin/ycsb.sh run arangodb  -P workloads/workload_grace  -p DBTYPE="arangodb" -p DBURI="http://localhost:8529"  -p REPLICATION_FACTOR=$i -p maxexecutiontime=${DURATION} -p threadcount=1 -p loadVertexFile=$DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json  -p loadEdgeFile=$DATA_DIRECTORY/${DATASET_NAME}_load_edges.json -p vertexAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_vertices.json -p edgeAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_edges.json > $RESULTS_DIRECTORY/ArangoDB/${i}.txt

    #Shutdown replicas
    cd $DEPLOYMENTS_DIR
    docker compose -f $COMPOSE_FILE down
done
