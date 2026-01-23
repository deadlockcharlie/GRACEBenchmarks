import csv
import json
import os
from pathlib import Path
from typing import Dict, List, Any
import argparse

class LDBCConverter:
    """Convert LDBC SNB CSV files to JSON format."""
    
    # Define vertex types (static entities)
    VERTEX_TYPES = [
        'organisation',
        'place',
        'tag',
        'tagclass'
    ]
    
    # Define dynamic vertex types (have creationDate)
    DYNAMIC_VERTEX_TYPES = [
        'person',
        'comment',
        'post',
        'forum'
    ]
    
    # Define edge types with their source and target vertex types
    EDGE_TYPES = [
        'person_knows_person',
        'person_likes_comment',
        'person_likes_post',
        'person_hasInterest_tag',
        'person_workAt_organisation',
        'person_studyAt_organisation',
        'person_isLocatedIn_place',
        'comment_hasCreator_person',
        'comment_isLocatedIn_place',
        'comment_replyOf_comment',
        'comment_replyOf_post',
        'comment_hasTag_tag',
        'post_hasCreator_person',
        'post_isLocatedIn_place',
        'post_hasTag_tag',
        'forum_hasMember_person',
        'forum_hasModerator_person',
        'forum_containerOf_post',
        'forum_hasTag_tag',
        'organisation_isLocatedIn_place',
        'place_isPartOf_place',
        'tag_hasType_tagclass',
        'tagclass_isSubclassOf_tagclass'
    ]
    
    def __init__(self, input_dir: str, output_file: str, delimiter: str = '|'):
        """Initialize converter with input directory and output file."""
        self.input_dir = Path(input_dir)
        self.output_file = Path(output_file)
        self.delimiter = delimiter
        self.vertex_id_counter = 1
        self.edge_id_counter = 1
        self.original_id_to_new_id = {}  # Map original IDs to new sequential IDs
        
        # Create output directory if needed
        self.output_file.parent.mkdir(parents=True, exist_ok=True)
        
    def read_csv_file(self, filepath: Path) -> List[Dict[str, Any]]:
        """Read a CSV file and return list of dictionaries."""
        data = []
        if not filepath.exists():
            print(f"Warning: File not found: {filepath}")
            return data
            
        with open(filepath, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f, delimiter=self.delimiter)
            for row in reader:
                # Convert empty strings to None and clean up data
                cleaned_row = {}
                for k, v in row.items():
                    if v == '':
                        cleaned_row[k] = None
                    else:
                        # Try to convert to appropriate type
                        cleaned_row[k] = self._convert_value(v)
                data.append(cleaned_row)
        
        print(f"Read {len(data)} records from {filepath.name}")
        return data
    
    def _convert_value(self, value: str) -> Any:
        """Convert string value to appropriate type."""
        if value is None or value == '':
            return None
        
        # Try integer
        try:
            return int(value)
        except ValueError:
            pass
        
        # Try float
        try:
            return float(value)
        except ValueError:
            pass
        
        # Return as string
        return value
    
    def find_csv_files(self, entity_name: str) -> List[Path]:
        """Find all CSV files for a given entity (handles both formats)."""
        # LDBC can have different naming conventions
        patterns = [
            f"{entity_name}_0_0.csv",
            f"{entity_name}.csv",
            f"dynamic/{entity_name}_0_0.csv",
            f"static/{entity_name}_0_0.csv"
        ]
        
        for pattern in patterns:
            filepath = self.input_dir / pattern
            if filepath.exists():
                return [filepath]
        
        # Check for partitioned files (e.g., person_0_0.csv, person_1_0.csv)
        dynamic_dir = self.input_dir / "dynamic"
        static_dir = self.input_dir / "static"
        
        files = []
        for directory in [self.input_dir, dynamic_dir, static_dir]:
            if directory.exists():
                files.extend(directory.glob(f"{entity_name}_*_*.csv"))
        
        return sorted(set(files))
    
    def get_vertex_label(self, vertex_type: str) -> str:
        """Get a short label for the vertex type."""
        # Map vertex types to short labels
        label_map = {
            'person': 'person',
            'comment': 'comment',
            'post': 'post',
            'forum': 'forum',
            'organisation': 'organisation',
            'place': 'place',
            'tag': 'tag',
            'tagclass': 'tagclass'
        }
        return label_map.get(vertex_type, vertex_type)
    
    def process_vertices(self) -> List[Dict[str, Any]]:
        """Process all vertex CSV files."""
        all_vertices = []
        
        # Process static vertices
        for vertex_type in self.VERTEX_TYPES:
            files = self.find_csv_files(vertex_type)
            for filepath in files:
                vertices = self.read_csv_file(filepath)
                for vertex in vertices:
                    # Get original ID (usually 'id' field)
                    original_id = vertex.get('id')
                    if original_id is None:
                        print(f"Warning: Vertex without ID in {vertex_type}")
                        continue
                    
                    # Create unique key for this vertex
                    vertex_key = f"{vertex_type}:{original_id}"
                    
                    # Assign new sequential ID
                    new_id = self.vertex_id_counter
                    self.vertex_id_counter += 1
                    self.original_id_to_new_id[vertex_key] = new_id
                    
                    # Create vertex in new format
                    new_vertex = {
                        "_type": "vertex",
                        "_id": new_id,
                        "oid": new_id,
                        "label": self.get_vertex_label(vertex_type),
                        "original_type": vertex_type
                    }
                    
                    # Add all other properties
                    for key, value in vertex.items():
                        if key != 'id':  # Skip the original id field
                            new_vertex[key] = value
                    
                    all_vertices.append(new_vertex)
        
        # Process dynamic vertices
        for vertex_type in self.DYNAMIC_VERTEX_TYPES:
            files = self.find_csv_files(vertex_type)
            for filepath in files:
                vertices = self.read_csv_file(filepath)
                for vertex in vertices:
                    # Get original ID
                    original_id = vertex.get('id')
                    if original_id is None:
                        print(f"Warning: Vertex without ID in {vertex_type}")
                        continue
                    
                    # Create unique key for this vertex
                    vertex_key = f"{vertex_type}:{original_id}"
                    
                    # Assign new sequential ID
                    new_id = self.vertex_id_counter
                    self.vertex_id_counter += 1
                    self.original_id_to_new_id[vertex_key] = new_id
                    
                    # Create vertex in new format
                    new_vertex = {
                        "_type": "vertex",
                        "_id": new_id,
                        "oid": new_id,
                        "label": self.get_vertex_label(vertex_type),
                        "original_type": vertex_type
                    }
                    
                    # Add all other properties
                    for key, value in vertex.items():
                        if key != 'id':  # Skip the original id field
                            new_vertex[key] = value
                    
                    all_vertices.append(new_vertex)
        
        print(f"\nTotal vertices: {len(all_vertices)}")
        return all_vertices
    
    def process_edges(self) -> List[Dict[str, Any]]:
        """Process all edge CSV files."""
        all_edges = []
        
        for edge_type in self.EDGE_TYPES:
            files = self.find_csv_files(edge_type)
            
            # Parse edge type to get source and target types
            parts = edge_type.split('_')
            if len(parts) >= 3:
                source_type = parts[0]
                relation = parts[1]
                target_type = '_'.join(parts[2:])  # Handle multi-word types
            else:
                print(f"Warning: Cannot parse edge type: {edge_type}")
                continue
            
            for filepath in files:
                edges = self.read_csv_file(filepath)
                if not edges:
                    continue
                
                # Get the first edge to inspect column names
                first_edge = edges[0]
                columns = list(first_edge.keys())
                
                # Find all columns with ".id" suffix
                # First column with .id is source, second is target
                id_fields = [col for col in columns if col.endswith('.id')]
                
                if len(id_fields) < 2:
                    print(f"Warning: Expected 2 .id columns in {edge_type}, found {len(id_fields)}: {id_fields}")
                    continue
                
                source_id_field = id_fields[0]
                target_id_field = id_fields[1]
                
                # Extract the actual vertex type from the column name (e.g., "Person.id" -> "person")
                source_vertex_type = source_id_field.replace('.id', '').lower()
                target_vertex_type = target_id_field.replace('.id', '').lower()
                
                for edge in edges:
                    source_original_id = edge.get(source_id_field)
                    target_original_id = edge.get(target_id_field)
                    
                    if source_original_id is None or target_original_id is None:
                        continue
                    
                    # Look up new IDs using the actual vertex types from column names
                    source_key = f"{source_vertex_type}:{source_original_id}"
                    target_key = f"{target_vertex_type}:{target_original_id}"
                    
                    source_new_id = self.original_id_to_new_id.get(source_key)
                    target_new_id = self.original_id_to_new_id.get(target_key)
                    
                    if source_new_id is None or target_new_id is None:
                        # Only print first few warnings to avoid spam
                        if len(all_edges) < 5:
                            print(f"Warning: Cannot find vertex mapping for {source_key} -> {target_key}")
                        continue
                    
                    # Create edge in new format
                    new_edge = {
                        "_type": "edge",
                        "_id": self.edge_id_counter,
                        "_outV": source_new_id,
                        "_inV": target_new_id,
                        "_label": relation,
                        "original_type": edge_type
                    }
                    
                    # Add all other properties (excluding the ID columns)
                    for key, value in edge.items():
                        if key not in [source_id_field, target_id_field]:
                            new_edge[key] = value
                    
                    self.edge_id_counter += 1
                    all_edges.append(new_edge)
        
        print(f"\nTotal edges: {len(all_edges)}")
        return all_edges
    
    def convert(self):
        """Main conversion process."""
        print(f"Converting LDBC SNB data from: {self.input_dir}")
        print(f"Output file: {self.output_file}\n")
        
        # Process vertices first (to build ID mapping)
        print("Processing vertices...")
        vertices = self.process_vertices()
        
        # Process edges (using ID mapping)
        print("\nProcessing edges...")
        edges = self.process_edges()
        
        # Create output structure
        output = {
            "mode": "NORMAL",
            "vertices": vertices,
            "edges": edges
        }
        
        # Write to file (compact format, no indentation)
        print(f"\nWriting to {self.output_file}...")
        with open(self.output_file, 'w', encoding='utf-8') as f:
            json.dump(output, f, separators=(',', ':'))
        
        # Print summary
        print("\n" + "="*50)
        print("CONVERSION COMPLETE")
        print("="*50)
        print(f"Total vertices: {len(vertices)}")
        print(f"Total edges: {len(edges)}")
        
        # Print vertex breakdown
        vertex_counts = {}
        for v in vertices:
            vtype = v.get('original_type', 'unknown')
            vertex_counts[vtype] = vertex_counts.get(vtype, 0) + 1
        
        print("\nVertex breakdown:")
        for vtype, count in sorted(vertex_counts.items()):
            print(f"  {vtype}: {count}")
        
        # Print edge breakdown
        edge_counts = {}
        for e in edges:
            etype = e.get('original_type', 'unknown')
            edge_counts[etype] = edge_counts.get(etype, 0) + 1
        
        print("\nEdge breakdown:")
        for etype, count in sorted(edge_counts.items()):
            print(f"  {etype}: {count}")


def main():
    parser = argparse.ArgumentParser(
        description='Convert LDBC SNB CSV files to JSON format'
    )
    parser.add_argument(
        'input_dir',
        help='Directory containing LDBC SNB CSV files'
    )
    parser.add_argument(
        'output_file',
        help='Output JSON file path'
    )
    parser.add_argument(
        '--delimiter',
        default='|',
        help='CSV delimiter (default: |)'
    )
    
    args = parser.parse_args()
    
    converter = LDBCConverter(args.input_dir, args.output_file, args.delimiter)
    converter.convert()


if __name__ == '__main__':
    main()