import argparse
import pandas as pd
import matplotlib.pyplot as plt
import re
from pathlib import Path
from typing import Dict

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
                        success_counts.append(cnt)
                        latencies.append(float(avg))

            # Compute "real throughput" (successes per sec)
            throughput = sum(success_counts)  # 1-second snapshot, already per sec

            # Compute average latency across successful ops
            avg_latency = sum(latencies) / len(latencies) if latencies else float("nan")

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

def plot_results(duration: int, db_results: Dict[str, pd.DataFrame], figure_path: str):
    """Plot throughput and avg latency across mapped ops, mark high-latency region."""
    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(5, 4), sharex=True)
    #sort db_results by DB_STYLES keys

    db_results = {k: db_results[k] for k in DB_STYLES.keys() if k in db_results}
    for db_name, df in db_results.items():
        style = DB_STYLES.get(db_name, {"color": "black", "linestyle": "-", "marker": None})

        # Plot throughput
        ax1.plot(
            df["time"], df["throughput"],
            label=db_name, color=style["color"],
            linestyle=style["linestyle"], marker=style["marker"], markevery=1, markersize=3, linewidth=1
        )

        # Plot average latency
        ax2.plot(
            df["time"], df["avg_latency"],
            label=db_name, color=style["color"],
            linestyle=style["linestyle"], marker=style["marker"], markevery=1, markersize=3, linewidth=1
        )

        # Mark high-latency region (from halfway point to end)
    halfway = (df["time"].max() / 2) -5
    ax1.axvspan(halfway, df["time"].max(), color="grey", alpha=0.4)
    ax2.axvspan(halfway, df["time"].max(), color="grey", alpha=0.4)

    # Labels and titles
    ax1.set_ylabel("Throughput (ops/sec)")
    ax1.set_yscale("log")
    ax1.grid(True, linestyle="--", linewidth=0.5)
    ax1.set_xlim(0, duration)

    ax2.set_ylabel("Avg Latency (ms)")
    ax2.set_yscale("log")
    ax2.set_xlabel("Time (sec)")
    ax2.grid(True, linestyle="--", linewidth=0.5)
    ax2.set_xlim(0, duration)

    ax1.legend(ncols=6, loc="upper center", bbox_to_anchor=(0.5, 1.25), fontsize=8)


    

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
