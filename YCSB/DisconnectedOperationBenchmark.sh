#!/bin/bash

cleanup() {
    echo "Caught termination signal. Cleaning up..."
    # kill background jobs if needed
    kill 0 2>/dev/null
    exit 1
}

# Catch Ctrl-C (SIGINT) and Ctrl-\ (SIGQUIT) and normal termination (SIGTERM)
trap cleanup SIGINT SIGQUIT SIGTERM


# Start first command in background
bin/ycsb.sh run grace -s -P workloads/workload_grace -p  HOSTURI="http://localhost:3000" -p threadcount=1 -p maxexecutiontime=300 > BenchmarkResults/DisconnectedOperation/GRACE/logs.txt 2>&1 &
first_command_pid=$!

# Wait 2 minutes seconds
sleep 120

# Start second command (concurrent with the first one)
python3 faultinjector.py &
second_command_pid=$!

# Optionally wait for both to finish
wait
