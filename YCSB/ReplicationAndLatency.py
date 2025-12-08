import os
import re
import pandas as pd
import matplotlib.pyplot as plt

# Root directory containing subdirectories (one per DB)
root_dir = "./BenchmarkResults/ThroughputLatencyAndReplicas"  # adjust as needed

readoperations=["GET_VERTEX_COUNT","GET_EDGE_COUNT", "GET_EDGE_LABELS","GET_VERTEX_WITH_PROPERTY", "GET_EDGE_WITH_PROPERTY", "GET_EDGES_WITH_LABEL"]
writeoperations=["ADD_VERTEX","ADD_EDGE","REMOVE_VERTEX", "REMOVE_EDGE", "SET_VERTEX_PROPERTY", "SET_EDGE_PROPERTY","REMOVE_VERTEX_PROPERTY", "REMOVE_EDGE_PROPERTY" ]

# Data collection
dataRead = []
dataWrite = []
for db in os.listdir(root_dir):
    db_dir = os.path.join(root_dir, db)
    if not os.path.isdir(db_dir):
        continue

    for fname in os.listdir(db_dir):
        match = re.match(r"(\d+)", fname)
        if not match:
            continue

        replicas = int(match.group(1))
        fpath = os.path.join(db_dir, fname)
        with open(fpath) as f:
            lines = f.readlines()

        avgReadLatency=0
        avgWriteLatency=0
        for line in lines:
            line = line.strip()
            if not line or "," not in line:
                continue
            parts = line.split(",")
            if len(parts) !=3:
                continue
            operation, metric, value = parts
            operation = operation.strip("[]")
            metric = metric.strip()
            value = value.strip()
            if operation not in readoperations + writeoperations:
                continue

            if metric == "AverageLatency(us)" and operation in readoperations:
                avgReadLatency = (avgReadLatency+float(value))/2

            elif metric == "AverageLatency(us)" and operation in writeoperations:
                avgWriteLatency = (avgWriteLatency+float(value))/2
        dataRead.append({
                "db": db,
                "replicas": replicas,
                "operation": "Reads",
                "latency_us": float(avgReadLatency)
                        })
        dataWrite.append({
                "db": db,
                "replicas": replicas,
                "operation": "Writes",
                "latency_us": float(avgWriteLatency)
                        })
#         if runtime and throughput:
#             data.append({
#                 "db": db,
#                 "replicas": replicas,
#                 "latency_ms": runtime,
#                 "throughput_ops": throughput
#             })

# Convert to DataFrame
dfread = pd.DataFrame(dataRead)
dfwrite = pd.DataFrame(dataWrite)


# print(dfread)
# print(dfwrite)


# Combine into one dataframe
df = pd.concat([dfread, dfwrite])

# Ensure replicas are sorted
df = df.sort_values(by="replicas")

# Style mapping
colors = {"Neo4J": "tab:blue", "GRACE": "tab:green", "MemGraph": "tab:orange"}
markers = {"Neo4J": "o", "GRACE": "s", "MemGraph": "^"}
linestyles = {"Reads": "dotted", "Writes": "solid"}

# Plot
plt.figure(figsize=(6, 4))
for db in df['db'].unique():
    db_data = df[df['db'] == db]
    for op in db_data['operation'].unique():
        op_data = db_data[db_data['operation'] == op]
        plt.plot(
            op_data['replicas'],
            op_data['latency_us'],
            marker=markers[db],
            color=colors[db],
            linestyle=linestyles[op],
            label=f"{db} {op}"
        )

plt.xlabel("Replica Count")
plt.ylabel("Latency (µs)")
plt.yscale("log")
plt.legend(loc='upper center', bbox_to_anchor=(0.5, 1.2),
          ncol=3, fancybox=True)
plt.grid(True)
plt.tight_layout()
plt.savefig("ReplicationAndLatency.png", dpi=500)