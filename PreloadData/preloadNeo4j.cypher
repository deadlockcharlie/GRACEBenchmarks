// Clean database (optional if you want fresh load each time)
MATCH (n) DETACH DELETE n;

// Drop old indexes if they exist
DROP INDEX vertex_id IF EXISTS;
DROP INDEX edge_id IF EXISTS;

// Create fresh indexes
CREATE INDEX vertex_id IF NOT EXISTS FOR (n:YCSBVertex) ON (n.id);
CREATE INDEX edge_id   IF NOT EXISTS FOR ()-[r:YCSBEdge]-() ON (r.id);

// Load vertices
LOAD CSV WITH HEADERS FROM 'file:///vertices.csv' AS row
CREATE (n:YCSBVertex {id: row._id})
SET n += apoc.map.clean(row, [], []);


// Load edges
LOAD CSV WITH HEADERS FROM 'file:///edges.csv' AS row
MATCH (a:YCSBVertex {id: row._outV}), (b:YCSBVertex {id: row._inV})
CREATE (a)-[r:YCSBEdge {id: row._id}]->(b)
SET r += apoc.map.clean(row, [], []);
