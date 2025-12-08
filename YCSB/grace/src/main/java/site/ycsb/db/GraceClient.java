package site.ycsb.db;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import site.ycsb.DB;
import site.ycsb.DBException;
import site.ycsb.Status;
import site.ycsb.db.DatabaseDrivers.DatabaseClient;
import site.ycsb.db.DatabaseDrivers.DatabaseClientFactory;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.*;

public class GraceClient extends DB {

  private static HttpClient httpClient;
  private static Properties props = new Properties();
  private final Logger log = LoggerFactory.getLogger(getClass());
  private DatabaseClient dbDriver;
  private Set<String> Vertices = new HashSet<>();
  private Set<String> Edges = new HashSet<>();

  public GraceClient() {
    System.out.println("GraceClient  Created");
  }

  @Override
  public void init() throws DBException {
    System.out.println("Starting GRACE client");
    props = getProperties();
    System.out.println(props);
    if (props.getProperty("HOSTURI") == null) {
      System.out.println("GRACE HOSTURI must be provided");
      throw new DBException("GRACE HOSTURI must be provided");
    }
    System.out.println("GRACE HOSTURI: " + props.getProperty("HOSTURI"));

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

    dbDriver = DatabaseClientFactory.getDatabaseClient(props.getProperty("DBTYPE"));
    dbDriver.connect(props.getProperty("DBTYPE"), props.getProperty("DBURI"));


    httpClient = HttpClient.newBuilder()
        .version(HttpClient.Version.HTTP_1_1)
        .followRedirects(HttpClient.Redirect.NORMAL)
        .connectTimeout(Duration.ofSeconds(5))
        .build();

  }

  @Override
  public Status addVertex(String label, String id, Map<String, String> properties) {
//    System.out.println("Add Vertex");
//    return Status.OK;
    int status = 0;
    try {
      String vertexProperties = "";
      for (Map.Entry<String, String> entry : properties.entrySet()) {
        vertexProperties += "\""+entry.getKey()+"\":\""+ entry.getValue() +"\",";
      }

      String reqBody = " { \"label\": [\"YCSBVertex\"], \"properties\": {"+vertexProperties+"\"id\":\""+id+"\"}}";
      String targetString = props.getProperty("HOSTURI") + "/api/addVertex";
//      System.out.println(targetString);
//      System.out.println(reqBody);
      URI target = new URI(targetString);
      HttpRequest request = HttpRequest.newBuilder()
          .uri(target)
          .POST(HttpRequest.BodyPublishers.ofString(reqBody))
          .header("Content-Type", "application/json")
          .build();
      HttpResponse<?> response = httpClient.send(request, HttpResponse.BodyHandlers.discarding());
//      System.out.println(response.statusCode());
      status += response.statusCode();
      return Status.OK;
    } catch (Exception e) {
      return Status.ERROR;
    }
  }
  @Override
  public Status addEdge(String label, String id, String from, String to, Map<String, String> properties) {
    int status = 0;
    try {
      String edgeProperties = "";
      for (Map.Entry<String, String> entry : properties.entrySet()) {
        edgeProperties += "\""+entry.getKey()+"\":\""+entry.getValue().toString()+"\",";
      }

      String reqBody = " { \"sourcePropName\": \"id\"" +
                            ",\"sourcePropValue\":\"" + from +"\""+
                            ",\"targetPropName\": \"id\"" +
                            ",\"targetPropValue\":\"" + to +"\""+
                            ",\"relationType\": [\"YCSBEdge\"]" +
                            ",\"properties\": {"+edgeProperties+"\"id\":\""+id+"\"}}";
      String targetString = props.getProperty("HOSTURI") + "/api/addEdge";
//      System.out.println(targetString);
//      System.out.println(reqBody);
      URI target = new URI(targetString);
      HttpRequest request = HttpRequest.newBuilder()
          .uri(target)
          .POST(HttpRequest.BodyPublishers.ofString(reqBody))
          .header("Content-Type", "application/json")
          .build();
      HttpResponse<?> response = httpClient.send(request, HttpResponse.BodyHandlers.discarding());
//      System.out.println(response.statusCode());
      status += response.statusCode();
      return Status.OK;
    } catch (Exception e) {
      return Status.ERROR;
    }

  }

