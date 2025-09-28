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
    "Neo4j": {"color": "tab:blue", "linestyle": "-", "marker": "o"},
    "JanusGraph": {"color": "tab:orange", "linestyle": "-", "marker": "s"},
    "ArangoDB": {"color": "tab:green", "linestyle": "--", "marker": "D"},
    "MemGraph": {"color": "tab:purple", "linestyle": "-", "marker": "^"},
    "MongoDB": {"color": "tab:brown", "linestyle": "--", "marker": "v"},
    "GRACE": {"color": "tab:red", "linestyle": "-", "marker": "x"},
}

DATASETS = {"yeast":"yeast", "mico":"mico", "ldbc":"LDBC", "frbs":"Freebase-S", "frbo":"Freebase-O", "frbm":"Freebase-M"}

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
    
    for threadCount_dir in root_path.iterdir():
        if not threadCount_dir.is_dir():
            continue
        
        # Thread count is the directory name
        try:
            thread_count = int(threadCount_dir.name)
        except ValueError:
            continue
            
        for db_path in threadCount_dir.iterdir():
            if not db_path.is_dir():
                continue
            
            # Look for 3.txt file in each database directory
            result_file = db_path / "3.txt"
            if not result_file.exists():
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
                        "ThreadCount": thread_count,
                        "ReplicaCount": 3,  # Fixed replica count since file is always 3.txt
                        "DB": db_path.name,
                        "Type": op_type,
                        "Latency": type_ops["Latency"].mean()
                    })
    
    return pd.DataFrame(results)


def plot_ldbc_dataset(ax: plt.Axes, data: pd.DataFrame, op_type: str) -> None:
    """Plot data for LDBC dataset on given axes."""
    dataset_data = data[data["Type"] == op_type]
    thread_counts = sorted(dataset_data["ThreadCount"].unique())
    
    for db in dataset_data["DB"].unique():
        db_data = dataset_data[dataset_data["DB"] == db].sort_values("ThreadCount")
        if db_data.empty:
            continue
        
        # Map thread counts to regular intervals (0, 1, 2, ...)
        x_positions = [thread_counts.index(tc) for tc in db_data["ThreadCount"]]
            
        style = DB_STYLES.get(db, {})
        ax.plot(x_positions, db_data["Latency"], label=db,
                color=style.get("color"), linestyle=style.get("linestyle", "-"),
                marker=style.get("marker", "o"), markersize=6, linewidth=2)
    
    ax.set_title(f"LDBC Dataset - {op_type} Operations")
    thread_counts = sorted(data["ThreadCount"].unique())
    ax.set_xticks(range(len(thread_counts)))
    ax.set_xticklabels(thread_counts)
    ax.set_xlabel("Thread Count")
    ax.set_ylabel("Latency (µs)")
    ax.set_yscale("log")
    ax.grid(axis="y", linestyle="--", alpha=0.7)
    ax.legend()


def create_plot(data: pd.DataFrame, op_type: str, output_path: str) -> None:
    """Create and save single plot for LDBC dataset and given operation type."""
    type_data = data[data["Type"] == op_type]
    if type_data.empty:
        print(f"No data for {op_type} operations")
        return
    
    # Create single plot
    fig, ax = plt.subplots(1, 1, figsize=(8, 6))
    
    # Plot data across all thread counts
    plot_ldbc_dataset(ax, type_data, op_type)
    
    fig.tight_layout()
    fig.savefig(output_path, dpi=500, bbox_inches='tight')
    plt.close(fig)


def main():
    parser = argparse.ArgumentParser(description="Generate latency plots for LDBC dataset only")
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