
# # Benchmark with MemGraph
# echo "Benchmarking MemGraph with 1 Replica"
# # Deploy the replicas
# cd $LF_DIRECTORY

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
#       "app_log_level": "error"
#     }
#   ]
# }
# EOL

# # Start the replicas
# python3 Deployment.py up $DIST_CONF
# sleep 5

# cd $ROOT_DIRECTORY

# #Run the benchmark with memgraph workload
# cd $YCSB_DIRECTORY
# echo "Running YCSB benchmark with Grace workload"
# bin/ycsb.sh run grace -P workloads/workload_grace -p  HOSTURI="http://localhost:3000" -p DBTYPE="memgraph" -p DBURI="bolt://localhost:7687" -p maxexecutiontime=$DURATION -p threadcount=1 -p loadVertexFile=$DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json  -p loadEdgeFile=$DATA_DIRECTORY/${DATASET_NAME}_load_edges.json -p vertexAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_vertices.json -p edgeAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_edges.json > $RESULTS_DIRECTORY/MemGraph/1.txt
# # Switch to GRACE directory
# cd $LF_DIRECTORY
# # Tear down the deployment
# python3 Deployment.py down $DIST_CONF
# # Remove the distribution configuration file
# rm $DIST_CONF

# # Benchmark memgraph with 2 replicas
# cd $LF_DIRECTORY
# echo "Benchmarking MemGraph with 2 Replicas"
# #Create a distribution configuration
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

# # Switch to the YCSB directory
# cd $YCSB_DIRECTORY
# bin/ycsb.sh load grace  -P workloads/workload_grace -p  HOSTURI="http://localhost:3000" -p DBTYPE="memgraph" -p DBURI="bolt://localhost:7687" -p threadcount=1  -p loadVertexFile=$DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json  -p loadEdgeFile=$DATA_DIRECTORY/${DATASET_NAME}_load_edges.json -p vertexAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_vertices.json -p edgeAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_edges.json > $LOAD_TIME_DIRECTORY/GRACE/2.txt

# #Setup Latencies
# # Replica1 → Replica2 = 50ms, Replica1 → Replica3 = 100ms
# docker exec -it Replica1 sh -c "/usr/local/bin/setup-latency.sh Replica1 Replica2 50 Replica2 50"

# # Replica2 → Replica1 = 50ms, Replica2 → Replica3 = 75ms
# docker exec -it Replica2 sh -c "/usr/local/bin/setup-latency.sh Replica2 Replica1 50 Replica1 50"




# #Run the benchmark with memgraph workload
# echo "Running YCSB benchmark with Grace workload"
# bin/ycsb.sh run grace -P workloads/workload_grace -p  HOSTURI="http://localhost:3000" -p DBTYPE="memgraph" -p DBURI="bolt://localhost:7687" -p maxexecutiontime=$DURATION -p threadcount=1 -p loadVertexFile=$DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json  -p loadEdgeFile=$DATA_DIRECTORY/${DATASET_NAME}_load_edges.json -p vertexAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_vertices.json -p edgeAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_edges.json > $RESULTS_DIRECTORY/MemGraph/2.txt
# # Switch to GRACE directory
# cd $LF_DIRECTORY
# # Tear down the deployment
# python3 Deployment.py down $DIST_CONF
# # Remove the distribution configuration file
# rm $DIST_CONF 


# Benchmark memgraph with 3 replicas
cd $LF_DIRECTORY
echo "Benchmarking MemGraph with 3 Replicas"
#Create a distribution configuration

cat > $DIST_CONF <<EOL
{
  "base_website_port": 7474,
  "base_protocol_port": 7687,
  "base_app_port": 3000,
  "base_prometheus_port": 9090,
  "base_grafana_port": 5000,
  "provider_port": 1234,
  "provider": false,
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
    }
    ,
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

#Setup Latencies
# Replica1 → Replica2 = 50ms, Replica1 → Replica3 = 100ms
docker exec -it Replica1 sh -c "/usr/local/bin/setup-latency.sh Replica1 Replica2 50 Replica3 50"

# # Replica2 → Replica1 = 50ms, Replica2 → Replica3 = 75ms
# docker exec -it Replica2 sh -c "/usr/local/bin/setup-latency.sh Replica2 Replica1 25 Replica3 32"

# # Replica3 → Replica1 = 100ms, Replica3 → Replica2 = 75ms
# docker exec -it Replica3 sh -c "/usr/local/bin/setup-latency.sh Replica3 Replica1 50 Replica2 50"

cd $YCSB_DIRECTORY
#Run the benchmark with memgraph workload
echo "Running YCSB benchmark with Grace workload"
bin/ycsb.sh run grace -P workloads/workload_grace -p  HOSTURI="http://localhost:3000" -p DBTYPE="memgraph" -p DBURI="bolt://localhost:7687" -p maxexecutiontime=$DURATION -p threadcount=1 -p loadVertexFile=$DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json  -p loadEdgeFile=$DATA_DIRECTORY/${DATASET_NAME}_load_edges.json -p vertexAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_vertices.json -p edgeAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_edges.json > $RESULTS_DIRECTORY/MemGraph/3.txt
# Switch to GRACE directory
cd $LF_DIRECTORY
# Tear down the deployment
python3 Deployment.py down $DIST_CONF
# Remove the distribution configuration file
rm $DIST_CONF


