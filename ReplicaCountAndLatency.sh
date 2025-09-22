
# cd $ROOT_DIRECTORY
# . ./Grace1to6Replicas.sh

# cd $ROOT_DIRECTORY
# . ./ArangoDB1to6Replicas.sh

# cd $ROOT_DIRECTORY
# . ./MongoDB1to6Replicas.sh

# cd $ROOT_DIRECTORY
# . ./Neo4J1to6Replicas.sh

cd $ROOT_DIRECTORY
. ./MemGraph1to6Replicas.sh

# cd $ROOT_DIRECTORY
# . ./JanusGraph1to6Replicas.sh


# echo "Benchmarking completed. Results are stored in the Results directory."


# Plotting the results
cd $ROOT_DIRECTORY
python3 LatencyByReplicaCount.py $ROOT_DIRECTORY/Results/ReplicaCountAndLatency $ROOT_DIRECTORY/BenchmarkPlots/ReplicaCountAndLatency.png
