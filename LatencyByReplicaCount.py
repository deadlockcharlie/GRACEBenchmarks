import os
import argparse
import pandas as pd
import matplotlib.pyplot as plt
import math
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
DATASETS = {"yeast":"yeast", "mico":"mico", "ldbc":"LDBC", "frbs":"Freebase-S", "frbm":"Freebase-M","frbo":"Freebase-O"}

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
        
        # Handle failed operations
        if operation.endswith("-FAILED"):
            base_op = operation.replace("-FAILED", "")
            if base_op in OPERATION_MAPPING:
                failed_latencies[OPERATION_MAPPING[base_op]] = value
        
        # Process successful operations
        elif metric == "AverageLatency(us)" and operation in OPERATION_MAPPING:
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
                
                # Calculate average latencies by operation type
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


def create_subplots(datasets: List[str]) -> Tuple[plt.Figure, List[plt.Axes]]:
    """Create optimally arranged subplots for datasets."""
    n_datasets = len(datasets)
    cols = min(3, n_datasets)
    rows = math.ceil(n_datasets / cols)
    
    fig, axes = plt.subplots(rows, cols, figsize=(cols * 2, rows * 2))
    axes = [axes] if n_datasets == 1 else axes.flatten() if rows > 1 else list(axes)
    
    # Hide unused subplots
    for ax in axes[n_datasets:]:
        ax.set_visible(False)
    
    return fig, axes[:n_datasets]


def plot_dataset(ax: plt.Axes, data: pd.DataFrame, dataset: str, op_type: str, show_legend: bool = False) -> None:
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

    ax.set_title(DATASETS.get(dataset, dataset), fontsize=10)
    ax.set_xticks(sorted(data["ReplicaCount"].unique()))
    # ax.set_xlabel("Replica Count")
    # ax.set_ylabel("Latency (µs)")
    ax.set_yscale("log")
    ax.grid(axis="y", linestyle="--", alpha=0.7)

def find_global_y_range(all_pivot_dfs: List[pd.DataFrame]) -> tuple:
    """Find the global minimum and maximum values across all datasets."""
    all_values = []
    
    for pivot_df in all_pivot_dfs:
        # Get all non-zero values for min calculation
        non_zero_values = pivot_df.values[pivot_df.values > 0]
        if len(non_zero_values) > 0:
            all_values.extend(non_zero_values)
    
    if not all_values:
        return 1, 1000  # Default range if no data
    
    global_min = min(all_values)
    global_max = max(all_values)
    
    # Add some padding to the range
    log_min = np.log10(global_min)
    log_max = np.log10(global_max)
    
    # Extend range slightly for better visualization
    padded_min = 10 ** (log_min -1)
    padded_max = 10 ** (log_max + 1)
    
    return padded_min, padded_max


def create_plot(data: pd.DataFrame, op_type: str, output_path: str) -> None:
    """Create and save multi-dataset plot for given operation type."""
    type_data = data[data["Type"] == op_type]
    if type_data.empty:
        print(f"No data for {op_type} operations")
        return
    
    datasets = sorted(type_data["Dataset"].unique())
    datasets.sort(key=lambda x: list(DATASETS.keys()).index(x) if x in DATASETS else len(DATASETS))
    fig, axes = create_subplots(datasets)

    # y_range = find_global_y_range([data[data["Dataset"] == ds] for ds in datasets])
    # Plot all datasets
    for ax, dataset in zip(axes, datasets):
        plot_dataset(ax, data, dataset, op_type)
    
    # Create single legend for entire figure
    # Sort databases by their order in DB_STYLES
    all_dbs = sorted(type_data["DB"].unique(), key=lambda x: list(DB_STYLES.keys()).index(x) if x in DB_STYLES else len(DB_STYLES))
    legend_elements = []
    for db in all_dbs:
        style = DB_STYLES.get(db, {})
        legend_elements.append(plt.Line2D([0], [0], 
                                        color=style.get("color"),
                                        linestyle=style.get("linestyle", "-"),
                                        marker=style.get("marker", "o"),
                                        markersize=6, linewidth=2, label=db))
    
    fig.legend(handles=legend_elements, loc="upper center", 
               bbox_to_anchor=(0.5, 0.95), ncol=len(all_dbs), fontsize=10)
    fig.text(0, 0.5, "Latency (µs)", va="center", rotation="vertical", fontsize=12)
    fig.text(0.5, 0.01, "Replica Count", ha="center", fontsize=12)
    # fig.suptitle(f"{op_type} Operations - All Datasets", fontsize=14, y=0.99)
    fig.tight_layout(rect=[0, 0, 1, 0.88])
    fig.savefig(output_path, dpi=500, bbox_inches='tight')
    plt.close(fig)


def main():
    parser = argparse.ArgumentParser(description="Generate latency plots with subplots per dataset")
    parser.add_argument("root_dir", help="Root directory containing dataset folders")
    parser.add_argument("figure_base", help="Base path for output figures (e.g., results.png)")
    args = parser.parse_args()
    
    data = collect_data(args.root_dir)
    if data.empty:
        print("No data found")
        return
    
    base_path = args.figure_base.replace(".png", "")
    create_plot(data, "Read", f"{base_path}_Read.png")
    create_plot(data, "Write", f"{base_path}_Write.png")


if __name__ == "__main__":
    main()