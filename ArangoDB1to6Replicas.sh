#loop over 1 to 6 replicas for ArangoDB
#!/bin/bash



for i in $(seq 6 -1 1);
do
    echo "Running benchmark with $i replicas..."
    COMPOSE_FILE="./Dockerfiles/ArangoDB${i}Replicas"

    cd $DEPLOYMENTS_DIR

    . ./ArangoDBReplicatedDeployment.sh

    cd $YCSB_DIRECTORY
    # Load the initial data in the DB
    bin/ycsb.sh load arangodb  -P workloads/workload_grace  -p DBTYPE="arangodb" -p DBURI="http://localhost:8529" -p REPLICATION_FACTOR=$i -p threadcount=1 -p loadVertexFile=$DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json  -p loadEdgeFile=$DATA_DIRECTORY/${DATASET_NAME}_load_edges.json -p vertexAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_vertices.json -p edgeAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_edges.json > $LOAD_TIME_DIRECTORY/ArangoDB/${i}.txt

    # Add latency between replicas if more than 1 replica
    if [ $i -gt 1 ]; then
        echo "Adding network latency between replicas..."
        # Introduce network latency between the replicas using netem
        # dbserver1-netem, dbserver2-netem, ... 
        # The latency values are just examples and can be adjusted as needed
        # Latency pattern:
        # dbserver1 ↔ dbserver2 = 100ms
        # dbserver1 ↔ dbserver3 = 300ms
        # dbserver2 ↔ dbserver3 = 150ms
        for (( j=1; j<=i; j++ )); do
            for (( k=j+1; k<=i; k++ )); do
                latency_index=$(( (j + k - 2) % ${#latencies[@]} ))
                latency_value=${latencies[$latency_index]}
                echo "Setting latency of ${latency_value}ms between dbserver${j} and dbserver${k}"
                docker exec -it dbserver${j}-netem sh -c "/usr/local/bin/setup-latency.sh dbserver${j} dbserver${k} ${latency_value}"
                docker exec -it dbserver${k}-netem sh -c "/usr/local/bin/setup-latency.sh dbserver${k} dbserver${j} ${latency_value}"
            done
        done
    fi


    # Switch to the YCSB directory
    cd $YCSB_DIRECTORY
    #Run the benchmark with graphdb workload
    bin/ycsb.sh run arangodb  -P workloads/workload_grace  -p DBTYPE="arangodb" -p DBURI="http://localhost:8529"  -p REPLICATION_FACTOR=$i -p maxexecutiontime=${DURATION} -p threadcount=1 -p loadVertexFile=$DATA_DIRECTORY/${DATASET_NAME}_load_vertices.json  -p loadEdgeFile=$DATA_DIRECTORY/${DATASET_NAME}_load_edges.json -p vertexAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_vertices.json -p edgeAddFile=$DATA_DIRECTORY/${DATASET_NAME}_update_edges.json > $RESULTS_DIRECTORY/ArangoDB/${i}.txt

    #Shutdown replicas
    cd $DEPLOYMENTS_DIR
    docker compose -f $COMPOSE_FILE down
done
