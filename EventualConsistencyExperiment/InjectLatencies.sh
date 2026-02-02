#!/bin/bash

# setup latency bewteen DC1 and DC2 for scylla nodes
# for i in 1 2 3; do
#     for j in 4 5 6; do
        docker exec scylla1-netem sh -c "/usr/local/bin/setup-latency.sh scylla1 scylla4 0";
        docker exec scylla4-netem sh -c "/usr/local/bin/setup-latency.sh scylla4 scylla1 0";
#     done
# done