  @Override
  public Status getVertexCount() {
//    System.out.println("Get Vertex Count");
    boolean result = dbDriver.getVertexCount();
//    boolean result = dbDriver.executeQuery("MATCH (n) RETURN count(n)");
    if(!result){
      return Status.ERROR;
    }
    return Status.OK;
  }

  @Override
  public Status getEdgeCount() {
//    System.out.println("Get Edge Count");
    boolean result = dbDriver.getEdgeCount();
//    boolean result = dbDriver.executeQuery("MATCH ()-[r]->() RETURN count(r)");
    if(!result){
      return Status.ERROR;
    }
    return Status.OK;
  }

  @Override
  public Status getEdgeLabels() {
  boolean result = dbDriver.getEdgeLabels();
    if(!result){
      return Status.ERROR;
    }
    return Status.OK;
  }

  @Override
  public Status getVertexWithProperty(String key, String value) {
    boolean result = dbDriver.getVertexWithProperty(key, value.toString());

    //    boolean result = dbDriver.executeQuery("MATCH (n {"+key+": '"+value.toString()+"'}) RETURN n");
    if(!result) {
      return Status.ERROR;
    }
    return Status.OK;
  }

  @Override
  public Status getEdgeWithProperty(String key, String value) {
    boolean result = dbDriver.getEdgeWithProperty(key, value.toString());
//    boolean result = dbDriver.executeQuery("MATCH ()-[r {"+key+": '"+value.toString()+"'}]->() RETURN r");
    if(!result) {
      return Status.ERROR;
    }
    return Status.OK;
  }

  @Override
  public Status getEdgesWithLabel(String label) {
    boolean result = dbDriver.getEdgesWithLabel(label);
//    boolean result = dbDriver.executeQuery("MATCH ()-[r:"+label+"]->() RETURN r");
    if(!result) {
      return Status.ERROR;
    }
    return Status.OK;
  }

  @Override
  public Status setVertexProperty(String id, String key, String value) {
    try{
      String reqBody = " { \"id\": \""+id+"\", \"key\": \""+key+"\", \"value\": \""+value.toString()+"\"}";
      String targetString = props.getProperty("HOSTURI") + "/api/setVertexProperty";
//      System.out.println(targetString);
//      System.out.println(reqBody);
      URI target = new URI(targetString);
      HttpRequest request = HttpRequest.newBuilder()
          .uri(target)
          .POST(HttpRequest.BodyPublishers.ofString(reqBody))
          .header("Content-Type", "application/json")
          .build();
      HttpResponse<?> response = httpClient.send(request, HttpResponse.BodyHandlers.discarding());
      return Status.OK;
    } catch (Exception e){
      return Status.ERROR;
    }
  }

  @Override
  public Status setEdgeProperty(String id, String key, String value) {
    try {
      String reqBody = " { \"id\": \"" + id + "\", \"key\": \"" + key + "\", \"value\": \"" + value.toString() + "\"}";
      String targetString = props.getProperty("HOSTURI") + "/api/setEdgeProperty";
//      System.out.println(targetString);
//      System.out.println(reqBody);
      URI target = new URI(targetString);
      HttpRequest request = HttpRequest.newBuilder()
          .uri(target)
          .POST(HttpRequest.BodyPublishers.ofString(reqBody))
          .header("Content-Type", "application/json")
          .build();
      HttpResponse<?> response = httpClient.send(request, HttpResponse.BodyHandlers.discarding());
        return Status.OK;
    } catch (Exception e) {
      return Status.ERROR;
    }
  }

  @Override
  public Status removeVertex(String id) {
    int status = 0;
    try {

      String reqBody = "{\"id\":\""+id+"\"}";
      String targetString = props.getProperty("HOSTURI") + "/api/deleteVertex";
//      System.out.println(targetString);
//      System.out.println(reqBody);
      URI target = new URI(targetString);
      HttpRequest request = HttpRequest.newBuilder()
          .uri(target)
          .POST(HttpRequest.BodyPublishers.ofString(reqBody))
          .header("Content-Type", "application/json")
          .build();
      HttpResponse<?> response = httpClient.send(request, HttpResponse.BodyHandlers.discarding());
//      System.out.println(response.statusCode());
      status += response.statusCode();
        return Status.OK;

    } catch (Exception e) {
      return Status.ERROR;
    }
  }

