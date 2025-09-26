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
  "preload_vertices": "/home/pandey/work/GRACEBenchmarks/GraphDBData/yeast_load_vertices.json",
  "preload_edges": "/home/pandey/work/GRACEBenchmarks/GraphDBData/yeast_load_edges.json",
  "dataset_name": "${DATASET_NAME}",
EOL
    elif [ $num_replicas -eq 2 ]; then
        cat >> $DIST_CONF <<EOL
  "preload_data": true,
  "preload_vertices": "/home/pandey/work/GRACEBenchmarks/GraphDBData/${DATASET_NAME}_load_vertices.json",
  "preload_edges": "/home/pandey/work/GRACEBenchmarks/GraphDBData/${DATASET_NAME}_load_edges.json",
EOL
    else
        cat >> $DIST_CONF <<EOL
  "preload_data": false,
EOL
    fi

    # Add databases array
    echo '  "dbs" : [' >> $DIST_CONF
    
    for ((i=1; i<=num_replicas; i++)); do
        # Set log level based on replica count
        if [ $num_replicas -eq 1 ]; then
            log_level="error"
        elif [ $num_replicas -eq 2 ]; then
            log_level="info"
        else
            log_level="error"
        fi
        
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

    # Handle directory navigation for readiness check
    if [ $num_replicas -eq 2 ] || [ $num_replicas -eq 4 ] || [ $num_replicas -eq 5 ] || [ $num_replicas -eq 6 ]; then
        cd $ROOT_DIRECTORY
    fi

    # Wait for server to be ready
    wait_interval=5
    if [ $num_replicas -eq 3 ]; then
        wait_interval=1
    fi
    
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
                    latency_args="$latency_args Replica${k} ${latency_value}"
                    echo "  Replica${j} -> Replica${k}: ${latency_value}ms"
                fi
            done
            
            echo "Configuring all latencies for Replica${j}..."
            if ! docker exec mongo${j}-netem sh -c "/usr/local/bin/setup-latency.sh Replica${j} $latency_args"; then
                echo "❌ Failed to configure latencies for Replica${j}"
            else
                echo "✅ Configured latencies for Replica${j}"
            fi
        done
        
        echo "✅ Network latency configuration completed"
    else
        echo "Only 1 replica, skipping latency configuration"
    fi


    # Run the benchmark with grace workload
    echo "Running YCSB benchmark with Grace workload for $num_replicas replicas"
    cd $YCSB_DIRECTORY
    # Build the ycsb command
    ycsb_cmd="bin/ycsb.sh run grace -P workloads/workload_grace \
        -p HOSTURI=\"http://localhost:3000\" \
        -p DBTYPE=\"memgraph\" \
        -p DBURI=\"bolt://localhost:7687\" \
        -p maxexecutiontime=$DURATION \
        -p threadcount=$YCSB_THREADS \
        -p loadVertexFile=$DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json \
        -p loadEdgeFile=$DATA_DIRECTORY/${DATASET_NAME}_load_edges.json \
        -p vertexAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_vertices.json \
        -p edgeAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_edges.json \
        > $RESULTS_DIRECTORY/MemGraph/$num_replicas.txt"
    
    eval $ycsb_cmd

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


#  # Benchmark with MemGraph
#  echo "Benchmarking MemGraph with 1 Replica"
#  # Deploy the replicas
#  cd $LF_DIRECTORY

#  #Create a distribution configuration
#  cat > $DIST_CONF <<EOL
#  {
#    "base_website_port": 7474,
#    "base_protocol_port": 7687,
#    "base_app_port": 3000,
#    "base_prometheus_port": 9090,
#    "base_grafana_port": 5000,
#    "provider_port": 1234,
#    "provider": false,
#    "preload_data": false,
#    "dbs" : [
#      {
#       "database": "memgraph", 
#        "password": "verysecretpassword",
#        "user": "pandey",
#        "app_log_level": "error"
#      }
#    ]
#  }
# EOL

