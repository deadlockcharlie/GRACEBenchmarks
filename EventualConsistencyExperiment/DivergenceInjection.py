#!/usr/bin/env python3
"""
JanusGraph Property Update Divergence Test
Creates divergence by updating properties on existing vertices
This simulates LWW (Last-Write-Wins) conflicts across datacenters
"""

import time
import json
import threading
import random
from datetime import datetime
from gremlin_python.process.anonymous_traversal import traversal
from gremlin_python.driver.driver_remote_connection import DriverRemoteConnection
from gremlin_python.process.traversal import T

class ReplicaUpdater:
    
    def __init__(self, name, url):
        self.name = name
        self.connection = DriverRemoteConnection(url, 'g')
        self.g = traversal().withRemote(self.connection)
        self.update_count = 0
        self.error_count = 0
        self.exists_errors = 0
        self.running = False
        print(f"[{self.name}] Connected to {url}")
        
    def clear_database(self):
        """Delete all vertices (and thus all edges) from the database."""
        try:
            self.g.V().drop().toList()
            print(f"[{self.name}] All vertices and edges deleted from the database.")
        except Exception as e:
            print(f"[{self.name}] Error clearing database: {e}")
    
    def create_initial_vertices(self, num_vertices):
        """Create initial set of vertices that will be updated"""
        print(f"[{self.name}] Creating {num_vertices} initial vertices...")
        created = 0
        
        for i in range(num_vertices):
            vertex_id = f"shared_vertex_{i}"
            try:
                self.g.addV("Person")\
                    .property(T.id, vertex_id)\
                    .property('name', 'initial')\
                    .next()
                created += 1
                if created % 100 == 0:
                    print(f"[{self.name}] Created {created}/{num_vertices}")
            except Exception as e:
                # Vertex might already exist from other replica
                if "already exists" in str(e).lower():
                    self.exists_errors += 1
                else:
                    print(f"[{self.name}] Error creating vertex {vertex_id}: {str(e)}")
        
        print(f"[{self.name}] Created {created} vertices, {self.exists_errors} already existed")
        time.sleep(2)  # Let replication settle
        return created
    
    def update_vertex(self, vertex_id, value, source):
        """Update a vertex's properties"""
        try:
            # Update properties on existing vertex
            self.g.V(vertex_id)\
                .property('name', source)\
                .next()
            
            self.update_count += 1
            if self.update_count % 100 == 0:
                print(f"[{self.name}] Updated {self.update_count} vertices")
            return True
        except Exception as e:
            self.error_count += 1
            if self.error_count % 50 == 0:
                error_msg = str(e)
                if "lock" in error_msg.lower():
                    print(f"[{self.name}] Lock errors: {self.error_count}")
                else:
                    print(f"[{self.name}] Error: {error_msg[:100]}")
            return False
    
    def run_continuous_updates(self, num_updates, num_vertices, delay_between=0.01, conflict_rate=0.8):
        """
        Run continuous updates on vertices
        
        Args:
            num_updates: Total number of updates to perform
            num_vertices: Size of the vertex pool to update
            delay_between: Delay between updates in seconds
            conflict_rate: Probability of updating the same vertices as other replica
        """
        self.running = True
        
        for i in range(num_updates):
            if not self.running:
                break
            
            # Select vertex to update
            if random.random() < conflict_rate:
                # Update from shared pool (creates conflicts)
                vertex_idx = random.randint(0, num_vertices - 1)
            else:
                # Update unique vertex
                vertex_idx = hash(f"{self.name}_{i}") % num_vertices
            
            vertex_id = f"shared_vertex_{vertex_idx}"
            value = i
            
            self.update_vertex(vertex_id, value, self.name.lower())
            time.sleep(delay_between)
        
        self.running = False
        print(f"[{self.name}] Completed! Updated: {self.update_count}, Errors: {self.error_count}")
    
    def get_vertex(self, vertex_id):
        """Get a vertex by ID with all properties"""
        try:
            results = self.g.V(vertex_id).valueMap(True).toList()
            if results:
                return results[0]
            return None
        except Exception as e:
            return None
    
    def get_count(self):
        """Get total vertex count"""
        try:
            return self.g.V().count().next()
        except:
            return -1
    
    def stop(self):
        """Stop updates"""
        self.running = False
    
    def close(self):
        """Close connection"""
        self.connection.close()

