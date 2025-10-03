import matplotlib.pyplot as plt
import numpy as np

# Example data (replace with your benchmark results)
# Assume metric = throughput (ops/sec)
deployments = ["All Same", "1 Different", "2 Different", "All Different"]
throughput = [1000, 995, 1002, 990]  # example values
std_dev = [20, 18, 22, 25]           # example error bars

# Normalize to first deployment
baseline = throughput[0]
relative_perf = [t / baseline for t in throughput]
relative_err = [s / baseline for s in std_dev]

# Plot
x = np.arange(len(deployments))

plt.figure(figsize=(6,4))
plt.errorbar(x, relative_perf, yerr=relative_err, fmt='o-', capsize=5, lw=2)

# Formatting
plt.axhline(1.0, color='gray', linestyle='--', linewidth=1)
plt.xticks(x, deployments, rotation=15)
plt.ylabel("Relative Throughput (vs. All Same)")
plt.xlabel("Deployment")
plt.ylim(0.9, 1.1)  # zoom to highlight closeness
plt.title("Relative Performance Across Heterogeneous Deployments")

plt.tight_layout()
plt.show()
