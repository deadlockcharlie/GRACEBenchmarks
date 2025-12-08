package site.ycsb.db;

import com.mongodb.ConnectionString;
import com.mongodb.MongoClientSettings;
import com.mongodb.ReadConcern;
import com.mongodb.client.FindIterable;
import com.mongodb.client.MongoClient;
import com.mongodb.client.MongoClients;
import com.mongodb.client.model.Filters;
import com.mongodb.client.model.Updates;
import com.mongodb.client.result.InsertOneResult;

import org.bson.Document;
import org.bson.types.ObjectId;
import site.ycsb.DB;
import site.ycsb.DBException;
import site.ycsb.Status;

import java.util.List;
import java.util.Map;
import java.util.Properties;
import java.util.Random;
import java.util.concurrent.atomic.AtomicLong;
import java.util.function.Supplier;
import java.util.stream.Collectors;

public class MongoDBClient extends DB {

  private static Properties props = new Properties();
  MongoClient mongoClient;

  @Override
  public void init() throws DBException {
    System.out.println("Starting Mongodb client");
    props = getProperties();
    System.out.println(props);

    if(props.getProperty("DBTYPE")==null){
      System.out.println("DBTYPE must be provided");
      throw new DBException("DBTYPE must be provided");
    }
    System.out.println("DBTYPE: "+props.getProperty("DBTYPE"));

    if(props.getProperty("DBURI")==null){
      System.out.println("DBURI must be provided");
      throw new DBException("DBURI must be provided");
    }
    System.out.println("DBURI: "+props.getProperty("DBURI"));
    try{
      this.mongoClient = MongoClients.create(
          MongoClientSettings.builder()
              .applyConnectionString(new ConnectionString(props.getProperty("DBURI")))
              .applyToClusterSettings(builder -> {
                  builder.serverSelectionTimeout(60, java.util.concurrent.TimeUnit.SECONDS);
              })
              .applyToSocketSettings(builder -> {
                  builder.connectTimeout(10, java.util.concurrent.TimeUnit.SECONDS);
                  builder.readTimeout(30, java.util.concurrent.TimeUnit.SECONDS);
              })
              .readConcern(ReadConcern.LOCAL)
              .writeConcern(com.mongodb.WriteConcern.ACKNOWLEDGED)
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
      throw new DBException(e);
    }
  }

  private <T> T withRefresh(Supplier<T> op) {
  try {
    return op.get();
  } catch (Exception e) {
    if (e.getMessage().contains("NotPrimary") || e.getMessage().contains("timed out")) {
      System.out.println("Detected stale topology; forcing driver refresh...");
      try { mongoClient.getDatabase("admin").runCommand(new Document("ping", 1)); } catch (Exception ignored) {}
    }
    throw e;
  }
}


  @Override
  public Status addVertex(String label, String id, Map<String, String> properties) {
//    System.out.println("Add Vertex");
//    return Status.OK;
    int status = 0;

    try {
//      System.out.println("Adding vertex with id: " + id);
      Document vertex = new Document();
      vertex.append("label", label);
      vertex.append("_id", id);
      Document props = new Document();
      for (Map.Entry<String, String> entry : properties.entrySet()) {
        props.append(entry.getKey(), entry.getValue().toString());
      }
      vertex.append("properties", props);
      return withRefresh(() -> {
        InsertOneResult result = this.mongoClient.getDatabase("grace").getCollection("vertices").insertOne(vertex);
        return Status.OK;
      });
      // InsertOneResult result = this.mongoClient.getDatabase("grace").getCollection("vertices").insertOne(vertex);
//      System.out.println("Inserted vertex with id: " + result);
      // return Status.OK;
    } catch (Exception e) {
      return Status.ERROR;
    }
  }
  @Override
  public Status addEdge(String label, String id, String from, String to, Map<String, String> properties) {
    int status = 0;
    try {
      Document edge = new Document();
      edge.append("label", label);
      edge.append("_id", id);
      edge.append("from", from);
      edge.append("to", to);
      Document props = new Document();
      for (Map.Entry<String, String> entry : properties.entrySet()) {
        props.append(entry.getKey(), entry.getValue().toString());
      }
      edge.append("properties", props);
      return withRefresh(() -> {
        InsertOneResult result = this.mongoClient.getDatabase("grace").getCollection("edges").insertOne(edge);
        return Status.OK;
      });
      // InsertOneResult result = this.mongoClient.getDatabase("grace").getCollection("edges").insertOne(edge);
//      System.out.println("Inserted edge with id: " + result);
      // return Status.OK;
    } catch (Exception e) {
      return Status.ERROR;
    }

  }


  @Override
  public Status setVertexProperty(String id, String key, String value) {
    try{
      return withRefresh(() -> {
        this.mongoClient.getDatabase("grace").getCollection("vertices").updateOne(new Document("_id", id), new Document("$set", new Document("properties." + key, value)), new com.mongodb.client.model.UpdateOptions().upsert(true));
        return Status.OK;
      });
      // this.mongoClient.getDatabase("grace").getCollection("vertices").updateOne(new Document("_id", id), new Document("$set", new Document("properties." + key, value)), new com.mongodb.client.model.UpdateOptions().upsert(true));
//      Document vertex = this.mongoClient.getDatabase("grace").getCollection("vertices").find().limit(1).first();
//      if(vertex==null){
//        System.out.println("Vertex not found with id: " + id);
//        return Status.ERROR;
//      }
//      System.out.println("Found vertex: " + vertex.toJson());
//      Document props = (Document) vertex.get("properties");
//      if(props==null){
//        props = new Document();
//      }
//      props.append(key, value);
//      vertex.put("properties", props);
//      System.out.println("Updating vertex with id: " + id + " to have properties: " + vertex.toJson());
//      this.mongoClient.getDatabase("grace").getCollection("vertices").updateOne(new Document("_id", id), new Document("$set", vertex));
      // return Status.OK;
    } catch (Exception e){
      System.out.println("Exception in setVertexProperty: " + e.getMessage());
      return Status.ERROR;
    }
  }

  @Override
  public Status setEdgeProperty(String id, String key, String value) {
    try {
      return withRefresh(() -> {
        this.mongoClient.getDatabase("grace").getCollection("edges").updateOne(new Document("_id", id), new Document("$set", new Document("properties." + key, value)), new com.mongodb.client.model.UpdateOptions().upsert(true));
        return Status.OK;
      });
    } catch (Exception e) {
//      }
//      Document props = (Document) edge.get("properties");
//      if (props == null) {
//        props = new Document();
//      }
//      props.append(key, value.toString());
//      edge.put("properties", props);
//      this.mongoClient.getDatabase("grace").getCollection("edges").replaceOne(new Document("_id", id), edge);
      return Status.ERROR;
    }
  }

  @Override
  public Status removeVertex(String id) {
    int status = 0;
    try {
      return withRefresh(() -> {
        this.mongoClient.getDatabase("grace").getCollection("vertices").deleteOne(new Document("_id", id));
        return Status.OK;
      });
      
    } catch (Exception e) {
      return Status.ERROR;
    }
  }

  @Override
  public Status removeEdge(String id) {
    int status = 0;
    try {
      return withRefresh(() -> {
        this.mongoClient.getDatabase("grace").getCollection("edges").deleteOne(new Document("_id", id));
        return Status.OK;
      });
    } catch (Exception e) {
      return Status.ERROR;
    }
  }

  @Override
  public Status removeVertexProperty(String id, String key) {
    try{

      return withRefresh(() -> {
        Document doc = this.mongoClient.getDatabase("grace").getCollection("vertices").find(Filters.eq("_id", id)).first();

        if (doc != null) {
          // Get field names (excluding _id)
          List<String> fieldNames = doc.keySet().stream()
              .filter(k -> !k.equals("_id"))
              .collect(Collectors.toList());

          if (!fieldNames.isEmpty()) {
            // Select random field
            Random random = new Random();
            String randomField = fieldNames.get(random.nextInt(fieldNames.size()));

            // Remove it
            this.mongoClient.getDatabase("grace").getCollection("vertices").updateOne(
                Filters.eq("_id", id),
                Updates.unset(randomField)
            );
//          System.out.println("Removed field: " + randomField);
          }
        }
        return Status.OK;
      });
    }catch (Exception e){
      System.out.println("Exception in removeVertexProperty: " + e.getMessage());
      return Status.ERROR;
    }
  }

  @Override
  public Status removeEdgeProperty(String id, String key) {
    try{

      return withRefresh(() -> {

      Document doc = this.mongoClient.getDatabase("grace").getCollection("edges").find(Filters.eq("_id", id)).first();

      if (doc != null) {
        // Get field names (excluding _id)
        List<String> fieldNames = doc.keySet().stream()
            .filter(k -> !k.equals("_id"))
            .collect(Collectors.toList());

        if (!fieldNames.isEmpty()) {
          // Select random field
          Random random = new Random();
          String randomField = fieldNames.get(random.nextInt(fieldNames.size()));

          // Remove it
          this.mongoClient.getDatabase("grace").getCollection("edges").updateOne(
              Filters.eq("_id", id),
              Updates.unset(randomField)
          );
        }
      }
      return Status.OK;
    });
    } catch (Exception e){
      return Status.ERROR;
    }
  }


  @Override
  public Status getVertexCount() {
    try{
      return withRefresh(() -> {
        Long res = this.mongoClient.getDatabase("grace").getCollection("vertices").countDocuments();
        return Status.OK;
        //      System.out.println("Vertex count: " + res);
      });
    } catch (Exception e){
      System.out.println("Exception in getVertexCount: " + e.getMessage());
      return Status.ERROR;
    }
  }

  @Override
  public Status getEdgeCount() {
    try{
      return withRefresh(() -> {
        Long res = this.mongoClient.getDatabase("grace").getCollection("edges").countDocuments();
        return Status.OK;
      });
    } catch (Exception e){
      System.out.println("Exception in getEdgeCount: " + e.getMessage());
        return Status.ERROR;
    }
  }

  @Override
  public Status getEdgeLabels() {
    try{
      return withRefresh(() -> {
        this.mongoClient.getDatabase("grace").getCollection("edges").distinct("label", String.class).first();
        return Status.OK;
      });
    } catch (Exception e){
      System.out.println("Exception in getEdgeLabels: " + e.getMessage());
      return Status.ERROR;
    }
  }

  @Override
  public Status getVertexWithProperty(String key, String value) {
    try{
      AtomicLong count= new AtomicLong();
//      System.out.println("Searching for vertices with " + key + " = " + value);
      return withRefresh(() -> {
      this.mongoClient.getDatabase("grace").getCollection("vertices").find(new org.bson.Document(key, value)).forEach(doc -> {
        // Print the document
        System.out.println(doc.toJson());
        count.getAndIncrement();
      });
      return Status.OK;
      });
    } catch (Exception e){
      System.out.println("Exception in getVertexWithProperty: " + e.getMessage());
      return Status.ERROR;
    }
  }

  @Override
  public  Status getEdgeWithProperty(String key, String value) {
    try{
      return withRefresh(() -> {
        FindIterable<Document> result = this.mongoClient.getDatabase("grace").getCollection("edges").find(new Document(key, value.toString()));
        for (Document doc : result) {
          doc.toJson();
        }
        return Status.OK;
      });
    } catch (Exception e){
      System.out.println("Exception in getEdgeWithProperty: " + e.getMessage());
      return Status.ERROR;
    }
  }

  @Override
  public Status getEdgesWithLabel(String label) {
    try{
      return withRefresh(() -> {
        FindIterable<Document> result = this.mongoClient.getDatabase("grace").getCollection("edges").find(new Document("label", label));
        for (Document doc : result) {
          doc.toJson();
        }
        return Status.OK;
      });
    } catch (Exception e){
      System.out.println("Exception in getEdgesWithLabel: " + e.getMessage());
      return Status.ERROR;
    }
  }
}
