import os
import argparse
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
from pathlib import Path
from typing import Optional, List
import seaborn as sns

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

DATASETS = {
    "yeast": "yeast", 
    "mico": "mico", 
    "ldbc": "LDBC", 
    "frbs": "Freebase-S", 
    "frbm": "Freebase-M",
    "frbo": "Freebase-O"
}

# Database ordering (GRACE last)
DB_ORDER = ["ArangoDB", "MongoDB", "Neo4j", "JanusGraph", "MemGraph", "GRACE"]


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
        
        # Skip non-numeric values
        try:
            value = float(value)
        except ValueError:
            print(f"Skipping non-numeric value: {value}")
            continue
        
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
    pivot_df = df.pivot(index="Operation", columns="DB", values="Latency")
    
    # Reorder columns according to DB_ORDER
    available_dbs = [db for db in DB_ORDER if db in pivot_df.columns]
    pivot_df = pivot_df[available_dbs]
    
    # Sort operations (R1-R6, then W1-W8)
    all_ops = [f"R{i}" for i in range(1, 7)] + [f"W{i}" for i in range(1, 9)]
    available_ops = [op for op in all_ops if op in pivot_df.index]
    pivot_df = pivot_df.reindex(available_ops)

    return pivot_df


def find_global_log_range(all_pivot_dfs: List[pd.DataFrame]) -> tuple:
    """Find the global min and max for log scale across all datasets."""
    all_values = []
    
    for pivot_df in all_pivot_dfs:
        non_zero_values = pivot_df.values[~np.isnan(pivot_df.values) & (pivot_df.values > 0)]
        if len(non_zero_values) > 0:
            all_values.extend(non_zero_values)
    
    if not all_values:
        return 1, 1000000
    
    global_min = min(all_values)
    global_max = max(all_values)
    
    # Add padding in log space
    log_min = np.log10(global_min)
    log_max = np.log10(global_max)
    
    padded_min = 10 ** (log_min - 0.5)
    padded_max = 10 ** (log_max + 0.5)
    
    return padded_min, padded_max


def format_latency_label(value):
    """Convert microseconds to readable format."""
    if np.isnan(value) or value == 0:
        return "N/A"
    
    if value < 1000:
        return f"{int(value)}µs"
    elif value < 1000000:
        return f"{value/1000:.0f}ms"
    else:
        return f"{value/1000000:.1f}s"


def plot_heatmap(replica_count: int, ax: plt.Axes, pivot_df: pd.DataFrame, 
                 dataset: str, vmin: float, vmax: float, 
                 show_values: bool = True, cbar: bool = False) -> None:
    """Plot heatmap for a single dataset."""
    
    # Take log of values for better color distribution
    log_data = np.log10(pivot_df.fillna(0).replace(0, np.nan))
    
    # Create heatmap
    sns.heatmap(
        log_data,
        ax=ax,
        cmap="RdYlGn_r",
        vmin=np.log10(vmin),
        vmax=np.log10(vmax),
        cbar=cbar,
        linewidths=0.5,
        linecolor='white',
        square=False,
        annot=False,
        fmt='',
        xticklabels=True,
        yticklabels=True
    )
    
    # Optionally add text annotations with actual values
    if show_values:
        for i in range(len(pivot_df.index)):
            for j in range(len(pivot_df.columns)):
                value = pivot_df.iloc[i, j]
                if pd.notna(value) and value > 0:
                    # Use white text for dark cells, black for light cells
                    log_val = np.log10(value)
                    text_color = 'white' if log_val > (np.log10(vmin) + np.log10(vmax)) / 2 else 'black'
                    
                    # Format the text
                    if value < 1000:
                        text = f"{int(value)}"
                    elif value < 10000:
                        text = f"{value/1000:.1f}m"
                    elif value < 1000000:
                        text = f"{int(value/1000)}m"
                    else:
                        text = f"{value/1000000:.1f}s"
                    
                    ax.text(j + 0.5, i + 0.5, text,
                           ha='center', va='center',
                           fontsize=6, color=text_color, weight='bold')
                else:
                    # Mark missing values with X
                    ax.text(j + 0.5, i + 0.5, '×',
                           ha='center', va='center',
                           fontsize=10, color='gray', weight='bold')
    
    ax.set_title(DATASETS[dataset], fontsize=10, pad=5)
    ax.set_xlabel('')
    ax.set_ylabel('')
    
    # Rotate x labels
    ax.set_xticklabels(ax.get_xticklabels(), rotation=45, ha='right', fontsize=8)
    ax.set_yticklabels(ax.get_yticklabels(), rotation=0, fontsize=8)