def extract_property_value(prop_value):
    """Extract value from JanusGraph property format"""
    if isinstance(prop_value, list) and len(prop_value) > 0:
        return prop_value[0]
    return prop_value

def compare_vertices(v1, v2):
    """Compare two vertices and return detailed comparison"""
    if v1 is None and v2 is None:
        return "both_missing", {}
    if v1 is None or v2 is None:
        return "one_missing", {}
    
    # Extract properties, excluding technical fields
    props1 = {k: extract_property_value(v) for k, v in v1.items() if not str(k).startswith('T.')}
    props2 = {k: extract_property_value(v) for k, v in v2.items() if not str(k).startswith('T.')}
    
    # Check if properties are different
    differences = {}
    all_keys = set(props1.keys()) | set(props2.keys())
    
    for key in all_keys:
        val1 = props1.get(key)
        val2 = props2.get(key)
        if val1 != val2:
            differences[key] = {"replica1": val1, "replica2": val2}
    
    if differences:
        return "different", differences
    else:
        return "identical", {}

def sample_and_compare(replica1, replica2, num_vertices, sample_size=100, start_time=None):
    """Sample vertices and compare between replicas"""
    print(f"\n  Sampling {sample_size} vertices for comparison...")
    
    # Sample random vertex IDs
    sample_indices = random.sample(range(num_vertices), min(sample_size, num_vertices))
    vertex_ids_to_check = [f"shared_vertex_{i}" for i in sample_indices]
    
    comparison = {
        "timestamp": datetime.now().isoformat(),
        "elapsed_time": time.time() - start_time if start_time else 0,
        "sample_size": sample_size,
        "identical": 0,
        "different": 0,
        "missing": 0,
        "divergent_vertices": []  # Store examples of divergent vertices
    }
    
    for vid in vertex_ids_to_check:
        v1 = replica1.get_vertex(vid)
        v2 = replica2.get_vertex(vid)
        
        status, differences = compare_vertices(v1, v2)
        
        if status == "identical":
            comparison["identical"] += 1
        elif status == "different":
            comparison["different"] += 1
            # Store first few examples
            if len(comparison["divergent_vertices"]) < 5:
                comparison["divergent_vertices"].append({
                    "vertex_id": vid,
                    "differences": differences
                })
        elif status in ["one_missing", "both_missing"]:
            comparison["missing"] += 1
    
    divergence_rate = (comparison["different"] / sample_size * 100) if sample_size > 0 else 0
    comparison["divergence_rate"] = divergence_rate
    comparison["divergence_proportion"] = comparison["different"] / sample_size if sample_size > 0 else 0
    
    print(f"  Results: {comparison['identical']} identical, {comparison['different']} different, {comparison['missing']} missing")
    print(f"  Divergence rate: {divergence_rate:.1f}%")
    
    # Print example divergences
    if comparison["divergent_vertices"]:
        print(f"  Example divergence:")
        ex = comparison["divergent_vertices"][0]
        print(f"    {ex['vertex_id']}: {ex['differences']}")
    
    return comparison

