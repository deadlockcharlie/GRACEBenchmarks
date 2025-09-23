import json
import csv
import sys
from pathlib import Path

def json_to_csv_and_ids(json_file: str, csv_file: str, ids_file: str, keys_file: str, id_key: str):
    with open(json_file, "r") as f:
        data = json.load(f)

    if not isinstance(data, list):
        raise ValueError(f"Expected a list of objects in {json_file}, got {type(data)}")

    # Collect all possible keys across all objects (union of keys)
    all_keys = sorted({k for obj in data for k in obj.keys()})
    print(all_keys)
    # Write the list of keys to a separate file
    with open(keys_file, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        for key in all_keys:
            writer.writerow([key])

    # Write CSV
    with open(csv_file, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=all_keys)
        writer.writeheader()
        for row in data:
            writer.writerow(row)

    # Write IDs to separate file
    with open(ids_file, "w", encoding="utf-8") as f:
        for row in data:
            if id_key not in row:
                raise ValueError(f"Row missing expected ID key '{id_key}': {row}")
            f.write(f"{row[id_key]}\n")

    print(f"✅ Converted {json_file} → {csv_file} with {len(data)} rows and {len(all_keys)} columns")
    print(f"✅ IDs written to {ids_file}")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python json_to_csv.py vertices.json edges.json")
        sys.exit(1)

    # Process vertices
    vertices_json = sys.argv[1]
    vertices_csv = Path(vertices_json).with_suffix(".csv")
    vertices_ids = Path(vertices_json).with_suffix(".loaded")
    vertices_keys = Path(vertices_json).with_suffix(".keys")
    json_to_csv_and_ids(vertices_json, vertices_csv, vertices_ids, vertices_keys, id_key="_id")
    

    # Process edges
    edges_json = sys.argv[2]
    edges_csv = Path(edges_json).with_suffix(".csv")
    edges_ids = Path(edges_json).with_suffix(".loaded")
    edges_keys = Path(edges_json).with_suffix(".keys")
    json_to_csv_and_ids(edges_json, edges_csv, edges_ids, edges_keys, id_key="_id")