#  # Start the replicas
#  python3 Deployment.py up $DIST_CONF
#  sleep 5

#  cd $ROOT_DIRECTORY
#  . ./waitForPreload.sh

#  #Run the benchmark with memgraph workload
#  cd $YCSB_DIRECTORY
#  echo "Running YCSB benchmark with Grace workload"
#  bin/ycsb.sh run grace -P workloads/workload_grace -p  HOSTURI="http://localhost:3000" -p DBTYPE="memgraph" -p DBURI="bolt://localhost:7687" -p maxexecutiontime=$DURATION -p threadcount=1 -p loadVertexFile=$DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json  -p loadEdgeFile=$DATA_DIRECTORY/${DATASET_NAME}_load_edges.json -p vertexAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_vertices.json -p edgeAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_edges.json > $RESULTS_DIRECTORY/MemGraph/1.txt
#  # Switch to GRACE directory
#  cd $LF_DIRECTORY
#  # Tear down the deployment
#  python3 Deployment.py down $DIST_CONF
#  # Remove the distribution configuration file
#  rm $DIST_CONF

# # # Benchmark memgraph with 2 replicas
# # cd $LF_DIRECTORY
# # echo "Benchmarking MemGraph with 2 Replicas"
# # #Create a distribution configuration
# # #Create a distribution configuration
# # cat > $DIST_CONF <<EOL
# # {
# #   "base_website_port": 7474,
# #   "base_protocol_port": 7687,
# #   "base_app_port": 3000,
# #   "base_prometheus_port": 9090,
# #   "base_grafana_port": 5000,
# #   "provider_port": 1234,
# #   "provider": false,
# #   "preload_data": false,
# #   "dbs" : [
# #     {
# #      "database": "memgraph", 
# #       "password": "verysecretpassword",
# #       "user": "pandey",
# #       "app_log_level": "error"
# #     },
# #     {
# #      "database": "memgraph", 
# #       "password": "verysecretpassword",
# #       "user": "pandey",
# #       "app_log_level": "error"
# #     }
# #   ]
# # }
# # EOL


# # # Start the replicas
# # python3 Deployment.py up $DIST_CONF
# # sleep 5

# # # Switch to the YCSB directory
# # cd $YCSB_DIRECTORY
# # bin/ycsb.sh load grace  -P workloads/workload_grace -p  HOSTURI="http://localhost:3000" -p DBTYPE="memgraph" -p DBURI="bolt://localhost:7687" -p threadcount=1  -p loadVertexFile=$DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json  -p loadEdgeFile=$DATA_DIRECTORY/${DATASET_NAME}_load_edges.json -p vertexAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_vertices.json -p edgeAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_edges.json > $LOAD_TIME_DIRECTORY/GRACE/2.txt

# # #Setup Latencies
# # # Replica1 → Replica2 = 50ms, Replica1 → Replica3 = 100ms
# # docker exec -it Replica1 sh -c "/usr/local/bin/setup-latency.sh Replica1 Replica2 50 Replica2 50"

# # # Replica2 → Replica1 = 50ms, Replica2 → Replica3 = 75ms
# # docker exec -it Replica2 sh -c "/usr/local/bin/setup-latency.sh Replica2 Replica1 50 Replica1 50"




# # #Run the benchmark with memgraph workload
# # echo "Running YCSB benchmark with Grace workload"
# # bin/ycsb.sh run grace -P workloads/workload_grace -p  HOSTURI="http://localhost:3000" -p DBTYPE="memgraph" -p DBURI="bolt://localhost:7687" -p maxexecutiontime=$DURATION -p threadcount=1 -p loadVertexFile=$DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json  -p loadEdgeFile=$DATA_DIRECTORY/${DATASET_NAME}_load_edges.json -p vertexAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_vertices.json -p edgeAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_edges.json > $RESULTS_DIRECTORY/MemGraph/2.txt
# # # Switch to GRACE directory
# # cd $LF_DIRECTORY
# # # Tear down the deployment
# # python3 Deployment.py down $DIST_CONF
# # # Remove the distribution configuration file
# # rm $DIST_CONF 


