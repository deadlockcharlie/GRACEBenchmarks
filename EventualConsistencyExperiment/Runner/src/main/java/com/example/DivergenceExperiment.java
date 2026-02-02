package com.example;

import org.apache.tinkerpop.gremlin.driver.Client;
import org.apache.tinkerpop.gremlin.driver.Cluster;
import org.apache.tinkerpop.gremlin.process.remote.RemoteConnection;
import org.apache.tinkerpop.gremlin.process.traversal.AnonymousTraversalSource;
import org.apache.tinkerpop.gremlin.process.traversal.dsl.graph.GraphTraversal;
import org.apache.tinkerpop.gremlin.structure.Edge;
import org.apache.tinkerpop.gremlin.structure.T;
import org.apache.tinkerpop.gremlin.structure.Vertex;

import org.apache.tinkerpop.gremlin.driver.remote.DriverRemoteConnection;
import org.apache.tinkerpop.gremlin.process.traversal.dsl.graph.GraphTraversalSource;



import org.neo4j.driver.Driver;
import org.neo4j.driver.GraphDatabase;
import org.neo4j.driver.Session;

import java.util.*;
import java.util.concurrent.*;
import java.time.Instant;
import java.time.Duration;
import java.io.*;
import java.net.URI;
import java.text.SimpleDateFormat;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;

public class DivergenceExperiment {


    // ------------------------------
    // Configuration Class
    // ------------------------------
    static class ExperimentConfig {
        String replica1Host;
        int replica1Port;
        String replica2Host;
        int replica2Port;

        int numVertices;
        int numWaves;
        int updatesPerWave;
        double conflictRate;
        long delayBetweenUpdates;
        long reconciliationWaitMs;
        
        int sampleSize;
        boolean enableDetailedLogging;
        boolean resetDatabaseBeforeRun;
        String outputDir;
        String database;
        
        ExperimentConfig() {
            // Defaults
            replica1Host = "localhost";
            replica1Port = 8182;
            replica2Host = "localhost";
            replica2Port = 8183;
            
            numVertices = 100;
            numWaves = 5;
            updatesPerWave = 50;
            conflictRate = 0.8;
            delayBetweenUpdates = 10;
            reconciliationWaitMs = 3000;
            
            sampleSize = 50;
            enableDetailedLogging = true;
            resetDatabaseBeforeRun = true;
            outputDir = "experiment_results";

            database = "janusgraph";
        }
        
        void printConfig() {
            System.out.println("\n=== EXPERIMENT CONFIGURATION ===");
            System.out.println("Database type: " + database);
            System.out.println("Replica 1: " + replica1Host + ":" + replica1Port);
            System.out.println("Replica 2: " + replica2Host + ":" + replica2Port);
            System.out.println("Number of vertices: " + numVertices);
            System.out.println("Number of waves: " + numWaves);
            System.out.println("Updates per wave (per replica): " + updatesPerWave);
            System.out.println("Conflict rate: " + (conflictRate * 100) + "%");
            System.out.println("Delay between updates: " + delayBetweenUpdates + "ms");
            System.out.println("Reconciliation wait between waves: " + reconciliationWaitMs + "ms");
            System.out.println("Sample size for divergence check: " + sampleSize);
            System.out.println("Detailed logging: " + enableDetailedLogging);
            System.out.println("Reset database before run: " + resetDatabaseBeforeRun);
            System.out.println("Output directory: " + outputDir);
            System.out.println("================================\n");
        }
    }

    // ------------------------------
    // Wave Metrics Tracker
    // ------------------------------
    static class WaveMetrics {
        int waveNumber;
        long startTime;
        long endTime;
        int updatesR1;
        int updatesR2;
        int errorsR1;
        int errorsR2;
        List<Long> latenciesR1 = new ArrayList<>();
        List<Long> latenciesR2 = new ArrayList<>();
        
        WaveMetrics(int waveNumber) {
            this.waveNumber = waveNumber;
        }
        
        void start() {
            startTime = System.currentTimeMillis();
        }
        
        void stop() {
            endTime = System.currentTimeMillis();
        }
        
        long getDuration() {
            return endTime - startTime;
        }
        
        double getAvgLatencyR1() {
            if (latenciesR1.isEmpty()) return 0;
            return latenciesR1.stream().mapToLong(Long::longValue).average().orElse(0.0);
        }
        
        double getAvgLatencyR2() {
            if (latenciesR2.isEmpty()) return 0;
            return latenciesR2.stream().mapToLong(Long::longValue).average().orElse(0.0);
        }
    }

    // ------------------------------
    // Divergence Snapshot
    // ------------------------------
    static class DivergenceSnapshot {
        int waveNumber;
        long timestamp;
        int sampleSize;
        int differentCount;
        int nullCount;
        int sameCount;
        double divergenceRate;
        List<String> divergentVertices = new ArrayList<>();
        Map<String, VertexComparison> comparisons = new HashMap<>();
        
        DivergenceSnapshot(int waveNumber) {
            this.waveNumber = waveNumber;
            this.timestamp = System.currentTimeMillis();
        }
        
        void calculate() {
            divergenceRate = (differentCount * 100.0) / sampleSize;
        }
        
