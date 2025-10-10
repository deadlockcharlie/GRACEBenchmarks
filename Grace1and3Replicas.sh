# Benchmark with GRACE
echo "Benchmarking GRACE with multiple replica configurations"

# Define replica configurations to test

for num_replicas in "${REPLICAS[@]}"; do
    echo "Benchmarking GRACE with $num_replicas Replica(s)"
    
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
    # python3 Deployment.py up $DIST_CONF
    sleep 5

    cd $ROOT_DIRECTORY

    # Wait for server to be ready
    wait_interval=5

    
    # until curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/ready | grep -q 200; do
    #     echo "Waiting for server preload to finish..."
    #     sleep $wait_interval
    # done

    # Setup latencies for multi-replica configurations
    if [ $num_replicas -gt 1 ]; then
        latency_cmd="docker exec -it wsserver sh -c \"/usr/local/bin/setup-latency.sh wsserver"
        for ((i=2; i<=num_replicas; i++)); do
            latency_value=$(get_latency $((0)) $((i-1)))
            echo " wsserver(${region_codes[0]}) -> Replica${i-1} (${region_codes[$((i-1))]}): ${latency_value}ms"
            latency_cmd="$latency_cmd Grace$i ${latency_value}"
        done
        latency_cmd="$latency_cmd\""
        eval $latency_cmd
    fi



    # # Run the benchmark with grace workload
    # echo "Running YCSB benchmark with Grace workload for $num_replicas replicas"
    # cd $YCSB_DIRECTORY
    # # Build the ycsb command
    # ycsb_cmd="bin/ycsb.sh run grace -P workloads/workload_grace \
    #     -p HOSTURI=\"http://localhost:3000\" \
    #     -p DBTYPE=\"memgraph\" \
    #     -p DBURI=\"bolt://localhost:7687\" \
    #     -p maxexecutiontime=$DURATION \
    #     -p threadcount=$YCSB_THREADS \
    #     -p loadVertexFile=$DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json \
    #     -p loadEdgeFile=$DATA_DIRECTORY/${DATASET_NAME}_load_edges.json \
    #     -p vertexAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_vertices.json \
    #     -p edgeAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_edges.json \
    #     > $RESULTS_DIRECTORY/GRACE/$num_replicas.txt"
    
    # eval $ycsb_cmd

    # # Switch to GRACE directory for cleanup
    # cd $GRACE_DIRECTORY
    
    # # Tear down the deployment
    # python3 Deployment.py down $DIST_CONF
    
    # Remove the distribution configuration file
    rm $DIST_CONF
    
    echo "Completed benchmarking with $num_replicas replica(s)"
    echo "----------------------------------------"
done

echo "All GRACE benchmarking completed!"




#  # Benchmark with GRACE
#  echo "Benchmarking GRACE with 1 Replica"
#  # Deploy the replicas
#  cd $GRACE_DIRECTORY

#  #Create a distribution configuration
#  cat > $DIST_CONF <<EOL
#  {
#    "base_website_port": 7474,
#    "base_protocol_port": 7687,
#    "base_app_port": 3000,
#    "base_prometheus_port": 9090,
#    "base_grafana_port": 5000,
#    "provider_port": 1234,
#    "provider": true,
#    "preload_data": true,
#    "preload_vertices": "/home/pandey/work/GRACEBenchmarks/GraphDBData/yeast_load_vertices.json",
#    "preload_edges": "/home/pandey/work/GRACEBenchmarks/GraphDBData/yeast_load_edges.json",
#    "dataset_name": "${DATASET_NAME}",
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

# # cd $ROOT_DIRECTORY
# # . ./waitForPreload.sh


#  # Wait for server to be ready
#  until curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/ready | grep -q 200; do
#      echo "Waiting for server preload to finish..."
#      sleep 5
#  done



