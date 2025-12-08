package site.ycsb.db;

import com.arangodb.ArangoCursor;
import com.arangodb.ArangoDB;
import com.arangodb.ArangoDatabase;
import com.arangodb.entity.DocumentCreateEntity;
import com.arangodb.entity.DocumentUpdateEntity;
import com.arangodb.entity.ReplicationFactor;
import com.arangodb.model.CollectionCreateOptions;
import com.arangodb.model.CollectionPropertiesOptions;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import site.ycsb.DB;
import site.ycsb.DBException;
import site.ycsb.Status;


import java.net.URI;
import java.util.*;

public class ArangoDBClient extends DB {

  private static Properties props = new Properties();
  private final Logger log = LoggerFactory.getLogger(getClass());
  ArangoDatabase db;


  @Override
  public void init() throws DBException {
    try {
      System.out.println("Starting ArangoDB client");
      props = getProperties();
      System.out.println(props);

      if (props.getProperty("DBTYPE") == null) {
        System.out.println("DBTYPE must be provided");
        throw new DBException("DBTYPE must be provided");
      }
      System.out.println("DBTYPE: " + props.getProperty("DBTYPE"));

      if (props.getProperty("DBURI") == null) {
        System.out.println("DBURI must be provided");
        throw new DBException("DBURI must be provided");
      }
      System.out.println("DBURI: " + props.getProperty("DBURI"));

      URI uri = new URI(props.getProperty("DBURI"));

      System.out.println("Connecting to ArangoDB database with params: " + uri.getHost() + ":" + uri.getPort());
      ArangoDB arangodb = new ArangoDB.Builder()
          .host(uri.getHost(), uri.getPort())
          .build();
      System.out.println("ArangoDB client initialized successfully");
      this.db = arangodb.db("ycsb");
      if (!db.exists()) {
        arangodb.createDatabase("ycsb");
        this.db = arangodb.db("ycsb");
//        int replicationFactor = props.getProperty("REPLICATION_FACTOR") != null ? Integer.parseInt(props.getProperty("REPLICATION_FACTOR")) : 1;
        // Set collection options
//        CollectionPropertiesOptions options = new CollectionPropertiesOptions()
//            .replicationFactor(ReplicationFactor.of(replicationFactor))  // replication factor of 3
//            .writeConcern(replicationFactor);      // optional, how many copies must be written
//
////        db.createCollection("vertices", options);
////        db.createCollection("edges", options);
//
//
//        db.collection("vertices").changeProperties(options);
//        db.collection("edges").changeProperties(options);

      }
      System.out.println("Connected to ArangoDB database successfully");

    }catch (Exception e){
      System.out.println("Failed to initialize ArangoDB client: " + e.getMessage());
      throw new DBException(e);
    }
  }

  @Override
  public Status addVertex(String label, String id, Map<String, String> properties) {
    int status = 0;
    try {
      Map<String, String> vertex = new HashMap<>();

      vertex.put("_key", id);
      vertex.putAll(properties);
      DocumentCreateEntity<Void> result = db.collection("vertices").insertDocument(vertex);
//      System.out.println("Inserted vertex with id: " + result.getKey());
      return Status.OK;
    } catch (Exception e) {
      System.out.println("Exception in addVertex: " + e.getMessage());
      return Status.ERROR;
    }
  }
  @Override
  public Status addEdge(String label, String id, String from, String to, Map<String, String> properties) {
    int status = 0;
    try {
      Map<String, String> edge = new HashMap<>();
      edge.put("_key", id);
      edge.put("_from", "vertices/" + from);
      edge.put("_to", "vertices/" + to);
      edge.putAll(properties);
      db.collection("edges").insertDocument(edge);
      return Status.OK;
    } catch (Exception e) {
      return Status.ERROR;
    }

  }
  @Override
  public Status getVertexCount() {
    try {
      db.collection("vertices").count();
      return Status.OK;
    } catch (Exception e) {
      System.out.println("Exception in getVertexCount: " + e.getMessage());
      return Status.ERROR;
    }
  }

  @Override
  public Status getEdgeCount() {
    try {
      db.collection("edges").count();
      return Status.OK;
    } catch (Exception e) {
      System.out.println("Exception in getEdgeCount: " + e.getMessage());
      return Status.ERROR;
    }
  }

