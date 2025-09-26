println "🎉 Starting JanusGraph JSON preload..."

import org.janusgraph.core.JanusGraphFactory
import org.apache.tinkerpop.gremlin.structure.T
import groovy.json.JsonSlurper
import java.util.concurrent.TimeUnit

// --- CONFIGURATION ---
// String vertexFile = "/var/lib/janusgraph/import/vertices.json"
// String edgeFile = "/var/lib/janusgraph/import/edges.json"
// String configFile = "/etc/opt/janusgraph/janusgraph.properties"

// String vertexKeysFile = "/var/lib/janusgraph/import/vertices.keys.json"
// String edgeKeysFile = "/var/lib/janusgraph/import/edges.keys.json"

// Performance tracking
def vertexMap = [:]
long vertexCounter = 0
long edgeCounter = 0
long skippedEdges = 0






try {
    // --- Open graph connection ---
    println "🔹 Connecting to JanusGraph..."
    graph = JanusGraphFactory.open("/etc/opt/janusgraph/janusgraph.properties")
    g = graph.traversal()

    def vertexMap = [:]
    long vertexCounter = 0
    long edgeCounter = 0
    long skippedEdges = 0
    int batchSize = 100000 // commit every 10k records

    // --- Validate input files ---
    def vertexFileObj = new File("/var/lib/janusgraph/import/vertices.json")
    def edgeFileObj = new File("/var/lib/janusgraph/import/edges.json")
    def vertexKeysFileObj = new File("/var/lib/janusgraph/import/vertices.keys")
    def edgeKeysFileObj = new File("/var/lib/janusgraph/import/edges.keys")

    if (!vertexFileObj.exists()) {
        throw new FileNotFoundException("Vertex file not found: ${vertexFile}")
    }
    if (!edgeFileObj.exists()) {
        throw new FileNotFoundException("Edge file not found: ${edgeFile}")
    }
    if (!vertexKeysFileObj.exists()) {
        throw new FileNotFoundException("Vertex keys file not found: ${vertexKeysFile}")
    }
    if (!edgeKeysFileObj.exists()) {
        throw new FileNotFoundException("Edge keys file not found: ${edgeKeysFile}")
    }
    println "✅ Input files found"
    println "📊 File sizes - Vertices: ${vertexFileObj.length() / 1024 / 1024} MB, Edges: ${edgeFileObj.length() / 1024 / 1024} MB"
    

    //Create property keys from keys files. File contains one key per line in a simple file.
    def readKeysFromFile = { file ->
        def keys = []
        if (file.exists()) {
            file.eachLine { line ->
                def key = line.trim()
                if (key && !key.isEmpty()) {
                    keys.add(key)
                }
            }
        }
        return keys
    }
    
    def vertexKeys = readKeysFromFile(vertexKeysFileObj)
    def edgeKeys = readKeysFromFile(edgeKeysFileObj)

    println "📋 Vertex keys found: ${vertexKeys}"
    println "📋 Edge keys found: ${edgeKeys}"

    // --- Load vertices ---
    println "🔹 Loading vertices from JSON..."
    // Alternative approach: Create all properties in one transaction
    def createAllPropertyKeys = { VK, EK ->
        def mgmt = graph.openManagement()
        if(!mgmt.containsVertexLabel("YCSBVertex")){
            mgmt.makeVertexLabel("YCSBVertex").make()
            println "🆕 Creating vertex label: YCSBVertex"
        } else {
            println "ℹ️ Vertex label YCSBVertex already exists"
        }
        if(!mgmt.containsEdgeLabel("YCSBEdge")){
            mgmt.makeEdgeLabel("YCSBEdge").make()
            println "🆕 Creating edge label: YCSBEdge"
        } else {
            println "ℹ️ Edge label YCSBEdge already exists"
        }
        def createdCount = 0
        // def allKeys = (VK + EK).unique()



        VK.add("searchKey") // Add searchKey, eventually used by YCSB
        try {
            VK.each { key ->
                if (!mgmt.containsPropertyKey(key)) {
                    def propKey = mgmt.makePropertyKey(key).dataType(String.class).make()
                    println "🆕 Created property key: ${key}"
                    if(key == "_id"){
                        mgmt.buildIndex("vertexById", Vertex.class).addKey(propKey).buildCompositeIndex()
                        println "📊 Created composite index for vertex _id"
                    }
                    createdCount++
                }
            }

            EK.each { key ->
                if (!mgmt.containsPropertyKey(key)) {
                    def propKey = mgmt.makePropertyKey(key).dataType(String.class).make()
                    println "🆕 Created property key: ${key}"
                    if(key == "_id"){
                        mgmt.buildIndex("edgeById", Edge.class).addKey(propKey).buildCompositeIndex()
                        println "📊 Created composite index for edge _id"
                    }
                    createdCount++
                }
            }
            mgmt.commit()
            println "✅ Successfully committed ${createdCount} property keys in single transaction"
        } catch (Exception e) {
            mgmt.rollback()
            println "❌ Failed to create property keys: ${e.message}"
            throw e
        }
    }

    createAllPropertyKeys(vertexKeys, edgeKeys)
    // Now you can use vertexKeys and edgeKeys arrays in your script
    // For example, to create properties for all vertex keys with String data type:
    // vertexKeys.each { key ->
    //     if (!graph.getPropertyKey(key)) {
    //         graph.makePropertyKey(key).dataType(String.class).make()
    //         println "🆕 Created property key: ${key} (String)"
    //     }
    // }
    // graph.tx().commit()
    // edgeKeys.each { key ->
    //     if (!graph.getPropertyKey(key)) {
    //         graph.makePropertyKey(key).dataType(String.class).make()
    //         println "🆕 Created property key: ${key} (String)"
    //     }
    // }
    // graph.tx().commit()


    
    def jsonSlurper = new JsonSlurper()
    def vertexJson = jsonSlurper.parse(vertexFileObj)
    
    println "📋 Found ${vertexJson.size()} vertices to process"
    
    vertexJson.each { obj ->
        try {
            // println obj
            // Create vertex with label
            def vertex = g.addV("YCSBVertex")
            
            // Add all properties
            obj.each { key, value ->
                if(key=="_id" && value != null){
                        vertex.property(T.id, value.toString())
                }
                // Handle different data types appropriately
                if (value instanceof List || value instanceof Map) {
                    vertex.property(key.toString(), value)
                } else {
                    vertex.property(key.toString(), value.toString())
                }
                
            }
            
            def v = vertex.next()
            vertexMap[obj["_id"]] = v
            vertexCounter++
            
            // Batch commit for performance
            if (vertexCounter % batchSize == 0) {
                graph.tx().commit()
                println "🔄 Committed ${vertexCounter} vertices so far..."
            }
            
        } catch (Exception e) {
            println "❌ Error processing vertex ${obj['_id']}: ${e.message}"

        }
    }
    
    // Final commit for vertices
    graph.tx().commit()
    println "✅ Finished loading ${vertexCounter} vertices"

    // --- Load edges ---
    println "🔹 Loading edges from JSON..."
    def edgeStartTime = System.currentTimeMillis()
    
    def edgeJson = jsonSlurper.parse(edgeFileObj)
    println "📋 Found ${edgeJson.size()} edges to process"
    
    edgeJson.each { obj ->
        try {
            def outV = vertexMap[obj["_outV"]]
            def inV = vertexMap[obj["_inV"]]
            
            if (outV && inV) {
                def inVertex = g.V(inV).next()
                def edge = g.V(outV).addE("YCSBEdge").to(inVertex)

                // Add edge properties
                obj.each { key, value ->
                    if (value instanceof List || value instanceof Map) {
                        edge.property(key, value.toString())
                    } else {
                        edge.property(key, value)
                    }
                }
                
                edge.next()
                edgeCounter++
                
                // Batch commit for performance
                if (edgeCounter % batchSize == 0) {
                    graph.tx().commit()
                    println "🔄 Committed ${edgeCounter} edges so far..."
                }
                
            } else {
                skippedEdges++
                println "⚠️ Skipping edge ${obj['_id']}: missing vertices outV=${obj['_outV']} inV=${obj['_inV']}"
            }
            
        } catch (Exception e) {
            skippedEdges++
            println "❌ Error processing edge ${obj['_id']}: ${e.message}"
        }
    }
    
    // Final commit for edges
    graph.tx().commit()
    def edgeElapsed = (System.currentTimeMillis() - edgeStartTime) / 1000
    println "✅ Finished loading ${edgeCounter} edges in ${edgeElapsed}s"
    
    if (skippedEdges > 0) {
        println "⚠️ Skipped ${skippedEdges} edges due to errors or missing vertices"
    }
    
} catch (Exception e) {
    println "💥 Fatal error during data loading: ${e.message}"
    e.printStackTrace()
    
    // Rollback transaction on error
    try {
        if (graph?.tx()?.isOpen()) {
            graph.tx().rollback()
            println "🔄 Transaction rolled back"
        }
    } catch (Exception rollbackEx) {
        println "❌ Error during rollback: ${rollbackEx.message}"
    }
    
} finally {
    // Always close the graph connection
    try {
        if (graph) {
            graph.close()
            println "🔐 Graph connection closed"
        }
    } catch (Exception closeEx) {
        println "❌ Error closing graph: ${closeEx.message}"
    }
}

// // --- Summary ---

// println "\n📊 === LOAD SUMMARY ==="
// // println "📈 Vertices loaded: ${vertexCounter}"
// // println "🔗 Edges loaded: ${edgeCounter}"
// // println "⚠️  Edges skipped: ${skippedEdges}"
// println "🎉 JSON preload complete!"

// Optional: Print some basic graph statistics
try {
    graph = JanusGraphFactory.open("/etc/opt/janusgraph/janusgraph.properties")
    g = graph.traversal()
    
    def totalVertices = g.V().count().next()
    def totalEdges = g.E().count().next()
    
    println "\n🔍 === GRAPH STATISTICS ==="
    println "📊 Total vertices in graph: ${totalVertices}"
    println "🔗 Total edges in graph: ${totalEdges}"
    
    graph.close()
} catch (Exception e) {
    println "⚠️ Could not retrieve graph statistics: ${e.message}"
}
