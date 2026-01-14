# GRACE Benchmarks

A comprehensive benchmarking framework for evaluating GRACE against traditional graph databases in distributed, geo-replicated environments.

## Overview

This repository contains the complete benchmarking suite used to evaluate GRACE's performance compared to popular graph databases including Neo4j, MemGraph, MongoDB, ArangoDB, and JanusGraph. The benchmarks assess various aspects of distributed graph database performance including throughput, latency, replication overhead, fault tolerance, and support for disconnected operations.

## Deployment Options

- **🚀 NEW: AWS Geo-Distributed Deployment** - See [aws-deployment/](aws-deployment/) for running real geo-distributed experiments across multiple AWS regions
- **Local Single-Machine Deployment** - Continue reading below for traditional Docker-based local deployment

## Table of Contents

- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Project Structure](#project-structure)
- [Datasets](#datasets)
- [Running Benchmarks](#running-benchmarks)
- [Benchmark Types](#benchmark-types)
- [Configuration](#configuration)
- [Results and Visualization](#results-and-visualization)
- [Deployment Scripts](#deployment-scripts)
- [AWS Deployment](#aws-deployment)

## Architecture

The benchmarking framework is built on three main components:

1. **ReplicatedGDB**: Core implementation of GRACE middleware
2. **replicatedGDBLF**: Reference implementation with primary-backup replication
3. **YCSB**: Modified Yahoo! Cloud Serving Benchmark for graph database workloads

## Prerequisites

- **Docker** (for containerized database deployments)
- **Python 3.8+** with dependencies:
  - `pandas`, `matplotlib`, `numpy`
  - `ijson` (for streaming JSON parsing)
- **Java 11+** (for YCSB and JanusGraph)
- **Maven** (for building Java components)
- **Bash** (shell scripts tested on Linux/macOS)
- **Network tools**: `tc` (traffic control) for latency simulation

## Installation

### 1. Download the repository

Download and extract the repository to your local machine.

### 2. Install Python dependencies

```bash
pip3 install pandas matplotlib numpy ijson
```

All Java components (YCSB, ReplicatedGDB, replicatedGDBLF) are included in the distribution.

## Project Structure

```
GRACE/
├── README.md                           # This file
├── RunBenchmark.sh                     # Main benchmark orchestration script
├── PrepareDatasets.sh                  # Dataset download and preprocessing
├── workloadGenerator.py                # Splits datasets into load/update workloads
├── jsontoCSV.py                        # Converts JSON data to CSV format
│
├── ReplicatedGDB/                      # GRACE middleware implementation
├── replicatedGDBLF/                    # Reference implementation with primary-backup
├── YCSB/                               # Modified YCSB benchmark
│
├── Deployments/                        # Database deployment scripts
│   ├── ArangoDBReplicatedDeployment.sh
│   ├── MongoDBReplicatedDeployment.sh
│   ├── Neo4JReplicatedDeployment.sh
│   ├── JanusgraphReplicatedDeployment.sh
│   ├── setup-latency.sh                # Network latency simulation
│   └── Dockerfiles/                    # Custom Docker images
│
├── BenchmarkScripts/                   # Benchmark execution scripts
│   ├── Grace1and3Replicas.sh
│   ├── GraceHeterogeneousReplicas.sh
│   ├── JanusGraph1and3Replicas.sh
│   ├── MongoDB1and3Replicas.sh
│   ├── Neo4J1and3Replicas.sh
│   ├── MemGraph1and3Replicas.sh
│   ├── ArangoDB1and3Replicas.sh
│   ├── ReplicaCountAndLatency.sh
│   ├── ThreeReplicasAndFailures.sh
│   ├── GraceInvariantCheck.sh
│   └── DisconnectedOperationBenchmark.sh
│
├── GraphDBData/                        # Preprocessed datasets
│   ├── ldbc_*.json/csv
│   ├── mico_*.json/csv
│   ├── frb*_*.json/csv                 # Freebase datasets
│   └── yeast_*.json/csv
│
├── Results/                            # Benchmark output files
│   ├── ThroughputLatency/
│   ├── DisconnectedOperations/
│   └── ReplicaComparison/
│
├── BenchmarkPlots/                     # Generated visualization plots
│   ├── ReplicaCountAndLatency.png
│   ├── ThroughputVsLatency.png
│   ├── DisconnectedOperation.png
│   ├── HeterogeneousDeployment.png
│   ├── SingleReplicaLatency.png
│   └── MultiReplicaLatency.png
│
├── conf/                               # Configuration files
│   ├── janusgraph-scylla.properties
│   └── janusgraph-server.yaml
│
├── distribution_config.json            # Replica distribution configuration
├── LatencyComparision.py               # Latency analysis script
├── LatencyByReplicaCount.py            # Replica count vs latency analysis
├── ThroughputVsLatency.py              # Throughput/latency tradeoff analysis
├── DisconnectedOperations.py           # Disconnected operations analysis
├── HeterogenousDeployments.py          # Heterogeneous deployment analysis
└── waitForPreload.sh                   # Wait for data preloading completion
```

## Datasets

The benchmark supports multiple graph datasets from various domains:

- **LDBC**: Social network benchmark dataset
- **MICO**: Microsoft co-authorship network
- **Yeast**: Protein-protein interaction network
- **Freebase** (small/medium/large): Knowledge graph subsets

### Preparing Datasets

```bash
# Download and preprocess datasets
./PrepareDatasets.sh

# This will:
# 1. Download raw datasets from Zenodo
# 2. Split into load/update workloads (80/20 split)
# 3. Generate CSV files for database import
# 4. Create vertex and edge files for each dataset
```

The `workloadGenerator.py` script uses a parallel, streaming approach to handle large datasets efficiently:
- Splits vertices into load (80%) and update (20%) sets
- Ensures referential integrity for edges
- Uses SQLite for fast ID lookups
- Processes data in shards for parallel execution

## Running Benchmarks

### Basic Benchmark Execution

```bash
# Run full benchmark suite (takes 2-3 hours to complete)
./RunBenchmark.sh

# Customize benchmark parameters
DURATION=180 INJECT_FAULTS=true ./RunBenchmark.sh
```

> **Note**: A complete benchmark run takes approximately 2-3 hours to execute, depending on the number of databases tested, replica configurations, and workload sizes.

> **For most use cases, running `RunBenchmark.sh` is sufficient.** While individual benchmark scripts are available for specific testing scenarios, the main script orchestrates the complete benchmark suite including deployment, data loading, execution, and result collection.

### Individual Benchmark Scripts

```bash
# Compare GRACE with 1 vs 3 replicas
./Grace1and3Replicas.sh

# Test heterogeneous deployments (mixed databases)
./GraceHeterogeneousReplicas.sh

# Evaluate with network failures
./ThreeReplicasAndFailures.sh

# Test invariant checking overhead
./GraceInvariantCheck.sh

# Benchmark specific database
./Neo4J1and3Replicas.sh
./MongoDB1and3Replicas.sh
./JanusGraph1and3Replicas.sh
```

## Benchmark Types

### 1. Throughput and Latency Benchmarks
Tests system performance under varying load conditions:
- Variable client thread counts (32, 64, 128)
- Different operation mixes (read/write ratios)
- Single vs multi-replica deployments

**Script**: `ReplicaCountAndLatency.sh`  
**Output**: Results per thread count and replica configuration

### 2. Geo-Distributed Replication
Simulates AWS multi-region deployments with realistic latencies:
- 6 AWS regions (us-east-1, us-west-2, eu-central-1, ap-south-1, ap-southeast-1, sa-east-1)
- Symmetric latency matrix based on actual AWS measurements
- Uses `tc` (traffic control) for network latency injection

**Configuration**: Latency matrix in `RunBenchmark.sh`

### 3. Heterogeneous Deployments
Tests GRACE with replicas running different backend databases:
- Neo4j + MemGraph + MongoDB
- Evaluates cross-database consistency
- Measures replication overhead

**Script**: `GraceHeterogeneousReplicas.sh`

### 4. Fault Tolerance
Injects network partitions and node failures:
- Random replica crashes
- Network partition simulation
- Recovery time measurement

**Script**: `ThreeReplicasAndFailures.sh`

### 5. Disconnected Operations
Tests support for offline/disconnected client operations:
- Local operation buffering
- Conflict resolution on reconnection
- Consistency guarantees

**Script**: `DisconnectedOperationBenchmark.sh`  
**Analysis**: `DisconnectedOperations.py`

### 6. Invariant Checking
Measures overhead of integrity constraint enforcement:
- Custom invariants defined per application
- Performance impact analysis
- Violation detection latency

**Script**: `GraceInvariantCheck.sh`

## Configuration

### Distribution Configuration (`distribution_config.json`)

```json
{
  "replicas": [
    {
      "id": 1,
      "region": "us-east-1",
      "database": "neo4j",
      "port": 7687
    },
    {
      "id": 2,
      "region": "eu-central-1",
      "database": "memgraph",
      "port": 7688
    }
  ],
  "latency_matrix": [[0, 48], [48, 0]]
}
```

### YCSB Workload Properties

Common parameters modified in benchmark scripts:
- `recordcount`: Number of records to preload
- `operationcount`: Total operations during benchmark
- `threadcount`: Concurrent client threads
- `readproportion`: Ratio of read operations (0.0-1.0)
- `updateproportion`: Ratio of update operations
- `scanproportion`: Ratio of scan/traversal operations
- `maxexecutiontime`: Benchmark duration in seconds

## Results and Visualization

### Generating Plots

```bash
# Throughput vs Latency comparison
python3 ThroughputVsLatency.py

# Latency by replica count
python3 LatencyByReplicaCount.py

# Latency comparison across databases
python3 LatencyComparision.py

# Disconnected operations analysis
python3 DisconnectedOperations.py

# Heterogeneous deployment analysis
python3 HeterogenousDeployments.py
```

### Plot Outputs

All plots are saved to `BenchmarkPlots/` directory:
- PNG format with 300 DPI
- Publication-ready styling
- Configurable colors per database system

## Deployment Scripts

Each database system has a dedicated deployment script in `Deployments/`:

### Database-Specific Deployments

```bash
# Deploy replicated Neo4j cluster
./Deployments/Neo4JReplicatedDeployment.sh <num_replicas>

# Deploy replicated MongoDB cluster
./Deployments/MongoDBReplicatedDeployment.sh <num_replicas>

# Deploy replicated ArangoDB cluster
./Deployments/ArangoDBReplicatedDeployment.sh <num_replicas>

# Deploy JanusGraph with Scylla backend
./Deployments/JanusgraphReplicatedDeployment.sh <num_replicas>
```

### Network Latency Setup

```bash
# Configure network latencies between replicas
./Deployments/setup-latency.sh <replica_id> <latency_config>
```

Uses Linux `tc qdisc` to add configurable network delays.

## Database Systems Tested

| Database | Version | Protocol | Replication | Consistency |
|----------|---------|----------|-------------|-------------|
| **GRACE** | Custom | Bolt/HTTP | Multi-master | Causal |
| **Neo4j** | 5.x | Bolt | Leader-follower | Eventual |
| **MemGraph** | 2.x | Bolt | Leader-follower | Eventual |
| **MongoDB** | 6.x | MongoDB Wire | Replica set | Eventual/Strong |
| **ArangoDB** | 3.x | HTTP | Multi-master | Eventual |
| **JanusGraph** | 1.1.0 | Gremlin | Backend-dependent | Backend-dependent |

## Metrics Collected

For each benchmark run, the following metrics are captured:

- **Throughput**: Operations per second (ops/sec)
- **Latency**: Average, P50, P95, P99, Max (microseconds)
- **Operation breakdown**: Per-operation type metrics
- **Error rates**: Failed operations, timeouts
- **Resource usage**: CPU, memory, network (when available)
- **Replication lag**: Time to propagate updates across replicas

## AWS Deployment

### Real Geo-Distributed Experiments

For running GRACE benchmarks across real geo-distributed infrastructure on AWS:

```bash
cd aws-deployment
./quickstart.sh
```

This will:
- Deploy EC2 instances across 3 AWS regions (US-East, US-West, EU-Central)
- Use real network latency (no simulation)
- Run benchmarks with actual geo-distribution
- Collect results from all regions

**Features:**
- ✅ Real inter-region network latency
- ✅ Automated Terraform infrastructure deployment
- ✅ SSH-based orchestration across regions
- ✅ Results collection and analysis
- ✅ Cost optimization (spot instances supported)

**Quick Links:**
- [AWS Deployment README](aws-deployment/README.md)
- [Migration Guide](aws-deployment/MIGRATION_GUIDE.md)
- [Cost estimation and management](aws-deployment/README.md#cost-estimation)

**Cost:** ~$1/hour for 3 regions with c5.2xlarge (can be reduced to ~$0.30/hour with spot instances)

**⚠️ Important:** Remember to run `./scripts/teardown.sh` when done to avoid AWS charges!

## License

This project is licensed under the MIT License.

```
MIT License

Copyright (c) 2025 [Anonymous for Review]

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Contributing

Contributions are welcome! Additional database system integrations, new benchmark scenarios, bug fixes, and performance improvements are appreciated.

---

**Note**: This benchmarking framework requires significant computational resources for realistic distributed deployments. AWS EC2 instances (t3.xlarge or larger) are recommended for production benchmarks.
