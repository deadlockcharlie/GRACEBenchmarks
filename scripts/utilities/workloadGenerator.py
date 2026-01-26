#!/usr/bin/env python3
"""
Split a large graph.json ({"vertices":[...],"edges":[...]}) into four files:
- <prefix>_load_vertices.json
- <prefix>_load_edges.json
- <prefix>_update_vertices.json
- <prefix>_update_edges.json

Massively parallel, streaming, and memory-friendly:
1. Stream vertices, assign randomly to load vs update (by SPLIT_RATIO).
   - Store vertex IDs in SQLite DB for referential integrity.
2. Partition edges into N shards by hash (single streaming pass).
3. Process shards in parallel, ensuring referential integrity:
   - Load edges: both endpoints must exist in load vertices
   - Update edges: both endpoints must exist in load vertices (for referential integrity)
4. Merge shard outputs into final edge files.
"""

import argparse
import json
import ijson
import random
import sqlite3
import os
import tempfile
import shutil
from multiprocessing import Pool, cpu_count
from hashlib import blake2b

# ---------- Helpers ----------
def open_json_array_writer(path):
    f = open(path, "w", encoding="utf-8")
    f.write("[\n")
    return f

def write_json_obj_to_array(f, obj, first):
    if not first:
        f.write(",\n")
    f.write(json.dumps(obj, ensure_ascii=False))
    return False

def close_json_array_writer(f):
    f.write("\n]\n")
    f.close()

# ---------- Vertex pass ----------
def vertex_pass(input_file, tmpdir, split_ratio, sqlite_path,
                out_load_vertices, out_update_vertices):
    conn = sqlite3.connect(sqlite_path, timeout=30)
    cur = conn.cursor()
    # table for update vertices
    cur.execute("CREATE TABLE IF NOT EXISTS upd_vid(id INTEGER PRIMARY KEY)")
    # table for loaded vertices
    cur.execute("CREATE TABLE IF NOT EXISTS load_vid(id INTEGER PRIMARY KEY)")
    # Create indices for faster lookups
    cur.execute("CREATE INDEX IF NOT EXISTS idx_upd_vid ON upd_vid(id)")
    cur.execute("CREATE INDEX IF NOT EXISTS idx_load_vid ON load_vid(id)")
    conn.commit()

    load_f = open_json_array_writer(out_load_vertices)
    update_f = open_json_array_writer(out_update_vertices)
    first_load, first_update = True, True

    with open(input_file, "rb") as f:
        parser = ijson.parse(f)
        in_vertices = False
        for prefix, event, value in parser:
            if (prefix, event) == ("vertices", "start_array"):
                in_vertices = True
                continue
            if in_vertices:
                if event == "end_array" and prefix == "vertices":
                    break
                if event == "start_map":
                    obj = {}
                    for p, e, v in parser:
                        if e == "end_map":
                            break
                        key = p.split(".")[-1]
                        obj[key] = v
                    vid = obj.get("_id")
                    if random.random() < split_ratio:
                        first_load = write_json_obj_to_array(load_f, obj, first_load)
                        if vid is not None:
                            cur.execute("INSERT OR IGNORE INTO load_vid(id) VALUES(?)", (vid,))
                    else:
                        first_update = write_json_obj_to_array(update_f, obj, first_update)
                        if vid is not None:
                            cur.execute("INSERT OR IGNORE INTO upd_vid(id) VALUES(?)", (vid,))
    conn.commit()
    conn.close()
    close_json_array_writer(load_f)
    close_json_array_writer(update_f)

# ---------- Partition edges into shards ----------
def partition_edges(input_file, tmpdir, num_shards, shard_prefix="edge_shard"):
    shard_paths = [os.path.join(tmpdir, f"{shard_prefix}_{i}.ndjson") for i in range(num_shards)]
    shard_files = [open(p, "w", encoding="utf-8") for p in shard_paths]

    with open(input_file, "rb") as f:
        parser = ijson.parse(f)
        in_edges = False
        for prefix, event, value in parser:
            if (prefix, event) == ("edges", "start_array"):
                in_edges = True
                continue
            if in_edges:
                if event == "end_array" and prefix == "edges":
                    break
                if event == "start_map":
                    obj = {}
                    for p, e, v in parser:
                        if e == "end_map":
                            break
                        key = p.split(".")[-1]
                        obj[key] = v
                    # assign shard by hashing endpoints
                    a = str(obj.get("_outV",""))
                    b = str(obj.get("_inV",""))
                    h = blake2b((a + ":" + b).encode("utf-8"), digest_size=8).digest()
                    idx = int.from_bytes(h, "big") % num_shards
                    shard_files[idx].write(json.dumps(obj, ensure_ascii=False) + "\n")

    for sf in shard_files:
        sf.close()
    return shard_paths

