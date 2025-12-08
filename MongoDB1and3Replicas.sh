#loop over 1 to 6 replicas for MongoDB
#!/bin/bash

for i in "${REPLICAS[@]}";
do
    echo "Running benchmark with $i replicas..."
    COMPOSE_FILE="./Dockerfiles/Mongodb${i}Replicas"
    
    cd $DEPLOYMENTS_DIR
    
    . ./MongoDBReplicatedDeployment.sh
    docker exec mongo1 /var/lib/mongodb/import/mongoDBImport.sh mongo1:27017
    
    
    
    
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
                    latency_args="$latency_args mongo${k} ${latency_value}"
                    echo " mongo${j} (${region_codes[$((j-1))]}) -> mongo${k} (${region_codes[$((k-1))]}): ${latency_value}ms"
                fi
            done
            
            echo "Configuring all latencies for mongo${j}..."
            if ! docker exec mongo${j}-netem sh -c "/usr/local/bin/setup-latency.sh mongo${j} $latency_args"; then
                echo "❌ Failed to configure latencies for mongo${j}"
            else
                echo "✅ Configured latencies for mongo${j}"
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

    STATUS_STRING=''
    if [ $INJECT_FAULTS=true ]; then
        STATUS_STRING='-s'
    fi

    # Switch to the YCSB directory
    cd $YCSB_DIRECTORY
    # set dburi containing all replicas
    for j in $(seq 1 $i); do
        if [ $j -eq 1 ]; then
            DBURI="mongodb://localhost:27017"
        else
            DBURI="${DBURI},localhost:$((27017 + j - 1))"
        fi
    done
    echo "Using DBURI: $DBURI"
    #Run the benchmark with graphdb workload
    ycsb_cmd="bin/ycsb.sh run mongodb $STATUS_STRING -P workloads/workload_grace  -p DBTYPE=\"mongodb\" -p DBURI=\"$DBURI/?replicaSet=rs0\" -p maxexecutiontime=${DURATION} -p threadcount=$YCSB_THREADS -p loadVertexFile=$DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json  -p loadEdgeFile=$DATA_DIRECTORY/${DATASET_NAME}_load_edges.json -p vertexAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_vertices.json -p edgeAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_edges.json &> $RESULTS_DIRECTORY/MongoDB/${i}.txt"

    eval $ycsb_cmd & YCSB_PID=$!

    sleep $((DURATION/2))
    if [ $INJECT_FAULTS=true ]; then
        echo "Injecting faults by stopping the primary replica..."
        #simulate a network partition by adding a large latency between R1 and one of the replicas. 

        # docker container stop mongo1
        # Wait for some time to let the system stabilize
        docker exec -it mongo1-netem sh -c "/usr/local/bin/setup-latency.sh mongo1 mongo3 100000"
        sleep 60

        docker container start mongo1
        # Restore normal latency
        docker exec -it mongo1-netem sh -c "/usr/local/bin/setup-latency.sh mongo1 mongo3 50"
        # echo "Network partition resolved."
    fi

    wait $YCSB_PID

    #Shutdown replicas
    cd $DEPLOYMENTS_DIR
    docker compose -f $COMPOSE_FILE down
done