        void printSummary() {
            System.out.println("  Sample size: " + sampleSize);
            System.out.println("  Same: " + sameCount + " (" + 
                String.format("%.1f%%", (sameCount * 100.0) / sampleSize) + ")");
            System.out.println("  Different: " + differentCount + " (" + 
                String.format("%.1f%%", (differentCount * 100.0) / sampleSize) + ")");
            System.out.println("  Null/Missing: " + nullCount);
            System.out.println("  Divergence rate: " + String.format("%.2f%%", divergenceRate));
        }
        
        String toCSV() {
            return String.format("%d,%d,%d,%d,%d,%.2f", 
                waveNumber, sampleSize, sameCount, differentCount, nullCount, divergenceRate);
        }
    }
    
    static class VertexComparison {
        String vertexId;
        Map<String, Object> replica1Data;
        Map<String, Object> replica2Data;
        boolean isDifferent;
        String difference;
        
        VertexComparison(String vertexId, Map<String, Object> r1, Map<String, Object> r2) {
            // System.out.println("Debug condition2" + r1);
            this.vertexId = vertexId;
            this.replica1Data = r1;
            this.replica2Data = r2;
            this.isDifferent = calculateDifference();
        }
        
        boolean calculateDifference() {
            System.out.println("DEBUG:" + replica1Data);
            System.out.println("DEBUG:" + replica2Data);
            // System.out.println("Debug condition" + replica1Data.keySet());
            if (replica1Data == null || replica2Data == null) {
                difference = "One or both replicas missing vertex";
                // System.out.println("Difference found in vertex " + vertexId + ": " + difference);
                return true;
            }
            
            if (!replica1Data.equals(replica2Data)) {
                difference = "Data mismatch";
                // System.out.println("Difference found in vertex " + vertexId + ": " + difference);
               return true;
            }

            if((replica1Data.get("name").equals("replica1") && replica1Data.containsKey("replica2")) || 
               (replica1Data.get("name").equals("replica2") && replica1Data.containsKey("replica1"))){
                difference = "One or both replicas missing vertex";
                // System.out.println("Difference found in vertex " + vertexId + ": " + difference);
                return true;
            }
            // Object name1 = replica1Data.get("Replica1");
            // Object name2 = replica2Data.get("Replica2");
            
            // if (!Objects.equals(name1, name2)) {
            //     difference = "name: " + name1 + " vs " + name2;
            //     return true;
            // }

            
            return false;
        }
        
        @Override
        public String toString() {
            return difference != null ? difference : "identical";
        }
    }

    // ------------------------------
    // Time Series Results
    // ------------------------------
    static class TimeSeriesResults {
        List<WaveMetrics> waveMetrics = new ArrayList<>();
        List<DivergenceSnapshot> divergenceSnapshots = new ArrayList<>();
        
        void addWaveMetrics(WaveMetrics metrics) {
            waveMetrics.add(metrics);
        }
        
        void addDivergenceSnapshot(DivergenceSnapshot snapshot) {
            divergenceSnapshots.add(snapshot);
        }
        
        void printTimeSeries() {
            System.out.println("\n" + new String(new char[80]).replace('\0', '='));
            System.out.println("TIME SERIES DIVERGENCE ANALYSIS");
            System.out.println(new String(new char[80]).replace('\0', '='));
            
            System.out.println("\nWave | Divergence | Same | Different | Missing | Duration | Avg Latency R1 | Avg Latency R2");
            System.out.println(new String(new char[100]).replace('\0', '-'));
            
            for (int i = 0; i < divergenceSnapshots.size(); i++) {
                DivergenceSnapshot div = divergenceSnapshots.get(i);
                WaveMetrics wave = i < waveMetrics.size() ? waveMetrics.get(i) : null;
                
                String latencyR1 = wave != null ? String.format("%.2f ms", wave.getAvgLatencyR1()) : "N/A";
                String latencyR2 = wave != null ? String.format("%.2f ms", wave.getAvgLatencyR2()) : "N/A";
                String duration = wave != null ? wave.getDuration() + " ms" : "N/A";
                
                System.out.printf(" %-4d | %6.2f%%   | %-4d | %-9d | %-7d | %-12s | %-14s | %-14s%n",
                    div.waveNumber,
                    div.divergenceRate,
                    div.sameCount,
                    div.differentCount,
                    div.nullCount,
                    duration,
                    latencyR1,
                    latencyR2
                );
            }
            
            System.out.println(String.format("%" + 100 + "s", "").replace(' ', '-'));
        }
        
