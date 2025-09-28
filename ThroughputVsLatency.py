import argparse
from pathlib import Path
from typing import Dict, Any
import pandas as pd
import matplotlib.pyplot as plt

# Configuration (unchanged)
OPERATION_MAPPING = {
    "GET_VERTEX_COUNT": "R1", "GET_EDGE_COUNT": "R2", "GET_EDGE_LABELS": "R3",
    "GET_VERTEX_WITH_PROPERTY": "R4", "GET_EDGE_WITH_PROPERTY": "R5", "GET_EDGES_WITH_LABEL": "R6",
    "ADD_VERTEX": "W1", "SET_VERTEX_PROPERTY": "W2", "REMOVE_VERTEX_PROPERTY": "W3",
    "ADD_EDGE": "W4", "SET_EDGE_PROPERTY": "W5", "REMOVE_VERTEX": "W6",
    "REMOVE_EDGE": "W7", "REMOVE_EDGE_PROPERTY": "W8"
}

DB_STYLES = {
    "ArangoDB": {"color": "tab:green", "linestyle": "--", "marker": "D"},
    "MongoDB": {"color": "tab:brown", "linestyle": "--", "marker": "v"},
    "Neo4j": {"color": "tab:blue", "linestyle": "-", "marker": "o"},
    "JanusGraph": {"color": "tab:orange", "linestyle": "-", "marker": "s"},
    "MemGraph": {"color": "tab:purple", "linestyle": "-", "marker": "^"},
    "GRACE": {"color": "tab:red", "linestyle": "-", "marker": "x"},
}


def parse_result_file(filepath: Path, db_name: str) -> Dict[str, Any]:
    """
    Parse a single results file and return:
      - Throughput (ops/sec) if present
      - RunTime(ms) if present
      - OpLatencies: dict mapping operation label (R1/W1...) -> latency (us)
    """
    if not filepath.exists():
        return {}

    throughput = None
    runtime_ms = None
    op_latencies: Dict[str, float] = {}
    failed_latencies: Dict[str, float] = {}

    for line in filepath.read_text().splitlines():
        if not line.strip() or "," not in line:
            continue

        parts = [p.strip() for p in line.split(",")]
        if len(parts) != 3:
            continue

        raw_op = parts[0]
        metric = parts[1]
        # parse value robustly
        try:
            value = float(parts[2])
        except ValueError:
            continue

        op = raw_op.strip("[]")  # remove surrounding brackets

        # overall metrics
        if metric == "RunTime(ms)":
            runtime_ms = value
            continue
        if metric == "Throughput(ops/sec)":
            throughput = value
            continue

        # per-operation latencies and failed lines
        if metric == "AverageLatency(us)":
            # failed operations may appear as NAME-FAILED
            if op.endswith("-FAILED"):
                base_op = op.replace("-FAILED", "")
                if base_op in OPERATION_MAPPING:
                    failed_latencies[OPERATION_MAPPING[base_op]] = value
            else:
                if op in OPERATION_MAPPING:
                    label = OPERATION_MAPPING[op]
                    latency = value
                    # if latency is zero, try to use matching failed latency if available
                    if latency == 0 and label in failed_latencies:
                        latency = failed_latencies[label]
                    op_latencies[label] = latency

    return {
        "DB": db_name,
        "Throughput": throughput,
        "RunTimeMs": runtime_ms,
        "OpLatencies": op_latencies
    }


