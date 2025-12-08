package site.ycsb.db.DatabaseDrivers;

import org.apache.tinkerpop.gremlin.driver.remote.DriverRemoteConnection;
import org.apache.tinkerpop.gremlin.process.traversal.AnonymousTraversalSource;
import org.apache.tinkerpop.gremlin.process.traversal.dsl.graph.GraphTraversalSource;

public class GremlinDriver implements DatabaseClient {
  String name;
  GraphTraversalSource g;

  @Override
  public void connect(String name, String URI) {
    this.name = name;
   this.g = AnonymousTraversalSource.traversal().withRemote(DriverRemoteConnection.using(URI));
  }

  @Override
  public boolean getVertexCount() {
    try{
      g.V().count().next();
      return true;
    }
    catch (Exception e){
      System.out.println("Exception in getVertexCount: " + e.getMessage());
      return false;
    }
  }

  @Override
  public boolean getEdgeCount() {
    try{
      g.E().count().next();
      return true;
    }
    catch (Exception e){
      System.out.println("Exception in getEdgeCount: " + e.getMessage());
      return false;
    }
  }

  @Override
  public boolean getEdgeLabels() {
    try{
      g.E().label().dedup().toList();
      return true;
    }
    catch (Exception e){
      System.out.println("Exception in getEdgeLabels: " + e.getMessage());
      return false;
    }
  }

  @Override
  public boolean getVertexWithProperty(String key, String value) {
    try{
      g.V().has(key, value).toList();
      return true;
    }
    catch (Exception e){
      System.out.println("Exception in getVertexWithProperty: " + e.getMessage());
      return false;
    }
  }

  @Override
  public boolean getEdgeWithProperty(String key, String value) {
    try{
      g.E().has(key, value).toList();
      return true;
    }
    catch (Exception e){
      System.out.println("Exception in getEdgeWithProperty: " + e.getMessage());
      return false;
    }
  }

  @Override
  public boolean getEdgesWithLabel(String label) {
    try{
      g.E().hasLabel(label).toList();
      return true;
    }
    catch (Exception e){
      System.out.println("Exception in getEdgesWithLabel: " + e.getMessage());
      return false;
    }
  }
}
