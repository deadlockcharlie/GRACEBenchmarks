import os
import argparse
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np

dict_operations = {
    "GET_VERTEX_COUNT": "R1",
    "GET_EDGE_COUNT": "R2",
    "GET_EDGE_LABELS": "R3",
    "GET_VERTEX_WITH_PROPERTY": "R4",
    "GET_EDGE_WITH_PROPERTY": "R5",
    "GET_EDGES_WITH_LABEL": "R6",
    "ADD_VERTEX": "W1",
    "SET_VERTEX_PROPERTY": "W2",
    "REMOVE_VERTEX_PROPERTY": "W3",
    "ADD_EDGE": "W4",
    "SET_EDGE_PROPERTY": "W5",
    "REMOVE_VERTEX": "W6",
    "REMOVE_EDGE": "W7",
    "REMOVE_EDGE_PROPERTY": "W8"
}

db_styles = {
    "Neo4j":     {"color": "tab:blue",   "linestyle": "-",  "marker": "o"},
    "JanusGraph": {"color": "tab:orange", "linestyle": "-", "marker": "s"},
    "ArangoDB":  {"color": "tab:green",  "linestyle": "--", "marker": "D"},
    "MemGraph":  {"color": "tab:purple", "linestyle": "-",  "marker": "^"},
    "MongoDB":   {"color": "tab:brown",  "linestyle": "--",  "marker": "v"},
    "GRACE":     {"color": "tab:red",    "linestyle": "-", "marker": "x"},
}

def parse_results(db_path, db_name):
    """Parse results.txt for one DB, return list of dicts."""
    results_file = os.path.join(db_path, "results.txt")
    if not os.path.exists(results_file):
        return []

    data = []
    failed_latencies = {}

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
            value = float(value.strip())

            # Store failed values
            if operation.endswith("-FAILED"):
                base_op = operation.replace("-FAILED", "")
                if base_op in dict_operations:
                    failed_latencies[(db_name, dict_operations[base_op])] = value

            if metric == "AverageLatency(us)" and operation in dict_operations:
                op_label = dict_operations[operation]
                if value == 0 and (db_name, op_label) in failed_latencies:
                    value = failed_latencies[(db_name, op_label)]
                data.append({"DB": db_name, "Operation": op_label, "Latency": value})

    return data


def build_pivot_for_dataset(dataset_path):
    """Build pivot DataFrame (operations × DBs) for one dataset."""
    data = []
    for db in os.listdir(dataset_path):
        db_path = os.path.join(dataset_path, db)
        if not os.path.isdir(db_path):
            continue
        data.extend(parse_results(db_path, db))

    if not data:
        return None

    df = pd.DataFrame(data)
    pivot_df = df.pivot(index="Operation", columns="DB", values="Latency").fillna(0)

    if "GRACE" in pivot_df.columns:
        cols = [c for c in pivot_df.columns if c != "GRACE"] + ["GRACE"]
        pivot_df = pivot_df[cols]

    return pivot_df


# SOLUTION 1: Fixed legend with better positioning
def plot_latencies_line_v1(root_dir: str, figure_path: str):
    datasets = [d for d in os.listdir(root_dir) if os.path.isdir(os.path.join(root_dir, d))]
    datasets.sort()

    # Increase figure height to accommodate legend
    fig, axes = plt.subplots(1, len(datasets), figsize=(4*len(datasets), 5))

    if len(datasets) == 1:
        axes = [axes]

    for i, dataset in enumerate(datasets):
        ax = axes[i]
        pivot_df = build_pivot_for_dataset(os.path.join(root_dir, dataset))
        if pivot_df is None:
            continue

        x = np.arange(len(pivot_df.index))
        for db in pivot_df.columns:
            style = db_styles.get(db, {})
            ax.plot(x, pivot_df[db].values, label=db,
                    color=style.get("color", None),
                    linestyle=style.get("linestyle", "-"),
                    marker=style.get("marker", "o"),
                    markersize=3,
                    linewidth=1
                    )

        ax.set_title(dataset, fontsize=10)
        ax.set_xticks(x)
        ax.set_xticklabels(pivot_df.index, fontsize=8)
        ax.set_yscale("log")
        ax.grid(axis="y", linestyle="--", alpha=0.7)

    # Common y-label
    fig.text(0.02, 0.5, "Latency (µs)", va="center", rotation="vertical")

    # Get legend from first axis and position it better
    handles, labels = axes[0].get_legend_handles_labels()
    fig.legend(handles, labels, 
               loc="upper center", 
               bbox_to_anchor=(0.5, 0.95),  # Explicit positioning
               ncol=3, 
               fontsize=9,
               frameon=True)

    # Adjust layout with more space for legend
    fig.tight_layout(rect=[0.03, 0.03, 1, 0.88])
    fig.savefig(figure_path, dpi=500, bbox_inches='tight')
    plt.close(fig)


