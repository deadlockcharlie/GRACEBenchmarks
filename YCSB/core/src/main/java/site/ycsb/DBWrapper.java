/**
 * Copyright (c) 2010 Yahoo! Inc., 2016-2020 YCSB contributors. All rights reserved.
 * <p>
 * Licensed under the Apache License, Version 2.0 (the "License"); you
 * may not use this file except in compliance with the License. You
 * may obtain a copy of the License at
 * <p>
 * http://www.apache.org/licenses/LICENSE-2.0
 * <p>
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
 * implied. See the License for the specific language governing
 * permissions and limitations under the License. See accompanying
 * LICENSE file.
 */

package site.ycsb;

import java.util.Map;

import site.ycsb.measurements.Measurements;
import org.apache.htrace.core.TraceScope;
import org.apache.htrace.core.Tracer;

import java.util.*;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Wrapper around a "real" DB that measures latencies and counts return codes.
 * Also reports latency separately between OK and failed operations.
 */
public class DBWrapper extends DB {
  private final DB db;
  private final Measurements measurements;
  private final Tracer tracer;

  private boolean reportLatencyForEachError = false;
  private Set<String> latencyTrackedErrors = new HashSet<String>();

  private static final String REPORT_LATENCY_FOR_EACH_ERROR_PROPERTY = "reportlatencyforeacherror";
  private static final String REPORT_LATENCY_FOR_EACH_ERROR_PROPERTY_DEFAULT = "false";

  private static final String LATENCY_TRACKED_ERRORS_PROPERTY = "latencytrackederrors";

  private static final AtomicBoolean LOG_REPORT_CONFIG = new AtomicBoolean(false);

  private final String scopeStringCleanup;
  private final String scopeStringInit;

  private final String scopeAddVertex;
  private final String scopeAddEdge;
  private final String scopeGetVertexCount;
  private final String scopeGetEdgeCount;
  private final String scopeGetVertexWithProperty;
  private final String scopeGetEdgeWithProperty;
  private final String scopeGetEdgesWithLabel;
  private final String scopeSetVertexProperty;
  private final String scopeSetEdgeProperty;
  private final String scopeRemoveVertex;
  private final String scopeRemoveEdge;
  private final String scopeRemoveVertexProperty;
  private final String scopeRemoveEdgeProperty;



  public DBWrapper(final DB db, final Tracer tracer) {
    this.db = db;
    measurements = Measurements.getMeasurements();
    this.tracer = tracer;
    final String simple = db.getClass().getSimpleName();
    scopeStringCleanup = simple + "#cleanup";
    scopeStringInit = simple + "#init";
    scopeAddVertex = simple + "#addVertex";
    scopeAddEdge = simple + "#addEdge";
    scopeGetVertexCount = simple + "#getVertexCount";
    scopeGetEdgeCount = simple + "#getEdgeCount";
    scopeGetVertexWithProperty = simple + "#getVertexWithProperty";
    scopeGetEdgeWithProperty = simple + "#getEdgeWithProperty";
    scopeGetEdgesWithLabel = simple + "#getEdgesWithLabel";
    scopeSetVertexProperty = simple + "#setVertexProperty";
    scopeSetEdgeProperty = simple + "#setEdgeProperty";
    scopeRemoveVertex = simple + "#removeVertex";
    scopeRemoveEdge = simple + "#removeEdge";
    scopeRemoveVertexProperty = simple + "#removeVertexProperty";
    scopeRemoveEdgeProperty = simple + "#removeEdgeProperty";

  }

  /**
   * Set the properties for this DB.
   */
  public void setProperties(Properties p) {
    db.setProperties(p);
  }

  /**
   * Get the set of properties for this DB.
   */
  public Properties getProperties() {
    return db.getProperties();
  }

