import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
import sys

# Load CSV data
if len(sys.argv) < 3:
    print("Usage: python ycsb_charts.py <duration_in_s><input_csv> [output_image] ")
    sys.exit(1)

duration = sys.argv[1]
input_csv = sys.argv[2]
output_image = sys.argv[3] if len(sys.argv) > 3 else None

try:
    df = pd.read_csv(input_csv)
except Exception as e:
    print(f"Error reading CSV file: {e}")
    sys.exit(1)

# Check required columns
required_columns = ['Operation', 'Count', 'AverageLatency(us)',
                   '95thPercentile(us)', '99thPercentile(us)']
if not all(col in df.columns for col in required_columns):
    print("CSV is missing required columns. Needed:", required_columns)
    sys.exit(1)

# Create figure with subplots
plt.figure(figsize=(12, 10))
plt.suptitle('YCSB Performance Metrics', fontsize=16)


# 1. Operation Count Chart
plt.subplot(2, 1, 1)
bars = plt.bar(df['Operation'], df['Count'], color='#4C72B0', edgecolor='black')
plt.ylabel('Operation Count', fontsize=12)
plt.title('Operation Distribution', fontsize=14)
plt.grid(axis='y', linestyle='--', alpha=0.7)

# Add count labels on bars
for bar in bars:
    height = bar.get_height()
    plt.text(bar.get_x() + bar.get_width()/2., height,
             f'{height:,}', ha='center', va='bottom', fontsize=10)

# 2. Latency Metrics Chart
plt.subplot(2, 1, 2)
bar_width = 0.25
op_count = len(df['Operation'])
index = np.arange(op_count)

# Define latency metrics
metrics = ['AverageLatency(us)', '95thPercentile(us)', '99thPercentile(us)']
colors = ['#55A868', '#C44E52', '#8172B2']
names = ['Average', '95th %ile', '99th %ile']

for i, metric in enumerate(metrics):
    plt.bar(index + i*bar_width, df[metric],
            width=bar_width,
            color=colors[i],
            label=names[i],
            edgecolor='black')

plt.xlabel('Operation', fontsize=12)
plt.ylabel('Latency (μs)', fontsize=12)
plt.title('Latency Comparison', fontsize=14)
plt.xticks(index + bar_width, df['Operation'])
plt.legend()
plt.grid(axis='y', linestyle='--', alpha=0.7)

# Add latency values above bars
for i, op in enumerate(df['Operation']):
    for j, metric in enumerate(metrics):
        value = df.loc[df['Operation'] == op, metric].values[0]
        plt.text(index[i] + j*bar_width, value + 0.05*value,
                 f'{value:,.0f}',
                 ha='center', va='bottom',
                 fontsize=8, rotation=45)

# Final layout adjustments
plt.tight_layout(rect=[0, 0, 1, 0.96])  # Make room for suptitle

# Save or display results
if output_image:
    plt.savefig(output_image, dpi=300, bbox_inches='tight')
    print(f"Charts saved to {output_image}")
else:
    plt.show()