#!/bin/bash

ROOT_DIRECTORY=$(pwd)
DURATION=60 #Benchmark duration in seconds
echo "Benchmark duration: $DURATION seconds"

echo "Root Directory: $ROOT_DIRECTORY"
DEPLOYMENTS_DIR="$ROOT_DIRECTORY/Deployments"


GRACE_DIRECTORY="$ROOT_DIRECTORY/ReplicatedGDB"
LF_DIRECTORY="$ROOT_DIRECTORY/ReplicatedGDBLF"
YCSB_DIRECTORY="$ROOT_DIRECTORY/YCSB"

DIST_CONF=$ROOT_DIRECTORY"/distribution_config.json"
latencies=(0 50 150 150 100 125)



# Eventually this set of commands will be in a loop and potentially parallel?

DATA_DIRECTORY="$ROOT_DIRECTORY/GraphDBData"


datasets=(yeast mico ldbc frbo frbs frbm)

for dataset in "${datasets[@]}"; do
    echo "Starting benchmarks for dataset: $dataset"
DATASET_NAME=$dataset
RESULTS_DIRECTORY="$ROOT_DIRECTORY/Results/ReplicaCountAndLatency/$DATASET_NAME"
LOAD_TIME_DIRECTORY="$ROOT_DIRECTORY/LoadTimes/ReplicaCountAndLatency/$DATASET_NAME"



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


cd $YCSB_DIRECTORY
sudo mvn clean package -DskipTests -q

cd $ROOT_DIRECTORY
. ./ReplicaCountAndLatency.sh

done


cd $ROOT_DIRECTORY
python3 LatencyComparision.py 1 ./Results/ReplicaCountAndLatency/ ./BenchmarkPlots/SingleReplicaLatency.png

python3 LatencyComparision.py 3 ./Results/ReplicaCountAndLatency/ ./BenchmarkPlots/MultiReplicaLatency.png

echo "Benchmarking completed. Results are stored in the Results directory."