        void printSummaryStatistics() {
            if (divergenceSnapshots.isEmpty()) return;
            
            System.out.println("\n=== SUMMARY STATISTICS ===");
            
            double avgDivergence = divergenceSnapshots.stream()
                .mapToDouble(d -> d.divergenceRate)
                .average()
                .orElse(0.0);
            
            double maxDivergence = divergenceSnapshots.stream()
                .mapToDouble(d -> d.divergenceRate)
                .max()
                .orElse(0.0);
            
            double minDivergence = divergenceSnapshots.stream()
                .mapToDouble(d -> d.divergenceRate)
                .min()
                .orElse(0.0);
            
            System.out.println("Average divergence: " + String.format("%.2f%%", avgDivergence));
            System.out.println("Maximum divergence: " + String.format("%.2f%%", maxDivergence));
            System.out.println("Minimum divergence: " + String.format("%.2f%%", minDivergence));
            
            // Calculate trend (simple linear regression slope)
            if (divergenceSnapshots.size() > 1) {
                double trend = calculateTrend();
                System.out.println("Trend: " + (trend > 0 ? "↗ Increasing" : trend < 0 ? "↘ Decreasing" : "→ Stable") +
                    " (" + String.format("%.2f", trend) + "% per wave)");
            }
        }
        
        double calculateTrend() {
            int n = divergenceSnapshots.size();
            double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
            
            for (int i = 0; i < n; i++) {
                double x = i;
                double y = divergenceSnapshots.get(i).divergenceRate;
                sumX += x;
                sumY += y;
                sumXY += x * y;
                sumX2 += x * x;
            }
            
            return (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
        }
    }

    // ------------------------------
    // Enhanced Replica Updater Class
    // ------------------------------
    static class ReplicaUpdater {
        String name;
        GraphTraversalSource g;
        Driver neo4jDriver;
        Session session;
        static Random rand = new Random();
        Cluster cluster;
        int numVertices;
        boolean enableDetailedLogging;
        String database;
        String appPort;
        HttpClient httpClient;

        volatile int totalUpdateCount = 0;
        volatile int totalErrorCount = 0;
        
        // Per-wave tracking
        volatile int waveUpdateCount = 0;
        volatile int waveErrorCount = 0;
        volatile List<Long> waveLatencies = new CopyOnWriteArrayList<>();

        ReplicaUpdater(String database, String name, String host, int port,
                       int numVertices, boolean enableDetailedLogging) throws Exception {
                        
            this.database = database;
            this.name = name;
            this.numVertices = numVertices;
            this.enableDetailedLogging = enableDetailedLogging;
            if(database == "janusgraph"){
                log("Connecting to " + host + ":" + port + "...");
                this.cluster = Cluster.build(host).port(port).create();
                this.g = AnonymousTraversalSource.traversal()
                        .withRemote(DriverRemoteConnection.using(cluster, "g"));
            } else{
                try{
                String memgraphPort = name.equals("Replica1") ? "7687" : "7688";
                String appPort = name.equals("Replica1") ? "3000" : "3001";
                this.neo4jDriver = GraphDatabase.driver("bolt://localhost:" + memgraphPort);
                this.session = neo4jDriver.session();
                neo4jDriver.verifyConnectivity();
                } catch (Exception e) {
                    System.out.println("Failed to connect to Memgraph database: " + e.getMessage());
                    throw new RuntimeException(e);
                }
            }
            

            log("Connected successfully");
        }

        void log(String message) {
            String timestamp = new SimpleDateFormat("HH:mm:ss.SSS").format(new Date());
            System.out.println("[" + timestamp + "][" + name + "] " + message);
        }

        void resetWaveMetrics() {
            waveUpdateCount = 0;
            waveErrorCount = 0;
            waveLatencies.clear();
        }

        void createInitialVertices() {
            log("Creating " + numVertices + " initial vertices...");
            int created = 0;
            int existing = 0;
            if(this.database == "janusgraph"){
                for (int i = 0; i < numVertices; i++) {
                    String vid = "shared_vertex_" + i;
                    try {
                        long count = g.V(vid).count().next();
                        if (count == 0) {
                            g.addV("Person")
                                    .property(T.id, vid)
                                    .property("name", "initial")
                                    .property("created_by", name)
                                    // .property("created_at", System.currentTimeMillis())
                                    .iterate();
                            created++;
                        } else {
                            existing++;
                        }
                        
                        if ((i + 1) % 20 == 0) {
                            log("Progress: " + (i + 1) + "/" + numVertices + " vertices processed");
                        }
                    } catch (Exception e) {
                        log("ERROR creating vertex " + vid + ": " + e.getMessage());
                    }
                }
            } else {
                this.httpClient = HttpClient.newHttpClient();
                this.appPort = name.equals("Replica1") ? "3000" : "3001";
                for (int i=0; i< numVertices; i++){
                    String vertexProperties = "";
                    vertexProperties += "\"name\":\"initial\",";
                    vertexProperties += "\"created_by\":\""+name+"\",";
                    // vertexProperties += "\"created_at\":\""+System.currentTimeMillis()+"\",";
                    String id = "shared_vertex_" + i;
                    String targetString = "http://localhost:" + appPort + "/api/addVertex";
                    String reqBody = " { \"label\": [\"Person\"], \"properties\": {"+vertexProperties+"\"id\":\""+id+"\"}}";
                    

                    try{
                        URI target = new URI(targetString);
                        HttpRequest request = HttpRequest.newBuilder()
                            .uri(target)
                            .POST(HttpRequest.BodyPublishers.ofString(reqBody))
                            .header("Content-Type", "application/json")
                            .build();
                        HttpResponse<?> response = httpClient.send(request, HttpResponse.BodyHandlers.discarding());
                    //      System.out.println(response.statusCode());
                        if(response.statusCode() == 200){
                            created++;
                        } else{
                            existing++;
                        }

                        if ((i + 1) % 20 == 0) {
                            log("Progress: " + (i + 1) + "/" + numVertices + " vertices processed");
                        }
                    } catch (Exception e) {
                        log("ERROR creating vertex " + id + ": " + e.getMessage());
                    }
            }
        }
            log("Initial vertices complete. Created: " + created + ", Already existing: " + existing);
        }

