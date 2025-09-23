
# Benchmark with GRACE
echo "Benchmarking GRACE with 1 Replica"
# Deploy the replicas
cd $GRACE_DIRECTORY

#Create a distribution configuration
cat > $DIST_CONF <<EOL
{
  "base_website_port": 7474,
  "base_protocol_port": 7687,
  "base_app_port": 3000,
  "base_prometheus_port": 9090,
  "base_grafana_port": 5000,
  "provider_port": 1234,
  "provider": true,
  "preload_data": true,
  "preload_vertices": "/home/pandey/work/GRACEBenchmarks/GraphDBData/yeast_load_vertices.json",
  "preload_edges": "/home/pandey/work/GRACEBenchmarks/GraphDBData/yeast_load_edges.json",
  "dataset_name": "${DATASET_NAME}",
  "dbs" : [
    {
     "database": "memgraph", 
      "password": "verysecretpassword",
      "user": "pandey",
      "app_log_level": "error"
    }
  ]
}
EOL

# Start the replicas
python3 Deployment.py up $DIST_CONF
sleep 5


cd $YCSB_DIRECTORY
# Run the benchmark with grace workload
echo "Running YCSB benchmark with Grace workload"
bin/ycsb.sh run grace -P workloads/workload_grace -p  HOSTURI="http://localhost:3000" -p DBTYPE="memgraph" -p DBURI="bolt://localhost:7687" -p maxexecutiontime=$DURATION -p threadcount=1  -p loadVertexFile=$DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json  -p loadEdgeFile=$DATA_DIRECTORY/${DATASET_NAME}_load_edges.json -p vertexAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_vertices.json -p edgeAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_edges.json > $RESULTS_DIRECTORY/GRACE/1.txt
Switch to GRACE directory
cd $GRACE_DIRECTORY
# Tear down the deployment
python3 Deployment.py down $DIST_CONF
# Remove the distribution configuration file
rm $DIST_CONF

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





echo "Benchmarking GRACE with 3 Replicas "
# Deploy the replicas
cd $GRACE_DIRECTORY

#Create a distribution configuration
cat > $DIST_CONF <<EOL
{
  "base_website_port": 7474,
  "base_protocol_port": 7687,
  "base_app_port": 3000,
  "base_prometheus_port": 9090,
  "base_grafana_port": 5000,
  "provider_port": 1234,
  "provider": true,
  "preload_data": false,
  "dbs" : [
    {
     "database": "memgraph", 
      "password": "verysecretpassword",
      "user": "pandey",
      "app_log_level": "error"
    },
    {
     "database": "memgraph", 
      "password": "verysecretpassword",
      "user": "pandey",
      "app_log_level": "error"
    },
    {
     "database": "memgraph", 
      "password": "verysecretpassword",
      "user": "pandey",
      "app_log_level": "error"
    }
  ]
}
EOL

# Start the replicas
python3 Deployment.py up $DIST_CONF
sleep 5

# Provider → Grace2 = 100ms, provider → Grace3 = 150ms
docker exec -it wsserver sh -c "/usr/local/bin/setup-latency.sh wsserver Grace2 ${latencies[1]} Grace3 ${latencies[2]}"

cd $YCSB_DIRECTORY
#Run the benchmark with grace workload
echo "Running YCSB benchmark with Grace workload"
bin/ycsb.sh run grace -P workloads/workload_grace -p  HOSTURI="http://localhost:3000" -p DBTYPE="memgraph" -p DBURI="bolt://localhost:7687" -p maxexecutiontime=$DURATION -p threadcount=1  -p loadVertexFile=$DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json  -p loadEdgeFile=$DATA_DIRECTORY/${DATASET_NAME}_load_edges.json -p vertexAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_vertices.json -p edgeAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_edges.json > $RESULTS_DIRECTORY/GRACE/3.txt
# Switch to GRACE directory
cd $GRACE_DIRECTORY
# Tear down the deployment
python3 Deployment.py down $DIST_CONF
# Remove the distribution configuration file
rm $DIST_CONF




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



