import argparse
import pandas as pd
import matplotlib.pyplot as plt
import re
from pathlib import Path
from typing import Dict
import numpy as np

# Configuration
DB_STYLES = {
    "ArangoDB": {"color": "tab:green", "linestyle": "--", "marker": "D"},
    "MongoDB": {"color": "tab:brown", "linestyle": "--", "marker": "v"},
    "Neo4j": {"color": "tab:blue", "linestyle": "-", "marker": "o"},
    "JanusGraph": {"color": "tab:orange", "linestyle": "-", "marker": "s"},
    "MemGraph": {"color": "tab:purple", "linestyle": "-", "marker": "^"},
    "GRACE": {"color": "tab:red", "linestyle": "-", "marker": "x"},
}

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
    "REMOVE_EDGE_PROPERTY": "W8",
}

# Regex to capture throughput line
STATUS_LINE_RE = re.compile(
    r"(?P<ts>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}:\d{3}) "
    r"(?P<sec>\d+) sec: (?P<ops>\d+) operations; "
    r"(?P<throughput>[\d\.]+) current ops/sec.*"
)

# Regex to capture op stats (including FAILED ops)
OP_STATS_RE = re.compile(
    r"\[(?P<op>[A-Z_]+(?:-FAILED)?): Count=(?P<count>\d+), .*?Avg=(?P<avg>[\d\.]+)"
)

def parse_ycsb_file(file_path: Path, db_name: str) -> pd.DataFrame:
    """Parse YCSB log file into a DataFrame with *successful* throughput and avg latency."""
    times, throughputs, avg_latencies = [], [], []

    with file_path.open() as f:
        for line in f:
            m = STATUS_LINE_RE.search(line)
            if not m:
                continue

            sec = int(m.group("sec"))

            # Parse operation-level stats
            op_matches = OP_STATS_RE.findall(line)

            # Successful ops only (ignore -FAILED)
            success_counts = []
            latencies = []
            for op, count, avg in op_matches:
                if op.endswith("-FAILED"):
                    continue
                if op in OPERATION_MAPPING:  # consider only mapped ops
                    cnt = int(count)
                    if cnt > 0:
                        success_counts.append(cnt/10)
                        latencies.append(float(avg))

            # Compute "real throughput" (successes per sec)
            throughput = sum(success_counts)  # 1-second snapshot, already per sec

            # Compute average latency across successful ops
            # If no latencies or avg is 0, set to 120 seconds (120000000 microseconds)
            if not latencies:
                avg_latency = 120000000
            else:
                avg_latency = sum(latencies) / len(latencies)
                if avg_latency == 0:
                    avg_latency = 120000000

            times.append(sec)
            throughputs.append(throughput)
            avg_latencies.append(avg_latency)

        
    return pd.DataFrame(
        {"time": times, "throughput": throughputs, "avg_latency": avg_latencies, "DB": db_name}
    )


def collect_db_results(root_dir: Path) -> Dict[str, pd.DataFrame]:
    """Parse logs from each DB directory under root_dir."""
    db_results = {}
    for db_path in root_dir.iterdir():
        if not db_path.is_dir():
            continue
        db_name = db_path.name
        file_path = db_path / "3.txt"
        if file_path.exists():
            df = parse_ycsb_file(file_path, db_name)
            if not df.empty:
                db_results[db_name] = df
    return db_results

def interpolate_missing_values(df: pd.DataFrame, duration: int) -> tuple:
    """
    Interpolate missing time points with 120s latency value.
    Returns: (times, latencies, interpolated_times, interpolated_latencies)
    """
    # Get all expected time points (every 10 seconds)
    all_times = set(range(0, duration + 1, 10))
    existing_times = set(df["time"].values)
    missing_times = sorted(all_times - existing_times)
    
    # Fill with 120 seconds (120000000 microseconds)
    interpolation_value = 120000000
    
    # Create interpolated points
    interpolated_times = missing_times
    interpolated_latencies = [interpolation_value] * len(missing_times)
    
    return (df["time"].values, df["avg_latency"].values, 
            np.array(interpolated_times), np.array(interpolated_latencies))

def plot_results(duration: int, db_results: Dict[str, pd.DataFrame], figure_path: str):
    """Plot throughput and avg latency across mapped ops, mark high-latency region."""
    fig, ax = plt.subplots(figsize=(4.5, 2.7))
    
    # Sort db_results by DB_STYLES keys
    db_results = {k: db_results[k] for k in DB_STYLES.keys() if k in db_results}
    
    for db_name, df in db_results.items():
        style = DB_STYLES.get(db_name, {"color": "black", "linestyle": "-", "marker": None})

        # Get original and interpolated data
        times, latencies, interp_times, interp_latencies = interpolate_missing_values(df, duration)
        
        # Plot average latency (lines only, no markers) for legend
        ax.plot(
            times, latencies,
            label=db_name, color=style["color"],
            linestyle=style["linestyle"], marker=style["marker"], markevery=10000, markersize=3, linewidth=1
        )
        
        # Add markers based on latency value
        for i, (t, lat) in enumerate(zip(times, latencies)):
            if lat == 120000000:
                # 120s values get gray cross
                ax.plot(t, lat, marker='x', color='gray',
                       markersize=4, markeredgewidth=2, zorder=10)
            else:
                # Normal values get database-specific marker
                ax.plot(t, lat, marker=style["marker"], color=style["color"],
                       markersize=3, zorder=5)
        
        # Plot interpolated points with grey crosses
        for i, (t, lat) in enumerate(zip(interp_times, interp_latencies)):
            ax.plot(t, lat, marker='x', color='gray',
                   markersize=4, markeredgewidth=2, zorder=10)

    # Mark high-latency region (from halfway point for 60 seconds)
    halfway = (duration / 2)
    ax.axvspan(halfway, halfway + 60, color="grey", alpha=0.4)

    # Labels and titles
    yticks=[100, 1000, 10000, 100000, 1000000, 10000000, 100000000]
    yticksLabels=['0ms', '1ms', '10ms', '100ms', '1s', '10s', '100s']
    xticks = list(range(0, duration + 1, 30))
    ax.set_xticks(xticks)
    ax.set_ylabel("Avg Latency")
    ax.set_yscale("log")
    ax.set_yticks(yticks)
    ax.set_yticklabels(yticksLabels)

    ax.set_xlabel("Time (sec)")
    ax.grid(True, linestyle="--", linewidth=0.5)
    ax.set_xlim(0, duration)
    ax.set_ylim(100, None)
    ax.legend(ncols=3, loc="upper center", bbox_to_anchor=(0.48, 1.5), fontsize=8)

    plt.tight_layout()
    plt.savefig(figure_path, dpi=500, bbox_inches="tight")
    plt.close()


def main():
    parser = argparse.ArgumentParser(description="Plot YCSB throughput and avg latency (mapped ops) over time.")
    parser.add_argument("duration", type=int, help="Duration of the experiment in seconds (e.g., 600)")
    parser.add_argument("root_dir", help="Path to root results directory (contains DB subdirs)")
    parser.add_argument("figure_path", help="Path to save the output figure (e.g., .png)")
    
    args = parser.parse_args()

    db_results = collect_db_results(Path(args.root_dir))
    if not db_results:
        print("No valid DB results found.")
        return

    plot_results(args.duration, db_results, args.figure_path)


if __name__ == "__main__":
    main()