        boolean updateVertex(String vertexId, String source) {
            long startTime = System.currentTimeMillis();
            boolean success = false;
            try {
            //     if(name.equals("Replica2")){
            //     Thread.sleep(100);

            // }
                if (this.database == "janusgraph"){
                    g.V(vertexId)
                        .property(source, "updated_value")
                        .property("name", source)
                        // .property("updated_at", System.currentTimeMillis())
                        .property("updated_by", name)
                        .iterate();
                } else {
                    this.appPort = name.equals("Replica1") ? "3000" : "3001";
                    String reqBody = " { \"id\": \""+vertexId+"\", \"key\": \""+source+"\", \"value\": \"updated_value\"}";
                    String targetString = "http://localhost:" + appPort + "/api/setVertexProperty";
                    this.httpClient = HttpClient.newHttpClient();
                    URI target = new URI(targetString);
                    HttpRequest request = HttpRequest.newBuilder()
                        .uri(target)
                        .POST(HttpRequest.BodyPublishers.ofString(reqBody))
                        .header("Content-Type", "application/json")
                        .build();
                    HttpResponse<?> response = httpClient.send(request, HttpResponse.BodyHandlers.discarding());
                }
                
                totalUpdateCount++;
                waveUpdateCount++;
                success = true;
                
                long latency = System.currentTimeMillis() - startTime;
                waveLatencies.add(latency);
                
            } catch (Exception e) {
                totalErrorCount++;
                waveErrorCount++;
                
                if (enableDetailedLogging) {
                    log("ERROR updating " + vertexId + ": " + e.getMessage());
                }
            }
            
            return success;
        }

        void executeWave(int waveNumber, int updatesPerWave, double conflictRate, long delayMs) {
            log("Starting wave " + waveNumber + " (" + updatesPerWave + " updates)");
            
            
            int conflictingUpdates = 0;
            int nonConflictingUpdates = 0;

            for (int i = 0; i < updatesPerWave; i++) {
                int idx;
                boolean isConflicting = rand.nextDouble() < conflictRate;
                
                if (isConflicting) {
                    idx = i;
                    // idx = rand.nextInt(numVertices);
                    conflictingUpdates++;
                } else {
                    idx = i;
                    // idx = Math.abs(Objects.hash(name, waveNumber, i)) % numVertices;
                    nonConflictingUpdates++;
                }
                // if (name.equals("Replica2")){
                //     idx = numVertices - idx;
                // }
                String vid = "shared_vertex_" + idx;

                updateVertex(vid, name.toLowerCase());

                try { 
                    Thread.sleep(delayMs); 
                } catch (InterruptedException e) {
                    log("Interrupted during wave " + waveNumber);
                    break;
                }
            }

            log("Wave " + waveNumber + " completed: " + waveUpdateCount + " updates, " + 
                waveErrorCount + " errors (conflicting: " + conflictingUpdates + 
                ", non-conflicting: " + nonConflictingUpdates + ")");
        }

        Map<String, Object> getVertex(String vid) {
            try {
                if (this.database == "janusgraph"){
                List<Map<Object, Object>> res = g.V(vid).elementMap().toList();
                if (res.isEmpty()) return null;
                Map<String, Object> flat = new HashMap<>();
                for (Map.Entry<Object, Object> e : res.get(0).entrySet()) {
                    // System.out.println(e);
                    String key = e.getKey().toString();
                    Object val = e.getValue();
                    if (val instanceof List && !((List<?>) val).isEmpty()) {
                        val = ((List<?>) val).get(0);
                    }
                    flat.put(key, val);
                }
                return flat;
            } else {
                org.neo4j.driver.Result result = session.run("MATCH (n {id: $id}) RETURN n", 
                                                            Collections.singletonMap("id", vid));
                if (!result.hasNext()) {
                    return null;
                }
                org.neo4j.driver.Record record = result.next();
                org.neo4j.driver.types.Node node = record.get("n").asNode();

                Map<String, Object> flat = new HashMap<>();
                flat.put("id", node.get("id").asString());
                for (String key : node.keys()) {
                    flat.put(key, node.get(key).asObject());
                }
                return flat;
            }
            } catch (Exception e) {
                if (enableDetailedLogging) {
                    log("ERROR fetching vertex " + vid + ": " + e.getMessage());
                }
                return null;
            }
        }

        long countVertices() {
            try {
                if (database == "janusgraph") {
                    return g.V().count().next();
                } else {
                    org.neo4j.driver.Result result = session.run("MATCH (n) RETURN count(n)");
                    if (result.hasNext()) {
                        return result.next().get(0).asLong();
                    } else {
                        return 0;
                    }
                }
            } catch (Exception e) {
                log("ERROR counting vertices: " + e.getMessage());
                return -1;
            }
        }
        
