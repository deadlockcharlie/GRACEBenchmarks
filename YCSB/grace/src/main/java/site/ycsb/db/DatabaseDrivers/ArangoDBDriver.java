package site.ycsb.db.DatabaseDrivers;

import com.arangodb.ArangoCursor;
import com.arangodb.ArangoDB;
import com.arangodb.ArangoDatabase;
import com.arangodb.entity.BaseDocument;

import java.net.URI;
import java.util.HashMap;
import java.util.Map;

public class ArangoDBDriver implements DatabaseClient {
  String name;
  ArangoDatabase db;

  @Override
  public void connect(String name, String URI) {
    try {
      this.name = name;
      URI uri = new URI(URI);

      System.out.println("Connecting to ArangoDB database with params: " + uri.getHost() + ":" + uri.getPort());
      ArangoDB arangodb = new ArangoDB.Builder()
          .host(uri.getHost(), uri.getPort())
          .build();
      this.db = arangodb.db("ycsb");
      if (!db.exists()) {
        arangodb.createDatabase("ycsb");
        this.db = arangodb.db("ycsb");
        db.createCollection("vertices");
        db.createCollection("edges");
      }
      System.out.println("Connected to ArangoDB database successfully");
    } catch (Exception e) {
      System.out.println("Failed to connect to ArangoDB database: " + e.getMessage());
      throw new RuntimeException(e);
    }
  }

  @Override
  public boolean getVertexCount() {
    try {
      db.collection("vertices").count();
      return true;
    } catch (Exception e) {
      System.out.println("Exception in getVertexCount: " + e.getMessage());
      return false;
    }
  }

  @Override
  public boolean getEdgeCount() {
    try {
      db.collection("edges").count();
      return true;
    } catch (Exception e) {
      System.out.println("Exception in getEdgeCount: " + e.getMessage());
      return false;
    }
  }

  @Override
  public boolean getEdgeLabels() {
    try{
      db.query("FOR e IN edges COLLECT label = e._key RETURN label", String.class).asListRemaining();
      return true;
    } catch (Exception e) {
      System.out.println("Exception in getEdgeLabels: " + e.getMessage());
      return false;
    }
  }

  @Override
  public boolean getVertexWithProperty(String key, String value) {
    try{
      String query = "FOR v IN vertices FILTER v."+key+" ==\" "+value+"\" RETURN v";
      ArangoCursor<String> cursor = db.query(query, String.class);
      return true;
    } catch (Exception e) {
      System.out.println("Exception in getVertexWithProperty: " + e.getMessage());
      return false;
    }
  }

  @Override
  public boolean getEdgeWithProperty(String key, String value) {
    try {
      String query = "FOR e IN edges FILTER e."+key+" ==\" "+value+"\" RETURN e";
//      System.out.println(query);
      ArangoCursor<String> cursor = db.query(query, String.class);

//      System.out.println("Query executed: " + cursor.asListRemaining());
      return true;
    } catch (Exception e) {
      System.out.println("Exception in getEdgeWithProperty: " + e.getMessage());
      return false;
    }
  }

  @Override
  public boolean getEdgesWithLabel(String label) {
    try {
      String query = "FOR e IN edges FILTER e.label == [\"YCSBEdge\"] RETURN e";

      ArangoCursor<String> cursor = db.query(query, String.class);

//      System.out.println("Query executed: " + cursor.asListRemaining());
      return true;
    } catch (Exception e) {
      System.out.println("Exception in getEdgesWithLabel: " + e.getMessage());
      return false;
    }
  }
}