def run_divergence_experiment(num_vertices=1000, num_updates_per_replica=2000, 
                              conflict_rate=0.8, delay_between=0.01, 
                              snapshot_interval=30):
    """
    Run property update divergence experiment
    
    Args:
        num_vertices: Number of vertices to create initially
        num_updates_per_replica: Number of updates each replica performs
        conflict_rate: Probability of updating same vertices
        delay_between: Delay between updates
        snapshot_interval: Seconds between snapshots
    """
    print("="*70)
    print("PROPERTY UPDATE DIVERGENCE EXPERIMENT")
    print("="*70)
    print(f"Initial vertices: {num_vertices}")
    print(f"Updates per replica: {num_updates_per_replica}")
    print(f"Conflict rate: {conflict_rate * 100}%")
    print(f"Delay between updates: {delay_between}s")
    print(f"Snapshot interval: {snapshot_interval}s")
    print("="*70)
    
    # Connect to replicas
    print("\n1. Connecting to replicas...")
    replica1 = ReplicaUpdater("Replica1", "ws://localhost:8182/gremlin")
    replica2 = ReplicaUpdater("Replica2", "ws://localhost:8183/gremlin")
    
    # Create initial vertices
    print("\n2. Creating initial vertex set...")
    print("   (Only one replica needs to do this)")
    replica1.create_initial_vertices(num_vertices)
    
    # Wait for replication
    print("   Waiting 5 seconds for cross-DC replication...")
    time.sleep(5)
    
    # Verify both replicas see the vertices
    count1 = replica1.get_count()
    count2 = replica2.get_count()
    print(f"   Replica1: {count1} vertices")
    print(f"   Replica2: {count2} vertices")
    
    if abs(count1 - count2) > num_vertices * 0.1:  # More than 10% difference
        print(f"   WARNING: Replicas have significantly different counts!")
    
    # Start concurrent updates
    print(f"\n3. Starting concurrent property updates...")
    print(f"   Each replica will perform {num_updates_per_replica} updates")
    print(f"   Expected conflicts: ~{int(num_updates_per_replica * conflict_rate)}")
    
    start_time = time.time()
    
    results = {
        "experiment": "property_update_divergence",
        "start_time": datetime.now().isoformat(),
        "config": {
            "num_vertices": num_vertices,
            "num_updates_per_replica": num_updates_per_replica,
            "conflict_rate": conflict_rate,
            "delay_between": delay_between,
            "snapshot_interval": snapshot_interval
        },
        "time_series": []
    }
    
    # Create threads for updates
    thread1 = threading.Thread(
        target=replica1.run_continuous_updates,
        args=(num_updates_per_replica, num_vertices, delay_between, conflict_rate)
    )
    thread2 = threading.Thread(
        target=replica2.run_continuous_updates,
        args=(num_updates_per_replica, num_vertices, delay_between, conflict_rate)
    )
    
    thread1.start()
    thread2.start()
    
    # Monitor with snapshots
    snapshot_count = 0
    next_snapshot_time = start_time + snapshot_interval
    
    while thread1.is_alive() or thread2.is_alive():
        current_time = time.time()
        
        if current_time >= next_snapshot_time:
            snapshot_count += 1
            elapsed = current_time - start_time
            
            print(f"\n  --- Snapshot {snapshot_count} at {elapsed:.1f}s ---")
            print(f"  Replica1 progress: {replica1.update_count}/{num_updates_per_replica}")
            print(f"  Replica2 progress: {replica2.update_count}/{num_updates_per_replica}")
            
            comparison = sample_and_compare(replica1, replica2, num_vertices, 
                                          sample_size=200, start_time=start_time)
            comparison["snapshot_type"] = "during_updates"
            comparison["snapshot_number"] = snapshot_count
            comparison["replica1_update_count"] = replica1.update_count
            comparison["replica2_update_count"] = replica2.update_count
            
            results["time_series"].append(comparison)
            next_snapshot_time = current_time + snapshot_interval
        
        time.sleep(1)
    
    thread1.join()
    thread2.join()
    
    elapsed_time = time.time() - start_time
    
    print(f"\n4. Updates complete!")
    print(f"  Time elapsed: {elapsed_time:.1f} seconds")
    print(f"  Replica1: {replica1.update_count} updates, {replica1.error_count} errors")
    print(f"  Replica2: {replica2.update_count} updates, {replica2.error_count} errors")
    
    # Take post-update snapshots
    print("\n5. Taking post-update snapshots...")
    
    # Immediate snapshot
    print("\n  Snapshot: Immediately after updates")
    comparison = sample_and_compare(replica1, replica2, num_vertices, 
                                  sample_size=200, start_time=start_time)
    comparison["snapshot_type"] = "immediate_after_completion"
    results["time_series"].append(comparison)
    
    # Additional snapshots at intervals
    post_intervals = [10, 30, 60, 120, 180]  # seconds
    
    for wait_time in post_intervals:
        print(f"\n  Waiting {wait_time} seconds...")
        time.sleep(wait_time)
        
        elapsed = time.time() - start_time
        print(f"\n  Snapshot: After {elapsed:.1f}s total ({wait_time}s post-update)")
        comparison = sample_and_compare(replica1, replica2, num_vertices, 
                                      sample_size=200, start_time=start_time)
        comparison["snapshot_type"] = f"after_{wait_time}s_post_update"
        results["time_series"].append(comparison)
    
    # Add summary statistics
    results["summary"] = {
        "total_elapsed_time": time.time() - start_time,
        "update_time": elapsed_time,
        "total_snapshots": len(results["time_series"]),
        "replica1_final_update_count": replica1.update_count,
        "replica2_final_update_count": replica2.update_count,
        "replica1_final_error_count": replica1.error_count,
        "replica2_final_error_count": replica2.error_count,
        "update_rate": (replica1.update_count + replica2.update_count) / elapsed_time
    }
    
    # Save results
    timestamp = int(time.time())
    filename = f"property_update_divergence_{timestamp}.json"
    with open(filename, 'w') as f:
        json.dump(results, f, indent=2)
    print(f"\n6. Results saved to: {filename}")
    
    # Print summary
    print("\n" + "="*70)
    print("EXPERIMENT SUMMARY")
    print("="*70)
    print(f"Total time: {elapsed_time:.1f} seconds")
    print(f"Update rate: {results['summary']['update_rate']:.1f} updates/sec")
    print(f"\nDivergence over time:")
    for snapshot in results["time_series"]:
        elapsed = snapshot['elapsed_time']
        divergence = snapshot['divergence_rate']
        snap_type = snapshot.get('snapshot_type', 'during_updates')
        print(f"  {elapsed:6.1f}s - {snap_type:30s}: {divergence:5.1f}% divergence")
    
    # Cleanup
    replica1.close()
    replica2.close()
    print("\nExperiment complete!")
    
    return filename

