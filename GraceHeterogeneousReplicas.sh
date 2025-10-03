#!/bin/bash

# Benchmark with GRACE
echo "Benchmarking GRACE with multiple replica and database configurations"

# Define list of databases to test
DATABASES=("neo4j" "arangodb" "mongodb")  # Add your databases here
databaseNames=()
# Function to get database protocol
get_db_protocol() {
    local db_type=$1
    case "$db_type" in
        memgraph|neo4j)
            echo "bolt"
            ;;
        mongodb)
            echo "mongodb"
            ;;
        arangodb)
            echo "http"
            ;;
        *)
            echo "bolt"  # default
            ;;
    esac
}

# Array to track which database is used for each replica
declare -a replica_databases
# Define replica configurations to test
# REPLICAS array should be defined elsewhere in your script
# Iterate through database combinations
for db_config_idx in $(seq 0 3); do

    num_replicas=4
    
    echo "========================================="
    echo "Testing configuration: $num_replicas replicas with $db_config_idx alternate databases with $DATASET_NAME"
    echo "========================================="
    
    # Deploy the replicas
    cd $GRACE_DIRECTORY

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


    # Add databases array
    echo '  "dbs" : [' >> $DIST_CONF
    
    for ((i=1; i<=num_replicas; i++)); do
        # Determine which database to use
        if [ $i -le $((num_replicas - db_config_idx)) ]; then
            # Use memgraph for initial replicas
            current_db="memgraph"
        else
            # Use alternate database from list
            alt_db_idx=$((i - (num_replicas - db_config_idx) - 1))
            alt_db_idx=$((alt_db_idx % $num_replicas))
            current_db="${DATABASES[$alt_db_idx]}"
        fi
        
        # Store database for this replica (for later use in YCSB commands)
        replica_databases[$i]="$current_db"
        log_level="error"
        
        # Add database entry
        cat >> $DIST_CONF <<EOL
    {
     "database": "$current_db", 
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
    
    until curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/ready | grep -q 200; do
        echo "Waiting for server preload to finish..."
        sleep 5
    done

    # # Setup latencies for multi-replica configurations
    # if [ $num_replicas -gt 1 ]; then
    #     latency_cmd="docker exec -it wsserver sh -c \"/usr/local/bin/setup-latency.sh wsserver"
    #     for ((i=2; i<=num_replicas; i++)); do
    #         latency_cmd="$latency_cmd Grace$i \${latencies[$((i-1))]}"
    #     done
    #     latency_cmd="$latency_cmd\""
    #     eval $latency_cmd
    # fi

    sleep 30 # Wait for a while to ensure all YJS updates are propagated are ready

    # Create results directory for this configuration
    CONFIG_RESULTS_DIR="$RESULTS_DIRECTORY/${num_replicas}_replicas_${db_config_idx}_alt_dbs"
    mkdir -p $CONFIG_RESULTS_DIR

    # Run YCSB benchmark with one client per replica
    echo "Running YCSB benchmark with $num_replicas parallel clients"
    cd $YCSB_DIRECTORY
    
    # Array to store background process PIDs
    declare -a ycsb_pids
    
    # Start one YCSB client per replica
    for ((client_id=1; client_id<=num_replicas; client_id++)); do
        # Calculate port offsets for this replica
        port_offset=$((client_id - 1))
        website_port=$((7474 + port_offset))
        protocol_port=$((7687 + port_offset))
        app_port=$((3000 + port_offset))
        
        echo "Starting YCSB client $client_id (targeting ports: website=$website_port, protocol=$protocol_port, app=$app_port)"
        dbProtocol=$(get_db_protocol "${replica_databases[client_id]}")
        dbtype="${replica_databases[client_id]}"
        # Build the ycsb command for this client
        bin/ycsb.sh run grace -P workloads/workload_grace \
            -p HOSTURI="http://localhost:$app_port" \
            -p DBTYPE="$dbtype" \
            -p DBURI="$dbProtocol://localhost:$protocol_port" \
            -p maxexecutiontime=$DURATION \
            -p threadcount=1 \
            -p loadVertexFile=$DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json \
            -p loadEdgeFile=$DATA_DIRECTORY/${DATASET_NAME}_load_edges.json \
            -p vertexAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_vertices.json \
            -p edgeAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_edges.json \
            > $CONFIG_RESULTS_DIR/client_${client_id}.txt 2>&1 &
        
        # Store the PID
        ycsb_pids+=($!)
    done
    
    # Wait for all YCSB clients to complete
    echo "Waiting for all $num_replicas YCSB clients to complete..."
    for pid in "${ycsb_pids[@]}"; do
        wait $pid
        echo "Client with PID $pid completed"
    done
    
    echo "All YCSB clients completed for this configuration"
    
    # # Aggregate results (optional)
    # echo "Aggregating results from all clients..."
    # cat $CONFIG_RESULTS_DIR/client_*.txt > $CONFIG_RESULTS_DIR/aggregated_results.txt

    # Switch to GRACE directory for cleanup
    cd $GRACE_DIRECTORY
    
    # Tear down the deployment
    python3 Deployment.py down $DIST_CONF
    
    # Remove the distribution configuration file
    rm $DIST_CONF
    
    echo "Completed benchmarking with $num_replicas replica(s) and $db_config_idx alternate database(s)"
    echo "----------------------------------------"
done

echo "All GRACE benchmarking completed!"