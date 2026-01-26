import os
import argparse
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
from pathlib import Path
from typing import List, Dict

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
    "ArangoDB": {"color": "tab:green"},
    "MongoDB": {"color": "tab:brown"},
    "Neo4j": {"color": "tab:blue"},
    "JanusGraph": {"color": "tab:orange"},
    "MemGraph": {"color": "tab:purple"},
    "GRACE": {"color": "tab:red"},
}

group_replicas = [
    ["MemGraph", "MemGraph", "MemGraph", "MemGraph"],  # 0 heterogeneous
    ["MemGraph", "MemGraph", "MemGraph", "Neo4j"],  # 1 heterogeneous
    ["MemGraph", "MemGraph", "Neo4j", "ArangoDB"],  # 2 heterogeneous
    ["MemGraph", "Neo4j", "ArangoDB", "MongoDB"]  # All heterogeneous
]

group_clients = [
    ["client_1", "client_2", "client_3", "client_4"],
    ["client_1", "client_2", "client_3", "client_4"],
    ["client_1", "client_2", "client_3", "client_4"],
    ["client_1", "client_2", "client_3", "client_4"]
]


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
        elif metric == "50thPercentileLatency(us)" and operation in OPERATION_MAPPING:
            op_label = OPERATION_MAPPING[operation]
            latency = failed_latencies.get(op_label, value) if value == 0 else value

            data.append({"DB": db_name, "Operation": op_label, "Latency": latency})
    
    return data


def collect_data(root_dir: str, dataset_name: str) -> pd.DataFrame:
    """Collect benchmark data for heterogeneous deployments."""
    results = []
    root_path = Path(root_dir)
    dataset_path = root_path / dataset_name
    
    if not dataset_path.exists():
        print(f"Dataset {dataset_name} not found")
        return pd.DataFrame()
    
    # Collect data for each database
    for db_path in dataset_path.iterdir():
        scenarioName = db_path.stem
        if not db_path.is_dir():
            continue        
        for result_file in db_path.glob("*.txt"):
            try:
                clientNumber = result_file.stem
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
                        "ScenarioName": scenarioName,
                        "Client": clientNumber,
                        "DB": db_path.name,
                        "Type": op_type,
                        "Latency": type_ops["Latency"].mean()
                    })
    
    return pd.DataFrame(results)


def collect_baseline(baseline_dir: str) -> Dict[str, float]:
    """Collect baseline read/write latencies from single-replica deployment."""
    results = []
    baseline_path = Path(baseline_dir)
    if not baseline_path.exists():
        print(f"Baseline directory not found: {baseline_path}")
        return {"Read": None, "Write": None}
    for database in baseline_path.iterdir():
        if not database.is_dir():
            continue
        db_baseline_path = database
        for result_file in db_baseline_path.glob("1.txt"):
            operations = parse_result_file(result_file, database.name)
            if not operations:
                continue
            
            df = pd.DataFrame(operations)
            for op_type, op_set in [("Read", READ_OPS)]:
                type_ops = df[df["Operation"].isin(op_set)]
                if not type_ops.empty:
                    results.append({
                        "DB": database.name,
                        "Type": op_type,
                        "Latency": type_ops["Latency"].mean()
                    })
            for op_type, op_set in [("Write", WRITE_OPS)]:
                type_ops = df[df["Operation"].isin(op_set)]
                if not type_ops.empty:
                    results.append({
                        "DB": database.name,
                        "Type": op_type,
                        "Latency": type_ops["Latency"].mean()
                    })
    baseline = {r1["DB"]: {r["Type"]: r["Latency"] for r in results if r["DB"] == r1["DB"]} for r1 in results}
    # print(baseline)
    return baseline


def collect_replicated_baseline(baseline_dir: str) -> Dict[str, float]:
    """Collect baseline read/write latencies from single-replica deployment."""
    results = []
    baseline_path = Path(baseline_dir)
    if not baseline_path.exists():
        print(f"Baseline directory not found: {baseline_path}")
        return {"Read": None, "Write": None}
    for database in baseline_path.iterdir():
        if not database.is_dir():
            continue
        db_baseline_path = database
        for result_file in db_baseline_path.glob("4.txt"):
            operations = parse_result_file(result_file, database.name)
            if not operations:
                continue
            
            df = pd.DataFrame(operations)
            for op_type, op_set in [("Read", READ_OPS)]:
                type_ops = df[df["Operation"].isin(op_set)]
                if not type_ops.empty:
                    results.append({
                        "DB": database.name,
                        "Type": op_type,
                        "Latency": type_ops["Latency"].mean()
                    })
            for op_type, op_set in [("Write", WRITE_OPS)]:
                type_ops = df[df["Operation"].isin(op_set)]
                if not type_ops.empty:
                    results.append({
                        "DB": database.name,
                        "Type": op_type,
                        "Latency": type_ops["Latency"].mean()
                    })
    baseline = {r1["DB"]: {r["Type"]: r["Latency"] for r in results if r["DB"] == r1["DB"]} for r1 in results}
    # print(baseline)
    return baseline


