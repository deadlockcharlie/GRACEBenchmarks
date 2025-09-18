import os
import re
import argparse
import pandas as pd
import matplotlib.pyplot as plt

readoperations = ["GET_VERTEX_COUNT", "GET_EDGE_COUNT", "GET_EDGE_LABELS",
                  "GET_VERTEX_WITH_PROPERTY", "GET_EDGE_WITH_PROPERTY", "GET_EDGES_WITH_LABEL"]
writeoperations = ["ADD_VERTEX", "ADD_EDGE", "REMOVE_VERTEX", "REMOVE_EDGE",
                   "SET_VERTEX_PROPERTY", "SET_EDGE_PROPERTY", "REMOVE_VERTEX_PROPERTY", "REMOVE_EDGE_PROPERTY"]

db_styles = {
        "Neo4j":   {"color": "tab:blue",   "linestyle": "-"},
        "JanusGraph":   {"color": "tab:orange", "linestyle": "--"},
        "ArangoDB":  {"color": "tab:green",  "linestyle": "-."},
        "MemGraph": {"color": "tab:purple","linestyle": ":"},
        "MongoDB":  {"color": "tab:brown",  "linestyle": "-"},
        "GRACE":   {"color": "tab:red",    "linestyle": "--"},
    }

def plot_data(root_dir: str, figure_path: str):
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

            avgReadLatency = 0
            avgWriteLatency = 0
            for line in lines:
                line = line.strip()
                if not line or "," not in line:
                    continue
                parts = line.split(",")
                if len(parts) != 3:
                    continue
                operation, metric, value = parts
                operation = operation.strip("[]")
                metric = metric.strip()
                value = value.strip()
                if operation not in readoperations + writeoperations:
                    continue

                if metric == "AverageLatency(us)" and operation in readoperations:
                    avgReadLatency = (avgReadLatency + float(value)) / 2

                elif metric == "AverageLatency(us)" and operation in writeoperations:
                    avgWriteLatency = (avgWriteLatency + float(value)) / 2

            dataRead.append({
                "db": db,
                "replicas": replicas,
                "latency_us": float(avgReadLatency)
            })
            dataWrite.append({
                "db": db,
                "replicas": replicas,
                "latency_us": float(avgWriteLatency)
            })

    # Convert to DataFrame
    dfread = pd.DataFrame(dataRead).sort_values(by="replicas")
    dfwrite = pd.DataFrame(dataWrite).sort_values(by="replicas")

    # ---- Plot Reads ----
    plt.figure(figsize=(6, 4))
    for db in dfread['db'].unique():
        db_data = dfread[dfread['db'] == db]
        plt.plot(
            db_data['replicas'],
            db_data['latency_us'],
            label=f"{db} Reads",
            color=db_styles[db]["color"],
            linestyle=db_styles[db]["linestyle"],
            marker="o"
        )

    plt.xlabel("Replica Count")
    plt.ylabel("Latency (µs)")
    plt.yscale("log")
    plt.legend(loc='upper center', bbox_to_anchor=(0.5, 1.2),
            ncol=3, fancybox=True)
    plt.grid(True)
    plt.tight_layout()
    plt.savefig(figure_path+ "ReplicaCountAndLatency_Reads.png", dpi=500)

    # ---- Plot Writes ----
    plt.figure(figsize=(6, 4))
    for db in dfwrite['db'].unique():
        db_data = dfwrite[dfwrite['db'] == db]
        plt.plot(
            db_data['replicas'],
            db_data['latency_us'],
            label=f"{db} Writes",
            color=db_styles[db]["color"],
            linestyle=db_styles[db]["linestyle"],
            marker="o"
        )

    plt.xlabel("Replica Count")
    plt.ylabel("Latency (µs)")
    plt.yscale("log")
    plt.legend(loc='upper center', bbox_to_anchor=(0.5, 1.2),
            ncol=3, fancybox=True)
    plt.grid(True)
    plt.tight_layout()
    plt.savefig(figure_path+"/ReplicaCountAndLatency_Writes.png", dpi=500)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Plot database latencies as line chart.")
    parser.add_argument("root_dir", help="Path to the root results directory")
    parser.add_argument("figure_path", help="Path to save the output figure (with extension, e.g., .png)")
    args = parser.parse_args()


    plot_data(args.root_dir, args.figure_path)
