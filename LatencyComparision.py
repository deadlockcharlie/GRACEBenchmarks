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
    "REMOVE_VERTEX_PROPERTY": "W3",
    "ADD_EDGE": "W4", 
    "SET_EDGE_PROPERTY": "W5", 
    "REMOVE_VERTEX": "W6",
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

DATASETS = {"yeast":"yeast", "mico":"mico", "ldbc":"LDBC", "frbs":"Freebase-S", "frbo":"Freebase-O", "frbm":"Freebase-M"}


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
        value = float(value)/1000

        # Store failed values
        if operation.endswith("-FAILED"):
            base_op = operation.replace("-FAILED", "")
            if base_op in OPERATION_MAPPING:
                failed_latencies[(db_name, OPERATION_MAPPING[base_op])] = value

        if metric == "AverageLatency(us)" and operation in OPERATION_MAPPING:
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
    padded_min = 10 ** (log_min - 1)
    padded_max = 10 ** (log_max + 1)
    
    return global_min, global_max


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


def plot_dataset_operations(ax: plt.Axes, pivot_df: pd.DataFrame, dataset: str, y_range: tuple) -> None:
    """Plot operations for a single dataset with consistent y-axis range."""
    x = np.arange(len(pivot_df.index))
    for db in pivot_df.columns:
        style = DB_STYLES.get(db, {})
        y_values = pivot_df[db].values
        # print(y_values)
        
        # Replace zeros with NaN for log scale plotting (they won't be plotted)
        y_values_plot = np.where(y_values > 0, y_values, y_range[1])
        
        ax.plot(x, y_values_plot, label=db,
                color=style.get("color"),
                linestyle=style.get("linestyle", "-"),
                marker=style.get("marker", "o"),
                markersize=3, linewidth=1)

    ax.set_title(DATASETS[dataset], fontsize=10)
    ax.set_xticks(x)
    ax.set_xticklabels(pivot_df.index, fontsize=10, rotation=90, ha="right")
    # ax.set_yscale("log")
    # ax.set_ylim(y_range[0], y_range[1])  # Set consistent y-axis range
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

    fig, axes = plt.subplots(2, 3, figsize=fig_size)

    all_dbs = set()
    
    # Second pass: create plots with consistent y-axis
    for i, (dataset, pivot_df) in enumerate(dataset_pivot_pairs):
        plot_dataset_operations(axes[i // 3, i % 3], pivot_df, dataset, y_range)
        all_dbs.update(pivot_df.columns)

    # Add common y-label
    # fig.text(0.02, 0.5, "Latency (µs)", va="center", rotation="vertical", fontsize=12)
    fig.text(0.02, 0.5, "Latency (ms)", va="center", rotation="vertical", fontsize=12)

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