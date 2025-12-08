#!/bin/bash

ROOT_DIRECTORY=$(pwd)
PRELOAD=false
DURATION=120 #Benchmark duration in seconds
echo "Benchmark duration: $DURATION seconds"
INJECT_FAULTS=false
echo "Root Directory: $ROOT_DIRECTORY"
DEPLOYMENTS_DIR="$ROOT_DIRECTORY/Deployments"
GRACE_DIRECTORY="$ROOT_DIRECTORY/ReplicatedGDB"
LF_DIRECTORY="$ROOT_DIRECTORY/replicatedGDBLF"
YCSB_DIRECTORY="$ROOT_DIRECTORY/YCSB"
PRELOAD_DATA="$ROOT_DIRECTORY/PreloadData"
export PRELOAD_DATA="$ROOT_DIRECTORY/PreloadData"


JANUSGRAPH_DIRECTORY="$ROOT_DIRECTORY/JanusgraphServer"
mkdir -p $JANUSGRAPH_DIRECTORY
cd $JANUSGRAPH_DIRECTORY
if [ ! -f "./janusgraph-full-1.1.0.zip" ]; then
    wget -P . https://github.com/JanusGraph/janusgraph/releases/download/v1.1.0/janusgraph-full-1.1.0.zip
fi




DIST_CONF=$ROOT_DIRECTORY"/distribution_config.json"
# latencies=(54 147 54 54 54 54 54 54 54)
# latencies=(0 1 2 3 4 5 6 7 0 0)
# Use associative array for reliable cross-shell compatibility
declare -A latency_matrix

# Helper function to get/set matrix element
get_latency() {
    local r=$1
    local c=$2
    local key="${r},${c}"
    echo "${latency_matrix[$key]}"
}

set_latency() {
    local r=$1
    local c=$2
    local value=$3
    local key="${r},${c}"
    latency_matrix[$key]=$value
}

# AWS Region latencies from cloudping.co (in milliseconds)
# Region mapping (index 0-5):
# 0: us-east-1 (N. Virginia)
# 1: us-west-2 (Oregon)
# 2: eu-central-1 (Frankfurt)
# 3: ap-south-1 (Mumbai)
# 4: ap-southeast-1 (Singapore)
# 5: sa-east-1 (São Paulo)

# Initialize the symmetric latency matrix with actual AWS latencies
# Row 0: us-east-1
set_latency 0 0 0
set_latency 0 1 33
set_latency 0 2 48
set_latency 0 3 104
set_latency 0 4 111
set_latency 0 5 57

# Row 1: us-west-2
set_latency 1 0 33
set_latency 1 1 0
set_latency 1 2 72
set_latency 1 3 112
set_latency 1 4 83
set_latency 1 5 89

# Row 2: eu-central-1
set_latency 2 0 48
set_latency 2 1 72
set_latency 2 2 0
set_latency 2 3 65
set_latency 2 4 81
set_latency 2 5 102

# Row 3: ap-south-1
set_latency 3 0 104
set_latency 3 1 112
set_latency 3 2 65
set_latency 3 3 0
set_latency 3 4 33
set_latency 3 5 152

# Row 4: ap-southeast-1
set_latency 4 0 111
set_latency 4 1 83
set_latency 4 2 81
set_latency 4 3 33
set_latency 4 4 0
set_latency 4 5 166

# Row 5: sa-east-1
set_latency 5 0 57
set_latency 5 1 89
set_latency 5 2 102
set_latency 5 3 152
set_latency 5 4 166
set_latency 5 5 0

# Region names and codes for display
region_names=("US East (Virginia)" "US West (Oregon)" "EU Central (Frankfurt)" "AP South (Mumbai)" "AP Southeast (Singapore)" "SA East (São Paulo)")
region_codes=("us-east-1" "us-west-2" "eu-central-1" "ap-south-1" "ap-southeast-1" "sa-east-1")


DATABASES=(GRACE MemGraph Neo4j ArangoDB MongoDB JanusGraph)


# yeast mico ldbc frbs frbm frbo
datasets=(yeast mico ldbc frbs frbm frbo)



# Eventually this set of commands will be in a loop and potentially parallel?

DATA_DIRECTORY="$ROOT_DIRECTORY/GraphDBData"





