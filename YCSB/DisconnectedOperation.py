import re
import sys
import pandas as pd
import matplotlib.pyplot as plt
from datetime import datetime

def parse_ycsb_log(filename):
    pattern = re.compile(
        r"(?P<timestamp>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}:\d{3}).*?; "
        r"(?P<throughput>[\d.]+) current ops/sec;.*?",
        re.DOTALL
    )

    records = []
    with open(filename, "r") as f:
        for line in f:
            match = pattern.search(line)
            if match:
                ts = datetime.strptime(match.group("timestamp"), "%Y-%m-%d %H:%M:%S:%f")
                print(ts)
                records.append({
                    "timestamp": ts,
                    "throughput": float(match.group("throughput")),
#                     "insert_avg_latency": float(match.group("insert_avg"))
                })

    if not records:
        raise ValueError("No valid entries found in log file!")

    # Normalize time to start at 0
    start_time = records[0]["timestamp"]
    for r in records:
        r["time_sec"] = (r["timestamp"] - start_time).total_seconds()

    return pd.DataFrame(records)

def plot_ycsb(df):
    fig, ax1 = plt.subplots(figsize=(10,6))

    # Throughput
    ax1.set_xlabel("Time (s)")
    ax1.set_ylabel("Throughput (ops/sec)", color="tab:blue")
    ax1.plot(df["time_sec"], df["throughput"], marker="o", color="tab:blue", label="Throughput")
    ax1.tick_params(axis="y", labelcolor="tab:blue")
    ax1.set_ylim(0, None)
    # Latency
#     ax2 = ax1.twinx()
#     ax2.set_ylabel("Latency (µs)", color="tab:red")
#     ax2.plot(df["time_sec"], df["insert_avg_latency"], marker="s", linestyle="--", color="tab:red", label="Avg Insert Latency")
#     ax2.tick_params(axis="y", labelcolor="tab:red")
#     ax2.set_ylim(0, None)
#     fig.tight_layout()
#     plt.title("YCSB Benchmark: Throughput & Latency over Time")
    plt.show()

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(f"Usage: python {sys.argv[0]} <logfile>")
        sys.exit(1)

    logfile = sys.argv[1]
    df = parse_ycsb_log(logfile)
    plot_ycsb(df)