  @Override
  public Status getEdgeLabels() {
    try{
      db.query("FOR e IN edges COLLECT label = e._key RETURN label", String.class).asListRemaining();
      return Status.OK;
    } catch (Exception e) {
      System.out.println("Exception in getEdgeLabels: " + e.getMessage());
      return Status.ERROR;
    }
  }

  @Override
  public Status getVertexWithProperty(String key, String value) {
    try{
      String query = "FOR v IN vertices FILTER v."+key+" ==\" "+ value +"\" RETURN v";
      ArangoCursor<String> cursor = db.query(query, String.class);
      return Status.OK;
    } catch (Exception e) {
      System.out.println("Exception in getVertexWithProperty: " + e.getMessage());
      return Status.ERROR;
    }
  }

  @Override
  public Status getEdgeWithProperty(String key, String value) {
    try {
      String query = "FOR e IN edges FILTER e."+key+" ==\" "+ value +"\" RETURN e";
//      System.out.println(query);
      ArangoCursor<String> cursor = db.query(query, String.class);

//      System.out.println("Query executed: " + cursor.asListRemaining());
      return Status.OK;
    } catch (Exception e) {
      System.out.println("Exception in getEdgeWithProperty: " + e.getMessage());
      return Status.ERROR;
    }
  }

  @Override
  public Status getEdgesWithLabel(String label) {
    try {
      String query = "FOR e IN edges FILTER e.label == [\"YCSBEdge\"] RETURN e";

      ArangoCursor<String> cursor = db.query(query, String.class);

//      System.out.println("Query executed: " + cursor.asListRemaining());
      return Status.OK;
    } catch (Exception e) {
      System.out.println("Exception in getEdgesWithLabel: " + e.getMessage());
      return Status.ERROR;
    }
  }

  @Override
  public Status setVertexProperty(String id, String key, String value) {
    try{
      Map vertex = db.collection("vertices").getDocument(id, Map.class);
      vertex.put(key, value);
      DocumentUpdateEntity<Void> result = db.collection("vertices").updateDocument(id, vertex);
//      System.out.println("Updatinted vertex with id: " + result.getNew());
      return Status.OK;
    } catch (Exception e){
      System.out.println("Exception in setVertexProperty: " + e.getMessage());
      return Status.ERROR;
    }
  }

  @Override
  public Status setEdgeProperty(String id, String key, String value) {
    try {
//      System.out.println("Setting edge property for id: " + id + ", key: " + key + ", value: " + value);
      Map edge = db.collection("edges").getDocument(id, Map.class);
      edge.put(key, value);
      DocumentUpdateEntity<Void> result = db.collection("edges").updateDocument(id, edge);
//      System.out.println("Updated edge with id: " + result.getNew());
        return Status.OK;
    } catch (Exception e) {
      System.out.println("Exception in setEdgeProperty: " + e.getMessage());
      return Status.ERROR;
    }
  }

  @Override
  public Status removeVertex(String id) {
    int status = 0;
    try {

      db.collection("vertices").deleteDocument(id);
        return Status.OK;

    } catch (Exception e) {
      return Status.ERROR;
    }
  }

  @Override
  public Status removeEdge(String id) {
    int status = 0;
    try {
      db.collection("edges").deleteDocument(id);
        return Status.OK;
    } catch (Exception e) {
      return Status.ERROR;
    }
  }

  @Override
  public Status removeVertexProperty(String id, String key) {
    try{
      Map vertex = db.collection("vertices").getDocument(id, Map.class);
      if(vertex==null){
        return Status.OK;
      }
      vertex.remove(key);
      db.collection("vertices").updateDocument(id, vertex);
     return Status.OK;
  }catch (Exception e){
      return Status.ERROR;
    }
  }

  @Override
  public Status removeEdgeProperty(String id, String key) {
    try{
      Map edge = db.collection("edges").getDocument(id, Map.class);
      if(edge==null){
        return Status.OK;
      }
      edge.remove(key);
      db.collection("edges").updateDocument(id, edge);
      return Status.OK;
    }catch (Exception e){
      e.printStackTrace();
      return Status.ERROR;
    }
  }



}