# In this benchmark, we measure the latencies of read and write operations for a single replica setup. 
# The aim is to measure the net performance hit of keeping a graph in memory in addition to the underlying database. 


#!/bin/bash

ROOT_DIRECTORY=$(pwd)

echo "Root Directory: $ROOT_DIRECTORY"

GRACE_DIRECTORY="$ROOT_DIRECTORY/ReplicatedGDB"
LF_DIRECTORY="$ROOT_DIRECTORY/ReplicatedGDBLF"
YCSB_DIRECTORY="$ROOT_DIRECTORY/YCSB"

DIST_CONF=$ROOT_DIRECTORY"/distribution_config.json"

RESULTS_DIRECTORY="$ROOT_DIRECTORY/Results/OneReplicaLatencies"

# Create results directory if it doesn't exist
mkdir -p $RESULTS_DIRECTORY
mkdir -p $RESULTS_DIRECTORY/GRACE
mkdir -p $RESULTS_DIRECTORY/MemGraph
mkdir -p $RESULTS_DIRECTORY/Neo4j
mkdir -p $RESULTS_DIRECTORY/ArangoDB
mkdir -p $RESULTS_DIRECTORY/MongoDB

#Compile YCSB
echo "Compiling YCSB"
cd $YCSB_DIRECTORY
mvn -q clean install -DskipTests

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
# Switch to the YCSB directory
cd $YCSB_DIRECTORY
#Run the benchmark with grace workload
echo "Running YCSB benchmark with Grace workload"
bin/ycsb.sh run grace -P workloads/workload_grace -p  HOSTURI="http://localhost:3000" -p DBTYPE="memgraph" -p DBURI="bolt://localhost:7687" -p maxexecutiontime=60 -p threadcount=1 > $RESULTS_DIRECTORY/GRACE/results.txt
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
      "app_log_level": "info"
    }
  ]
}
EOL

# Start the replicas
python3 Deployment.py up $DIST_CONF
# Switch to the YCSB directory
cd $YCSB_DIRECTORY
#Run the benchmark with graphdb workload
bin/ycsb.sh run grace  -P workloads/workload_grace -p  HOSTURI="http://localhost:3000" -p DBTYPE="memgraph" -p DBURI="bolt://localhost:7687" -p maxexecutiontime=60 -p threadcount=1 > $RESULTS_DIRECTORY/MemGraph/results.txt
# Switch to LF directory
cd $LF_DIRECTORY
# Tear down the deployment
python3 Deployment.py down $DIST_CONF
# Remove the distribution configuration file
rm $DIST_CONF





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
      "app_log_level": "info"
    }
  ]
}
EOL

# Start the replicas
python3 Deployment.py up $DIST_CONF
# Switch to the YCSB directory
cd $YCSB_DIRECTORY
#Run the benchmark with graphdb workload
bin/ycsb.sh run grace  -P workloads/workload_grace -p  HOSTURI="http://localhost:3000" -p DBTYPE="neo4j" -p DBURI="bolt://localhost:7687" -p maxexecutiontime=60 -p threadcount=1 > $RESULTS_DIRECTORY/Neo4j/results.txt
# Switch to Neo4j directory
cd $LF_DIRECTORY
# Tear down the deployment
python3 Deployment.py down $DIST_CONF
# Remove the distribution configuration file
rm $DIST_CONF




# Benchmark with ArangoDB
echo "Running YCSB benchmark with ArangoDB workload"
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
      "database": "arangodb", 
      "password": "verysecretpassword",
      "user": "pandey",
      "app_log_level": "info"
    }
  ]
}
EOL

# Start the replicas
python3 Deployment.py up $DIST_CONF
# Switch to the YCSB directory
cd $YCSB_DIRECTORY
#Run the benchmark with graphdb workload
bin/ycsb.sh run grace  -P workloads/workload_grace -p HOSTURI="http://localhost:3000" -p DBTYPE="arangodb" -p DBURI="http://localhost:7687" -p maxexecutiontime=60 -p threadcount=1 > $RESULTS_DIRECTORY/ArangoDB/results.txt
# Switch to ArangoDB directory
cd $LF_DIRECTORY
# Tear down the deployment
python3 Deployment.py down $DIST_CONF
# Remove the distribution configuration file
rm $DIST_CONF


# Benchmark with MongoDB
echo "Running YCSB benchmark with MongoDB workload"
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
      "database": "mongodb", 
      "password": "verysecretpassword",
      "user": "pandey",
      "app_log_level": "info"
    }
  ]
}
EOL

# Start the replicas
python3 Deployment.py up $DIST_CONF
# Switch to the YCSB directory
cd $YCSB_DIRECTORY
#Run the benchmark with graphdb workload
bin/ycsb.sh run grace  -P workloads/workload_grace -p HOSTURI="http://localhost:3000" -p DBTYPE="mongodb" -p DBURI="mongodb://localhost:7687" -p maxexecutiontime=60 -p threadcount=1 > $RESULTS_DIRECTORY/MongoDB/results.txt

# Switch to MongoDB directory
cd $LF_DIRECTORY
# Tear down the deployment
python3 Deployment.py down $DIST_CONF
# Remove the distribution configuration file
rm $DIST_CONF


echo "Benchmarking completed. Results are stored in the Results directory."

# Plotting the results
cd $ROOT_DIRECTORY
python3 LatencyComparision.py $ROOT_DIRECTORY/Results/OneReplicaLatencies $ROOT_DIRECTORY/BenchmarkPlots/SingleReplicaLatency