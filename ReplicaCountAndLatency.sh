# In this benchmark, we measure the latencies of read and write operations for a single replica setup. 
# The aim is to measure the net performance hit of keeping a graph in memory in addition to the underlying database. 


#!/bin/bash

ROOT_DIRECTORY=$(pwd)

echo "Root Directory: $ROOT_DIRECTORY"


DEPLOYMENTS_DIR="$ROOT_DIRECTORY/Deployments"

GRACE_DIRECTORY="$ROOT_DIRECTORY/ReplicatedGDB"
LF_DIRECTORY="$ROOT_DIRECTORY/replicatedGDBLF"
YCSB_DIRECTORY="$ROOT_DIRECTORY/YCSB"

DIST_CONF=$ROOT_DIRECTORY"/distribution_config.json"

RESULTS_DIRECTORY="$ROOT_DIRECTORY/Results/ReplicaCountAndLatency"

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

#Install python dependencies
# pip3 install ./requirements.txt


# # Compile YCSB
# echo "Compiling YCSB"
# cd $YCSB_DIRECTORY
# sudo mvn -q clean install -DskipTests


cd $ROOT_DIRECTORY
. ./Grace1to6Replicas.sh
cd $ROOT_DIRECTORY
. ./Neo4j1to6Replicas.sh
cd $ROOT_DIRECTORY
. ./MemGraph1to6Replicas.sh

echo "Benchmarking completed. Results are stored in the Results directory."


# Plotting the results
cd $ROOT_DIRECTORY
python3 LatencyByReplicaCount.py $ROOT_DIRECTORY/Results/ReplicaCountAndLatency $ROOT_DIRECTORY/BenchmarkPlots
