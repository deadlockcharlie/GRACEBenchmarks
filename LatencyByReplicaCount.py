import os
import argparse
import pandas as pd
import matplotlib.pyplot as plt
import math
import numpy as np
from pathlib import Path
from typing import List, Dict, Tuple

# Configuration
OPERATION_MAPPING = {
    "GET_VERTEX_COUNT": "R1", "GET_EDGE_COUNT": "R2", "GET_EDGE_LABELS": "R3",
    "GET_VERTEX_WITH_PROPERTY": "R4", "GET_EDGE_WITH_PROPERTY": "R5", "GET_EDGES_WITH_LABEL": "R6",
    "ADD_VERTEX": "W1", "SET_VERTEX_PROPERTY": "W2", "REMOVE_VERTEX_PROPERTY": "W3",
    "ADD_EDGE": "W4", "SET_EDGE_PROPERTY": "W5", "REMOVE_VERTEX": "W6",
    "REMOVE_EDGE": "W7", "REMOVE_EDGE_PROPERTY": "W8"
}

READ_OPS = {"R1", "R2", "R3", "R4", "R5", "R6"}
WRITE_OPS = {"W1", "W2", "W3", "W4", "W5", "W6", "W7", "W8"}

DB_STYLES = {
    "ArangoDB": {"color": "tab:green", "linestyle": "--", "marker": "D"},
    "MongoDB": {"color": "tab:brown", "linestyle": "--", "marker": "v"},
    "Neo4j": {"color": "tab:blue", "linestyle": "-", "marker": "o"},
    "JanusGraph": {"color": "tab:orange", "linestyle": "-", "marker": "s"},
    "MemGraph": {"color": "tab:purple", "linestyle": "-", "marker": "^"},
    "GRACE": {"color": "tab:red", "linestyle": "-", "marker": "x"},
}
DATASETS = {"yeast": "yeast", "mico": "mico", "ldbc": "LDBC", "frbs": "Freebase-S", "frbm": "Freebase-M", "frbo": "Freebase-O"}


def parse_result_file(filepath: Path, db_name: str) -> List[Dict]:
    """Parse a single results file and return operation latencies."""
    if not filepath.exists():
        return []
    data, failed_latencies = [], {}
    for line in filepath.read_text().splitlines():
        if not line.strip() or "," not in line:
            continue
        parts = [p.strip() for p in line.split(",")]
        if len(parts) != 3:
            continue
        operation, metric, value = parts[0].strip("[]"), parts[1], float(parts[2])
        if operation.endswith("-FAILED"):
            base_op = operation.replace("-FAILED", "")
            if base_op in OPERATION_MAPPING:
                failed_latencies[OPERATION_MAPPING[base_op]] = value
        elif metric == "50thPercentileLatency(us)" and operation in OPERATION_MAPPING:
            op_label = OPERATION_MAPPING[operation]
            latency = failed_latencies.get(op_label, value) if value == 0 else value
            data.append({"DB": db_name, "Operation": op_label, "Latency": latency})
    return data


def collect_data(root_dir: str) -> pd.DataFrame:
    """Collect and aggregate all benchmark data."""
    results = []
    root_path = Path(root_dir)
    for dataset_path in root_path.iterdir():
        if not dataset_path.is_dir():
            continue
        for db_path in dataset_path.iterdir():
            if not db_path.is_dir():
                continue
            for result_file in db_path.glob("*.txt"):
                try:
                    replica_count = int(result_file.stem)
                except ValueError:
                    continue
                operations = parse_result_file(result_file, db_path.name)
                if not operations:
                    continue
                df = pd.DataFrame(operations)
                for op_type, op_set in [("Read", READ_OPS), ("Write", WRITE_OPS)]:
                    type_ops = df[df["Operation"].isin(op_set)]
                    if not type_ops.empty:
                        results.append({
                            "Dataset": dataset_path.name,
                            "ReplicaCount": replica_count,
                            "DB": db_path.name,
                            "Type": op_type,
                            "Latency": type_ops["Latency"].mean()
                        })
    return pd.DataFrame(results)