#  cd $YCSB_DIRECTORY
#  # Run the benchmark with grace workload
#  echo "Running YCSB benchmark with Grace workload"
#  bin/ycsb.sh run grace -P workloads/workload_grace -p  HOSTURI="http://localhost:3000" -p DBTYPE="memgraph" -p DBURI="bolt://localhost:7687" -p maxexecutiontime=$DURATION -p threadcount=1  -p loadVertexFile=$DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json  -p loadEdgeFile=$DATA_DIRECTORY/${DATASET_NAME}_load_edges.json -p vertexAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_vertices.json -p edgeAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_edges.json > $RESULTS_DIRECTORY/GRACE/1.txt
#  #Switch to GRACE directory
#  cd $GRACE_DIRECTORY
#  # Tear down the deployment
#  python3 Deployment.py down $DIST_CONF
#  # Remove the distribution configuration file
#  rm $DIST_CONF




# echo "Benchmarking GRACE with 2 Replicas "
# # Deploy the replicas
# cd $GRACE_DIRECTORY

# #Create a distribution configuration
# cat > $DIST_CONF <<EOL
# {
#   "base_website_port": 7474,
#   "base_protocol_port": 7687,
#   "base_app_port": 3000,
#   "base_prometheus_port": 9090,
#   "base_grafana_port": 5000,
#   "provider_port": 1234,
#   "provider": true,
#   "preload_data": true,
#   "preload_vertices": "/home/pandey/work/GRACEBenchmarks/GraphDBData/${DATASET_NAME}_load_vertices.json",
#   "preload_edges": "/home/pandey/work/GRACEBenchmarks/GraphDBData/${DATASET_NAME}_load_edges.json",
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
#   ]
# }
# EOL

# # Start the replicas
# python3 Deployment.py up $DIST_CONF
# sleep 5
# cd $ROOT_DIRECTORY
#  # Wait for server to be ready
#  until curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/ready | grep -q 200; do
#      echo "Waiting for server preload to finish..."
#      sleep 5
#  done


# # Provider → Grace2 = 100ms, provider → Grace3 = 150ms
# docker exec -it wsserver sh -c "/usr/local/bin/setup-latency.sh wsserver Grace2 ${latencies[1]}"

# # Switch to the YCSB directory
# cd $YCSB_DIRECTORY

# bin/ycsb.sh load grace  -P workloads/workload_grace -p  HOSTURI="http://localhost:3000" -p DBTYPE="memgraph" -p DBURI="bolt://localhost:7687" -p maxexecutiontime=$DURATION -p threadcount=1  -p loadVertexFile=$DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json  -p loadEdgeFile=$DATA_DIRECTORY/${DATASET_NAME}_load_edges.json -p vertexAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_vertices.json -p edgeAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_edges.json > $LOAD_TIME_DIRECTORY/GRACE/2.txt

# #Run the benchmark with grace workload
# echo "Running YCSB benchmark with Grace workload"
# bin/ycsb.sh run grace -P workloads/workload_grace -p  HOSTURI="http://localhost:3000" -p DBTYPE="memgraph" -p DBURI="bolt://localhost:7687" -p maxexecutiontime=$DURATION -p threadcount=1  -p loadVertexFile=$DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json  -p loadEdgeFile=$DATA_DIRECTORY/${DATASET_NAME}_load_edges.json -p vertexAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_vertices.json -p edgeAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_edges.json > $RESULTS_DIRECTORY/GRACE/2.txt

# # Switch to GRACE directory
# cd $GRACE_DIRECTORY
# # Tear down the deployment
# python3 Deployment.py down $DIST_CONF
# # Remove the distribution configuration file
# rm $DIST_CONF





# echo "Benchmarking GRACE with 3 Replicas "
# # Deploy the replicas
# cd $GRACE_DIRECTORY

