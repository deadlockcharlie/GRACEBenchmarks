# In this benchmark, we measure the latencies of read and write operations for a single replica setup. 
# The aim is to measure the net performance hit of keeping a graph in memory in addition to the underlying database. 


#!/bin/bash

ROOT_DIRECTORY=$(pwd)

echo "Root Directory: $ROOT_DIRECTORY"


DEPLOYMENTS_DIR="$ROOT_DIRECTORY/Deployments"

GRACE_DIRECTORY="$ROOT_DIRECTORY/ReplicatedGDB"
LF_DIRECTORY="$ROOT_DIRECTORY/replicatedGDBLF"
YCSB_DIRECTORY="$ROOT_DIRECTORY/YCSB"

DATA_DIRECTORY="$ROOT_DIRECTORY/GraphDBData"
DATASET_NAME=yeast


DIST_CONF=$ROOT_DIRECTORY"/distribution_config.json"

RESULTS_DIRECTORY="$ROOT_DIRECTORY/Results/ThreeReplicaLatencies/$DATASET_NAME"
LOAD_TIME_DIRECTORY="$ROOT_DIRECTORY/LoadTimes/ThreeReplicaLatencies/$DATASET_NAME"




ln $DEPLOYMENTS_DIR/setup-latency.sh $GRACE_DIRECTORY
ln $DEPLOYMENTS_DIR/setup-latency.sh $LF_DIRECTORY

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

# Compile YCSB
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

cd $ROOT_DIRECTORY



# Switch to the YCSB directory
cd $YCSB_DIRECTORY

# Load the initial data in the DB
 bin/ycsb.sh load grace  -P workloads/workload_grace -p  HOSTURI="http://localhost:3000" -p DBTYPE="memgraph" -p DBURI="bolt://localhost:7687" -p maxexecutiontime=60 -p threadcount=1  -p loadVertexFile=$DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json  -p loadEdgeFile=$DATA_DIRECTORY/${DATASET_NAME}_load_edges.json -p vertexAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_vertices.json -p edgeAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_edges.json > $LOAD_TIME_DIRECTORY/GRACE/load_time.txt



# Provider → Grace2 = 100ms, provider → Grace3 = 150ms
docker exec -it wsserver sh -c "/usr/local/bin/setup-latency.sh wsserver Grace2 50 Grace3 75"


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

# Switch to the YCSB directory
cd $YCSB_DIRECTORY
# Load the initial data in the DB
 bin/ycsb.sh load grace  -P workloads/workload_grace -p  HOSTURI="http://localhost:3000" -p DBTYPE="memgraph" -p DBURI="bolt://localhost:7687" -p maxexecutiontime=60 -p threadcount=1  -p loadVertexFile=$DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json  -p loadEdgeFile=$DATA_DIRECTORY/${DATASET_NAME}_load_edges.json -p vertexAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_vertices.json -p edgeAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_edges.json > $LOAD_TIME_DIRECTORY/MemGraph/load_time.txt



#Setup Latencies
# Replica1 → Replica2 = 50ms, Replica1 → Replica3 = 100ms
docker exec -it Replica1 sh -c "/usr/local/bin/setup-latency.sh Replica1 Replica2 50 Replica3 100"

# Replica2 → Replica1 = 50ms, Replica2 → Replica3 = 75ms
docker exec -it Replica2 sh -c "/usr/local/bin/setup-latency.sh Replica2 Replica1 50 Replica3 75"

# Replica3 → Replica1 = 100ms, Replica3 → Replica2 = 75ms
docker exec -it Replica3 sh -c "/usr/local/bin/setup-latency.sh Replica3 Replica1 100 Replica2 75"



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
# Switch to Neo4j directory
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
      "database": "neo4j", 
      "password": "verysecretpassword",
      "user": "pandey",
      "app_log_level": "error"
    },
    {
      "database": "neo4j", 
      "password": "verysecretpassword",
      "user": "pandey",
      "app_log_level": "error"
    },
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

# Switch to the YCSB directory
cd $YCSB_DIRECTORY
# Load the initial data in the DB
 bin/ycsb.sh load grace  -P workloads/workload_grace -p  HOSTURI="http://localhost:3000" -p DBTYPE="neo4j" -p DBURI="bolt://localhost:7687" -p maxexecutiontime=60 -p threadcount=1  -p loadVertexFile=$DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json  -p loadEdgeFile=$DATA_DIRECTORY/${DATASET_NAME}_load_edges.json -p vertexAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_vertices.json -p edgeAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_edges.json > $LOAD_TIME_DIRECTORY/Neo4j/load_time.txt
 

