# Benchmark with MemGraph
echo "Benchmarking MemGraph with multiple replica configurations"
 export UID
 export GID="$(id -g)"
# Define replica configurations to test

for num_replicas in "${REPLICAS[@]}"; do
    echo "Benchmarking MemGraph with $num_replicas Replica(s)"
    
    # Deploy the replicas
    cd $LF_DIRECTORY

    # Create a distribution configuration
    cat > $DIST_CONF <<EOL
{
  "base_website_port": 7474,
  "base_protocol_port": 7687,
  "base_app_port": 3000,
  "base_prometheus_port": 9090,
  "base_grafana_port": 5000,
  "provider_port": 1234,
  "provider": true,
EOL

    # Handle preload_data logic based on number of replicas
    if [ $num_replicas -eq 1 ]; then
        cat >> $DIST_CONF <<EOL
  "preload_data": true,
  "preload_vertices": "$ROOT_DIRECTORY/GraphDBData/yeast_load_vertices.json",
  "preload_edges": "$ROOT_DIRECTORY/GraphDBData/yeast_load_edges.json",
  "dataset_name": "${DATASET_NAME}",
EOL
    elif [ $num_replicas -eq 2 ]; then
        cat >> $DIST_CONF <<EOL
  "preload_data": true,
  "preload_vertices": "$ROOT_DIRECTORY/GraphDBData/${DATASET_NAME}_load_vertices.json",
  "preload_edges": "$ROOT_DIRECTORY/GraphDBData/${DATASET_NAME}_load_edges.json",
EOL
    else
        cat >> $DIST_CONF <<EOL
  "preload_data": false,
EOL
    fi

    # Add databases array
    echo '  "dbs" : [' >> $DIST_CONF
    
    for ((i=1; i<=num_replicas; i++)); do
        log_level="error"
        # Add database entry
        cat >> $DIST_CONF <<EOL
    {
     "database": "memgraph", 
      "password": "verysecretpassword",
      "user": "pandey",
      "app_log_level": "$log_level"
    } 
EOL
        
        # Add comma if not last entry
        if [ $i -lt $num_replicas ]; then
            echo "," >> $DIST_CONF
        fi
    done
    
    echo '' >> $DIST_CONF
    echo '  ]' >> $DIST_CONF
    echo '}' >> $DIST_CONF

    # Start the replicas
    python3 Deployment.py up $DIST_CONF
    sleep 5

   cd $ROOT_DIRECTORY
    # Wait for server to be ready
    wait_interval=5

    cd $ROOT_DIRECTORY
  . ./waitForPreload.sh

    if [ $num_replicas -gt 1 ]; then
        echo "Adding network latency between replicas..."
        echo "Using AWS inter-region latencies from cloudping.co"
        echo ""
        echo "Latency Matrix (milliseconds):"
        echo "═══════════════════════════════════════════════════════════════════════════"
        
        # Print the matrix header
        printf "%-25s " ""
        for (( col=0; col<num_replicas; col++ )); do
            printf "%-8s " "R$((col+1))"
        done
        echo
        printf "%-25s " ""
        for (( col=0; col<num_replicas; col++ )); do
            printf "%-8s " "(${region_codes[$col]#*-})"
        done
        echo
        echo "───────────────────────────────────────────────────────────────────────────"
        
        # Print the matrix with row labels
        for (( row=0; row<num_replicas; row++ )); do
            printf "R%-2d %-20s " $((row+1)) "${region_names[$row]}"
            for (( col=0; col<num_replicas; col++ )); do
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
        for (( j=1; j<=num_replicas; j++ )); do
            # Build arguments for all peers of container j
            latency_args=""
            for (( k=1; k<=num_replicas; k++ )); do
                if [ $j -ne $k ]; then
                    echo $j $k
                    # Get latency from matrix (convert from 1-indexed to 0-indexed)
                    latency_value=$(get_latency $((j-1)) $((k-1)))
                    latency_args="$latency_args Replica${k} ${latency_value}"
                    echo " Replica${j} (${region_codes[$((j-1))]}) -> Replica${k} (${region_codes[$((k-1))]}): ${latency_value}ms"
                fi
            done
            
            echo "Configuring all latencies for Replica${j}..."
            if ! docker exec Replica${j} sh -c "/usr/local/bin/setup-latency.sh Replica${j} $latency_args"; then
                echo "❌ Failed to configure latencies for Replica${j}"
            else
                echo "✅ Configured latencies for Replica${j}"
            fi
        done
        
        echo ""
        echo "✅ Network latency configuration completed"
        echo ""
        echo "Region Summary:"
        for (( idx=0; idx<num_replicas; idx++ )); do
            echo "  R$((idx+1)): ${region_names[$idx]} (${region_codes[$idx]})"
        done
    else
        echo "Only 1 replica, skipping latency configuration"
    fi

    STATUS_STRING=''
    if [ $INJECT_FAULTS=true ]; then
        STATUS_STRING='-s'
    fi

    # Run the benchmark with grace workload
    echo "Running YCSB benchmark with Grace workload for $num_replicas replicas"
    cd $YCSB_DIRECTORY
    # Build the ycsb command
    ycsb_cmd="bin/ycsb.sh run grace -P workloads/workload_grace $STATUS_STRING\
        -p HOSTURI=\"http://localhost:3000\" \
        -p DBTYPE=\"memgraph\" \
        -p DBURI=\"bolt://localhost:7687\" \
        -p maxexecutiontime=$DURATION \
        -p threadcount=$YCSB_THREADS \
        -p loadVertexFile=$DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json \
        -p loadEdgeFile=$DATA_DIRECTORY/${DATASET_NAME}_load_edges.json \
        -p vertexAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_vertices.json \
        -p edgeAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_edges.json \
        &> $RESULTS_DIRECTORY/MemGraph/$num_replicas.txt"
    
    eval $ycsb_cmd & YCSB_PID=$! 
    sleep $((DURATION/2))
    if [ $INJECT_FAULTS=true ]; then
        echo "Injecting faults by stopping the primary replica..."
        #simulate a network partition by adding a large latency between R1 and one of the replicas. 
        docker exec -it Replica1 sh -c "/usr/local/bin/setup-latency.sh Replica1 Replica2 100000"
        sleep 60
        # Restore normal latency
        docker exec -it Replica1 sh -c "/usr/local/bin/setup-latency.sh Replica1 Replica2 50"
        echo "Network partition resolved."
        
    fi
    wait $YCSB_PID

    # Switch to GRACE directory for cleanup
    cd $LF_DIRECTORY
    
    # Tear down the deployment
    python3 Deployment.py down $DIST_CONF
    
    # Remove the distribution configuration file
    rm $DIST_CONF
    
    echo "Completed benchmarking with $num_replicas replica(s)"
    echo "----------------------------------------"
done

echo "All MemGraph benchmarking completed!"