# #Create a distribution configuration
# cat > $DIST_CONF <<EOL
# {
#   "base_website_port": 7474,
#   "base_protocol_port": 7687,
#   "base_app_port": 3000,
#   "base_prometheus_port": 9090,
#   "base_grafana_port": 5000,
#   "provider_port": 1234,
#   "provider": true,
#   "preload_data": false,
#   "dbs" : [
#     {
#      "database": "memgraph", 
#       "password": "verysecretpassword",
#       "user": "pandey",
#       "app_log_level": "error"
#     },
#     {
#      "database": "memgraph", 
#       "password": "verysecretpassword",
#       "user": "pandey",
#       "app_log_level": "error"
#     },
#     {
#      "database": "memgraph", 
#       "password": "verysecretpassword",
#       "user": "pandey",
#       "app_log_level": "error"
#     }
#   ]
# }
# EOL

# # Start the replicas
# python3 Deployment.py up $DIST_CONF
# sleep 5


# # Wait for server to be ready
# until curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/ready | grep -q 200; do
#     echo "Waiting for server preload to finish..."
#     sleep 1
# done

# # Provider → Grace2 = 100ms, provider → Grace3 = 150ms
# docker exec -it wsserver sh -c "/usr/local/bin/setup-latency.sh wsserver Grace2 ${latencies[1]} Grace3 ${latencies[2]}"

# cd $YCSB_DIRECTORY
# #Run the benchmark with grace workload
# echo "Running YCSB benchmark with Grace workload"
# bin/ycsb.sh run grace -P workloads/workload_grace -p  HOSTURI="http://localhost:3000" -p DBTYPE="memgraph" -p DBURI="bolt://localhost:7687" -p maxexecutiontime=$DURATION -p threadcount=1  -p loadVertexFile=$DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json  -p loadEdgeFile=$DATA_DIRECTORY/${DATASET_NAME}_load_edges.json -p vertexAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_vertices.json -p edgeAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_edges.json > $RESULTS_DIRECTORY/GRACE/3.txt
# # Switch to GRACE directory
# cd $GRACE_DIRECTORY
# # Tear down the deployment
# python3 Deployment.py down $DIST_CONF
# # Remove the distribution configuration file
# rm $DIST_CONF




# echo "Benchmarking GRACE with 4 Replicas "
# # Deploy the replicas
# cd $GRACE_DIRECTORY

# #Create a distribution configuration
# cat > $DIST_CONF <<EOL
# {
#   "base_website_port": 7474,
#   "base_protocol_port": 7687,
#   "base_app_port": 3000,
#   "base_prometheus_port": 9090,
#   "base_grafana_port": 5000,
#   "provider_port": 1234,
#   "provider": true,
#   "preload_data": false,
#   "dbs" : [
#     {
#      "database": "memgraph", 
#       "password": "verysecretpassword",
#       "user": "pandey",
#       "app_log_level": "error"
#     },
#     {
#      "database": "memgraph", 
#       "password": "verysecretpassword",
#       "user": "pandey",
#       "app_log_level": "error"
#     },
#     {
#      "database": "memgraph", 
#       "password": "verysecretpassword",
#       "user": "pandey",
#       "app_log_level": "error"
#     },
#     {
#      "database": "memgraph", 
#       "password": "verysecretpassword",
#       "user": "pandey",
#       "app_log_level": "error"
#     }
#   ]
# }
# EOL

# # Start the replicas
# python3 Deployment.py up $DIST_CONF
# sleep 5
# cd $ROOT_DIRECTORY
#  # Wait for server to be ready
#  until curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/ready | grep -q 200; do
#      echo "Waiting for server preload to finish..."
#      sleep 5
#  done


# # Provider → Grace2 = 100ms, provider → Grace3 = 150ms
# docker exec -it wsserver sh -c "/usr/local/bin/setup-latency.sh wsserver Grace2 ${latencies[1]} Grace3 ${latencies[2]} Grace4 ${latencies[3]}"

# # Switch to the YCSB directory
# cd $YCSB_DIRECTORY

# bin/ycsb.sh load grace  -P workloads/workload_grace -p  HOSTURI="http://localhost:3000" -p DBTYPE="memgraph" -p DBURI="bolt://localhost:7687" -p maxexecutiontime=$DURATION -p threadcount=1  -p loadVertexFile=$DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json  -p loadEdgeFile=$DATA_DIRECTORY/${DATASET_NAME}_load_edges.json -p vertexAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_vertices.json -p edgeAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_edges.json > $LOAD_TIME_DIRECTORY/GRACE/4.txt

