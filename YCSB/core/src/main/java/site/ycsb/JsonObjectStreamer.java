package site.ycsb;

import org.apache.htrace.shaded.fasterxml.jackson.core.JsonFactory;
import org.apache.htrace.shaded.fasterxml.jackson.core.JsonParser;
import org.apache.htrace.shaded.fasterxml.jackson.core.JsonToken;

import java.io.File;
import java.io.IOException;
import java.util.HashMap;
import java.util.Map;

public class JsonObjectStreamer {
  private final JsonParser parser;
  private final JsonFactory factory;

  public JsonObjectStreamer(String filename) throws IOException {
    factory = new JsonFactory();
    parser = factory.createParser(new File(filename));
    if (parser.nextToken() != JsonToken.START_ARRAY) {
      throw new IOException("Expected JSON array");
    }
  }

  public Map<String, String> nextObject() throws IOException {
    if (parser.nextToken() != JsonToken.START_OBJECT) {
      return null; // end of array
    }

    Map<String, String> properties = new HashMap<>();
    while (parser.nextToken() != JsonToken.END_OBJECT) {
      String fieldName = parser.getCurrentName();
      parser.nextToken();
      String value = parser.getValueAsString();
      properties.put(fieldName, value);
    }
    return properties;
  }

  public void close() throws IOException {
    parser.close();
  }
}