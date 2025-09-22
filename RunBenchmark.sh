#!/bin/bash

ROOT_DIRECTORY=$(pwd)
PRELOAD=false
DURATION=30 #Benchmark duration in seconds
echo "Benchmark duration: $DURATION seconds"

echo "Root Directory: $ROOT_DIRECTORY"
DEPLOYMENTS_DIR="$ROOT_DIRECTORY/Deployments"


GRACE_DIRECTORY="$ROOT_DIRECTORY/ReplicatedGDB"
LF_DIRECTORY="$ROOT_DIRECTORY/replicatedGDBLF"
YCSB_DIRECTORY="$ROOT_DIRECTORY/YCSB"

DIST_CONF=$ROOT_DIRECTORY"/distribution_config.json"
latencies=(50 50 75 50 67.5 50 50 50)


DATABASES=(GRACE MemGraph Neo4j ArangoDB MongoDB JanusGraph)


# yeast mico ldbc frbs frbm frbo
datasets=(yeast)

# Eventually this set of commands will be in a loop and potentially parallel?

DATA_DIRECTORY="$ROOT_DIRECTORY/GraphDBData"


. ./PrepareDatasets.sh




for dataset in "${datasets[@]}"; do
    echo "Starting benchmarks for dataset: $dataset"
    DATASET_NAME=$dataset
    RESULTS_DIRECTORY="$ROOT_DIRECTORY/Results/ReplicaCountAndLatency/$DATASET_NAME"
    LOAD_TIME_DIRECTORY="$ROOT_DIRECTORY/LoadTimes/ReplicaCountAndLatency/$DATASET_NAME"
    cp $DATA_DIRECTORY/${DATASET_NAME}_load_vertices.loaded $YCSB_DIRECTORY/Vertices.loaded
    cp $DATA_DIRECTORY/${DATASET_NAME}_load_edges.loaded $YCSB_DIRECTORY/Edges.loaded


    cp $DATA_DIRECTORY/${DATASET_NAME}_load_vertices.csv $LF_DIRECTORY/Dockerfiles/PreloadData/vertices.csv
    cp $DATA_DIRECTORY/${DATASET_NAME}_load_edges.csv $YCSB_DIRECTORY/Dockerfiles/PreloadData/edges.csv


    # Create results directory if it doesn't exist
    mkdir -p $RESULTS_DIRECTORY
    for db in "${DATABASES[@]}"; do
        mkdir -p $RESULTS_DIRECTORY/$db
    done

    for db in "${DATABASES[@]}"; do
        mkdir -p $LOAD_TIME_DIRECTORY/$db
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