## Replication and Latency Benchmarks
REPLICAS=( 3 2 4 5 6)
YCSB_THREADS=1
for dataset in "${datasets[@]}"; do
    
    echo "Starting benchmarks for dataset: $dataset"
    DATASET_NAME=$dataset
    cd $ROOT_DIRECTORY
    . ./PrepareDatasets.sh
    RESULTS_DIRECTORY="$ROOT_DIRECTORY/Results/ReplicaCountAndLatency/$DATASET_NAME"
    LOAD_TIME_DIRECTORY="$ROOT_DIRECTORY/LoadTimes/ReplicaCountAndLatency/$DATASET_NAME"
    cp $DATA_DIRECTORY/${DATASET_NAME}_load_vertices.loaded $YCSB_DIRECTORY/Vertices.loaded
    cp $DATA_DIRECTORY/${DATASET_NAME}_load_edges.loaded $YCSB_DIRECTORY/Edges.loaded
    
    
    cp $DATA_DIRECTORY/${DATASET_NAME}_load_vertices.csv $PRELOAD_DATA/vertices.csv
    cp $DATA_DIRECTORY/${DATASET_NAME}_load_edges.csv $PRELOAD_DATA/edges.csv
    cp $DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json $PRELOAD_DATA/vertices.json
    cp $DATA_DIRECTORY/${DATASET_NAME}_load_edges.json $PRELOAD_DATA/edges.json
    cp $DATA_DIRECTORY/${DATASET_NAME}_load_vertices.keys $PRELOAD_DATA/vertices.keys
    cp $DATA_DIRECTORY/${DATASET_NAME}_load_edges.keys $PRELOAD_DATA/edges.keys
    
    
    # Create results directory if it doesn't exist
    mkdir -p $RESULTS_DIRECTORY
    for db in "${DATABASES[@]}"; do
        mkdir -p $RESULTS_DIRECTORY/$db
    done
    
    for db in "${DATABASES[@]}"; do
        mkdir -p $LOAD_TIME_DIRECTORY/$db
    done
    
    cd $YCSB_DIRECTORY
    mvn clean package -DskipTests -q
    
    cd $ROOT_DIRECTORY
    . ./ReplicaCountAndLatency.sh
    
done

cd $ROOT_DIRECTORY

python3 LatencyComparision.py 1 ./Results/ReplicaCountAndLatency/ ./BenchmarkPlots/SingleReplicaLatency.png

python3 LatencyComparision.py 3 ./Results/ReplicaCountAndLatency/ ./BenchmarkPlots/MultiReplicaLatency.png

3 replica throughput
REPLICAS=(3)

    DATASET_NAME=ldbc
    echo "Starting benchmarks for dataset: $DATASET_NAME"
    cd $ROOT_DIRECTORY
    . ./PrepareDatasets.sh

    cp $DATA_DIRECTORY/${DATASET_NAME}_load_vertices.loaded $YCSB_DIRECTORY/Vertices.loaded
    cp $DATA_DIRECTORY/${DATASET_NAME}_load_edges.loaded $YCSB_DIRECTORY/Edges.loaded


    cp $DATA_DIRECTORY/${DATASET_NAME}_load_vertices.csv $PRELOAD_DATA/vertices.csv
    cp $DATA_DIRECTORY/${DATASET_NAME}_load_edges.csv $PRELOAD_DATA/edges.csv
    cp $DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json $PRELOAD_DATA/vertices.json
    cp $DATA_DIRECTORY/${DATASET_NAME}_load_edges.json $PRELOAD_DATA/edges.json
    cp $DATA_DIRECTORY/${DATASET_NAME}_load_vertices.keys $PRELOAD_DATA/vertices.keys
    cp $DATA_DIRECTORY/${DATASET_NAME}_load_edges.keys $PRELOAD_DATA/edges.keys



for i in {3..6}; do
    YCSB_THREADS=$((2**i))
    RESULTS_DIRECTORY="$ROOT_DIRECTORY/Results/ThroughputLatency/$YCSB_THREADS"
    # echo "Results Directory: $RESULTS_DIRECTORY"

    # Create results directory if it doesn't exist
    mkdir -p $RESULTS_DIRECTORY
    for db in "${DATABASES[@]}"; do
        mkdir -p $RESULTS_DIRECTORY/$db
    done


    echo "Running benchmarks with $YCSB_THREADS threads"
    cd $ROOT_DIRECTORY
    . ./ReplicaCountAndLatency.sh

done


DATASET_NAME=mico
DURATION=30
cd $ROOT_DIRECTORY
. ./PrepareDatasets.sh
RESULTS_DIRECTORY="$ROOT_DIRECTORY/Results/HeterogeneousDeployment/$DATASET_NAME"
LOAD_TIME_DIRECTORY="$ROOT_DIRECTORY/LoadTimes/HeterogeneousDeployment/$DATASET_NAME"
cp $DATA_DIRECTORY/${DATASET_NAME}_load_vertices.loaded $YCSB_DIRECTORY/Vertices.loaded
cp $DATA_DIRECTORY/${DATASET_NAME}_load_edges.loaded $YCSB_DIRECTORY/Edges.loaded
cp $DATA_DIRECTORY/${DATASET_NAME}_load_vertices.csv $PRELOAD_DATA/vertices.csv
cp $DATA_DIRECTORY/${DATASET_NAME}_load_edges.csv $PRELOAD_DATA/edges.csv
cp $DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json $PRELOAD_DATA/vertices.json
cp $DATA_DIRECTORY/${DATASET_NAME}_load_edges.json $PRELOAD_DATA/edges.json
cp $DATA_DIRECTORY/${DATASET_NAME}_load_vertices.keys $PRELOAD_DATA/vertices.keys
cp $DATA_DIRECTORY/${DATASET_NAME}_load_edges.keys $PRELOAD_DATA/edges.keys