# ---------- Process a shard ----------
def process_shard(shard_path, sqlite_path, out_load_shard, out_update_shard, edge_update_ratio=0.2):
    """
    Stream a shard of edges, assign to load vs update with proper referential integrity:
    - Load edges: both endpoints must exist in the load vertex set
    - Update edges: both endpoints must exist in the load vertex set (to maintain referential integrity)
    """
    import sqlite3
    import json

    conn = sqlite3.connect(sqlite_path, timeout=30)
    cur = conn.cursor()

    load_f = open_json_array_writer(out_load_shard)
    upd_f = open_json_array_writer(out_update_shard)
    first_load, first_upd = True, True

    with open(shard_path, "r", encoding="utf-8") as sf:
        for line in sf:
            if not line.strip():
                continue
            obj = json.loads(line)
            outv, inv = obj.get("_outV"), obj.get("_inV")

            # Check if both endpoints exist in LOAD vertices (referential integrity)
            endpoints_in_load = True
            if outv is not None:
                cur.execute("SELECT 1 FROM load_vid WHERE id = ? LIMIT 1", (outv,))
                if not cur.fetchone():
                    endpoints_in_load = False
            if inv is not None and endpoints_in_load:  # Short-circuit if already failed
                cur.execute("SELECT 1 FROM load_vid WHERE id = ? LIMIT 1", (inv,))
                if not cur.fetchone():
                    endpoints_in_load = False

            if not endpoints_in_load:
                # Skip edges that reference vertices not in the load set
                continue

            # Now we know both endpoints exist in load set
            # Randomly assign edge to load or update set
            if random.random() < edge_update_ratio:
                first_upd = write_json_obj_to_array(upd_f, obj, first_upd)
            else:
                first_load = write_json_obj_to_array(load_f, obj, first_load)

    conn.close()
    close_json_array_writer(load_f)
    close_json_array_writer(upd_f)
    return out_load_shard, out_update_shard

# ---------- Merge shards ----------
def merge_array_files(shard_json_paths, dst_path):
    with open(dst_path, "w", encoding="utf-8") as out:
        out.write("[\n")
        first = True
        for p in shard_json_paths:
            if os.path.getsize(p) > 2:  # Check if file has content beyond just "[\n]\n"
                arr = json.load(open(p, "r", encoding="utf-8"))
                for obj in arr:
                    if not first:
                        out.write(",\n")
                    out.write(json.dumps(obj, ensure_ascii=False))
                    first = False
        out.write("\n]\n")

# ---------- Main ----------
def main():
    parser = argparse.ArgumentParser(description="Split large graph JSON into load/update sets (parallel, separate files).")
    parser.add_argument("--input", "-i", required=True, help="Input JSON file (with vertices and edges arrays).")
    parser.add_argument("--out-prefix", "-o", default="dataset", help="Prefix for output files.")
    parser.add_argument("--split", "-s", type=float, default=0.8, help="Fraction of vertices in load set.")
    parser.add_argument("--edge-update-ratio", "-e", type=float, default=0.2, help="Fraction of valid edges in update set.")
    parser.add_argument("--shards", type=int, default=max(4, cpu_count()), help="Number of edge shards / workers.")
    parser.add_argument("--seed", type=int, default=None, help="Optional RNG seed for reproducibility.")
    parser.add_argument("--tmp", default=None, help="Optional temp directory.")
    parser.add_argument("--keep-tmp", action="store_true", help="Keep temporary directory for debugging.")
    args = parser.parse_args()

    if args.seed is not None:
        random.seed(args.seed)

    tmpdir = args.tmp or tempfile.mkdtemp(prefix="split_graph_")
    sqlite_path = os.path.join(tmpdir, "vertex_sets.sqlite")

    load_v = f"{args.out_prefix}_load_vertices.json"
    update_v = f"{args.out_prefix}_update_vertices.json"
    load_e = f"{args.out_prefix}_load_edges.json"
    update_e = f"{args.out_prefix}_update_edges.json"

    print("Temporary dir:", tmpdir)
    print("Phase 1: splitting vertices...")
    vertex_pass(args.input, tmpdir, args.split, sqlite_path, load_v, update_v)

    print("Phase 2: partitioning edges...")
    shard_paths = partition_edges(args.input, tmpdir, args.shards)

    print("Phase 3: classifying edges in parallel...")
    load_edge_shards, update_edge_shards = [], []
    for i in range(len(shard_paths)):
        load_edge_shards.append(os.path.join(tmpdir, f"edges_load_shard_{i}.json"))
        update_edge_shards.append(os.path.join(tmpdir, f"edges_update_shard_{i}.json"))

    with Pool(processes=min(len(shard_paths), cpu_count())) as pool:
        pool.starmap(process_shard,
                     [(sp, sqlite_path, load_edge_shards[i], update_edge_shards[i], args.edge_update_ratio)
                      for i, sp in enumerate(shard_paths)])

    print("Phase 4: merging edge shards...")
    merge_array_files(load_edge_shards, load_e)
    merge_array_files(update_edge_shards, update_e)

    # Print statistics
    print("\nDone. Output files:")
    for file_path in [load_v, update_v, load_e, update_e]:
        if os.path.exists(file_path):
            try:
                with open(file_path, 'r') as f:
                    data = json.load(f)
                    print(f"  {file_path}: {len(data)} items")
            except:
                print(f"  {file_path}: exists (unable to count)")
        else:
            print(f"  {file_path}: not created")

    if not args.keep_tmp:
        print(f"Cleaning up temp dir: {tmpdir}")
        shutil.rmtree(tmpdir, ignore_errors=True)
    else:
        print(f"Temp dir preserved: {tmpdir}")

if __name__ == "__main__":
    main()