  @Override
  public Status removeEdge(String id) {
    int status = 0;
    try {
      String reqBody = "{\"id\":\""+id+"\"}";
      String targetString = props.getProperty("HOSTURI") + "/api/deleteEdge";
//      System.out.println(targetString);
//      System.out.println(reqBody);
      URI target = new URI(targetString);
      HttpRequest request = HttpRequest.newBuilder()
          .uri(target)
          .POST(HttpRequest.BodyPublishers.ofString(reqBody))
          .header("Content-Type", "application/json")
          .build();
      HttpResponse<?> response = httpClient.send(request, HttpResponse.BodyHandlers.discarding());
//      System.out.println(response);
      status += response.statusCode();
        return Status.OK;
    } catch (Exception e) {
      return Status.ERROR;
    }
  }

  @Override
  public Status removeVertexProperty(String id, String key) {
    try{
      String reqBody = " { \"id\": \""+id+"\", \"key\": \""+key+"\"}";
      String targetString = props.getProperty("HOSTURI") + "/api/removeVertexProperty";
//      System.out.println(targetString);
//      System.out.println(reqBody);
      URI target = new URI(targetString);
      HttpRequest request = HttpRequest.newBuilder()
          .uri(target)
          .POST(HttpRequest.BodyPublishers.ofString(reqBody))
          .header("Content-Type", "application/json")
          .build();
      HttpResponse<?> response = httpClient.send(request, HttpResponse.BodyHandlers.discarding());
     return Status.OK;
  }catch (Exception e){
      return Status.ERROR;
    }
  }

