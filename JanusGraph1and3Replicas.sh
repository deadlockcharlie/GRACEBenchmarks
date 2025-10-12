#loop over 1 to 6 replicas for MongoDB
#!/bin/bash

# export UID=$(id -u)
# export GID=$(id -g)

for i in "${REPLICAS[@]}";
do
    echo "Running benchmark with $i replicas..."
    COMPOSE_FILE="./Dockerfiles/JanusgraphScyllaDB${i}Replicas"

    cd $DEPLOYMENTS_DIR
    #Setup scylladb cluster
    . ./JanusgraphReplicatedDeployment.sh


    cd $JANUSGRAPH_DIRECTORY/janusgraph-full-1.1.0
    ./bin/gremlin.sh -e $ROOT_DIRECTORY/PreloadData/janusgraphImport.groovy "$ROOT_DIRECTORY/PreloadData" "$ROOT_DIRECTORY/conf/janusgraph-scylla.properties"

    cd $ROOT_DIRECTORY

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
                    latency_args="$latency_args scylla${k} ${latency_value}"
                    echo "  scylla${j} -> scylla${k}: ${latency_value}ms"
                fi
            done

            echo "Configuring all latencies for scylla${j}..."
            if ! docker exec scylla${j}-netem sh -c "/usr/local/bin/setup-latency.sh scylla${j} $latency_args"; then
                echo "❌ Failed to configure latencies for scylla${j}"
            else
                echo "✅ Configured latencies for scylla${j}"
            fi
        done
        
        echo "✅ Network latency configuration completed"
    else
        echo "Only 1 replica, skipping latency configuration"
    fi
    # Switch to the YCSB directory
    cd $YCSB_DIRECTORY
    #Run the benchmark with graphdb workload
    bin/ycsb.sh run janusgraph  -P workloads/workload_grace  -p DBTYPE="janusgraph" -p DBURI="ws://localhost:8182" -p maxexecutiontime=$((DURATION * 3)) -p threadcount=$YCSB_THREADS -p loadVertexFile=$DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json  -p loadEdgeFile=$DATA_DIRECTORY/${DATASET_NAME}_load_edges.json -p vertexAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_vertices.json -p edgeAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_edges.json > $RESULTS_DIRECTORY/JanusGraph/${i}.txt

    cd $JANUSGRAPH_DIRECTORY/janusgraph-full-1.1.0
    ./bin/janusgraph-server.sh stop   

    #Shutdown replicas
    cd $DEPLOYMENTS_DIR
    docker compose -f $COMPOSE_FILE down

    

done
