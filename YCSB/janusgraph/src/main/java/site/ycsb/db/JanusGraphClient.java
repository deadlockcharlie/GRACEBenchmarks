package site.ycsb.db;

import org.apache.tinkerpop.gremlin.driver.Client;
import org.apache.tinkerpop.gremlin.driver.Cluster;
import org.apache.tinkerpop.gremlin.process.remote.RemoteConnection;
import org.apache.tinkerpop.gremlin.process.traversal.AnonymousTraversalSource;
import org.apache.tinkerpop.gremlin.process.traversal.dsl.graph.GraphTraversal;
import org.apache.tinkerpop.gremlin.structure.Edge;
import org.apache.tinkerpop.gremlin.structure.T;
import org.apache.tinkerpop.gremlin.structure.Vertex;
import site.ycsb.DB;

import org.apache.tinkerpop.gremlin.driver.remote.DriverRemoteConnection;
import org.apache.tinkerpop.gremlin.process.traversal.dsl.graph.GraphTraversalSource;
import site.ycsb.DBException;
import site.ycsb.Status;

import java.net.URI;
import java.util.Map;
import java.util.Properties;


public class JanusGraphClient extends DB{
  GraphTraversalSource g;
  private static Properties props = new Properties();

  @Override
  public void init() throws DBException {
    System.out.println("Starting Janusgraph client");
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
      URI uri = new URI(props.getProperty("DBURI"));
      Cluster cluster = Cluster.build()
              .addContactPoint(uri.getHost())
              .port(uri.getPort())
              .create();
      Client client = cluster.connect();
      RemoteConnection connection = DriverRemoteConnection.using(client, "g");

      this.g = AnonymousTraversalSource.traversal().withRemote(connection);
      System.out.println("Connected to Janusgraph successfully");
    } catch (Exception e) {
      System.out.println("Failed to connect to Janusgraph database: " + e.getMessage());
      throw new DBException(e);
    }
  }


  @Override
  public Status addVertex(String label, String id, Map<String, String> properties) {
    int status = 0;
    try {
      GraphTraversal<Vertex, Vertex> t = this.g.addV(label).property(T.id, id);
      for (Map.Entry<String, String> entry : properties.entrySet()) {
        t = t.property(entry.getKey(), entry.getValue().toString());
      }
      t.valueMap().next();

      return Status.OK;
    } catch (Exception e) {
      System.out.println("Exception in addVertex: " + e);
      return Status.ERROR;
    }
  }
  @Override
  public Status addEdge(String label, String id, String from, String to, Map<String, String> properties) {
    int status = 0;
    try {

      GraphTraversal<Vertex, Edge> t = this.g.V().has(T.id, from).as("a").V().has(T.id, to).addE(label).from("a").property("_id", id);
      for (Map.Entry<String, String> entry : properties.entrySet()) {
        t = t.property(entry.getKey(), entry.getValue());
      }
      t.valueMap().next();
//      this.client.submit("g.V().has('i', from).as('a').V().has('i', to).addE(l).from('a').property('i', i)", Map.of("from", from, "to", to, "l", label, T.id, id));
//      for (Map.Entry<String, String> entry : properties.entrySet()) {
//        this.client.submit("g.E().has('i', i).property(k, v)", Map.of(T.id, id, "k", entry.getKey(), "v", entry.getValue().toString()));
//      }
      return Status.OK;
    } catch (Exception e) {
      System.out.println("Exception in addEdge: " + e.getMessage());
      return Status.ERROR;
    }

  }

  @Override
  public Status setVertexProperty(String id, String key, String value) {
    try{
      GraphTraversal<Vertex, Vertex> t = this.g.V().has(T.id, id).property(key, value.toString());
      t.valueMap().iterate();
//      this.client.submit("g.V().has('i', i).property(k, v)", Map.of(T.id, id, "k", key, "v", value.toString()));
      return Status.OK;
    } catch (Exception e){
      System.out.println("Exception in setVertexProperty: " + e.getMessage());
      return Status.ERROR;
    }
  }

  @Override
  public Status setEdgeProperty(String id, String key, String value) {
    try {
      this.g.E().has("_id", id).property(key, value.toString()).valueMap().iterate();
//      this.client.submit("g.E().has('i', i).property(k, v)", Map.of(T.id, id, "k", key, "v", value.toString()));
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
      this.g.V().has(T.id, id).drop().iterate();
//      this.client.submit("g.V().has('i', i).drop()", Map.of(T.id, id));
      return Status.OK;

    } catch (Exception e) {
      System.out.println("Exception in removeVertex: " + e.getMessage());
      return Status.ERROR;
    }
  }

  @Override
  public Status removeEdge(String id) {
    int status = 0;
    try {
      this.g.E().has("_id", id).drop().iterate();
//      this.client.submit("g.E().has('i', i).drop()", Map.of(T.id, id));
      return Status.OK;
    } catch (Exception e) {
      System.out.println("Exception in removeEdge: " + e.getMessage());
      return Status.ERROR;
    }
  }

  @Override
  public Status removeVertexProperty(String id, String key) {
    try{
      this.g.V().has(T.id, id).properties(key).drop().iterate();
//      this.client.submit("g.V().has('i', i).properties(k).drop()", Map.of(T.id, id, "k", key));
      return Status.OK;
    }catch (Exception e){
      System.out.println("Exception in removeVertexProperty: " + e);
      return Status.ERROR;
    }
  }

  @Override
  public Status removeEdgeProperty(String id, String key) {
    try{
      this.g.E().has("_id", id).properties(key).drop().iterate();
//      this.client.submit("g.E().has('i', i).properties(k).drop()", Map.of(T.id, id, "k", key));
      return Status.OK;
    }catch (Exception e){
      System.out.println("Exception in removeEdgeProperty: " + e);
      return Status.ERROR;
    }
  }



  @Override
  public Status getVertexCount() {
    try{
      this.g.V().count().next();
//      this.client.submit("g.V().count()");
      return Status.OK;
    }
    catch (Exception e){
      System.out.println("Exception in getVertexCount: " + e.getMessage());
      return Status.ERROR;
    }
  }

  @Override
  public Status getEdgeCount() {
    try{
      this.g.E().count().next();
//      this.client.submit("g.E().count()");
      return Status.OK;
    }
    catch (Exception e){
      System.out.println("Exception in getEdgeCount: " + e.getMessage());
      return Status.ERROR;
    }
  }

  @Override
  public Status getEdgeLabels() {
    try{
      this.g.E().label().dedup().toList();
//      this.client.submit("g.E().label().dedup()");
      return Status.OK;
    }
    catch (Exception e){
      System.out.println("Exception in getEdgeLabels: " + e.getMessage());
      return Status.ERROR;
    }
  }

  @Override
  public Status getVertexWithProperty(String key, String value) {
    try{
      this.g.V().has(key, value.toString()).valueMap().toList();
//      this.client.submit("g.V().has(k, v)", Map.of("k", key, "v", value.toString()));
      return Status.OK;
    }
    catch (Exception e){
      System.out.println("Exception in getVertexWithProperty: " + e.getMessage());
      return Status.ERROR;
    }
  }

  @Override
  public Status getEdgeWithProperty(String key, String value) {
    try{
      this.g.E().has(key, value.toString()).valueMap().toList();
//      this.client.submit("g.E().has(k, v)", Map.of("k", key, "v", value.toString()));
      return Status.OK;
    }
    catch (Exception e){
      System.out.println("Exception in getEdgeWithProperty: " + e.getMessage());
      return Status.ERROR;
    }
  }

  @Override
  public Status getEdgesWithLabel(String label) {
    try{
      this.g.E().hasLabel(label).valueMap().toList();
//      this.client.submit("g.E().hasLabel(l)", Map.of("l", label));
      return Status.OK;
    }
    catch (Exception e){
      System.out.println("Exception in getEdgesWithLabel: " + e.getMessage());
      return Status.ERROR;
    }
  }
}