# #Run the benchmark with grace workload
# echo "Running YCSB benchmark with Grace workload"
# bin/ycsb.sh run grace -P workloads/workload_grace -p  HOSTURI="http://localhost:3000" -p DBTYPE="memgraph" -p DBURI="bolt://localhost:7687" -p maxexecutiontime=$DURATION -p threadcount=1  -p loadVertexFile=$DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json  -p loadEdgeFile=$DATA_DIRECTORY/${DATASET_NAME}_load_edges.json -p vertexAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_vertices.json -p edgeAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_edges.json > $RESULTS_DIRECTORY/GRACE/4.txt
# # Switch to GRACE directory
# cd $GRACE_DIRECTORY
# # Tear down the deployment
# python3 Deployment.py down $DIST_CONF
# # Remove the distribution configuration file
# rm $DIST_CONF



# echo "Benchmarking GRACE with 6 Replicas "
# # Deploy the replicas
# cd $GRACE_DIRECTORY

# #Create a distribution configuration
# cat > $DIST_CONF <<EOL
# {
#   "base_website_port": 7474,
#   "base_protocol_port": 7687,
#   "base_app_port": 3000,
#   "base_prometheus_port": 9090,
#   "base_grafana_port": 5000,
#   "provider_port": 1234,
#   "provider": true,
#   "preload_data": false,
#   "dbs" : [
#     {
#      "database": "memgraph", 
#       "password": "verysecretpassword",
#       "user": "pandey",
#       "app_log_level": "error"
#     },
#     {
#      "database": "memgraph", 
#       "password": "verysecretpassword",
#       "user": "pandey",
#       "app_log_level": "error"
#     },
#     {
#      "database": "memgraph", 
#       "password": "verysecretpassword",
#       "user": "pandey",
#       "app_log_level": "error"
#     },
#     {
#      "database": "memgraph", 
#       "password": "verysecretpassword",
#       "user": "pandey",
#       "app_log_level": "error"
#     },
#     {
#      "database": "memgraph", 
#       "password": "verysecretpassword",
#       "user": "pandey",
#       "app_log_level": "error"
#     }
#   ]
# }
# EOL

# # Start the replicas
# python3 Deployment.py up $DIST_CONF
# sleep 5
# cd $ROOT_DIRECTORY
#  # Wait for server to be ready
#  until curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/ready | grep -q 200; do
#      echo "Waiting for server preload to finish..."
#      sleep 5
#  done


# # Provider → Grace2 = 100ms, provider → Grace3 = 150ms
# docker exec -it wsserver sh -c "/usr/local/bin/setup-latency.sh wsserver Grace2 ${latencies[1]} Grace3 ${latencies[2]} Grace4 ${latencies[3]} Grace5 ${latencies[4]}"

# # Switch to the YCSB directory
# cd $YCSB_DIRECTORY
# bin/ycsb.sh load grace  -P workloads/workload_grace -p  HOSTURI="http://localhost:3000" -p DBTYPE="memgraph" -p DBURI="bolt://localhost:7687" -p maxexecutiontime=$DURATION -p threadcount=1  -p loadVertexFile=$DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json  -p loadEdgeFile=$DATA_DIRECTORY/${DATASET_NAME}_load_edges.json -p vertexAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_vertices.json -p edgeAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_edges.json > $LOAD_TIME_DIRECTORY/GRACE/5.txt