  @Override
  public Status removeEdgeProperty(String id, String key) {
    try{
      String reqBody = " { \"id\": \""+id+"\", \"key\": \""+key+"\"}";
      String targetString = props.getProperty("HOSTURI") + "/api/removeEdgeProperty";
//      System.out.println(targetString);
//      System.out.println(reqBody);
      URI target = new URI(targetString);
      HttpRequest request = HttpRequest.newBuilder()
          .uri(target)
          .POST(HttpRequest.BodyPublishers.ofString(reqBody))
          .header("Content-Type", "application/json")
          .build();
      HttpResponse<?> response = httpClient.send(request, HttpResponse.BodyHandlers.discarding());
//      System.out.println(response);
      return Status.OK;
    }catch (Exception e){
      return Status.ERROR;
    }
  }


//
//  @Override
//  public Status read(String table, String key, Set<String> fields, Map<String, String> result) {
//    return Status.OK;
//  }
//
//  @Override
//  public Status scan(String table, String startkey, int recordcount, Set<String> fields, Vector<HashMap<String, String>> result) {
//    try {
//      String reqBody = " { \"limit\": \"23\"}";
//      String targetString = props.getProperty("HOSTURI") + "/api/getGraph";
////      System.out.println(targetString);
//      URI target = new URI(targetString);
//      HttpRequest request = HttpRequest.newBuilder()
//          .uri(target)
//          .GET()
//          .header("Content-Type", "application/json")
//          .build();
//      HttpResponse<?> response = httpClient.send(request, HttpResponse.BodyHandlers.discarding());
//      if(response.statusCode() == 200 || response.statusCode() == 201){
//        return Status.OK;
//      } else{
//        return Status.ERROR;
//      }
//    } catch (Exception e){
////      System.out.println(e.getMessage());
//      return Status.ERROR;
//    }
//  }
//
//  // CAUTION. WE need a delete API for the database we are testing. YCSB by default does not execute deletes.
//  // The delete operation is implemented as an update, which is sent to the database.
//  @Override
//  public Status update(String table, String key, Map<String, String> values) {
//    if (!(Vertices.isEmpty())) {
//      int size = Vertices.size();
//      int item = new Random().nextInt(size); // In real life, the Random object should be rather more shared than this
//      int i = 0;
//      String deleteVertex = "";
//      for (String vert : Vertices) {
//        if (i == item) {
//          deleteVertex = vert;
//          break;
//        }
//        i++;
//      }
//      if(Objects.equals(deleteVertex, "")){
//        return Status.ERROR;
//      }
//
//      try {
//        String reqBody = " { \"label\": \"ProductItem\", \"properties\": {\"identifier\":\"" + deleteVertex + "\"}}";
//        String targetString = props.getProperty("HOSTURI") + "/api/deleteVertex";
////        System.out.println(targetString);
//        URI target = new URI(targetString);
//        HttpRequest request = HttpRequest.newBuilder()
//            .uri(target)
//            .POST(HttpRequest.BodyPublishers.ofString(reqBody))
//            .header("Content-Type", "application/json")
//            .build();
//        HttpResponse<?> response = httpClient.send(request, HttpResponse.BodyHandlers.discarding());
//        if(response.statusCode()==200 || response.statusCode()==201){
//          Vertices.remove(deleteVertex);
//          return Status.OK;
//
//        } else {
//          return Status.ERROR;
//        }
//      } catch (Exception e) {
////        System.out.println(e.getMessage());
//        return Status.ERROR;
//      }
//    }
//    return Status.OK;
//  }
//
//  @Override
//  public Status insert(String table, String key, Map<String, String> values) {
//    int status = 0;
//    try {
//      String edge = reader.readLine();
//      String[] vertices = edge.split(" ");
//      for (String vertex : vertices) {
////        System.out.println("Insert "+vertex);
//        if (!Vertices.contains(vertex)) {
//          String reqBody = " { \"label\": \"ProductItem\", \"properties\": {\"identifier\":\"" + vertex + "\",\"name\": \"Vertex" + vertex + "\" }}";
//          String targetString= props.getProperty("HOSTURI") + "/api/addVertex";
////          System.out.println(targetString);
//          URI target = new URI(targetString);
//          HttpRequest request = HttpRequest.newBuilder()
//              .uri(target)
//              .POST(HttpRequest.BodyPublishers.ofString(reqBody))
//              .header("Content-Type", "application/json")
//              .build();
//          HttpResponse<?> response = httpClient.send(request, HttpResponse.BodyHandlers.discarding());
//          status+= response.statusCode();
//        }
//      }
//
//      // We receive responses for two requests. The success codes are 200 and 201. The sum of these should be less than 500 always.
//      // If either request is 500, this sum would be greater than 500 at least. so, we do not execute the edge add.
//      if(status<500) {
//        Vertices.add(vertices[0]);
//        Vertices.add(vertices[1]);
//        String reqBody = " { \"sourceLabel\": \"ProductItem\"" +
//                            ",\"sourcePropName\": \"identifier\"" +
//                            ",\"sourcePropValue\":\"" + vertices[0] +"\""+
//                            ",\"targetLabel\": \"ProductItem\"" +
//                            ",\"targetPropName\": \"identifier\"" +
//                            ",\"targetPropValue\":\"" + vertices[1] +"\""+
//                            ",\"relationType\": \"SAME_CATEGORY\"" +
//                            ",\"properties\": {\"identifier\":\"" + vertices[0]+"-"+vertices[1]  + "\",\"relation\": [\"recommendation\"] } }";
//        String targetString= props.getProperty("HOSTURI") + "/api/addEdge";
////        System.out.println(targetString);
//        URI target = new URI(targetString);
//
//        HttpRequest request = HttpRequest.newBuilder()
//            .uri(target)
//            .POST(HttpRequest.BodyPublishers.ofString(reqBody))
//            .header("Content-Type", "application/json")
//            .build();
//
//        HttpResponse<?> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
////        System.out.println(response.statusCode());
////        System.out.println(response.body().toString());
//        if(response.statusCode()==500) {
//          return Status.ERROR;
//        }
//        Edges.add( vertices[0]+"-"+vertices[1]);
//      }
//
//      return Status.OK;
//
//    } catch (IOException e) {
//      return Status.ERROR;
//    } catch (InterruptedException | URISyntaxException e) {
//      throw new RuntimeException(e);
//    }
//  }
//
//  @Override
//  public Status delete(String table, String key) {
//    return Status.OK;
//  }

}