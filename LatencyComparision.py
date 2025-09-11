import os
import argparse
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np


def plot_latencies(root_dir: str, figure_path: str):
    data = []

    dict_operations = {
        "GET_VERTEX_COUNT": "R1",
        "GET_EDGE_COUNT": "R2",
        "GET_EDGE_LABELS": "R3",
        "GET_VERTEX_WITH_PROPERTY": "R4",
        "GET_EDGE_WITH_PROPERTY": "R5",
        "GET_EDGES_WITH_LABEL": "R6",
        "ADD_VERTEX": "W1",
        "ADD_EDGE": "W2",
        "REMOVE_VERTEX": "W3",
        "REMOVE_EDGE": "W4",
        "SET_VERTEX_PROPERTY": "W5",
        "SET_EDGE_PROPERTY": "W6",
        "REMOVE_VERTEX_PROPERTY": "W7",
        "REMOVE_EDGE_PROPERTY": "W8"
    }

    operations = list(dict_operations.keys())

    for db in os.listdir(root_dir):
        db_path = os.path.join(root_dir, db)
        if not os.path.isdir(db_path):
            continue

        results_file = os.path.join(db_path, "results.txt")
        if not os.path.exists(results_file):
            continue

        with open(results_file, "r") as f:
            for line in f:
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
                if metric == "AverageLatency(us)" and operation in operations:
                    data.append({
                        "DB": db,
                        "Operation": dict_operations[operation],
                        "Latency": float(value)
                    })

    # Convert to DataFrame
    plot_df = pd.DataFrame(data)
    pivot_df = plot_df.pivot(index="Operation", columns="DB", values="Latency").fillna(0)

    # Reorder columns: put GRACE last
    if "GRACE" in pivot_df.columns:
        cols = [c for c in pivot_df.columns if c != "GRACE"] + ["GRACE"]
        pivot_df = pivot_df[cols]

    # Define DB-specific colors and hatches
    db_styles = {
        "Neo4j":   {"color": "tab:blue",   "hatch": "//"},
        "Janus":   {"color": "tab:orange", "hatch": "xx"},
        "ArangoDB":  {"color": "tab:green",  "hatch": "\\\\"},
        "Memgraph": {"color": "tab:purple","hatch": "--"},
        "MongoDB":  {"color": "tab:brown",  "hatch": "++"},
        "GRACE":   {"color": "tab:red",    "hatch": ".."},
    }

    dbs = pivot_df.columns
    x = np.arange(len(pivot_df.index))  # positions for operations
    width = 0.7 / len(dbs)  # bar width

    fig, ax = plt.subplots(figsize=(8,4))
    group_width = width * len(dbs)  # width of a full group
    
    for i, db in enumerate(dbs):
        values = pivot_df[db].values
        color = db_styles.get(db, {}).get("color", f"C{i}")
        hatch = db_styles.get(db, {}).get("hatch", "")
        bars = ax.bar(x + i * width, values, width, label=db,
                      color=color, hatch = hatch, edgecolor=color, facecolor="none")

    ax.grid(axis="y", linestyle="--", alpha=0.7)
    for pos in range(1, len(pivot_df.index)):
        ax.axvline(pos-0.18, alpha=1,  linestyle='--', color='gray', linewidth=0.5)

    ax.set_ylabel("Latency (µs)", fontsize=10)
    ax.set_yscale("log")
    ax.set_xticks(x + width * (len(dbs) - 1) / 2)
    ax.set_xticklabels(pivot_df.index, rotation=0, fontsize=10)
    ax.legend(loc="upper center", bbox_to_anchor=(0.5, 1.2),
              ncol=len(dbs), fontsize=10)
    fig.tight_layout()
    fig.savefig(figure_path, dpi=500)
    plt.close(fig)
    

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Plot database latencies.")
    parser.add_argument("root_dir", help="Path to the root results directory")
    parser.add_argument("figure_path", help="Path to save the output figure (with extension, e.g., .png)")
    args = parser.parse_args()

    plot_latencies(args.root_dir, args.figure_path)
