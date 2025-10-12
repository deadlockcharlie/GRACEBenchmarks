import os
import argparse
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
from pathlib import Path
from typing import Optional, List

# Configuration
OPERATION_MAPPING = {
    "GET_VERTEX_COUNT": "R1", 
    "GET_EDGE_COUNT": "R2", 
    "GET_EDGE_LABELS": "R3",
    "GET_VERTEX_WITH_PROPERTY": "R4", 
    "GET_EDGE_WITH_PROPERTY": "R5", 
    "GET_EDGES_WITH_LABEL": "R6",
    "ADD_VERTEX": "W1", 
    "SET_VERTEX_PROPERTY": "W2", 
    "ADD_EDGE": "W3", 
    "SET_EDGE_PROPERTY": "W4", 
    "REMOVE_VERTEX": "W5",
    "REMOVE_VERTEX_PROPERTY": "W6",
    "REMOVE_EDGE": "W7", 
    "REMOVE_EDGE_PROPERTY": "W8"
}

DB_STYLES = {
    "ArangoDB": {"color": "tab:green", "linestyle": "--", "marker": "D"},
    "MongoDB": {"color": "tab:brown", "linestyle": "--", "marker": "v"},
    "Neo4j": {"color": "tab:blue", "linestyle": "-", "marker": "o"},
    "JanusGraph": {"color": "tab:orange", "linestyle": "-", "marker": "s"},
    "MemGraph": {"color": "tab:purple", "linestyle": "-", "marker": "^"},
    "GRACE": {"color": "tab:red", "linestyle": "-", "marker": "x"},
}

DATASETS = {"yeast":"yeast", "mico":"mico", "ldbc":"LDBC", "frbs":"Freebase-S", "frbm":"Freebase-M","frbo":"Freebase-O"}


def parse_results(replica_count: int, db_path: Path, db_name: str) -> List[dict]:
    """Parse results.txt for one DB, return list of dicts."""
    results_file = db_path / f"{replica_count}.txt"
    if not results_file.exists():
        return []

    data = []
    failed_latencies = {}

    for line in results_file.read_text().splitlines():
        if not line.strip() or "," not in line:
            continue
            
        parts = line.split(",")
        if len(parts) != 3:
            continue

        operation, metric, value = [p.strip() for p in parts]
        operation = operation.strip("[]")
        value = float(value)
        # If the operation is read, and db is not grace deduct 4 micros from the latency, injected due to traffic shaping. 
        # if operation in OPERATION_MAPPING and OPERATION_MAPPING[operation].startswith("R") and db_name != "GRACE":
            # value = max(0, value - 2000)  # Ensure latency doesn't go negative        
        # Store failed values
        if operation.endswith("-FAILED"):
            base_op = operation.replace("-FAILED", "")
            if base_op in OPERATION_MAPPING:
                failed_latencies[(db_name, OPERATION_MAPPING[base_op])] = value

        if metric == "50thPercentileLatency(us)" and operation in OPERATION_MAPPING:
            op_label = OPERATION_MAPPING[operation]
            if value == 0 and (db_name, op_label) in failed_latencies:
                value = failed_latencies[(db_name, op_label)]
            data.append({"DB": db_name, "Operation": op_label, "Latency": value})

    return data


def build_pivot_for_dataset(replica_count: int, dataset_path: Path) -> Optional[pd.DataFrame]:
    """Build pivot DataFrame (operations × DBs) for one dataset."""
    data = []
    
    for db_path in dataset_path.iterdir():
        if not db_path.is_dir():
            continue
        data.extend(parse_results(replica_count, db_path, db_path.name))

    if not data:
        return None

    df = pd.DataFrame(data)
    pivot_df = df.pivot(index="Operation", columns="DB", values="Latency").fillna(0)

    # Move GRACE to end if present
    if "GRACE" in pivot_df.columns:
        cols = [c for c in pivot_df.columns if c != "GRACE"] + ["GRACE"]
        pivot_df = pivot_df[cols]

    return pivot_df


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


def create_single_legend(fig: plt.Figure, all_dbs: List[str], legend_pos: str = 'top') -> None:
    """Create a single legend for the entire figure."""
    legend_elements = []
    ## Sort DBs according to the order in DB_STYLES, with GRACE last
    all_dbs = [db for db in DB_STYLES.keys() if db in all_dbs] + [db for db in all_dbs if db not in DB_STYLES]
    
    for db in all_dbs:
        style = DB_STYLES.get(db, {})
        legend_elements.append(plt.Line2D([0], [0], 
                                        color=style.get("color"),
                                        linestyle=style.get("linestyle", "-"),
                                        marker=style.get("marker", "o"),
                                        markersize=6, linewidth=2, label=db))

    if legend_pos == 'top':
        fig.legend(handles=legend_elements, loc="upper center", 
                  bbox_to_anchor=(0.5, 0.95), ncol=len(all_dbs), fontsize=9, frameon=True)
    elif legend_pos == 'bottom':
        fig.legend(handles=legend_elements, loc="lower center", 
                  bbox_to_anchor=(0.5, 0.02), ncol=len(all_dbs), fontsize=9)
    elif legend_pos == 'right':
        fig.legend(handles=legend_elements, loc="center left", 
                  bbox_to_anchor=(1.02, 0.5), fontsize=9)