# # Benchmark memgraph with 3 replicas
# cd $LF_DIRECTORY
# echo "Benchmarking MemGraph with 3 Replicas"
# #Create a distribution configuration

# cat > $DIST_CONF <<EOL
# {
#   "base_website_port": 7474,
#   "base_protocol_port": 7687,
#   "base_app_port": 3000,
#   "base_prometheus_port": 9090,
#   "base_grafana_port": 5000,
#   "provider_port": 1234,
#   "provider": false,
#   "preload_data": false,
#   "dbs" : [
#     {
#      "database": "memgraph", 
#       "password": "verysecretpassword",
#       "user": "pandey",
#       "app_log_level": "info"
#     },
#     {
#      "database": "memgraph", 
#       "password": "verysecretpassword",
#       "user": "pandey",
#       "app_log_level": "info"
#     }
#     ,
#     {
#      "database": "memgraph", 
#       "password": "verysecretpassword",
#       "user": "pandey",
#       "app_log_level": "info"
#     }
#   ]
# }
# EOL

# # Start the replicas
# python3 Deployment.py up $DIST_CONF

# sleep 5
# cd $ROOT_DIRECTORY
# . ./waitForPreload.sh

# #Setup Latencies
# # Replica1 → Replica2 = 200ms, Replica1 → Replica3 = 600ms
# docker exec -it Replica1 sh -c "/usr/local/bin/setup-latency.sh Replica1 Replica2 100 Replica3 300"

# # # Replica2 → Replica1 = 50ms, Replica2 → Replica3 = 75ms
# # docker exec -it Replica2 sh -c "/usr/local/bin/setup-latency.sh Replica2 Replica1 400 Replica3 400"

# # # Replica3 → Replica1 = 100ms, Replica3 → Replica2 = 75ms
# # docker exec -it Replica3 sh -c "/usr/local/bin/setup-latency.sh Replica3 Replica1 400 Replica2 400"

# cd $YCSB_DIRECTORY
# #Run the benchmark with memgraph workload
# echo "Running YCSB benchmark with Grace workload"
# bin/ycsb.sh run grace -P workloads/workload_grace -p  HOSTURI="http://localhost:3000" -p DBTYPE="memgraph" -p DBURI="bolt://localhost:7687" -p maxexecutiontime=$DURATION -p threadcount=1 -p loadVertexFile=$DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json  -p loadEdgeFile=$DATA_DIRECTORY/${DATASET_NAME}_load_edges.json -p vertexAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_vertices.json -p edgeAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_edges.json > $RESULTS_DIRECTORY/MemGraph/3.txt
# # Switch to GRACE directory
# cd $LF_DIRECTORY
# # Tear down the deployment
# python3 Deployment.py down $DIST_CONF
# # Remove the distribution configuration file
# rm $DIST_CONF


# # # Benchmark neo4j with 4 replicas
# # cd $LF_DIRECTORY
# # echo "Benchmarking Neo4j with 4 Replicas"
# # #Create a distribution configuration 
# # cat > $DIST_CONF <<EOL
# # {
# #   "base_website_port": 7474,
# #   "base_protocol_port": 7687,
# #   "base_app_port": 3000,
# #   "base_prometheus_port": 9090,
# #   "base_grafana_port": 5000,
# #   "provider_port": 1234,
# #   "provider": false,
# #   "preload_data": false,
# #   "dbs" : [
# #     {
# #      "database": "memgraph", 
# #       "password": "verysecretpassword",
# #       "user": "pandey",
# #       "app_log_level": "error"
# #     },
# #     {
# #      "database": "memgraph", 
# #       "password": "verysecretpassword",
# #       "user": "pandey",
# #       "app_log_level": "error"
# #     }
# #     ,
# #     {
# #      "database": "memgraph", 
# #       "password": "verysecretpassword",
# #       "user": "pandey",
# #       "app_log_level": "error"
# #     },
# #     {
# #      "database": "memgraph", 
# #       "password": "verysecretpassword",
# #       "user": "pandey",
# #       "app_log_level": "error"
# #     }
# #   ]
# # }
# # EOL


