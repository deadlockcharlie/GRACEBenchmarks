#loop over 1 to 6 replicas for MongoDB
#!/bin/bash

for i in {1..6}
do
    echo "Running benchmark with $i replicas..."
    COMPOSE_FILE="./Dockerfiles/JanusgraphScyllaDB${i}Replicas"

    cd $DEPLOYMENTS_DIR

    . ./JanusgraphReplicatedDeployment.sh

    cd $YCSB_DIRECTORY
    # Load the initial data in the DB
    bin/ycsb.sh load janusgraph  -P workloads/workload_grace  -p DBTYPE="janusgraph" -p DBURI="ws://localhost:8182" -p threadcount=1 -p loadVertexFile=$DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json  -p loadEdgeFile=$DATA_DIRECTORY/${DATASET_NAME}_load_edges.json -p vertexAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_vertices.json -p edgeAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_edges.json > $LOAD_TIME_DIRECTORY/JanusGraph/${i}.txt

    # Add latency between replicas if more than 1 replica
    if [ $i -gt 1 ]; then
        echo "Adding network latency between replicas..."
        # Introduce network latency between the replicas using netem
        # scylla1-netem, scylla2-netem, ... 
        # The latency values are just examples and can be adjusted as needed
        # Latency pattern:
        for (( j=1; j<=i; j++ )); do
            for (( k=j+1; k<=i; k++ )); do
                latency_index=$(( (j + k - 2) % ${#latencies[@]} ))
                latency_value=${latencies[$latency_index]}
                echo "Setting latency of ${latency_value}ms between scylla${j} and scylla${k}"
                docker exec -it scylla${j}-netem sh -c "/usr/local/bin/setup-latency.sh scylla${j} scylla${k} ${latency_value}"
                docker exec -it scylla${k}-netem sh -c "/usr/local/bin/setup-latency.sh scylla${k} scylla${j} ${latency_value}"
            done
        done
    fi
    # Switch to the YCSB directory
    cd $YCSB_DIRECTORY
    #Run the benchmark with graphdb workload
    bin/ycsb.sh run janusgraph  -P workloads/workload_grace  -p DBTYPE="janusgraph" -p DBURI="ws://localhost:8182" -p maxexecutiontime=${DURATION} -p threadcount=1 -p loadVertexFile=$DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json  -p loadEdgeFile=$DATA_DIRECTORY/${DATASET_NAME}_load_edges.json -p vertexAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_vertices.json -p edgeAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_edges.json > $RESULTS_DIRECTORY/JanusGraph/${i}.txt

    #Shutdown replicas
    cd $DEPLOYMENTS_DIR
    docker compose -f $COMPOSE_FILE down
done