# SOLUTION 2: Legend below the plots
def plot_latencies_line_v2(root_dir: str, figure_path: str):
    datasets = [d for d in os.listdir(root_dir) if os.path.isdir(os.path.join(root_dir, d))]
    datasets.sort()

    fig, axes = plt.subplots(1, len(datasets), figsize=(4*len(datasets), 5))

    if len(datasets) == 1:
        axes = [axes]

    for i, dataset in enumerate(datasets):
        ax = axes[i]
        pivot_df = build_pivot_for_dataset(os.path.join(root_dir, dataset))
        if pivot_df is None:
            continue

        x = np.arange(len(pivot_df.index))
        for db in pivot_df.columns:
            style = db_styles.get(db, {})
            ax.plot(x, pivot_df[db].values, label=db,
                    color=style.get("color", None),
                    linestyle=style.get("linestyle", "-"),
                    marker=style.get("marker", "o"),
                    markersize=3,
                    linewidth=1
                    )

        ax.set_title(dataset, fontsize=10)
        ax.set_xticks(x)
        ax.set_xticklabels(pivot_df.index, fontsize=8)
        ax.set_yscale("log")
        ax.grid(axis="y", linestyle="--", alpha=0.7)

    # Common y-label
    fig.text(0.02, 0.5, "Latency (µs)", va="center", rotation="vertical")

    # Legend below the plots
    handles, labels = axes[0].get_legend_handles_labels()
    fig.legend(handles, labels, 
               loc="lower center", 
               bbox_to_anchor=(0.5, -0.05),
               ncol=len(labels), 
               fontsize=9)

    fig.tight_layout(rect=[0.03, 0.08, 1, 1])
    fig.savefig(figure_path, dpi=500, bbox_inches='tight')
    plt.close(fig)


# SOLUTION 3: Legend on the right side
def plot_latencies_line_v3(root_dir: str, figure_path: str):
    datasets = [d for d in os.listdir(root_dir) if os.path.isdir(os.path.join(root_dir, d))]
    datasets.sort()

    fig, axes = plt.subplots(1, len(datasets), figsize=(4*len(datasets) + 1.5, 4))

    if len(datasets) == 1:
        axes = [axes]

    for i, dataset in enumerate(datasets):
        ax = axes[i]
        pivot_df = build_pivot_for_dataset(os.path.join(root_dir, dataset))
        if pivot_df is None:
            continue

        x = np.arange(len(pivot_df.index))
        for db in pivot_df.columns:
            style = db_styles.get(db, {})
            ax.plot(x, pivot_df[db].values, label=db,
                    color=style.get("color", None),
                    linestyle=style.get("linestyle", "-"),
                    marker=style.get("marker", "o"),
                    markersize=3,
                    linewidth=1
                    )

        ax.set_title(dataset, fontsize=10)
        ax.set_xticks(x)
        ax.set_xticklabels(pivot_df.index, fontsize=8)
        ax.set_yscale("log")
        ax.grid(axis="y", linestyle="--", alpha=0.7)

    # Common y-label
    fig.text(0.02, 0.5, "Latency (µs)", va="center", rotation="vertical")

    # Legend on the right
    handles, labels = axes[0].get_legend_handles_labels()
    fig.legend(handles, labels, 
               loc="center left", 
               bbox_to_anchor=(1.02, 0.5),
               fontsize=9)

    fig.tight_layout(rect=[0.03, 0, 0.85, 1])
    fig.savefig(figure_path, dpi=500, bbox_inches='tight')
    plt.close(fig)


# Use the original function name but with the fixed version
def plot_latencies_line(root_dir: str, figure_path: str):
    """Default implementation using solution 1 (legend on top)"""
    plot_latencies_line_v1(root_dir, figure_path)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Plot benchmark latencies across datasets.")
    parser.add_argument("root_dir", help="Path to the root results directory")
    parser.add_argument("figure_path", help="Path to save the output figure (with extension, e.g., .png)")
    parser.add_argument("--legend-pos", choices=['top', 'bottom', 'right'], default='top',
                       help="Legend position (default: top)")
    args = parser.parse_args()

    if args.legend_pos == 'top':
        plot_latencies_line_v1(args.root_dir, args.figure_path)
    elif args.legend_pos == 'bottom':
        plot_latencies_line_v2(args.root_dir, args.figure_path)
    elif args.legend_pos == 'right':
        plot_latencies_line_v3(args.root_dir, args.figure_path)