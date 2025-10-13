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

    
    
    if [ $i -gt 1 ]; then
        echo "Adding network latency between replicas..."
        echo "Using AWS inter-region latencies from cloudping.co"
        echo ""
        echo "Latency Matrix (milliseconds):"
        echo "═══════════════════════════════════════════════════════════════════════════"
        
        # Print the matrix header
        printf "%-25s " ""
        for (( col=0; col<i; col++ )); do
            printf "%-8s " "R$((col+1))"
        done
        echo
        printf "%-25s " ""
        for (( col=0; col<i; col++ )); do
            printf "%-8s " "(${region_codes[$col]#*-})"
        done
        echo
        echo "───────────────────────────────────────────────────────────────────────────"
        
        # Print the matrix with row labels
        for (( row=0; row<i; row++ )); do
            printf "R%-2d %-20s " $((row+1)) "${region_names[$row]}"
            for (( col=0; col<i; col++ )); do
                if [ $row -eq $col ]; then
                    printf "%-8s " "-"
                else
                    printf "%-8d " "$(get_latency $row $col)"
                fi
            done
            echo
        done
        echo "═══════════════════════════════════════════════════════════════════════════"
        echo ""
        
        # Configure latencies for each container
        for (( j=1; j<=i; j++ )); do
            # Build arguments for all peers of container j
            latency_args=""
            for (( k=1; k<=i; k++ )); do
                if [ $j -ne $k ]; then
                    echo $j $k
                    # Get latency from matrix (convert from 1-indexed to 0-indexed)
                    latency_value=$(get_latency $((j-1)) $((k-1)))
                    latency_args="$latency_args scylla${k} ${latency_value}"
                    echo " scylla${j} (${region_codes[$((j-1))]}) -> scylla${k} (${region_codes[$((k-1))]}): ${latency_value}ms"
                fi
            done
            
            echo "Configuring all latencies for scylla${j}..."
            if ! docker exec scylla${j}-netem sh -c "/usr/local/bin/setup-latency.sh scylla${j} $latency_args"; then
                echo "❌ Failed to configure latencies for scylla${j}"
            else
                echo "✅ Configured latencies for scylla${j}"
            fi
        done
        
        echo ""
        echo "✅ Network latency configuration completed"
        echo ""
        echo "Region Summary:"
        for (( idx=0; idx<i; idx++ )); do
            echo "  R$((idx+1)): ${region_names[$idx]} (${region_codes[$idx]})"
        done
    else
        echo "Only 1 replica, skipping latency configuration"
    fi
    # Switch to the YCSB directory
    cd $YCSB_DIRECTORY
    #Run the benchmark with graphdb workload
    bin/ycsb.sh run janusgraph  -P workloads/workload_grace  -p DBTYPE="janusgraph" -p DBURI="ws://localhost:8182" -p maxexecutiontime=$((DURATION * 5)) -p threadcount=$YCSB_THREADS -p loadVertexFile=$DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json  -p loadEdgeFile=$DATA_DIRECTORY/${DATASET_NAME}_load_edges.json -p vertexAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_vertices.json -p edgeAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_edges.json > $RESULTS_DIRECTORY/JanusGraph/${i}.txt

    cd $JANUSGRAPH_DIRECTORY/janusgraph-full-1.1.0
    ./bin/janusgraph-server.sh stop   

    #Shutdown replicas
    cd $DEPLOYMENTS_DIR
    docker compose -f $COMPOSE_FILE down

    

done
