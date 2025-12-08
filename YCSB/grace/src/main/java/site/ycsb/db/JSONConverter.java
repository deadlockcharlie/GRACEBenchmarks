package site.ycsb.db;

import org.apache.htrace.shaded.fasterxml.jackson.databind.ObjectMapper;
import site.ycsb.ByteIterator;

import java.util.HashMap;
import java.util.Map;

public class JSONConverter {
   private static final ObjectMapper mapper = new ObjectMapper();

    public static String toJson(Map<String, ByteIterator> values) {
      Map<String, String> stringMap = new HashMap<>();
      for (Map.Entry<String, ByteIterator> entry : values.entrySet()) {
        // Convert ByteIterator to string
        stringMap.put(entry.getKey(), entry.getValue().toString());
      }

      try {

        return mapper.writeValueAsString(stringMap);
      } catch (Exception e) {
        throw new RuntimeException("Failed to convert to JSON", e);
      }
    }
  }
