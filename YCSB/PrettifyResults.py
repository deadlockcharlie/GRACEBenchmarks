import re
import csv
import sys

def parse_ycsb_output(file_path):
    """Parse YCSB output file and extract metrics with improved throughput handling"""
    results = {
        'OVERALL': {},
        'UPDATE': {},
        'INSERT': {},
        'SCAN': {},
    }

    opCountPattern = r'\[(\w+)\],\s*Operations,\s*([\d\.]+)'


    latency_pattern = r'\[(\w+)\],\s*([\w\%\(\)]+),\s*([\d\.]+)'

    with open(file_path, 'r') as f:
        content = f.read()

#         # Extract throughput using multiple patterns
#         throughput = 0
#         for pattern in throughput_patterns:
#             match = re.search(pattern, content)
#             if match:
#                 throughput = float(match.group(1))
#                 break
#         results['OVERALL']['Throughput(ops/sec)'] = throughput

        # Extract latency metrics
        for match in re.finditer(latency_pattern, content):
            category, metric, value = match.groups()
            value = float(value) if '.' in value else int(value)

            # Handle different category names
            if category in results:
                results[category][metric] = value
            elif "Percentile" in metric:
                # Handle percentile metrics without category
                for cat in results:
                    if cat != 'OVERALL' and metric in results[cat]:
                        results[cat][metric] = value
    return results

def write_ycsb_csv(parsed_data, output_file):
    """Write parsed YCSB data to CSV file with improved formatting"""
    with open(output_file, 'w', newline='') as csvfile:
        fieldnames = [ 'Operation', 'Count' ,
                     'AverageLatency(us)', '95thPercentile(us)', '99thPercentile(us)']
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        writer.writeheader()

        # Process individual operations
        for op in [ 'UPDATE', 'INSERT', 'SCAN']:
            if op in parsed_data and parsed_data[op]:
                data = parsed_data[op]
                if(op=='UPDATE'):
                    writer.writerow({
                        'Operation': 'DELETE VERTEX',
                        'Count': data.get('Operations', '')*3,
                        'AverageLatency(us)': data.get('AverageLatency(us)', ''),
                        '95thPercentile(us)': data.get('95thPercentileLatency(us)', data.get('95thPercentile(us)', '')),
                        '99thPercentile(us)': data.get('99thPercentileLatency(us)', data.get('99thPercentile(us)', ''))
                    })
                else:
                 writer.writerow({
                        'Operation': op,
                        'Count': data.get('Operations', ''),
                        'AverageLatency(us)': data.get('AverageLatency(us)', ''),
                        '95thPercentile(us)': data.get('95thPercentileLatency(us)', data.get('95thPercentile(us)', '')),
                        '99thPercentile(us)': data.get('99thPercentileLatency(us)', data.get('99thPercentile(us)', ''))
                    })


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python ycsb_parser.py <input_txt_file> <output_csv_file>")
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2]

    try:
        parsed_data = parse_ycsb_output(input_file)
        write_ycsb_csv(parsed_data, output_file)
        print(f"Successfully converted YCSB output to {output_file}")
    except Exception as e:
        print(f"Error processing YCSB output: {str(e)}")
        sys.exit(1)