# # # Start the replicas
# # python3 Deployment.py up $DIST_CONF
# # sleep 5


# # # Switch to the YCSB directory
# # cd $YCSB_DIRECTORY

# # bin/ycsb.sh load grace  -P workloads/workload_grace -p  HOSTURI="http://localhost:3000" -p DBTYPE="neo4j" -p DBURI="bolt://localhost:7687" -p threadcount=1  -p loadVertexFile=$DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json  -p loadEdgeFile=$DATA_DIRECTORY/${DATASET_NAME}_load_edges.json -p vertexAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_vertices.json -p edgeAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_edges.json > $LOAD_TIME_DIRECTORY/MemGraph/4.txt

# # #Setup Latencies
# # # Replica1 → Replica2 = 50ms, Replica1 → Replica3 = 100ms
# # docker exec -it Replica1 sh -c "/usr/local/bin/setup-latency.sh Replica1 Replica2 50 Replica3 50 Replica4 50"

# # # Replica2 → Replica1 = 50ms, Replica2 → Replica3 = 75ms
# # docker exec -it Replica2 sh -c "/usr/local/bin/setup-latency.sh Replica2 Replica1 50 Replica3 50 Replica4 50"

# # # Replica3 → Replica1 = 100ms, Replica3 → Replica2 = 75ms
# # docker exec -it Replica3 sh -c "/usr/local/bin/setup-latency.sh Replica3 Replica1 50 Replica2 50 Replica4 50"

# # # Replica4 → Replica1 = 150ms, Replica4 → Replica2 = 100ms, Replica4 → Replica3 = 50ms
# # docker exec -it Replica4 sh -c "/usr/local/bin/setup-latency.sh Replica4 Replica1 50 Replica2 50 Replica3 50"


# # #Run the benchmark with memgraph workload
# # echo "Running YCSB benchmark with Grace workload"
# # bin/ycsb.sh run grace -P workloads/workload_grace -p  HOSTURI="http://localhost:3000" -p DBTYPE="memgraph" -p DBURI="bolt://localhost:7687" -p maxexecutiontime=$DURATION -p threadcount=1 -p loadVertexFile=$DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json  -p loadEdgeFile=$DATA_DIRECTORY/${DATASET_NAME}_load_edges.json -p vertexAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_vertices.json -p edgeAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_edges.json > $RESULTS_DIRECTORY/MemGraph/4.txt


# # # Switch to GRACE directory
# # cd $LF_DIRECTORY
# # # Tear down the deployment
# # python3 Deployment.py down $DIST_CONF
# # # Remove the distribution configuration file
# # rm $DIST_CONF 


# # # Benchmark memgraph with 5 replicas
# # cd $LF_DIRECTORY
# # echo "Benchmarking MemgGraph with 5 Replicas"
# # #Create a distribution configuration
# # cat > $DIST_CONF <<EOL
# # {
# #   "base_website_port": 7474,
# #   "base_protocol_port": 7687,
# #   "base_app_port": 3000,
# #   "base_prometheus_port": 9090,
# #   "base_grafana_port": 5000,
# #   "provider_port": 1234,
# #   "provider": false,
# #   "preload_data": false,
# #   "dbs" : [
# #     {
# #      "database": "memgraph", 
# #       "password": "verysecretpassword", 
# #       "user": "pandey",
# #       "app_log_level": "error"
# #     },{
# #      "database": "memgraph", 
# #       "password": "verysecretpassword", 
# #       "user": "pandey",
# #       "app_log_level": "error"
# #     },{
# #      "database": "memgraph", 
# #       "password": "verysecretpassword", 
# #       "user": "pandey",
# #       "app_log_level": "error"
# #     },{
# #      "database": "memgraph", 
# #       "password": "verysecretpassword", 
# #       "user": "pandey",
# #       "app_log_level": "error"
# #     },{
# #      "database": "memgraph", 
# #       "password": "verysecretpassword", 
# #       "user": "pandey",
# #       "app_log_level": "error"
# #     }
# #   ]
# # }
# # EOL

