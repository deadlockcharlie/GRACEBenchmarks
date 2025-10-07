#!/bin/bash

ROOT_DIRECTORY=$(pwd)
PRELOAD=false
DURATION=180 #Benchmark duration in seconds
echo "Benchmark duration: $DURATION seconds"

echo "Root Directory: $ROOT_DIRECTORY"
DEPLOYMENTS_DIR="$ROOT_DIRECTORY/Deployments"


GRACE_DIRECTORY="$ROOT_DIRECTORY/ReplicatedGDB"
LF_DIRECTORY="$ROOT_DIRECTORY/replicatedGDBLF"
YCSB_DIRECTORY="$ROOT_DIRECTORY/YCSB"
PRELOAD_DATA="$ROOT_DIRECTORY/PreloadData"
export PRELOAD_DATA="$ROOT_DIRECTORY/PreloadData"


DIST_CONF=$ROOT_DIRECTORY"/distribution_config.json"
latencies=(100 300 100 100 100 100 100 100 100)


DATABASES=(GRACE MemGraph Neo4j ArangoDB MongoDB JanusGraph)


# yeast mico ldbc frbs frbm frbo
datasets=(yeast)



# Eventually this set of commands will be in a loop and potentially parallel?

DATA_DIRECTORY="$ROOT_DIRECTORY/GraphDBData"





# ## Replication and Latency Benchmarks
#  REPLICAS=(1)
#  YCSB_THREADS=1
#  for dataset in "${datasets[@]}"; do
    
#      echo "Starting benchmarks for dataset: $dataset"
#      DATASET_NAME=$dataset
#      cd $ROOT_DIRECTORY
#  . ./PrepareDatasets.sh
#      RESULTS_DIRECTORY="$ROOT_DIRECTORY/Results/ReplicaCountAndLatency/$DATASET_NAME"
#      LOAD_TIME_DIRECTORY="$ROOT_DIRECTORY/LoadTimes/ReplicaCountAndLatency/$DATASET_NAME"
#      cp $DATA_DIRECTORY/${DATASET_NAME}_load_vertices.loaded $YCSB_DIRECTORY/Vertices.loaded
#      cp $DATA_DIRECTORY/${DATASET_NAME}_load_edges.loaded $YCSB_DIRECTORY/Edges.loaded


#      cp $DATA_DIRECTORY/${DATASET_NAME}_load_vertices.csv $PRELOAD_DATA/vertices.csv
#      cp $DATA_DIRECTORY/${DATASET_NAME}_load_edges.csv $PRELOAD_DATA/edges.csv
#      cp $DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json $PRELOAD_DATA/vertices.json
#      cp $DATA_DIRECTORY/${DATASET_NAME}_load_edges.json $PRELOAD_DATA/edges.json
#      cp $DATA_DIRECTORY/${DATASET_NAME}_load_vertices.keys $PRELOAD_DATA/vertices.keys
#      cp $DATA_DIRECTORY/${DATASET_NAME}_load_edges.keys $PRELOAD_DATA/edges.keys


#      # Create results directory if it doesn't exist
#      mkdir -p $RESULTS_DIRECTORY
#      for db in "${DATABASES[@]}"; do
#          mkdir -p $RESULTS_DIRECTORY/$db
#      done

#      for db in "${DATABASES[@]}"; do
#          mkdir -p $LOAD_TIME_DIRECTORY/$db
#      done

#     cd $YCSB_DIRECTORY
#     mvn clean package -DskipTests -q

#      cd $ROOT_DIRECTORY
#      . ./ReplicaCountAndLatency.sh

#  done

#  cd $ROOT_DIRECTORY

#  python3 LatencyComparision.py 1 ./Results/ReplicaCountAndLatency/ ./BenchmarkPlots/SingleReplicaLatency.png

#  python3 LatencyComparision.py 3 ./Results/ReplicaCountAndLatency/ ./BenchmarkPlots/MultiReplicaLatency.png
# exit 0

# # 3 replica throughput 
# REPLICAS=(3)

#     DATASET_NAME=ldbc
#     echo "Starting benchmarks for dataset: $DATASET_NAME"
#     cd $ROOT_DIRECTORY
#     . ./PrepareDatasets.sh
    
#     cp $DATA_DIRECTORY/${DATASET_NAME}_load_vertices.loaded $YCSB_DIRECTORY/Vertices.loaded
#     cp $DATA_DIRECTORY/${DATASET_NAME}_load_edges.loaded $YCSB_DIRECTORY/Edges.loaded


#     cp $DATA_DIRECTORY/${DATASET_NAME}_load_vertices.csv $PRELOAD_DATA/vertices.csv
#     cp $DATA_DIRECTORY/${DATASET_NAME}_load_edges.csv $PRELOAD_DATA/edges.csv
#     cp $DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json $PRELOAD_DATA/vertices.json
#     cp $DATA_DIRECTORY/${DATASET_NAME}_load_edges.json $PRELOAD_DATA/edges.json
#     cp $DATA_DIRECTORY/${DATASET_NAME}_load_vertices.keys $PRELOAD_DATA/vertices.keys
#     cp $DATA_DIRECTORY/${DATASET_NAME}_load_edges.keys $PRELOAD_DATA/edges.keys



# for i in {6..7}; do
#     YCSB_THREADS=$((2**i))
#     RESULTS_DIRECTORY="$ROOT_DIRECTORY/Results/ThroughputLatency/$YCSB_THREADS"
#     # echo "Results Directory: $RESULTS_DIRECTORY"

#     # Create results directory if it doesn't exist
#     mkdir -p $RESULTS_DIRECTORY
#     for db in "${DATABASES[@]}"; do
#         mkdir -p $RESULTS_DIRECTORY/$db
#     done

    
#     echo "Running benchmarks with $YCSB_THREADS threads"
#     cd $ROOT_DIRECTORY
#     . ./ReplicaCountAndLatency.sh

# done


DATASET_NAME=yeast
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


echo "Benchmarking completed. Results are stored in the Results directory."