def main():
    import sys
    
    print("JanusGraph Property Update Divergence Test")
    print("="*70)
    print("\nThis test creates divergence by updating properties on existing vertices")
    print("rather than trying to create the same vertex multiple times.")
    print("\nSelect experiment mode:")
    print("  1. Full test (1000 vertices, 2000 updates per replica)")
    print("  2. Quick test (100 vertices, 200 updates per replica)")
    print("  3. Custom parameters")
    print("  4. Clear both databases and exit")

    choice = input("\nEnter choice (1/2/3/4) [default: 2]: ").strip() or "2"

    if choice == "4":
        print("\nConnecting to both replicas to clear databases...")
        replica1 = ReplicaUpdater("Replica1", "ws://localhost:8182/gremlin")
        replica2 = ReplicaUpdater("Replica2", "ws://localhost:8183/gremlin")
        replica1.clear_database()
        replica2.clear_database()
        replica1.close()
        replica2.close()
        print("Both databases cleared. Exiting.")
        return

    if choice == "1":
        filename = run_divergence_experiment(
            num_vertices=1000,
            num_updates_per_replica=2000,
            conflict_rate=0.8,
            delay_between=0.01,
            snapshot_interval=30
        )
    elif choice == "3":
        num_vertices = int(input("Number of vertices [default: 500]: ") or "500")
        num_updates = int(input("Updates per replica [default: 1000]: ") or "1000")
        conflict_rate = float(input("Conflict rate 0.0-1.0 [default: 0.8]: ") or "0.8")
        snapshot_interval = int(input("Snapshot interval in seconds [default: 20]: ") or "20")

        filename = run_divergence_experiment(
            num_vertices=num_vertices,
            num_updates_per_replica=num_updates,
            conflict_rate=conflict_rate,
            delay_between=0.01,
            snapshot_interval=snapshot_interval
        )
    else:
        print("\nRunning quick test...")
        filename = run_divergence_experiment(
            num_vertices=100,
            num_updates_per_replica=200,
            conflict_rate=0.8,
            delay_between=0.01,
            snapshot_interval=10
        )

    print(f"\n{'='*70}")
    print(f"Data file: {filename}")
    print(f"Use visualize_divergence.py to generate charts from this data")
    print(f"{'='*70}")

if __name__ == "__main__":
    main()