# # Benchmark neo4j with 4 replicas
# cd $LF_DIRECTORY
# echo "Benchmarking Neo4j with 4 Replicas"
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
#       "app_log_level": "error"
#     },
#     {
#      "database": "memgraph", 
#       "password": "verysecretpassword",
#       "user": "pandey",
#       "app_log_level": "error"
#     }
#     ,
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


# # Switch to the YCSB directory
# cd $YCSB_DIRECTORY

# bin/ycsb.sh load grace  -P workloads/workload_grace -p  HOSTURI="http://localhost:3000" -p DBTYPE="neo4j" -p DBURI="bolt://localhost:7687" -p threadcount=1  -p loadVertexFile=$DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json  -p loadEdgeFile=$DATA_DIRECTORY/${DATASET_NAME}_load_edges.json -p vertexAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_vertices.json -p edgeAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_edges.json > $LOAD_TIME_DIRECTORY/MemGraph/4.txt

# #Setup Latencies
# # Replica1 → Replica2 = 50ms, Replica1 → Replica3 = 100ms
# docker exec -it Replica1 sh -c "/usr/local/bin/setup-latency.sh Replica1 Replica2 50 Replica3 50 Replica4 50"

# # Replica2 → Replica1 = 50ms, Replica2 → Replica3 = 75ms
# docker exec -it Replica2 sh -c "/usr/local/bin/setup-latency.sh Replica2 Replica1 50 Replica3 50 Replica4 50"

# # Replica3 → Replica1 = 100ms, Replica3 → Replica2 = 75ms
# docker exec -it Replica3 sh -c "/usr/local/bin/setup-latency.sh Replica3 Replica1 50 Replica2 50 Replica4 50"

# # Replica4 → Replica1 = 150ms, Replica4 → Replica2 = 100ms, Replica4 → Replica3 = 50ms
# docker exec -it Replica4 sh -c "/usr/local/bin/setup-latency.sh Replica4 Replica1 50 Replica2 50 Replica3 50"


# #Run the benchmark with memgraph workload
# echo "Running YCSB benchmark with Grace workload"
# bin/ycsb.sh run grace -P workloads/workload_grace -p  HOSTURI="http://localhost:3000" -p DBTYPE="memgraph" -p DBURI="bolt://localhost:7687" -p maxexecutiontime=$DURATION -p threadcount=1 -p loadVertexFile=$DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json  -p loadEdgeFile=$DATA_DIRECTORY/${DATASET_NAME}_load_edges.json -p vertexAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_vertices.json -p edgeAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_edges.json > $RESULTS_DIRECTORY/MemGraph/4.txt


# # Switch to GRACE directory
# cd $LF_DIRECTORY
# # Tear down the deployment
# python3 Deployment.py down $DIST_CONF
# # Remove the distribution configuration file
# rm $DIST_CONF 


# # Benchmark memgraph with 5 replicas
# cd $LF_DIRECTORY
# echo "Benchmarking MemgGraph with 5 Replicas"
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
#       "app_log_level": "error"
#     },{
#      "database": "memgraph", 
#       "password": "verysecretpassword", 
#       "user": "pandey",
#       "app_log_level": "error"
#     },{
#      "database": "memgraph", 
#       "password": "verysecretpassword", 
#       "user": "pandey",
#       "app_log_level": "error"
#     },{
#      "database": "memgraph", 
#       "password": "verysecretpassword", 
#       "user": "pandey",
#       "app_log_level": "error"
#     },{
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

# # Switch to the YCSB directory
# cd $YCSB_DIRECTORY

# bin/ycsb.sh load grace  -P workloads/workload_grace -p  HOSTURI="http://localhost:3000" -p DBTYPE="memgraph" -p DBURI="bolt://localhost:7687" -p threadcount=1  -p loadVertexFile=$DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json  -p loadEdgeFile=$DATA_DIRECTORY/${DATASET_NAME}_load_edges.json -p vertexAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_vertices.json -p edgeAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_edges.json > $LOAD_TIME_DIRECTORY/MemGraph/5.txt