#Setup Latencies
# Replica1 → Replica2 = 50ms, Replica1 → Replica3 = 100ms
docker exec -it Replica1 sh -c "/usr/local/bin/setup-latency.sh Replica1 Replica2 50 Replica3 100"

# Replica2 → Replica1 = 50ms, Replica2 → Replica3 = 75ms
docker exec -it Replica2 sh -c "/usr/local/bin/setup-latency.sh Replica2 Replica1 50 Replica3 75"

# Replica3 → Replica1 = 100ms, Replica3 → Replica2 = 75ms
docker exec -it Replica3 sh -c "/usr/local/bin/setup-latency.sh Replica3 Replica1 100 Replica2 75"



# Switch to the YCSB directory
cd $YCSB_DIRECTORY
#Run the benchmark with graphdb workload
bin/ycsb.sh run grace  -P workloads/workload_grace -p  HOSTURI="http://localhost:3000" -p DBTYPE="neo4j" -p DBURI="bolt://localhost:7687" -p maxexecutiontime=60 -p threadcount=1 -p loadVertexFile=$DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json  -p loadEdgeFile=$DATA_DIRECTORY/${DATASET_NAME}_load_edges.json -p vertexAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_vertices.json -p edgeAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_edges.json  > $RESULTS_DIRECTORY/Neo4j/results.txt
# Switch to Neo4j directory
cd $LF_DIRECTORY
# Tear down the deployment
python3 Deployment.py down $DIST_CONF
# Remove the distribution configuration file
rm $DIST_CONF



# Benchmark with Arangodb
echo "Running YCSB benchmark with ArangoDB workload"
cd $DEPLOYMENTS_DIR
./ArangoDBReplicatedDeployment.sh #Replication latencies set in this script


cd $YCSB_DIRECTORY
# Load the initial data in the DB
  bin/ycsb.sh load arangodb  -P workloads/workload_grace  -p DBTYPE="arangodb" -p DBURI="http://localhost:8529" -p maxexecutiontime=60 -p threadcount=1 -p REPLICATION_FACTOR=3 -p loadVertexFile=$DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json  -p loadEdgeFile=$DATA_DIRECTORY/${DATASET_NAME}_load_edges.json -p vertexAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_vertices.json -p edgeAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_edges.json > $LOAD_TIME_DIRECTORY/ArangoDB/load_time.txt


# agent1 → agent2 = 50ms, agent1 → agent3 = 100ms
# docker exec -it agent1-netem sh -c "/usr/local/bin/setup-latency.sh agent1 agent2 50 agent3 100"

# agent2 → agent1 = 50ms, agent2 → agent3 = 75ms
docker exec -it agent2-netem sh -c "/usr/local/bin/setup-latency.sh agent2 agent1 100 agent3 150"

# agent3 → agent1 = 100ms, agent3 → agent2 = 75ms
docker exec -it agent3-netem sh -c "/usr/local/bin/setup-latency.sh agent3 agent1 200 agent2 150"


# dbserver1 → dbserver2 = 50ms, dbserver1 → dbserver3 = 100ms
# docker exec -it dbserver1-netem sh -c "/usr/local/bin/setup-latency.sh dbserver1 dbserver2 50 dbserver3 100"

# dbserver2 → dbserver1 = 50ms, dbserver2 → dbserver3 = 75ms
docker exec -it dbserver2-netem sh -c "/usr/local/bin/setup-latency.sh dbserver2 dbserver1 100 dbserver3 150"

# dbserver3 → dbserver1 = 100ms, dbserver3 → dbserver2 = 75ms
docker exec -it dbserver3-netem sh -c "/usr/local/bin/setup-latency.sh dbserver3 agent1 200 dbserver2 150"


# Switch to the YCSB directory
cd $YCSB_DIRECTORY
#Run the benchmark with graphdb workload
bin/ycsb.sh run arangodb  -P workloads/workload_grace  -p DBTYPE="arangodb" -p DBURI="http://localhost:8529" -p maxexecutiontime=60 -p threadcount=1 -p REPLICATION_FACTOR=3 -p loadVertexFile=$DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json  -p loadEdgeFile=$DATA_DIRECTORY/${DATASET_NAME}_load_edges.json -p vertexAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_vertices.json -p edgeAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_edges.json > $RESULTS_DIRECTORY/ArangoDB/results.txt

#Shutdown replicas
cd $DEPLOYMENTS_DIR
docker compose -f ./Dockerfiles/ArangoDB3Replicas down