def plot_dataset_operations(replica_count: int, ax: plt.Axes, pivot_df: pd.DataFrame, dataset: str, y_range: tuple) -> None:
    """Plot operations for a single dataset with consistent y-axis range."""
    x = np.arange(len(pivot_df.index))
    # print(pivot_df)
    for db in pivot_df.columns:
        style = DB_STYLES.get(db, {})
        y_values = pivot_df[db].values
        
        # Replace zeros with max y_range value for log scale plotting
        y_values_plot = np.where(y_values > 0, y_values, y_range[1])
        
        # Plot the line
        ax.plot(x, y_values_plot, 
                color=style.get("color"),
                linestyle=style.get("linestyle", "-"),
                linewidth=1)
        
        # Plot markers - red cross for missing/zero values, normal markers otherwise
        for i, (y_val, y_plot) in enumerate(zip(y_values, y_values_plot)):
            if y_val == 0:
                # Plot red cross for missing/failed operations (originally zero)
                ax.plot(x[i], y_plot, marker='x', color='gray',
                       markersize=4, markeredgewidth=2, zorder=10)
            elif y_val > 0:
                # Plot normal marker for valid data
                ax.plot(x[i], y_plot, marker=style.get("marker", "o"),
                       color=style.get("color"), markersize=3)
    
    # For charts more than 1 replica
    if replica_count > 1:
        ax.axhline(y=144000, color='black', linestyle=':', linewidth=1, alpha=0.8, label='600ms threshold')
    
    ax.set_title(DATASETS[dataset], fontsize=10)
    ax.set_xticks(x)
    ax.set_xticklabels(pivot_df.index, fontsize=10, rotation=90, ha="right")
    
    # Set yticks labels to be readable
    yticks = [100, 1000, 10000, 100000, 1000000, 10000000, 100000000]
    yticklabels = ['0ms', '1ms', '10ms', '100ms', '1s', '10s', '100s']
    ax.set_yscale("log")
    ax.set_yticks(yticks)
    ax.set_yticklabels(yticklabels, fontsize=8)
    ax.grid(axis="y", linestyle="--", alpha=0.7)


def plot_operations_comparison(replica_count: int, root_dir: str, figure_path: str, legend_pos: str = 'top') -> None:
    """Create operations comparison plot with single legend and consistent y-axis."""
    root_path = Path(root_dir)
    datasets = [d.name for d in root_path.iterdir() if d.is_dir()]
    print(datasets)
    
    if not datasets:
        print("No datasets found")
        return

    # Sort datasets according to DATASETS order and if a dataset is not present, then ignore it
    datasets = [d for d in DATASETS.keys() if d in datasets]
    
    # First pass: collect all pivot DataFrames to determine global y-range
    all_pivot_dfs = []
    dataset_pivot_pairs = []
    
    for dataset in datasets:
        dataset_path = root_path / dataset
        pivot_df = build_pivot_for_dataset(replica_count, dataset_path)
        if pivot_df is not None:
            all_pivot_dfs.append(pivot_df)
            dataset_pivot_pairs.append((dataset, pivot_df))
    
    if not all_pivot_dfs:
        print("No valid data found in any dataset")
        return
    
    # Calculate global y-axis range
    y_range = find_global_y_range(all_pivot_dfs)
    print(f"Global y-axis range: {y_range[0]:.2e} to {y_range[1]:.2e}")

    # Determine figure size and layout based on legend position
    base_width = 12
    if legend_pos == 'right':
        fig_size = (base_width + 1.5, 4)
        layout_rect = [0.03, 0, 0.85, 1]
    elif legend_pos == 'bottom':
        fig_size = (base_width, 5)
        layout_rect = [0.03, 0.08, 1, 1]
    else:  # top
        fig_size = (base_width, 5)
        layout_rect = [0.03, 0.03, 1, 0.88]

    fig, axes = plt.subplots(2, 3, figsize=fig_size, sharey=True)

    all_dbs = set()
    
    # Second pass: create plots with consistent y-axis
    for i, (dataset, pivot_df) in enumerate(dataset_pivot_pairs):
        plot_dataset_operations(replica_count, axes[i // 3, i % 3], pivot_df, dataset, y_range)
        all_dbs.update(pivot_df.columns)

    # Add common y-label
    fig.text(0.02, 0.5, "Latency (µs)", va="center", rotation="vertical", fontsize=12)

    # Create single legend
    if all_dbs:
        all_dbs_sorted = sorted(all_dbs, key=lambda x: x != "GRACE")  # GRACE last
        create_single_legend(fig, all_dbs_sorted, legend_pos)

    fig.tight_layout(rect=layout_rect)
    fig.savefig(figure_path, dpi=500, bbox_inches='tight')
    plt.close(fig)


def main():
    parser = argparse.ArgumentParser(description="Plot benchmark latencies across datasets with consistent y-axis range.")
    parser.add_argument("replica_count", type=int, choices=[1, 3], help="Number of replicas (1 or 3)")
    parser.add_argument("root_dir", help="Path to the root results directory")
    parser.add_argument("figure_path", help="Path to save the output figure (with extension, e.g., .png)")
    parser.add_argument("--legend-pos", choices=['top', 'bottom', 'right'], default='top',
                       help="Legend position (default: top)")
    
    args = parser.parse_args()

    plot_operations_comparison(args.replica_count, args.root_dir, args.figure_path, args.legend_pos)


if __name__ == "__main__":
    main()