        void resetDatabase() {
            log("Starting database reset...");
            
            try {
                if(database == "janusgraph"){
                long initialCount = g.V().count().next();
                log("Found " + initialCount + " vertices to delete");
                
                if (initialCount == 0) {
                    log("Database is already empty");
                    return;
                }
                
                long edgeCount = g.E().count().next();
                if (edgeCount > 0) {
                    log("Deleting " + edgeCount + " edges...");
                    g.E().drop().iterate();
                    log("Edges deleted");
                }
                
                int batchSize = 1000;
                long remaining = initialCount;
                int batchCount = 0;
                
                while (remaining > 0) {
                    g.V().limit(batchSize).drop().iterate();
                    batchCount++;
                    
                    long currentCount = g.V().count().next();
                    long deletedThisBatch = remaining - currentCount;
                    remaining = currentCount;
                    
                    log("Batch " + batchCount + ": deleted " + deletedThisBatch + 
                        " vertices, " + remaining + " remaining");
                    
                    if (deletedThisBatch == 0) {
                        log("WARNING: No progress in deletion, stopping");
                        break;
                    }
                }
                
                long finalCount = g.V().count().next();
                log("Database reset complete. Remaining vertices: " + finalCount);
                
                if (finalCount > 0) {
                    log("WARNING: " + finalCount + " vertices could not be deleted");
                }
            } else {
                session.run("MATCH (n) DETACH DELETE n");
                log("Database reset complete.");
            }
            } catch (Exception e) {
                log("ERROR during database reset: " + e.getMessage());
                e.printStackTrace();
            }
        }
        
        void cleanup() {
            try {
                if (cluster != null && !cluster.isClosed()) {
                    cluster.close();
                    log("Connection closed");
                }
            } catch (Exception e) {
                log("ERROR during cleanup: " + e.getMessage());
            }
        }
    }

    // ------------------------------
    // Divergence Analyzer
    // ------------------------------
    static class DivergenceAnalyzer {
        
        static DivergenceSnapshot analyzeDivergence(ReplicaUpdater r1, ReplicaUpdater r2, 
                                                     int waveNumber, int sampleSize, 
                                                     int numVertices) {
            DivergenceSnapshot snapshot = new DivergenceSnapshot(waveNumber);
            snapshot.sampleSize = sampleSize;
            
            System.out.println("  Analyzing divergence for wave " + waveNumber + "...");
            
            Random rand = new Random();
            Set<Integer> sampledIndices = new HashSet<>();
            
            while (sampledIndices.size() < sampleSize) {
                sampledIndices.add(rand.nextInt(numVertices));
            }
            
            int checked = 0;
            for (int idx : sampledIndices) {
                String vid = "shared_vertex_" + idx;
                
                Map<String, Object> v1 = r1.getVertex(vid);
                Map<String, Object> v2 = r2.getVertex(vid);

                
                
                VertexComparison comp = new VertexComparison(vid, v1, v2);
                snapshot.comparisons.put(vid, comp);
                
                if (v1 == null || v2 == null) {
                    snapshot.nullCount++;
                } else if (comp.isDifferent) {
                    snapshot.differentCount++;
                    snapshot.divergentVertices.add(vid);
                } else {
                    snapshot.sameCount++;
                }
                
                checked++;
                if (checked % 10 == 0) {
                    System.out.print(".");
                }
            }
            System.out.println(" Done!");
            
            snapshot.calculate();
            
            return snapshot;
        }
    }

    // ------------------------------
    // Results Writer
    // ------------------------------
    static class ResultsWriter {
        private final String outputDir;
        private final String timestamp;
        
        ResultsWriter(String outputDir) {
            this.outputDir = outputDir;
            this.timestamp = new SimpleDateFormat("yyyyMMdd_HHmmss").format(new Date());
            
            File dir = new File(outputDir);
            if (!dir.exists()) {
                dir.mkdirs();
            }
        }
        
        void writeResults(ExperimentConfig config, TimeSeriesResults results) {
            String baseFilename = outputDir + "/wave_experiment_" + timestamp;
            
            // Write detailed text report
            writeTextReport(baseFilename + ".txt", config, results);
            
            // Write CSV for time series data
            writeCSVReport(baseFilename + "_timeseries.csv", results);
            
            System.out.println("\nResults written to:");
            System.out.println("  - " + baseFilename + ".txt");
            System.out.println("  - " + baseFilename + "_timeseries.csv");
        }
        