# Benchmark with MongoDB
echo "Running YCSB benchmark with MongoDB workload"
cd $DEPLOYMENTS_DIR
./MongoDBReplicatedDeployment.sh #Replication latencies set in this script

# Load the initial data in the DB
  cd $YCSB_DIRECTORY
  bin/ycsb.sh load mongodb  -P workloads/workload_grace  -p DBTYPE="mongodb" -p DBURI="mongodb://localhost:27017" -p maxexecutiontime=60 -p threadcount=1 -p loadVertexFile=$DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json  -p loadEdgeFile=$DATA_DIRECTORY/${DATASET_NAME}_load_edges.json -p vertexAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_vertices.json -p edgeAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_edges.json > $LOAD_TIME_DIRECTORY/MongoDB/load_time.txt

# mongo1 → mongo2 = 50ms, mongo1 → mongo3 = 100ms
# docker exec -it mongo1-netem sh -c "/usr/local/bin/setup-latency.sh mongo1 mongo2 100 mongo3 200"

# # mongo2 → mongo1 = 50ms, mongo2 → mongo3 = 75ms
docker exec -it mongo2-netem sh -c "/usr/local/bin/setup-latency.sh mongo2 mongo1 100"

# # mongo3 → mongo1 = 100ms, mongo3 → mongo2 = 75ms
docker exec -it mongo3-netem sh -c "/usr/local/bin/setup-latency.sh mongo3 mongo1 200"



# Switch to the YCSB directory
cd $YCSB_DIRECTORY
#Run the benchmark with graphdb workload
bin/ycsb.sh run mongodb  -P workloads/workload_grace  -p DBTYPE="mongodb" -p DBURI="mongodb://localhost:27017" -p maxexecutiontime=60 -p threadcount=1 > $RESULTS_DIRECTORY/MongoDB/results.txt

cd $DEPLOYMENTS_DIR
docker compose -f ./Dockerfiles/Mongodb3Replicas down


# Benchmark with Janusgraph
echo "Running YCSB benchmark with Janusgraph workload"
cd $DEPLOYMENTS_DIR
./JanusgraphReplicatedDeployment.sh #Replication latencies set in this script

cd $YCSB_DIRECTORY
# Load the initial data in the DB
  bin/ycsb.sh load janusgraph  -P workloads/workload_grace  -p DBTYPE="janusgraph" -p DBURI="ws://localhost:8182" -p maxexecutiontime=60 -p threadcount=1 -p loadVertexFile=$DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json  -p loadEdgeFile=$DATA_DIRECTORY/${DATASET_NAME}_load_edges.json -p vertexAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_vertices.json -p edgeAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_edges.json > $LOAD_TIME_DIRECTORY/JanusGraph/load_time.txt


# scylla1 → scylla2 = 50ms, scylla1 → scylla3 = 100ms
 docker exec -it scylla1-netem sh -c "/usr/local/bin/setup-latency.sh scylla1 scylla2 50 scylla3 50"

# scylla2 → scylla1 = 50ms, scylla2 → scylla3 = 75ms
docker exec -it scylla2-netem sh -c "/usr/local/bin/setup-latency.sh scylla2 scylla1 50 scylla3 75"

# scylla3 → scylla1 = 100ms, scylla3 → scylla2 = 75ms
docker exec -it scylla3-netem sh -c "/usr/local/bin/setup-latency.sh scylla3 scylla1 100 scylla2 75"


# Switch to the YCSB directory
cd $YCSB_DIRECTORY
#Run the benchmark with graphdb workload
bin/ycsb.sh run janusgraph  -P workloads/workload_grace  -p DBTYPE="janusgraph" -p DBURI="ws://localhost:8182" -p maxexecutiontime=60 -p threadcount=1 -p loadVertexFile=$DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json  -p loadEdgeFile=$DATA_DIRECTORY/${DATASET_NAME}_load_edges.json -p vertexAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_vertices.json -p edgeAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_edges.json > $RESULTS_DIRECTORY/JanusGraph/results.txt

cd $DEPLOYMENTS_DIR
docker compose -f ./Dockerfiles/JanusgraphScyllaDB3Replicas down

echo "Benchmarking completed. Results are stored in the Results directory."


# Plotting the results
cd $ROOT_DIRECTORY
python3 LatencyComparision.py $ROOT_DIRECTORY/Results/ThreeReplicaLatencies $ROOT_DIRECTORY/BenchmarkPlots/MultiReplicaLatency
