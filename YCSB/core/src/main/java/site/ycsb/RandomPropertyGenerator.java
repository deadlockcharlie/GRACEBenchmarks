package site.ycsb;

import java.util.*;

public class RandomPropertyGenerator {
  private final List<String> pool;
  private final Random random;

  /**
   * Generates a pool of unique random strings of given length.
   * @param poolSize Number of unique strings in the pool
   * @param stringLength Length of each string
   */
  public RandomPropertyGenerator(int poolSize, int stringLength) {
    if (poolSize <= 0 || stringLength <= 0) {
      throw new IllegalArgumentException("Pool size and string length must be positive");
    }

    random = new Random();
    pool = new ArrayList<>(poolSize);
    Set<String> seen = new HashSet<>();

    while (pool.size() < poolSize) {
      String s = randomString(stringLength);
      if (seen.add(s)) {  // ensure uniqueness
        pool.add(s);
      }
    }
  }

  private String randomString(int length) {
    String chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
    StringBuilder sb = new StringBuilder(length);
    for (int i = 0; i < length; i++) {
      sb.append(chars.charAt(random.nextInt(chars.length())));
    }
    return sb.toString();
  }

  /** Returns a random string from the pool */
  public String next() {
    return pool.get(random.nextInt(pool.size()));
  }

  /** Returns the full pool if needed */
  public List<String> getPool() {
    return Collections.unmodifiableList(pool);
  }
}