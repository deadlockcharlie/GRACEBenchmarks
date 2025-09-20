#!/bin/bash

ROOT_DIRECTORY=$(pwd)
DURATION=10 #Benchmark duration in seconds
echo "Benchmark duration: $DURATION seconds"

echo "Root Directory: $ROOT_DIRECTORY"
DEPLOYMENTS_DIR="$ROOT_DIRECTORY/Deployments"


GRACE_DIRECTORY="$ROOT_DIRECTORY/ReplicatedGDB"
LF_DIRECTORY="$ROOT_DIRECTORY/replicatedGDBLF"
YCSB_DIRECTORY="$ROOT_DIRECTORY/YCSB"

DIST_CONF=$ROOT_DIRECTORY"/distribution_config.json"
latencies=(0 50 50 75 50 67.5 50 50 50)



# Eventually this set of commands will be in a loop and potentially parallel?

DATA_DIRECTORY="$ROOT_DIRECTORY/GraphDBData"


datasets=(yeast mico ldbc frbs frbm frbo)

for dataset in "${datasets[@]}"; do
    echo "Starting benchmarks for dataset: $dataset"
DATASET_NAME=$dataset
RESULTS_DIRECTORY="$ROOT_DIRECTORY/Results/ReplicaCountAndLatency/$DATASET_NAME"
LOAD_TIME_DIRECTORY="$ROOT_DIRECTORY/LoadTimes/ReplicaCountAndLatency/$DATASET_NAME"

DATABASES=(GRACE MemGraph Neo4j ArangoDB MongoDB JanusGraph)

# Create results directory if it doesn't exist
mkdir -p $RESULTS_DIRECTORY
for db in "${DATABASES[@]}"; do
    mkdir -p $RESULTS_DIRECTORY/$db
    for i in {1..6}
    do
        echo "" > $RESULTS_DIRECTORY/$db/${i}.txt   
    done
done

for db in "${DATABASES[@]}"; do
    mkdir -p $LOAD_TIME_DIRECTORY/$db
    for i in {1..6}
    do
        echo "" > $LOAD_TIME_DIRECTORY/$db/${i}.txt
    done
done

# cd $YCSB_DIRECTORY
# sudo mvn clean package -DskipTests -q

cd $ROOT_DIRECTORY
. ./ReplicaCountAndLatency.sh

done


cd $ROOT_DIRECTORY
python3 LatencyComparision.py 1 ./Results/ReplicaCountAndLatency/ ./BenchmarkPlots/SingleReplicaLatency.png

python3 LatencyComparision.py 3 ./Results/ReplicaCountAndLatency/ ./BenchmarkPlots/MultiReplicaLatency.png

echo "Benchmarking completed. Results are stored in the Results directory."