  private void measure(String op, Status result, long intendedStartTimeNanos,
                       long startTimeNanos, long endTimeNanos) {
    String measurementName = op;
    if (result == null || !result.isOk()) {
      if (this.reportLatencyForEachError ||
          this.latencyTrackedErrors.contains(result.getName())) {
        measurementName = op + "-" + result.getName();
      } else {
        measurementName = op + "-FAILED";
      }
    }
    measurements.measure(measurementName,
        (int) ((endTimeNanos - startTimeNanos) / 1000));
    measurements.measureIntended(measurementName,
        (int) ((endTimeNanos - intendedStartTimeNanos) / 1000));
  }
  /**
   * Initialize any state for this DB.
   * Called once per DB instance; there is one DB instance per client thread.
   */
  public void init() throws DBException {
    try (final TraceScope span = tracer.newScope(scopeStringInit)) {
      db.init();

      this.reportLatencyForEachError = Boolean.parseBoolean(getProperties().
          getProperty(REPORT_LATENCY_FOR_EACH_ERROR_PROPERTY,
              REPORT_LATENCY_FOR_EACH_ERROR_PROPERTY_DEFAULT));

      if (!reportLatencyForEachError) {
        String latencyTrackedErrorsProperty = getProperties().getProperty(LATENCY_TRACKED_ERRORS_PROPERTY, null);
        if (latencyTrackedErrorsProperty != null) {
          this.latencyTrackedErrors = new HashSet<String>(Arrays.asList(
              latencyTrackedErrorsProperty.split(",")));
        }
      }

      if (LOG_REPORT_CONFIG.compareAndSet(false, true)) {
        System.err.println("DBWrapper: report latency for each error is " +
            this.reportLatencyForEachError + " and specific error codes to track" +
            " for latency are: " + this.latencyTrackedErrors.toString());
      }
    }
  }

  /**
   * Cleanup any state for this DB.
   * Called once per DB instance; there is one DB instance per client thread.
   */
  public void cleanup() throws DBException {
    try (final TraceScope span = tracer.newScope(scopeStringCleanup)) {
      long ist = measurements.getIntendedStartTimeNs();
      long st = System.nanoTime();
      db.cleanup();
      long en = System.nanoTime();
      measure("CLEANUP", Status.OK, ist, st, en);
    }
  }


    public Status addVertex(String table, String vertexId, Map<String, String> properties) {
      try (final TraceScope span = tracer.newScope(scopeAddVertex)) {
        long ist = measurements.getIntendedStartTimeNs();
        long st = System.nanoTime();
        Status res = db.addVertex(table, vertexId, properties);
        long en = System.nanoTime();
        measure("ADD_VERTEX", res, ist, st, en);
        measurements.reportStatus("ADD_VERTEX", res);
        return res;
      }
    }
    public Status addEdge(String table, String fromVertexId, String toVertexId, String label, Map<String, String> properties) {
      try (final TraceScope span = tracer.newScope(scopeAddEdge)) {
        long ist = measurements.getIntendedStartTimeNs();
        long st = System.nanoTime();
        Status res = db.addEdge(table, fromVertexId, toVertexId, label, properties);
        long en = System.nanoTime();
        measure("ADD_EDGE", res, ist, st, en);
        measurements.reportStatus("ADD_EDGE", res);
        return res;
      }
    }
    public Status getVertexCount() {
      try (final TraceScope span = tracer.newScope(scopeGetVertexCount)) {
        long ist = measurements.getIntendedStartTimeNs();
        long st = System.nanoTime();
        Status res = db.getVertexCount();
        long en = System.nanoTime();
        measure("GET_VERTEX_COUNT", res, ist, st, en);
        measurements.reportStatus("GET_VERTEX_COUNT", res);
        return res;
      }
    }

    public Status getEdgeCount() {
      try (final TraceScope span = tracer.newScope(scopeGetEdgeCount)) {
        long ist = measurements.getIntendedStartTimeNs();
        long st = System.nanoTime();
        Status res = db.getEdgeCount();
        long en = System.nanoTime();
        measure("GET_EDGE_COUNT", res, ist, st, en);
        measurements.reportStatus("GET_EDGE_COUNT", res);
        return res;
      }
    }

    public Status getEdgeLabels() {
      try (final TraceScope span = tracer.newScope(scopeGetEdgesWithLabel)) {
        long ist = measurements.getIntendedStartTimeNs();
        long st = System.nanoTime();
        Status res = db.getEdgeLabels();
        long en = System.nanoTime();
        measure("GET_EDGE_LABELS", res, ist, st, en);
        measurements.reportStatus("GET_EDGE_LABELS", res);
        return res;
      }
    }