# # # Start the replicas
# # python3 Deployment.py up $DIST_CONF
# # sleep 5

# # # Switch to the YCSB directory
# # cd $YCSB_DIRECTORY

# # bin/ycsb.sh load grace  -P workloads/workload_grace -p  HOSTURI="http://localhost:3000" -p DBTYPE="memgraph" -p DBURI="bolt://localhost:7687" -p threadcount=1  -p loadVertexFile=$DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json  -p loadEdgeFile=$DATA_DIRECTORY/${DATASET_NAME}_load_edges.json -p vertexAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_vertices.json -p edgeAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_edges.json > $LOAD_TIME_DIRECTORY/MemGraph/5.txt

# # #Setup Latencies
# # # Replica1 → Replica2 = 50ms, Replica1 → Replica3 = 100ms
# # docker exec -it Replica1 sh -c "/usr/local/bin/setup-latency.sh Replica1 Replica2 50 Replica3 50 Replica4 50 Replica5 50"
# # # Replica2 → Replica1 = 50ms, Replica2 → Replica3 = 75ms
# # docker exec -it Replica2 sh -c "/usr/local/bin/setup-latency.sh Replica2 Replica1 50 Replica3 50 Replica4 50 Replica5 50"
# # # Replica3 → Replica1 = 100ms, Replica3 → Replica2 = 75ms
# # docker exec -it Replica3 sh -c "/usr/local/bin/setup-latency.sh Replica3 Replica1 50 Replica2 50 Replica4 50 Replica5 50"
# # # Replica4 → Replica1 = 150ms, Replica4 → Replica2 = 100ms, Replica4 → Replica3 = 50ms
# # docker exec -it Replica4 sh -c "/usr/local/bin/setup-latency.sh Replica4 Replica1 50 Replica2 50 Replica3 50 Replica5 50"
# # # Replica5 → Replica1 = 150ms, Replica5 → Replica2 = 150
# # docker exec -it Replica5 sh -c "/usr/local/bin/setup-latency.sh Replica5 Replica1 50 Replica2 50 Replica3 50 Replica4 50"

# # #Run the benchmark with memgraph workload
# # echo "Running YCSB benchmark with Grace workload"
# # bin/ycsb.sh run grace -P workloads/workload_grace -p  HOSTURI="http://localhost:3000" -p DBTYPE="memgraph" -p DBURI="bolt://localhost:7687" -p maxexecutiontime=$DURATION -p threadcount=1 -p loadVertexFile=$DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json  -p loadEdgeFile=$DATA_DIRECTORY/${DATASET_NAME}_load_edges.json -p vertexAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_vertices.json -p edgeAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_edges.json > $RESULTS_DIRECTORY/MemGraph/5.txt
# # # Switch to GRACE directory
# # cd $LF_DIRECTORY   
# # # Tear down the deployment
# # python3 Deployment.py down $DIST_CONF
# # # Remove the distribution configuration file
# # rm $DIST_CONF


