package site.ycsb.db.DatabaseDrivers;

import com.mongodb.ConnectionString;
import com.mongodb.MongoClientSettings;
import com.mongodb.client.MongoClient;
import com.mongodb.client.MongoClients;

import java.util.concurrent.atomic.AtomicLong;

public class MongodbDriver implements DatabaseClient {
  String name;
  MongoClient mongoClient;

  @Override
  public void connect(String name, String URI) {
    try {
    this.name = name;
     this.mongoClient = MongoClients.create(
         MongoClientSettings.builder()
             .applyConnectionString(new ConnectionString(URI))
             .build()
     );

     // Create a database and a vertex and edge collection if they don't exist
      mongoClient.getDatabase("grace").createCollection("vertices");
      mongoClient.getDatabase("grace").createCollection("edges");

      // Test connection status and print it

        mongoClient.listDatabaseNames().first();
        System.out.println("Connected to MongoDB database successfully");
      } catch (Exception e) {
        System.out.println("Failed to connect to MongoDB database: " + e.getMessage());
        throw new RuntimeException(e);
      }
  }

  @Override
  public boolean getVertexCount() {
    try{
      Long res = this.mongoClient.getDatabase("grace").getCollection("vertices").countDocuments();
//      System.out.println("Vertex count: " + res);
    } catch (Exception e){
      System.out.println("Exception in getVertexCount: " + e.getMessage());
      return false;
    }
    return true;
  }

  @Override
  public boolean getEdgeCount() {
    try{
      this.mongoClient.getDatabase("grace").getCollection("edges").countDocuments();
    } catch (Exception e){
      System.out.println("Exception in getEdgeCount: " + e.getMessage());
      return false;
    }
    return true;
  }

  @Override
  public boolean getEdgeLabels() {
    try{
      this.mongoClient.getDatabase("grace").getCollection("edges").distinct("label", String.class).first();
    } catch (Exception e){
      System.out.println("Exception in getEdgeLabels: " + e.getMessage());
      return false;
    }
    return true;
  }

  @Override
  public boolean getVertexWithProperty(String key, String value) {
    try{
      AtomicLong count= new AtomicLong();
      this.mongoClient.getDatabase("grace").getCollection("vertices").find(new org.bson.Document(key, value)).forEach(doc -> {
        // Print the document
        System.out.println(doc.toJson());
        count.getAndIncrement();
      });

    } catch (Exception e){
      System.out.println("Exception in getVertexWithProperty: " + e.getMessage());
      return false;
    }
    return true;
  }

  @Override
  public boolean getEdgeWithProperty(String key, String value) {
    try{
      this.mongoClient.getDatabase("grace").getCollection("edges").find(new org.bson.Document(key, value));
    } catch (Exception e){
      System.out.println("Exception in getEdgeWithProperty: " + e.getMessage());
      return false;
    }
    return true;
  }

  @Override
  public boolean getEdgesWithLabel(String label) {
    try{
      this.mongoClient.getDatabase("grace").getCollection("edges").find(new org.bson.Document("label", label));
    } catch (Exception e){
      System.out.println("Exception in getEdgesWithLabel: " + e.getMessage());
      return false;
    }
    return true;
  }
}