def plot_dataset(ax: plt.Axes, data: pd.DataFrame, dataset: str, op_type: str, ylim: Tuple[float, float]) -> None:
    """Plot data for a single dataset on given axes."""
    dataset_data = data[(data["Dataset"] == dataset) & (data["Type"] == op_type)]
    for db in dataset_data["DB"].unique():
        db_data = dataset_data[dataset_data["DB"] == db].sort_values("ReplicaCount")
        if db_data.empty:
            continue
        style = DB_STYLES.get(db, {})
        ax.plot(db_data["ReplicaCount"], db_data["Latency"], label=db,
                color=style.get("color"), linestyle=style.get("linestyle", "-"),
                marker=style.get("marker", "o"), markersize=4, linewidth=1)
    # Set yticks labels to be readable
    yticks = [100, 1000, 10000, 100000, 1000000, 10000000, 100000000]
    yticklabels = ['0ms', '1ms', '10ms', '100ms', '1s', '10s', '100s']

    ax.set_title(DATASETS.get(dataset, dataset), fontsize=9)
    ax.set_xticks(sorted(data["ReplicaCount"].unique()))
    ax.set_yscale("log")
    ax.set_ylim(ylim)
    ax.set_yticks(yticks)
    ax.set_yticklabels(yticklabels, fontsize=8)
    
    # ax.set_yticklabels([f"{y/1000:.0f}ms" if y < 1_000_000 else f"{y/1_000_000:.1f}s" for y in yticks])
    
    ax.grid(axis="y", linestyle="--", alpha=0.7)


def create_combined_plot(data: pd.DataFrame, output_path: str) -> None:
    """Create and save one figure with all datasets for both Read and Write."""
    datasets = sorted(data["Dataset"].unique())
    datasets.sort(key=lambda x: list(DATASETS.keys()).index(x) if x in DATASETS else len(DATASETS))

    n_datasets = len(datasets)
    cols = min(3, n_datasets)
    rows = math.ceil(2)
    fig, axes = plt.subplots(2 * rows, cols, figsize=(cols * 1.8, rows * 4), sharey = "row")

    axes = np.array(axes)
    axes = axes.reshape(2, rows, cols)  # [op_type_index][row][col]
    op_types = ["Read", "Write"]
    
    # Calculate global y-axis limits
    y_min = data["Latency"].min()
    y_max = data["Latency"].max()
    ylim = (y_min * 0.5, y_max * 2)  # Add some padding
    
    for op_idx, op_type in enumerate(op_types):
        for i, dataset in enumerate(datasets):
            row, col = divmod(i, cols)
            ax = axes[op_idx, row, col]
            plot_dataset(ax, data, dataset, op_type, ylim)
            if row == rows - 1:
                ax.set_xlabel("Replica Count", fontsize=8)
            if col == 0:
                ax.set_ylabel("Median Latency", fontsize=8)
        # Hide unused subplots if datasets < rows*cols
        for j in range(n_datasets, rows * cols):
            row, col = divmod(j, cols)
            axes[op_idx, row, col].set_visible(False)

    # Add section labels for Read/Write
    for op_idx, op_type in enumerate(op_types):
        fig.text(-0.01, 0.70 - op_idx * 0.45, f"{op_type} Operations", rotation=90,
                 va="center", fontsize=11, fontweight="bold")

    # Create global legend
    all_dbs = sorted(data["DB"].unique(), key=lambda x: list(DB_STYLES.keys()).index(x)
                     if x in DB_STYLES else len(DB_STYLES))
    legend_elements = []
    for db in all_dbs:
        style = DB_STYLES.get(db, {})
        legend_elements.append(plt.Line2D([0], [0],
                                          color=style.get("color"),
                                          linestyle=style.get("linestyle", "-"),
                                          marker=style.get("marker", "o"),
                                          markersize=5, linewidth=1.5, label=db))
    fig.legend(handles=legend_elements, loc="upper center", bbox_to_anchor=(0.5, 0.98),
               ncol=len(all_dbs), fontsize=9)

    fig.tight_layout(rect=[0, 0, 1, 0.93])
    fig.savefig(output_path, dpi=500, bbox_inches='tight')
    plt.close(fig)


def main():
    parser = argparse.ArgumentParser(description="Generate latency plots (Read + Write in one figure)")
    parser.add_argument("root_dir", help="Root directory containing dataset folders")
    parser.add_argument("figure_path", help="Path to output figure (e.g., results.png)")
    args = parser.parse_args()

    data = collect_data(args.root_dir)
    if data.empty:
        print("No data found")
        return

    create_combined_plot(data, args.figure_path)


if __name__ == "__main__":
    main()