cd $ROOT_DIRECTORY
. ./GraceHeterogeneousReplicas.sh





## Replication and Latency Benchmarks
REPLICAS=(1)
YCSB_THREADS=1
datasets=(ldbc)
for dataset in "${datasets[@]}"; do
    
    echo "Starting benchmarks for dataset: $dataset"
    DATASET_NAME=$dataset
    cd $ROOT_DIRECTORY
    . ./PrepareDatasets.sh
    RESULTS_DIRECTORY="$ROOT_DIRECTORY/Results/InvariantLatency/$DATASET_NAME"
    LOAD_TIME_DIRECTORY="$ROOT_DIRECTORY/LoadTimes/InvariantLatency/$DATASET_NAME"
    cp $DATA_DIRECTORY/${DATASET_NAME}_load_vertices.loaded $YCSB_DIRECTORY/Vertices.loaded
    cp $DATA_DIRECTORY/${DATASET_NAME}_load_edges.loaded $YCSB_DIRECTORY/Edges.loaded
    
    
    cp $DATA_DIRECTORY/${DATASET_NAME}_load_vertices.csv $PRELOAD_DATA/vertices.csv
    cp $DATA_DIRECTORY/${DATASET_NAME}_load_edges.csv $PRELOAD_DATA/edges.csv
    cp $DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json $PRELOAD_DATA/vertices.json
    cp $DATA_DIRECTORY/${DATASET_NAME}_load_edges.json $PRELOAD_DATA/edges.json
    cp $DATA_DIRECTORY/${DATASET_NAME}_load_vertices.keys $PRELOAD_DATA/vertices.keys
    cp $DATA_DIRECTORY/${DATASET_NAME}_load_edges.keys $PRELOAD_DATA/edges.keys
    
    
    # Create results directory if it doesn't exist
    mkdir -p $RESULTS_DIRECTORY
    for db in "${DATABASES[@]}"; do
        mkdir -p $RESULTS_DIRECTORY/$db
    done
    
    for db in "${DATABASES[@]}"; do
        mkdir -p $LOAD_TIME_DIRECTORY/$db
    done
    
    cd $YCSB_DIRECTORY
    mvn clean package -DskipTests -q
    
    cd $ROOT_DIRECTORY
    . ./Grace1and3Replicas.sh
    
done


## Failure benchmarks
DURATION=300
INJECT_FAULTS=true
REPLICAS=(3)
YCSB_THREADS=1
datasets=(ldbc)
for dataset in "${datasets[@]}"; do
    
    echo "Starting benchmarks for dataset: $dataset"
    DATASET_NAME=$dataset
    cd $ROOT_DIRECTORY
    . ./PrepareDatasets.sh
    RESULTS_DIRECTORY="$ROOT_DIRECTORY/Results/DisconnectedOperation/$DATASET_NAME"
    LOAD_TIME_DIRECTORY="$ROOT_DIRECTORY/LoadTimes/DisconnectedOperation/$DATASET_NAME"
    cp $DATA_DIRECTORY/${DATASET_NAME}_load_vertices.loaded $YCSB_DIRECTORY/Vertices.loaded
    cp $DATA_DIRECTORY/${DATASET_NAME}_load_edges.loaded $YCSB_DIRECTORY/Edges.loaded
    
    
    cp $DATA_DIRECTORY/${DATASET_NAME}_load_vertices.csv $PRELOAD_DATA/vertices.csv
    cp $DATA_DIRECTORY/${DATASET_NAME}_load_edges.csv $PRELOAD_DATA/edges.csv
    cp $DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json $PRELOAD_DATA/vertices.json
    cp $DATA_DIRECTORY/${DATASET_NAME}_load_edges.json $PRELOAD_DATA/edges.json
    cp $DATA_DIRECTORY/${DATASET_NAME}_load_vertices.keys $PRELOAD_DATA/vertices.keys
    cp $DATA_DIRECTORY/${DATASET_NAME}_load_edges.keys $PRELOAD_DATA/edges.keys
    
    
    # Create results directory if it doesn't exist
    mkdir -p $RESULTS_DIRECTORY
    for db in "${DATABASES[@]}"; do
        mkdir -p $RESULTS_DIRECTORY/$db
    done
    
    for db in "${DATABASES[@]}"; do
        mkdir -p $LOAD_TIME_DIRECTORY/$db
    done
    
    cd $YCSB_DIRECTORY
    mvn clean package -DskipTests -q
    
    cd $ROOT_DIRECTORY
    . ./ReplicaCountAndLatency.sh
    
done

echo "Benchmarking completed. Results are stored in the Results directory."