        void writeTextReport(String filename, ExperimentConfig config, TimeSeriesResults results) {
            try (PrintWriter writer = new PrintWriter(new FileWriter(filename))) {
                writer.println("=== WAVE-BASED DIVERGENCE EXPERIMENT RESULTS ===");
                writer.println("Timestamp: " + new Date());
                writer.println();
                
                writer.println("--- Configuration ---");
                writer.println("Replica 1: " + config.replica1Host + ":" + config.replica1Port);
                writer.println("Replica 2: " + config.replica2Host + ":" + config.replica2Port);
                writer.println("Vertices: " + config.numVertices);
                writer.println("Number of waves: " + config.numWaves);
                writer.println("Updates per wave (per replica): " + config.updatesPerWave);
                writer.println("Conflict rate: " + (config.conflictRate * 100) + "%");
                writer.println("Update delay: " + config.delayBetweenUpdates + "ms");
                writer.println("Reconciliation wait: " + config.reconciliationWaitMs + "ms");
                writer.println();
                
                writer.println("--- Time Series Results ---");
                writer.println(String.format("%-6s %-12s %-6s %-10s %-8s %-12s %-16s %-16s",
                    "Wave", "Divergence", "Same", "Different", "Missing", "Duration", "AvgLatency R1", "AvgLatency R2"));
                writer.println(String.format("%" + 100 + "s", "").replace(' ', '-'));
                
                for (int i = 0; i < results.divergenceSnapshots.size(); i++) {
                    DivergenceSnapshot div = results.divergenceSnapshots.get(i);
                    WaveMetrics wave = i < results.waveMetrics.size() ? results.waveMetrics.get(i) : null;
                    
                    String latencyR1 = wave != null ? String.format("%.2f ms", wave.getAvgLatencyR1()) : "N/A";
                    String latencyR2 = wave != null ? String.format("%.2f ms", wave.getAvgLatencyR2()) : "N/A";
                    String duration = wave != null ? wave.getDuration() + " ms" : "N/A";
                    
                    writer.println(String.format("%-6d %-11.2f%% %-6d %-10d %-8d %-12s %-16s %-16s",
                        div.waveNumber, div.divergenceRate, div.sameCount, div.differentCount,
                        div.nullCount, duration, latencyR1, latencyR2));
                }
                
                writer.println();
                writer.println("--- Summary Statistics ---");
                
                double avgDivergence = results.divergenceSnapshots.stream()
                    .mapToDouble(d -> d.divergenceRate).average().orElse(0.0);
                double maxDivergence = results.divergenceSnapshots.stream()
                    .mapToDouble(d -> d.divergenceRate).max().orElse(0.0);
                double minDivergence = results.divergenceSnapshots.stream()
                    .mapToDouble(d -> d.divergenceRate).min().orElse(0.0);
                
                writer.println("Average divergence: " + String.format("%.2f%%", avgDivergence));
                writer.println("Maximum divergence: " + String.format("%.2f%%", maxDivergence));
                writer.println("Minimum divergence: " + String.format("%.2f%%", minDivergence));
                
                if (results.divergenceSnapshots.size() > 1) {
                    double trend = results.calculateTrend();
                    writer.println("Trend: " + String.format("%.2f", trend) + "% per wave");
                }
                
            } catch (IOException e) {
                System.err.println("ERROR writing text report: " + e.getMessage());
            }
        }
        
        void writeCSVReport(String filename, TimeSeriesResults results) {
            try (PrintWriter writer = new PrintWriter(new FileWriter(filename))) {
                writer.println("wave,sample_size,same,different,missing,divergence_rate,duration_ms,avg_latency_r1_ms,avg_latency_r2_ms");
                
                for (int i = 0; i < results.divergenceSnapshots.size(); i++) {
                    DivergenceSnapshot div = results.divergenceSnapshots.get(i);
                    WaveMetrics wave = i < results.waveMetrics.size() ? results.waveMetrics.get(i) : null;
                    
                    String duration = wave != null ? String.valueOf(wave.getDuration()) : "";
                    String latencyR1 = wave != null ? String.format("%.2f", wave.getAvgLatencyR1()) : "";
                    String latencyR2 = wave != null ? String.format("%.2f", wave.getAvgLatencyR2()) : "";
                    
                    writer.println(String.format("%d,%d,%d,%d,%d,%.2f,%s,%s,%s",
                        div.waveNumber, div.sampleSize, div.sameCount, div.differentCount,
                        div.nullCount, div.divergenceRate, duration, latencyR1, latencyR2));
                }
                
            } catch (IOException e) {
                System.err.println("ERROR writing CSV report: " + e.getMessage());
            }
        }
    }