def calculate_relative_performance(data: pd.DataFrame, baseline: Dict[str, float]) -> Dict:
    # """Calculate relative performance compared to provided baseline latencies."""
    # if not baseline["Read"] or not baseline["Write"]:
    #     print("Warning: Missing baseline latencies")
    #     return {"Read": {}, "Write": {}}
    
    # baseline_read = baseline["Read"]
    # baseline_write = baseline["Write"]
    
    deployment_map = {
        "4_replicas_0_alt_dbs": 0,
        "4_replicas_1_alt_dbs": 1,
        "4_replicas_2_alt_dbs": 2,
        "4_replicas_3_alt_dbs": 3
    }
    
    reads = [{} for _ in range(4)]
    writes = [{} for _ in range(4)]
    
    for _, row in data.iterrows():
        scenario = row["ScenarioName"]
        if scenario not in deployment_map:
            continue
        deployment_idx = deployment_map[scenario]
        index = int(row["Client"].split("_")[1]) - 1
        db_for_client = group_replicas[deployment_idx][index]
        db = row["Client"]

        
        if row["Type"] == "Read":
            relative_perf = row["Latency"]
            reads[deployment_idx][db] = relative_perf
        else:
            relative_perf = row["Latency"]
            writes[deployment_idx][db] = relative_perf
    return {"Read": reads, "Write": writes}


def create_heterogeneous_plot(data: pd.DataFrame, baseline: Dict[str, float], replicated_baseline: Dict[str, float], output_path: str) -> None:
    """Create bar chart showing relative performance across heterogeneous deployments."""
    
    perf_data = calculate_relative_performance(data, baseline)
    reads = perf_data["Read"]
    writes = perf_data["Write"]
    
    deployments = ["0", "1", "2", "4"]
    
    x = np.arange(len(deployments))
    bar_width = 0.12
    spacing = 0.02
    group_width = bar_width * 4 + spacing * 3
    
    fig, axes = plt.subplots(1, 2, figsize=(5, 2.3), sharey=True)
    legend_elements = {}

    def plot_subplot(ax, data, title):
        labeled_dbs = set()
        
        for idx, dbs in enumerate(group_clients):
            if idx >= len(data) or not data[idx]:
                continue
            for j, db in enumerate(dbs):                
                if db not in data[idx]:
                    continue
                offset = -group_width/2 + j*(bar_width + spacing) + bar_width/2
                val = data[idx][db]
                #The error is the difference between val and the throughput compared to baseline
                # yerr = [val- baseline[db][title], 0] if db in baseline and title in baseline[db] else [0, 0]
                # print(yerr)
                # yerr = [[abs(val)], [0]]
                base= 0
                # print(title)
                if title == "Reads":
                    base = baseline[group_replicas[idx][j]]['Read']
                    base_rep = replicated_baseline[group_replicas[idx][j]]['Read']
                else:
                    base = baseline[group_replicas[idx][j]]['Write']
                    base_rep = replicated_baseline[group_replicas[idx][j]]['Write']

                # print(base)
                label = db if db not in labeled_dbs else ""
                if db not in labeled_dbs:
                    labeled_dbs.add(db)
                db_label = group_replicas[idx][j]
                
                bar = ax.bar(
                    x[idx] + offset,
                    val,
                    bar_width,
                    label=db_label,
                    color=DB_STYLES[db_label]["color"],
                    # yerr=yerr,
                    capsize=4,
                    ecolor="black",
                    error_kw=dict(lw=1, capthick=1)
                )

                ax.hlines(
                y=base, 
                xmin=x[idx] + offset - bar_width/2, 
                xmax=x[idx] + offset + bar_width/2,
                colors='black', 
                linewidth=1,
                linestyle='-',
                alpha=0.8
            )

                ax.hlines(
                y=base_rep, 
                xmin=x[idx] + offset - bar_width/2, 
                xmax=x[idx] + offset + bar_width/2,
                colors='firebrick', 
                linewidth=1,
                linestyle='-',
                alpha=0.8
            )

                if db_label not in legend_elements:
                    legend_elements[db_label] = bar
        yticks = [100, 1000, 10000, 100000, 1000000, 10000000]
        yticklabels = ['0ms', '1ms', '10ms', '100ms', '1s', '10s']
        # ax.axhline(1.0, color="black", linestyle="--", linewidth=1)
        
        ax.set_title(title)
        ax.set_xticks(x)
        ax.set_yscale("log")
        ax.set_yticks(yticks)
        ax.set_yticklabels(yticklabels)
        ax.set_xticklabels(deployments)
    
    # Reads subplot
    plot_subplot(axes[0], reads, "Reads")
    
    # Create a single centered legend at the top
    fig.legend(handles=list(legend_elements.values()), loc='upper center', ncol=4, bbox_to_anchor=(0.5, 1.1))

    # Writes subplot
    plot_subplot(axes[1], writes, "Writes")
    fig.supylabel("Latency")
    fig.supxlabel("Heterogeneous database count")
    
    plt.tight_layout()
    fig.savefig(output_path, dpi=500, bbox_inches='tight')
    plt.close(fig)


def main():
    parser = argparse.ArgumentParser(description="Generate heterogeneous deployment bar charts")
    parser.add_argument("root_dir", help="Root directory containing dataset folders")
    parser.add_argument("dataset", help="Dataset name (e.g., 'yeast', 'mico', 'ldbc')")
    parser.add_argument("output_path", help="Output path for the figure (e.g., heterogeneous.png)")
    parser.add_argument("--baseline_dir", required=True, help="Directory containing single-replica baseline results")
    args = parser.parse_args()
    
    data = collect_data(args.root_dir, args.dataset)
    if data.empty:
        print("No data found")
        return
    
    baseline = collect_baseline(args.baseline_dir)
    replicatedBaseline = collect_replicated_baseline(args.baseline_dir)

    create_heterogeneous_plot(data, baseline, replicatedBaseline, args.output_path)
    print(f"Plot saved to {args.output_path}")


if __name__ == "__main__":
    main()