# #Setup Latencies
# # Replica1 → Replica2 = 50ms, Replica1 → Replica3 = 100ms
# docker exec -it Replica1 sh -c "/usr/local/bin/setup-latency.sh Replica1 Replica2 50 Replica3 50 Replica4 50 Replica5 50"
# # Replica2 → Replica1 = 50ms, Replica2 → Replica3 = 75ms
# docker exec -it Replica2 sh -c "/usr/local/bin/setup-latency.sh Replica2 Replica1 50 Replica3 50 Replica4 50 Replica5 50"
# # Replica3 → Replica1 = 100ms, Replica3 → Replica2 = 75ms
# docker exec -it Replica3 sh -c "/usr/local/bin/setup-latency.sh Replica3 Replica1 50 Replica2 50 Replica4 50 Replica5 50"
# # Replica4 → Replica1 = 150ms, Replica4 → Replica2 = 100ms, Replica4 → Replica3 = 50ms
# docker exec -it Replica4 sh -c "/usr/local/bin/setup-latency.sh Replica4 Replica1 50 Replica2 50 Replica3 50 Replica5 50"
# # Replica5 → Replica1 = 150ms, Replica5 → Replica2 = 150
# docker exec -it Replica5 sh -c "/usr/local/bin/setup-latency.sh Replica5 Replica1 50 Replica2 50 Replica3 50 Replica4 50"

# #Run the benchmark with memgraph workload
# echo "Running YCSB benchmark with Grace workload"
# bin/ycsb.sh run grace -P workloads/workload_grace -p  HOSTURI="http://localhost:3000" -p DBTYPE="memgraph" -p DBURI="bolt://localhost:7687" -p maxexecutiontime=$DURATION -p threadcount=1 -p loadVertexFile=$DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json  -p loadEdgeFile=$DATA_DIRECTORY/${DATASET_NAME}_load_edges.json -p vertexAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_vertices.json -p edgeAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_edges.json > $RESULTS_DIRECTORY/MemGraph/5.txt
# # Switch to GRACE directory
# cd $LF_DIRECTORY   
# # Tear down the deployment
# python3 Deployment.py down $DIST_CONF
# # Remove the distribution configuration file
# rm $DIST_CONF


# # Benchmark memgraph with 6 replicas
# cd $LF_DIRECTORY
# echo "Benchmarking Memgraph with 6 Replicas"
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
#       "app_log_level": "error"
#     },{
#      "database": "memgraph", 
#       "password": "verysecretpassword", 
#       "user": "pandey",
#       "app_log_level": "error"
#     },{
#      "database": "memgraph", 
#       "password": "verysecretpassword", 
#       "user": "pandey",
#       "app_log_level": "error"
#     },{
#      "database": "memgraph", 
#       "password": "verysecretpassword", 
#       "user": "pandey",
#       "app_log_level": "error"
#     },{
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

# # Switch to the YCSB directory
# cd $YCSB_DIRECTORY

# bin/ycsb.sh load grace  -P workloads/workload_grace -p  HOSTURI="http://localhost:3000" -p DBTYPE="memgraph" -p DBURI="bolt://localhost:7687" -p threadcount=1  -p loadVertexFile=$DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json  -p loadEdgeFile=$DATA_DIRECTORY/${DATASET_NAME}_load_edges.json -p vertexAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_vertices.json -p edgeAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_edges.json > $LOAD_TIME_DIRECTORY/MemGraph/6.txt

# #Setup Latencies
# # Replica1 → Replica2 = 50ms, Replica1 → Replica3 = 100ms
# docker exec -it Replica1 sh -c "/usr/local/bin/setup-latency.sh Replica1 Replica2 50 Replica3 50 Replica4 50 Replica5 50 Replica6 50"
# # Replica2 → Replica1 = 50ms, Replica2 → Replica3 = 75ms
# docker exec -it Replica2 sh -c "/usr/local/bin/setup-latency.sh Replica2 Replica1 50 Replica3 50 Replica4 50 Replica5 50 Replica6 50"
# # Replica3 → Replica1 = 100ms, Replica3 → Replica2 = 75ms
# docker exec -it Replica3 sh -c "/usr/local/bin/setup-latency.sh Replica3 Replica1 50 Replica2 50 Replica4 50 Replica5 50 Replica6 50"
# # Replica4 → Replica1 = 150ms, Replica4 → Replica2 = 100ms, Replica4 → Replica3 = 50ms
# docker exec -it Replica4 sh -c "/usr/local/bin/setup-latency.sh Replica4 Replica1 50 Replica2 50 Replica3 50 Replica5 50 Replica6 50"
# # Replica5 → Replica1 = 150ms, Replica5 → Replica2 = 150
# docker exec -it Replica5 sh -c "/usr/local/bin/setup-latency.sh Replica5 Replica1 50 Replica2 50 Replica3 50 Replica4 50 Replica6 50"


# #Run the benchmark with memgraph workload
# echo "Running YCSB benchmark with Grace workload"
# bin/ycsb.sh run grace -P workloads/workload_grace -p  HOSTURI="http://localhost:3000" -p DBTYPE="memgraph" -p DBURI="bolt://localhost:7687" -p maxexecutiontime=$DURATION -p threadcount=1 -p loadVertexFile=$DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json  -p loadEdgeFile=$DATA_DIRECTORY/${DATASET_NAME}_load_edges.json -p vertexAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_vertices.json -p edgeAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_edges.json > $RESULTS_DIRECTORY/MemGraph/6.txt
# # Switch to GRACE directory
# cd $LF_DIRECTORY  
# # Tear down the deployment
# python3 Deployment.py down $DIST_CONF
# # Remove the distribution configuration file
# rm $DIST_CONF