def collect_data(root_dir: str) -> pd.DataFrame:
    """
    Traverse root_dir/<threadCount>/<DB>/3.txt and return a DataFrame with:
      ThreadCount, ReplicaCount, DB, Throughput, AvgLatency (us), OpLatencies (dict)
    """
    root = Path(root_dir)
    rows = []

    for thread_dir in sorted(root.iterdir(), key=lambda p: p.name if p.is_dir() else ""):
        if not thread_dir.is_dir():
            continue
        # thread count is the directory name; skip non-integers
        try:
            thread_count = int(thread_dir.name)
        except ValueError:
            continue

        for db_dir in sorted(thread_dir.iterdir(), key=lambda p: p.name if p.is_dir() else ""):
            if not db_dir.is_dir():
                continue
            result_file = db_dir / "3.txt"
            if not result_file.exists():
                continue

            parsed = parse_result_file(result_file, db_dir.name)
            if not parsed:
                continue

            throughput = parsed.get("Throughput")
            op_latencies = parsed.get("OpLatencies", {})

            # compute average latency (µs) from per-operation dictionary if possible
            avg_latency = None
            if op_latencies:
                vals = list(op_latencies.values())
                # compute mean carefully
                if len(vals) > 0:
                    avg_latency = sum(vals) / len(vals)
            # fallback: compute from throughput if no per-op latencies available
            if avg_latency is None and throughput:
                # latency (µs) = 1 / throughput (s/op) * 1e6
                if throughput > 0:
                    avg_latency = (1.0 / throughput) * 1.0e6

            # only add rows where we have at least throughput and a derived latency
            if throughput is None or avg_latency is None:
                # skip incomplete runs
                continue

            rows.append({
                "ThreadCount": thread_count,
                "ReplicaCount": 3,
                "DB": parsed["DB"],
                "Throughput": throughput,
                "AvgLatency": avg_latency,
                "OpLatencies": op_latencies
            })

    return pd.DataFrame(rows)

def create_plot(data: pd.DataFrame, output_path: str) -> None:
    """
    Single plot: Throughput (x, linear) vs AvgLatency (y, log).
    Each point annotated with the thread count.
    """
    if data.empty:
        print("No data to plot")
        return

    fig, ax = plt.subplots(figsize=(4, 2.5))

    for db in [db for db in DB_STYLES.keys()]:
        # 🔑 sort by ThreadCount to ensure line goes 1 → 2 → 3 … max
        db_data = data[data["DB"] == db].sort_values("ThreadCount")
        if db_data.empty:
            continue
        style = DB_STYLES.get(db, {})
        ax.plot(
            db_data["Throughput"],
            db_data["AvgLatency"],
            label=db,
            color=style.get("color"),
            linestyle=style.get("linestyle", "-"),
            marker=style.get("marker", "o"),
            markersize=3,
            linewidth=1
        )

        # annotate each point with its thread count
        for _, row in db_data.iterrows():
            x = row["Throughput"]
            y = row["AvgLatency"]
            txt = str(int(row["ThreadCount"]))
            ax.annotate(
                txt,
                xy=(x, y),
                xytext=(1, 0),
                textcoords="offset points",
                fontsize=3,
                ha="left",
                va="top"
            )

    ax.set_xlabel("Throughput (ops/sec) logscale")
    ax.set_ylabel("Latency (µs) logscale")
    ax.set_yscale("log")  # log scale on latency
    ax.set_xscale("log")  # linear scale on throughput
    ax.grid(axis="both", linestyle="--", alpha=0.7)
    ax.legend(ncol=3 , fontsize=7, loc="upper center", frameon=True, bbox_to_anchor=(0.5, 1.35))
    fig.tight_layout()
    fig.savefig(output_path, dpi=300, bbox_inches="tight")
    plt.close(fig)


def main():
    parser = argparse.ArgumentParser(description="Generate throughput vs avg-latency chart")
    parser.add_argument("root_dir", help="Root directory containing runs organized by thread count")
    parser.add_argument("figure_file", help="Output image file (e.g., results.png)")
    args = parser.parse_args()

    df = collect_data(args.root_dir)
    if df.empty:
        print("No valid data found")
        return

    # optional: save aggregated CSV for inspection
    # csv_out = Path(args.figure_file).with_suffix(".csv")
    # expand OpLatencies into JSON-like strings for easier inspection
    # df_to_save = df.copy()
    # df_to_save["OpLatencies"] = df_to_save["OpLatencies"].apply(lambda d: str(d))
    # df_to_save.to_csv(csv_out, index=False)
    # print(f"Aggregated data saved to {csv_out}")

    create_plot(df, args.figure_file)
    print(f"Plot saved to {args.figure_file}")


if __name__ == "__main__":
    main()