# # # Benchmark memgraph with 6 replicas
# # cd $LF_DIRECTORY
# # echo "Benchmarking Memgraph with 6 Replicas"
# # #Create a distribution configuration
# # cat > $DIST_CONF <<EOL
# # {
# #   "base_website_port": 7474,
# #   "base_protocol_port": 7687,
# #   "base_app_port": 3000,
# #   "base_prometheus_port": 9090,
# #   "base_grafana_port": 5000,
# #   "provider_port": 1234,
# #   "provider": false,
# #   "preload_data": false,
# #   "dbs" : [
# #     {
# #      "database": "memgraph", 
# #       "password": "verysecretpassword", 
# #       "user": "pandey",
# #       "app_log_level": "error"
# #     },{
# #      "database": "memgraph", 
# #       "password": "verysecretpassword", 
# #       "user": "pandey",
# #       "app_log_level": "error"
# #     },{
# #      "database": "memgraph", 
# #       "password": "verysecretpassword", 
# #       "user": "pandey",
# #       "app_log_level": "error"
# #     },{
# #      "database": "memgraph", 
# #       "password": "verysecretpassword", 
# #       "user": "pandey",
# #       "app_log_level": "error"
# #     },{
# #      "database": "memgraph", 
# #       "password": "verysecretpassword", 
# #       "user": "pandey",
# #       "app_log_level": "error"
# #     },
# #     {
# #      "database": "memgraph", 
# #       "password": "verysecretpassword", 
# #       "user": "pandey",
# #       "app_log_level": "error"
# #     }
# #   ]
# # }
# # EOL
# # # Start the replicas
# # python3 Deployment.py up $DIST_CONF
# # sleep 5

# # # Switch to the YCSB directory
# # cd $YCSB_DIRECTORY

# # bin/ycsb.sh load grace  -P workloads/workload_grace -p  HOSTURI="http://localhost:3000" -p DBTYPE="memgraph" -p DBURI="bolt://localhost:7687" -p threadcount=1  -p loadVertexFile=$DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json  -p loadEdgeFile=$DATA_DIRECTORY/${DATASET_NAME}_load_edges.json -p vertexAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_vertices.json -p edgeAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_edges.json > $LOAD_TIME_DIRECTORY/MemGraph/6.txt

# # #Setup Latencies
# # # Replica1 → Replica2 = 50ms, Replica1 → Replica3 = 100ms
# # docker exec -it Replica1 sh -c "/usr/local/bin/setup-latency.sh Replica1 Replica2 50 Replica3 50 Replica4 50 Replica5 50 Replica6 50"
# # # Replica2 → Replica1 = 50ms, Replica2 → Replica3 = 75ms
# # docker exec -it Replica2 sh -c "/usr/local/bin/setup-latency.sh Replica2 Replica1 50 Replica3 50 Replica4 50 Replica5 50 Replica6 50"
# # # Replica3 → Replica1 = 100ms, Replica3 → Replica2 = 75ms
# # docker exec -it Replica3 sh -c "/usr/local/bin/setup-latency.sh Replica3 Replica1 50 Replica2 50 Replica4 50 Replica5 50 Replica6 50"
# # # Replica4 → Replica1 = 150ms, Replica4 → Replica2 = 100ms, Replica4 → Replica3 = 50ms
# # docker exec -it Replica4 sh -c "/usr/local/bin/setup-latency.sh Replica4 Replica1 50 Replica2 50 Replica3 50 Replica5 50 Replica6 50"
# # # Replica5 → Replica1 = 150ms, Replica5 → Replica2 = 150
# # docker exec -it Replica5 sh -c "/usr/local/bin/setup-latency.sh Replica5 Replica1 50 Replica2 50 Replica3 50 Replica4 50 Replica6 50"


# # #Run the benchmark with memgraph workload
# # echo "Running YCSB benchmark with Grace workload"
# # bin/ycsb.sh run grace -P workloads/workload_grace -p  HOSTURI="http://localhost:3000" -p DBTYPE="memgraph" -p DBURI="bolt://localhost:7687" -p maxexecutiontime=$DURATION -p threadcount=1 -p loadVertexFile=$DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json  -p loadEdgeFile=$DATA_DIRECTORY/${DATASET_NAME}_load_edges.json -p vertexAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_vertices.json -p edgeAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_edges.json > $RESULTS_DIRECTORY/MemGraph/6.txt
# # # Switch to GRACE directory
# # cd $LF_DIRECTORY  
# # # Tear down the deployment
# # python3 Deployment.py down $DIST_CONF
# # # Remove the distribution configuration file
# # rm $DIST_CONF