    public Status getVertexWithProperty(String key, String value) {
      try (final TraceScope span = tracer.newScope(scopeGetVertexWithProperty)) {
        long ist = measurements.getIntendedStartTimeNs();
        long st = System.nanoTime();
        Status res = db.getVertexWithProperty(key, value);
        long en = System.nanoTime();
        measure("GET_VERTEX_WITH_PROPERTY", res, ist, st, en);
        measurements.reportStatus("GET_VERTEX_WITH_PROPERTY", res);
        return res;
      }
    }
    public Status getEdgeWithProperty(String key, String value) {
      try (final TraceScope span = tracer.newScope(scopeGetEdgeWithProperty)) {
        long ist = measurements.getIntendedStartTimeNs();
        long st = System.nanoTime();
        Status res = db.getEdgeWithProperty(key, value);
        long en = System.nanoTime();
        measure("GET_EDGE_WITH_PROPERTY", res, ist, st, en);
        measurements.reportStatus("GET_EDGE_WITH_PROPERTY", res);
        return res;
      }
    }
    public Status getEdgesWithLabel(String label) {
      try (final TraceScope span = tracer.newScope(scopeGetEdgesWithLabel)) {
        long ist = measurements.getIntendedStartTimeNs();
        long st = System.nanoTime();
        Status res = db.getEdgesWithLabel(label);
        long en = System.nanoTime();
        measure("GET_EDGES_WITH_LABEL", res, ist, st, en);
        measurements.reportStatus("GET_EDGES_WITH_LABEL", res);
        return res;
      }
    }

    public Status setVertexProperty(String vertexId, String key, String value) {
      try (final TraceScope span = tracer.newScope(scopeSetVertexProperty)) {
        long ist = measurements.getIntendedStartTimeNs();
        long st = System.nanoTime();
        Status res = db.setVertexProperty(vertexId, key, value);
        long en = System.nanoTime();
        measure("SET_VERTEX_PROPERTY", res, ist, st, en);
        measurements.reportStatus("SET_VERTEX_PROPERTY", res);
        return res;
      }
    }
    public Status setEdgeProperty(String edgeId, String key, String value) {
      try (final TraceScope span = tracer.newScope(scopeSetEdgeProperty)) {
        long ist = measurements.getIntendedStartTimeNs();
        long st = System.nanoTime();
        Status res = db.setEdgeProperty(edgeId, key, value);
        long en = System.nanoTime();
        measure("SET_EDGE_PROPERTY", res, ist, st, en);
        measurements.reportStatus("SET_EDGE_PROPERTY", res);
        return res;
      }

    }

    public Status removeVertex(String vertexId) {
      try (final TraceScope span = tracer.newScope(scopeRemoveVertex)) {
        long ist = measurements.getIntendedStartTimeNs();
        long st = System.nanoTime();
        Status res = db.removeVertex(vertexId);
        long en = System.nanoTime();
        measure("REMOVE_VERTEX", res, ist, st, en);
        measurements.reportStatus("REMOVE_VERTEX", res);
        return res;
      }
    }
    public Status removeEdge(String edgeId) {
      try (final TraceScope span = tracer.newScope(scopeRemoveEdge)) {
        long ist = measurements.getIntendedStartTimeNs();
        long st = System.nanoTime();
        Status res = db.removeEdge(edgeId);
        long en = System.nanoTime();
        measure("REMOVE_EDGE", res, ist, st, en);
        measurements.reportStatus("REMOVE_EDGE", res);
        return res;
      }
    }

    public Status removeVertexProperty(String vertexId, String key) {
      try (final TraceScope span = tracer.newScope(scopeRemoveVertexProperty)) {
        long ist = measurements.getIntendedStartTimeNs();
        long st = System.nanoTime();
        Status res = db.removeVertexProperty(vertexId, key);
        long en = System.nanoTime();
        measure("REMOVE_VERTEX_PROPERTY", res, ist, st, en);
        measurements.reportStatus("REMOVE_VERTEX_PROPERTY", res);
        return res;
      }
    }
    public Status removeEdgeProperty(String edgeId, String key) {
      try (final TraceScope span = tracer.newScope(scopeRemoveEdgeProperty)) {
        long ist = measurements.getIntendedStartTimeNs();
        long st = System.nanoTime();
        Status res = db.removeEdgeProperty(edgeId, key);
        long en = System.nanoTime();
        measure("REMOVE_EDGE_PROPERTY", res, ist, st, en);
        measurements.reportStatus("REMOVE_EDGE_PROPERTY", res);
        return res;
      }
    }
}