# #Run the benchmark with grace workload
# echo "Running YCSB benchmark with Grace workload"
# bin/ycsb.sh run grace -P workloads/workload_grace -p  HOSTURI="http://localhost:3000" -p DBTYPE="memgraph" -p DBURI="bolt://localhost:7687" -p maxexecutiontime=$DURATION -p threadcount=1  -p loadVertexFile=$DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json  -p loadEdgeFile=$DATA_DIRECTORY/${DATASET_NAME}_load_edges.json -p vertexAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_vertices.json -p edgeAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_edges.json > $RESULTS_DIRECTORY/GRACE/5.txt
# # Switch to GRACE directory
# cd $GRACE_DIRECTORY
# # Tear down the deployment
# python3 Deployment.py down $DIST_CONF
# # Remove the distribution configuration file
# rm $DIST_CONF



# echo "Benchmarking GRACE with 6 Replicas "
# # Deploy the replicas
# cd $GRACE_DIRECTORY

# #Create a distribution configuration
# cat > $DIST_CONF <<EOL
# {
#   "base_website_port": 7474,
#   "base_protocol_port": 7687,
#   "base_app_port": 3000,
#   "base_prometheus_port": 9090,
#   "base_grafana_port": 5000,
#   "provider_port": 1234,
#   "provider": true,
#   "preload_data": false,
#   "dbs" : [
#     {
#      "database": "memgraph", 
#       "password": "verysecretpassword",
#       "user": "pandey",
#       "app_log_level": "error"
#     },
#     {
#      "database": "memgraph", 
#       "password": "verysecretpassword",
#       "user": "pandey",
#       "app_log_level": "error"
#     },
#     {
#      "database": "memgraph", 
#       "password": "verysecretpassword",
#       "user": "pandey",
#       "app_log_level": "error"
#     },
#     {
#      "database": "memgraph", 
#       "password": "verysecretpassword",
#       "user": "pandey",
#       "app_log_level": "error"
#     },
#     {
#      "database": "memgraph", 
#       "password": "verysecretpassword",
#       "user": "pandey",
#       "app_log_level": "error"
#     },
#     {
#      "database": "memgraph", 
#       "password": "verysecretpassword",
#       "user": "pandey",
#       "app_log_level": "error"
#     }
#   ]
# }
# EOL

# # Start the replicas
# python3 Deployment.py up $DIST_CONF

# cd $ROOT_DIRECTORY
#  # Wait for server to be ready
#  until curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/ready | grep -q 200; do
#      echo "Waiting for server preload to finish..."
#      sleep 5
#  done


# # Provider → Grace2 = 100ms, provider → Grace3 = 150ms
# docker exec -it wsserver sh -c "/usr/local/bin/setup-latency.sh wsserver Grace2 ${latencies[1]} Grace3 ${latencies[2]} Grace4 ${latencies[3]} Grace5 ${latencies[4]} Grace6 ${latencies[5]}"

# # Switch to the YCSB directory
# cd $YCSB_DIRECTORY

# bin/ycsb.sh load grace  -P workloads/workload_grace -p  HOSTURI="http://localhost:3000" -p DBTYPE="memgraph" -p DBURI="bolt://localhost:7687" -p threadcount=1  -p loadVertexFile=$DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json  -p loadEdgeFile=$DATA_DIRECTORY/${DATASET_NAME}_load_edges.json -p vertexAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_vertices.json -p edgeAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_edges.json > $LOAD_TIME_DIRECTORY/GRACE/6.txt

# #Run the benchmark with grace workload
# echo "Running YCSB benchmark with Grace workload"
# bin/ycsb.sh run grace -P workloads/workload_grace -p  HOSTURI="http://localhost:3000" -p DBTYPE="memgraph" -p DBURI="bolt://localhost:7687" -p maxexecutiontime=$DURATION -p threadcount=1  -p loadVertexFile=$DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json  -p loadEdgeFile=$DATA_DIRECTORY/${DATASET_NAME}_load_edges.json -p vertexAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_vertices.json -p edgeAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_edges.json > $RESULTS_DIRECTORY/GRACE/6.txt
# # Switch to GRACE directory
# cd $GRACE_DIRECTORY
# # Tear down the deployment
# python3 Deployment.py down $DIST_CONF
# # Remove the distribution configuration file
# rm $DIST_CONF



