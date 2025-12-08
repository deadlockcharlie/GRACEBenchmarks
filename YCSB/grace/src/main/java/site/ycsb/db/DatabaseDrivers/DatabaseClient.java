package site.ycsb.db.DatabaseDrivers;

public interface DatabaseClient {

void connect(String name, String URI);

// Read operations. Send these directly to the graph database.
public boolean getVertexCount();
public boolean getEdgeCount();
public boolean getEdgeLabels();
public boolean getVertexWithProperty(String key, String value);
public boolean getEdgeWithProperty(String key, String value);
public boolean getEdgesWithLabel(String label);
}
