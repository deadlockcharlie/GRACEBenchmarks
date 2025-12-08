package site.ycsb.db.DatabaseDrivers;


import org.neo4j.driver.Driver;
import org.neo4j.driver.GraphDatabase;
import org.neo4j.driver.Session;

public class Neo4jDriver implements DatabaseClient {
  String name;
  Driver neo4jDriver;
  Session session;
  @Override
  public void connect(String name, String URI) {
    try {
      this.name = name;
      this.neo4jDriver = GraphDatabase.driver(URI);
      this.session = neo4jDriver.session();
      neo4jDriver.verifyConnectivity();
    } catch (Exception e) {
      System.out.println("Failed to connect to Neo4j database: " + e.getMessage());
      throw new RuntimeException(e);
    }
  }

  @Override
  public boolean getVertexCount() {

    try{
      session.run("MATCH (n) RETURN count(n)");
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
      session.run("MATCH ()-[r]->() RETURN count(r)");
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
      session.run("MATCH ()-[r]->() RETURN DISTINCT type(r)");
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
      session.run("MATCH (n) WHERE n." + key + " = '" + value + "' RETURN n");
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
      session.run("MATCH ()-[r]->() WHERE r." + key + " = '" + value + "' RETURN r");
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
      session.run("MATCH ()-[r:" + label + "]->() RETURN r");
      return true;
    }
    catch (Exception e){
      System.out.println("Exception in getEdgesWithLabel: " + e.getMessage());
      return false;
    }
  }
}