    // ------------------------------
    // Main Experiment Orchestrator
    // ------------------------------
    public static void main(String[] args) throws Exception {
        Scanner scanner = new Scanner(System.in);
        ExperimentConfig config = new ExperimentConfig();
        
        System.out.println("╔═══════════════════════════════════════════════════════════╗");
        System.out.println("║  WAVE-BASED MULTI-REPLICA DIVERGENCE EXPERIMENT          ║");
        System.out.println("╚═══════════════════════════════════════════════════════════╝");
        
        // Interactive configuration
        System.out.println("\nConfigure experiment (press Enter for defaults):\n");
        config.database = promptWithDefault(scanner, "Database type (janusgraph/memgraph)", config.database);
        config.replica1Host = promptWithDefault(scanner, "Replica 1 host", config.replica1Host);
        config.replica1Port = Integer.parseInt(promptWithDefault(scanner, "Replica 1 port", 
            String.valueOf(config.replica1Port)));
        
        config.replica2Host = promptWithDefault(scanner, "Replica 2 host", config.replica2Host);
        config.replica2Port = Integer.parseInt(promptWithDefault(scanner, "Replica 2 port", 
            String.valueOf(config.replica2Port)));
        
        config.numVertices = Integer.parseInt(promptWithDefault(scanner, 
            "Number of vertices", String.valueOf(config.numVertices)));
        config.numWaves = Integer.parseInt(promptWithDefault(scanner, 
            "Number of waves", String.valueOf(config.numWaves)));
        config.updatesPerWave = Integer.parseInt(promptWithDefault(scanner, 
            "Updates per wave (per replica)", String.valueOf(config.updatesPerWave)));
        config.conflictRate = Double.parseDouble(promptWithDefault(scanner, 
            "Conflict rate (0.0-1.0)", String.valueOf(config.conflictRate)));
        config.delayBetweenUpdates = Long.parseLong(promptWithDefault(scanner, 
            "Delay between updates (ms)", String.valueOf(config.delayBetweenUpdates)));
        config.reconciliationWaitMs = Long.parseLong(promptWithDefault(scanner, 
            "Reconciliation wait between waves (ms)", String.valueOf(config.reconciliationWaitMs)));
        config.sampleSize = Integer.parseInt(promptWithDefault(scanner, 
            "Sample size for divergence check", String.valueOf(config.sampleSize)));
        
        String logging = promptWithDefault(scanner, "Enable detailed logging? (y/n)", "y");
        config.enableDetailedLogging = logging.equalsIgnoreCase("y");
        
        String resetDb = promptWithDefault(scanner, "Reset database before experiment? (y/n)", "y");
        config.resetDatabaseBeforeRun = resetDb.equalsIgnoreCase("y");
        
        config.printConfig();
        
        System.out.print("\nProceed with experiment? (y/n): ");
        String proceed = scanner.nextLine().trim();
        if (!proceed.equalsIgnoreCase("y")) {
            System.out.println("Experiment cancelled.");
            return;
        }
        
        System.out.println("\n" + String.format("%" + 60 + "s", "").replace(' ', '='));
        System.out.println("STARTING WAVE-BASED EXPERIMENT");
        System.out.println(String.format("%" + 60 + "s", "").replace(' ', '=') + "\n");
        
        // Initialize replicas
        final ReplicaUpdater[] replicas = new ReplicaUpdater[2];
        TimeSeriesResults timeSeriesResults = new TimeSeriesResults();
        
        try {
            replicas[0] = new ReplicaUpdater(config.database, "Replica1", config.replica1Host, config.replica1Port,
                    config.numVertices, config.enableDetailedLogging);

            replicas[1] = new ReplicaUpdater(config.database, "Replica2", config.replica2Host, config.replica2Port,
                    config.numVertices, config.enableDetailedLogging);
            
            final ReplicaUpdater r1 = replicas[0];
            final ReplicaUpdater r2 = replicas[1];

            // Phase 0: Database reset (if enabled)
            if (config.resetDatabaseBeforeRun) {
                System.out.println("\n" + String.format("%" + 60 + "s", "").replace(' ', '='));
                System.out.println("PHASE 0: DATABASE RESET");
                System.out.println(String.format("%" + 60 + "s", "").replace(' ', '=') + "\n");
                
                r1.resetDatabase();
                r2.resetDatabase();
                
                System.out.println("\nWaiting for deletion to propagate...");
                Thread.sleep(config.reconciliationWaitMs);
                
                long count1 = r1.countVertices();
                long count2 = r2.countVertices();
                
                System.out.println("\nPost-reset vertex counts:");
                System.out.println("  Replica 1: " + count1);
                System.out.println("  Replica 2: " + count2);
                
                if (count1 != 0 || count2 != 0) {
                    System.out.println("\nWARNING: Database reset incomplete!");
                    System.out.print("Continue anyway? (y/n): ");
                    String continueAnyway = scanner.nextLine().trim();
                    if (!continueAnyway.equalsIgnoreCase("y")) {
                        System.out.println("Experiment aborted.");
                        return;
                    }
                }
            }

            // Phase 1: Initial setup
            System.out.println("\n" + String.format("%" + 60 + "s", "").replace(' ', '='));
            System.out.println("PHASE 1: INITIAL SETUP");
            System.out.println(String.format("%" + 60 + "s", "").replace(' ', '=') + "\n");
            
            r1.createInitialVertices();
            
            System.out.println("\nWaiting for initial replication...");
            Thread.sleep(config.reconciliationWaitMs);
            
            long count1 = r1.countVertices();
            long count2 = r2.countVertices();
            
            System.out.println("\nInitial vertex counts:");
            System.out.println("  Replica 1: " + count1);
            System.out.println("  Replica 2: " + count2);
            
            if (count1 != count2) {
                System.out.println("\nWARNING: Replica counts differ!");
                System.out.print("Continue anyway? (y/n): ");
                String continueAnyway = scanner.nextLine().trim();
                if (!continueAnyway.equalsIgnoreCase("y")) {
                    System.out.println("Experiment aborted.");
                    return;
                }
            }

            // Phase 2: Wave-based updates
            System.out.println("\n" + String.format("%" + 60 + "s", "").replace(' ', '='));
            System.out.println("PHASE 2: WAVE-BASED UPDATES AND DIVERGENCE TRACKING");
            System.out.println(String.format("%" + 60 + "s", "").replace(' ', '=') + "\n");
            
            for (int wave = 1; wave <= config.numWaves; wave++) {
                final int currentWave = wave;  // Make effectively final for lambda
                final int updatesPerWave = config.updatesPerWave;
                final double conflictRate = config.conflictRate;
                final long delayBetweenUpdates = config.delayBetweenUpdates;
                final long reconciliationWaitMs = config.reconciliationWaitMs;
                final int sampleSize = config.sampleSize;
                final int numVertices = config.numVertices;
                
                System.out.println("\n" + String.format("%" + 60 + "s", "").replace(' ', '-'));
                System.out.println("WAVE " + currentWave + " of " + config.numWaves);
                System.out.println(String.format("%" + 60 + "s", "").replace(' ', '-'));
                
                // Reset wave metrics
                r1.resetWaveMetrics();
                r2.resetWaveMetrics();
                
                WaveMetrics waveMetrics = new WaveMetrics(currentWave);
                waveMetrics.start();
                
                // Execute concurrent updates
                CountDownLatch waveLatch = new CountDownLatch(2);
                
                Thread t1 = new Thread(() -> {
                    r1.executeWave(currentWave, updatesPerWave, conflictRate, delayBetweenUpdates);
                    waveLatch.countDown();
                });
                
                Thread t2 = new Thread(() -> {
                    r2.executeWave(currentWave, updatesPerWave, conflictRate, delayBetweenUpdates);
                    waveLatch.countDown();
                });
                
                t1.start();
                t2.start();
                
                waveLatch.await();
                t1.join();
                t2.join();
                
                waveMetrics.stop();
                waveMetrics.updatesR1 = r1.waveUpdateCount;
                waveMetrics.updatesR2 = r2.waveUpdateCount;
                waveMetrics.errorsR1 = r1.waveErrorCount;
                waveMetrics.errorsR2 = r2.waveErrorCount;
                waveMetrics.latenciesR1 = new ArrayList<>(r1.waveLatencies);
                waveMetrics.latenciesR2 = new ArrayList<>(r2.waveLatencies);
                
                timeSeriesResults.addWaveMetrics(waveMetrics);
                
                // Wait for reconciliation
                System.out.println("\nWaiting " + reconciliationWaitMs + 
                                   "ms for reconciliation...");
                Thread.sleep(reconciliationWaitMs);
                
                // Measure divergence
                System.out.println("\n--- Divergence Check (Wave " + currentWave + ") ---");
                DivergenceSnapshot snapshot = DivergenceAnalyzer.analyzeDivergence(
                    r1, r2, currentWave, sampleSize, numVertices);
                
                snapshot.printSummary();
                timeSeriesResults.addDivergenceSnapshot(snapshot);
                
                System.out.println("\nWave " + currentWave + " complete. Moving to next wave...");
            }

            // Phase 3: Final analysis
            System.out.println("\n" + String.format("%" + 60 + "s", "").replace(' ', '='));
            System.out.println("PHASE 3: FINAL ANALYSIS");
            System.out.println(String.format("%" + 60 + "s", "").replace(' ', '='));
            
            timeSeriesResults.printTimeSeries();
            timeSeriesResults.printSummaryStatistics();

            // Phase 4: Write results
            System.out.println("\n" + String.format("%" + 60 + "s", "").replace(' ', '='));
            System.out.println("PHASE 4: SAVING RESULTS");
            System.out.println(String.format("%" + 60 + "s", "").replace(' ', '=') + "\n");
            
            ResultsWriter writer = new ResultsWriter(config.outputDir);
            writer.writeResults(config, timeSeriesResults);

            // Final summary
            System.out.println("\n" + String.format("%" + 60 + "s", "").replace(' ', '='));
            System.out.println("EXPERIMENT COMPLETE");
            System.out.println(String.format("%" + 60 + "s", "").replace(' ', '=') + "\n");
            
            System.out.println("Total waves executed: " + config.numWaves);
            System.out.println("Total updates: " + (r1.totalUpdateCount + r2.totalUpdateCount));
            System.out.println("Total errors: " + (r1.totalErrorCount + r2.totalErrorCount));
            
            if (!timeSeriesResults.divergenceSnapshots.isEmpty()) {
                double avgDiv = timeSeriesResults.divergenceSnapshots.stream()
                    .mapToDouble(d -> d.divergenceRate).average().orElse(0.0);
                System.out.println("Average divergence across waves: " + 
                    String.format("%.2f%%", avgDiv));
            }
            
        } catch (Exception e) {
            System.err.println("\n❌ EXPERIMENT FAILED: " + e.getMessage());
            e.printStackTrace();
        } finally {
            // Cleanup
            if (replicas[0] != null) replicas[0].cleanup();
            if (replicas[1] != null) replicas[1].cleanup();
            scanner.close();
        }
    }
    
    private static String promptWithDefault(Scanner scanner, String prompt, String defaultValue) {
        System.out.print(prompt + " [" + defaultValue + "]: ");
        String input = scanner.nextLine().trim();
        return input.isEmpty() ? defaultValue : input;
    }
}