def plot_heatmaps_comparison(replica_count: int, root_dir: str, figure_path: str, 
                             show_values: bool = True) -> None:
    """Create heatmap comparison plot across all datasets."""
    root_path = Path(root_dir)
    datasets = [d.name for d in root_path.iterdir() if d.is_dir()]
    
    if not datasets:
        print("No datasets found")
        return

    # Sort datasets according to DATASETS order
    datasets = [d for d in DATASETS.keys() if d in datasets]
    
    # First pass: collect all pivot DataFrames to determine global range
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
    
    # Calculate global log range
    vmin, vmax = find_global_log_range(all_pivot_dfs)
    print(f"Global latency range: {vmin:.2e} to {vmax:.2e}")
    
    # Create figure
    fig, axes = plt.subplots(2, 3, figsize=(14, 8))
    
    # Plot each dataset
    for i, (dataset, pivot_df) in enumerate(dataset_pivot_pairs):
        row, col = i // 3, i % 3
        # Only show colorbar on the last plot
        show_cbar = (i == len(dataset_pivot_pairs) - 1)
        plot_heatmap(replica_count, axes[row, col], pivot_df, dataset, 
                    vmin, vmax, show_values=show_values, cbar=show_cbar)
    
    # Hide unused subplots
    for i in range(len(dataset_pivot_pairs), 6):
        row, col = i // 3, i % 3
        axes[row, col].axis('off')
    
    # Add common labels
    fig.text(0.5, 0.02, 'Database', ha='center', fontsize=11, weight='bold')
    fig.text(0.02, 0.5, 'Operation', va='center', rotation='vertical', 
             fontsize=11, weight='bold')
    
    # Add colorbar
    # cbar = fig.colorbar(axes[0, 0].collections[0], ax=axes, 
    #                    location='right', shrink=0.6, pad=0.1)
    # cbar.set_label('Latency', rotation=270, labelpad=15, fontsize=10)
    
    # # Set colorbar ticks to readable values
    # log_ticks = np.linspace(np.log10(vmin), np.log10(vmax), 6)
    # cbar.set_ticks(log_ticks)
    # tick_labels = []
    # for log_val in log_ticks:
    #     val = 10 ** log_val
    #     if val < 1000:
    #         tick_labels.append(f"{int(val)}µs")
    #     elif val < 1000000:
    #         tick_labels.append(f"{int(val/1000)}ms")
    #     else:
    #         tick_labels.append(f"{val/1000000:.1f}s")
    # cbar.set_ticklabels(tick_labels)
    
    plt.tight_layout(rect=[0.03, 0.03, 0.97, 0.97])
    plt.savefig(figure_path, dpi=300, bbox_inches='tight')
    print(f"Heatmap saved to {figure_path}")
    plt.close(fig)


def main():
    parser = argparse.ArgumentParser(
        description="Create heatmap visualization of benchmark latencies across datasets."
    )
    parser.add_argument("replica_count", type=int, choices=[1, 3], 
                       help="Number of replicas (1 or 3)")
    parser.add_argument("root_dir", 
                       help="Path to the root results directory")
    parser.add_argument("figure_path", 
                       help="Path to save the output figure (e.g., heatmap.png)")
    parser.add_argument("--hide-values", action="store_true",
                       help="Hide numerical values in heatmap cells")
    
    args = parser.parse_args()
    
    plot_heatmaps_comparison(
        args.replica_count, 
        args.root_dir, 
        args.figure_path,
        show_values=not args.hide_values
    )


if __name__ == "__main__":
    main()