# In this benchmark, we measure the latencies of read and write operations for a single replica setup. 
# The aim is to measure the net performance hit of keeping a graph in memory in addition to the underlying database. 


#!/bin/bash

ROOT_DIRECTORY=$(pwd)

echo "Root Directory: $ROOT_DIRECTORY"
DEPLOYMENTS_DIR="$ROOT_DIRECTORY/Deployments"


GRACE_DIRECTORY="$ROOT_DIRECTORY/ReplicatedGDB"
LF_DIRECTORY="$ROOT_DIRECTORY/ReplicatedGDBLF"
YCSB_DIRECTORY="$ROOT_DIRECTORY/YCSB"

DIST_CONF=$ROOT_DIRECTORY"/distribution_config.json"
DATA_DIRECTORY="$ROOT_DIRECTORY/GraphDBData"
DATASET_NAME=freebase_small

RESULTS_DIRECTORY="$ROOT_DIRECTORY/Results/OneReplicaLatencies/$DATASET_NAME"
LOAD_TIME_DIRECTORY="$ROOT_DIRECTORY/LoadTimes/OneReplicaLatencies/$DATASET_NAME"



# Create results directory if it doesn't exist
mkdir -p $RESULTS_DIRECTORY
mkdir -p $RESULTS_DIRECTORY/GRACE
mkdir -p $RESULTS_DIRECTORY/MemGraph
mkdir -p $RESULTS_DIRECTORY/Neo4j
mkdir -p $RESULTS_DIRECTORY/ArangoDB
mkdir -p $RESULTS_DIRECTORY/MongoDB
mkdir -p $RESULTS_DIRECTORY/JanusGraph


mkdir -p $LOAD_TIME_DIRECTORY
mkdir -p $LOAD_TIME_DIRECTORY/GRACE
mkdir -p $LOAD_TIME_DIRECTORY/MemGraph
mkdir -p $LOAD_TIME_DIRECTORY/Neo4j
mkdir -p $LOAD_TIME_DIRECTORY/ArangoDB
mkdir -p $LOAD_TIME_DIRECTORY/MongoDB
mkdir -p $LOAD_TIME_DIRECTORY/JanusGraph


#Compile YCSB
echo "Compiling YCSB"
cd $YCSB_DIRECTORY
sudo mvn -q clean install -DskipTests

# Benchmark with GRACE
echo "Benchmarking with GRACE"
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
    }
  ]
}
EOL

# Start the replicas
python3 Deployment.py up $DIST_CONF
sleep 3
# Switch to the YCSB directory
cd $YCSB_DIRECTORY
# Load the initial data in the DB
 bin/ycsb.sh load grace  -P workloads/workload_grace -p  HOSTURI="http://localhost:3000" -p DBTYPE="memgraph" -p DBURI="bolt://localhost:7687" -p maxexecutiontime=60 -p threadcount=1  -p loadVertexFile=$DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json  -p loadEdgeFile=$DATA_DIRECTORY/${DATASET_NAME}_load_edges.json -p vertexAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_vertices.json -p edgeAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_edges.json > $LOAD_TIME_DIRECTORY/GRACE/load_time.txt

#Run the benchmark with grace workload
echo "Running YCSB benchmark with Grace workload"
bin/ycsb.sh run grace -P workloads/workload_grace -p  HOSTURI="http://localhost:3000" -p DBTYPE="memgraph" -p DBURI="bolt://localhost:7687" -p maxexecutiontime=60 -p threadcount=1 -p loadVertexFile=$DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json  -p loadEdgeFile=$DATA_DIRECTORY/${DATASET_NAME}_load_edges.json -p vertexAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_vertices.json -p edgeAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_edges.json > $RESULTS_DIRECTORY/GRACE/results.txt

# Switch to GRACE directory
cd $GRACE_DIRECTORY
# Tear down the deployment
python3 Deployment.py down $DIST_CONF
# Remove the distribution configuration file
rm $DIST_CONF




# Benchmark with Memgraph
echo "Running YCSB benchmark with Memgraph workload"
#Switch to LF directory
cd $LF_DIRECTORY
#Create a distribution configuration
cat > $DIST_CONF <<EOL
{
  "base_website_port": 7474,
  "base_protocol_port": 7687,
  "base_app_port": 3000,
  "preload_data": false,
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
sleep 3
# Switch to the YCSB directory
cd $YCSB_DIRECTORY
# Load the initial data in the DB
 bin/ycsb.sh load grace  -P workloads/workload_grace -p  HOSTURI="http://localhost:3000" -p DBTYPE="memgraph" -p DBURI="bolt://localhost:7687" -p maxexecutiontime=60 -p threadcount=1  -p loadVertexFile=$DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json  -p loadEdgeFile=$DATA_DIRECTORY/${DATASET_NAME}_load_edges.json -p vertexAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_vertices.json -p edgeAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_edges.json > $LOAD_TIME_DIRECTORY/MemGraph/load_time.txt

#Run the benchmark with graphdb workload
bin/ycsb.sh run grace  -P workloads/workload_grace -p  HOSTURI="http://localhost:3000" -p DBTYPE="memgraph" -p DBURI="bolt://localhost:7687" -p maxexecutiontime=60 -p threadcount=1 -p loadVertexFile=$DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json  -p loadEdgeFile=$DATA_DIRECTORY/${DATASET_NAME}_load_edges.json -p vertexAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_vertices.json -p edgeAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_edges.json  > $RESULTS_DIRECTORY/MemGraph/results.txt
# Switch to LF directory
cd $LF_DIRECTORY
# Tear down the deployment
python3 Deployment.py down $DIST_CONF
# Remove the distribution configuration file
rm $DIST_CONF




# Benchmark with Neo4j
echo "Running YCSB benchmark with Neo4j workload"
#Switch to LF directory
cd $LF_DIRECTORY
#Create a distribution configuration
# Benchmark with Neo4j
echo "Running YCSB benchmark with Neo4j workload"
#Create a distribution configuration
cat > $DIST_CONF <<EOL
{
  "base_website_port": 7474,
  "base_protocol_port": 7687,
  "base_app_port": 3000,
  "preload_data": false,
  "dbs" : [
    {
      "database": "neo4j", 
      "password": "verysecretpassword",
      "user": "pandey",
      "app_log_level": "error"
    }
  ]
}
EOL

# Start the replicas
python3 Deployment.py up $DIST_CONF
sleep 3
# Switch to the YCSB directory
cd $YCSB_DIRECTORY
# Load the initial data in the DB
 bin/ycsb.sh load grace  -P workloads/workload_grace -p  HOSTURI="http://localhost:3000" -p DBTYPE="neo4j" -p DBURI="bolt://localhost:7687" -p maxexecutiontime=60 -p threadcount=1  -p loadVertexFile=$DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json  -p loadEdgeFile=$DATA_DIRECTORY/${DATASET_NAME}_load_edges.json -p vertexAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_vertices.json -p edgeAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_edges.json > $LOAD_TIME_DIRECTORY/Neo4j/load_time.txt
#Run the benchmark with graphdb workload
bin/ycsb.sh run grace  -P workloads/workload_grace -p  HOSTURI="http://localhost:3000" -p DBTYPE="neo4j" -p DBURI="bolt://localhost:7687" -p maxexecutiontime=60 -p threadcount=1 -p loadVertexFile=$DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json  -p loadEdgeFile=$DATA_DIRECTORY/${DATASET_NAME}_load_edges.json -p vertexAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_vertices.json -p edgeAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_edges.json  > $RESULTS_DIRECTORY/Neo4j/results.txt
# Switch to Neo4j directory
cd $LF_DIRECTORY
# Tear down the deployment
python3 Deployment.py down $DIST_CONF
# Remove the distribution configuration file
rm $DIST_CONF




# Benchmark with ArangoDB
echo "Running YCSB benchmark with ArangoDB workload"
#Switch to LF directory
cd $DEPLOYMENTS_DIR
./ArangoDBDeployment.sh #Replication latencies set in this script


# Switch to the YCSB directory
cd $YCSB_DIRECTORY
# Load the initial data in the DB
 bin/ycsb.sh load arangodb  -P workloads/workload_grace -p HOSTURI="http://localhost:3000" -p DBTYPE="arangodb" -p DBURI="http://localhost:8529" -p maxexecutiontime=60 -p threadcount=1  -p loadVertexFile=$DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json  -p loadEdgeFile=$DATA_DIRECTORY/${DATASET_NAME}_load_edges.json -p vertexAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_vertices.json -p edgeAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_edges.json > $LOAD_TIME_DIRECTORY/ArangoDB/load_time.txt
#Run the benchmark with graphdb workload

bin/ycsb.sh run arangodb  -P workloads/workload_grace -p HOSTURI="http://localhost:3000" -p DBTYPE="arangodb" -p DBURI="http://localhost:8529" -p maxexecutiontime=60 -p threadcount=1 -p loadVertexFile=$DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json  -p loadEdgeFile=$DATA_DIRECTORY/${DATASET_NAME}_load_edges.json -p vertexAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_vertices.json -p edgeAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_edges.json  > $RESULTS_DIRECTORY/ArangoDB/results.txt
cd $DEPLOYMENTS_DIR
docker compose -f ./Dockerfiles/ArangoDB1Replica down



# Benchmark with Mongodb
echo "Running YCSB benchmark with Mongodb workload"
cd $DEPLOYMENTS_DIR
./MongodbDeployment.sh #Replication latencies set in this script

# Switch to the YCSB directory
cd $YCSB_DIRECTORY
# Load the initial data in the DB
 bin/ycsb.sh load mongodb  -P workloads/workload_grace  -p DBTYPE="mongodb" -p DBURI="mongodb://localhost:27017" -p maxexecutiontime=60 -p threadcount=1  -p loadVertexFile=$DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json  -p loadEdgeFile=$DATA_DIRECTORY/${DATASET_NAME}_load_edges.json -p vertexAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_vertices.json -p edgeAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_edges.json > $LOAD_TIME_DIRECTORY/MongoDB/load_time.txt
#Run the benchmark with graphdb workload
bin/ycsb.sh run mongodb  -P workloads/workload_grace -p DBTYPE="mongodb" -p DBURI="mongodb://localhost:27017" -p maxexecutiontime=60 -p threadcount=1 -p loadVertexFile=$DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json  -p loadEdgeFile=$DATA_DIRECTORY/${DATASET_NAME}_load_edges.json -p vertexAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_vertices.json -p edgeAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_edges.json  > $RESULTS_DIRECTORY/MongoDB/results.txt

cd $DEPLOYMENTS_DIR
docker compose -f ./Dockerfiles/Mongodb1Replica down

# Benchmark with Janusgraph
echo "Running YCSB benchmark with Janusgraph workload"
cd $DEPLOYMENTS_DIR
./JanusgraphDeployment.sh #Replication latencies set in this script

# Switch to the YCSB directory
cd $YCSB_DIRECTORY
# Load the initial data in the DB
 bin/ycsb.sh load janusgraph  -P workloads/workload_grace  -p DBTYPE="janusgraph" -p DBURI="ws://localhost:8182" -p maxexecutiontime=60 -p threadcount=1  -p loadVertexFile=$DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json  -p loadEdgeFile=$DATA_DIRECTORY/${DATASET_NAME}_load_edges.json -p vertexAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_vertices.json -p edgeAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_edges.json  > $LOAD_TIME_DIRECTORY/JanusGraph/load_time.txt

#Run the benchmark with graphdb workload
bin/ycsb.sh run janusgraph  -P workloads/workload_grace  -p DBTYPE="janusgraph" -p DBURI="ws://localhost:8182" -p maxexecutiontime=60 -p threadcount=1 -p loadVertexFile=$DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json  -p loadEdgeFile=$DATA_DIRECTORY/${DATASET_NAME}_load_edges.json -p vertexAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_vertices.json -p edgeAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_edges.json  > $RESULTS_DIRECTORY/JanusGraph/results.txt
cd $DEPLOYMENTS_DIR
docker compose -f ./Dockerfiles/JanusgraphScyllaDB3Replicas down


echo "Benchmarking completed. Results are stored in the Results directory."

# Plotting the results
cd $ROOT_DIRECTORY
python3 LatencyComparision.py $ROOT_DIRECTORY/Results/OneReplicaLatencies $ROOT_DIRECTORY/BenchmarkPlots/SingleReplicaLatency