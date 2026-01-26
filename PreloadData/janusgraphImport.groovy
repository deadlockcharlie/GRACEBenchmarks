import org.janusgraph.core.JanusGraphFactory
import org.janusgraph.core.schema.SchemaAction
import org.janusgraph.core.schema.SchemaStatus
import org.janusgraph.core.schema.Mapping
import org.janusgraph.graphdb.database.management.ManagementSystem
import org.apache.tinkerpop.gremlin.structure.T
import org.apache.tinkerpop.gremlin.structure.Vertex
import org.apache.tinkerpop.gremlin.structure.Edge
import groovy.json.JsonSlurper

println "🎉 Starting JanusGraph JSON preload..."

binding.setVariable("vertexMap", [:])
binding.setVariable("vertexCounter", 0L)
binding.setVariable("edgeCounter", 0L)
binding.setVariable("skippedEdges", 0L)

try {
    if (args.size() < 2) {
        println "Usage: groovy Preload.groovy <preloadPath> <configFile>"
        System.exit(1)
    }
    def dataDir = args[0]
    def propertiesDir = args[1]

    println "🔹 Connecting to JanusGraph..."
    graph = JanusGraphFactory.open(propertiesDir)
    g = graph.traversal()

    int batchSize = 100000

    // --- Input files ---
    def vertexFileObj = new File("${dataDir}/vertices.json")
    def edgeFileObj   = new File("${dataDir}/edges.json")
    def vertexKeysFileObj = new File("${dataDir}/vertices.keys")
    def edgeKeysFileObj   = new File("${dataDir}/edges.keys")

    [vertexFileObj, edgeFileObj, vertexKeysFileObj, edgeKeysFileObj].each { f ->
        if (!f.exists()) throw new FileNotFoundException("Missing file: ${f}")
    }

    println "✅ Input files found"
    println "📊 File sizes - Vertices: ${vertexFileObj.length() / 1024 / 1024} MB, Edges: ${edgeFileObj.length() / 1024 / 1024} MB"

    // --- Helper to read keys ---
    def readKeysFromFile = { file ->
        def keys = []
        file.eachLine { line ->
            def key = line.trim()
            if (key) keys.add(key)
        }
        return keys
    }
    def vertexKeys = readKeysFromFile(vertexKeysFileObj)
    def edgeKeys   = readKeysFromFile(edgeKeysFileObj)

    println "📋 Vertex keys found: ${vertexKeys}"
    println "📋 Edge keys found: ${edgeKeys}"

    // --- ⭐ EVICT ZOMBIE INSTANCES ---
    def evictZombieInstances = { ->
        println "\n🧹 Checking for zombie instances..."
        def mgmt = graph.openManagement()
        def instances = mgmt.getOpenInstances()
        println "Found ${instances.size()} instance(s)"
        
        instances.each { instanceId ->
            if (!instanceId.contains("(current)")) {
                println "  🔄 Evicting zombie: ${instanceId}"
                mgmt.forceCloseInstance(instanceId)
            }
        }
        mgmt.commit()
        
        if (instances.size() > 1) {
            println "⏳ Waiting 30 seconds for eviction..."
            Thread.sleep(30000)
        }
    }
    
    evictZombieInstances()

    // --- ⭐ SCHEMA AND INDEXES ---
    def createSchemaAndIndexes = { VK, EK ->
        println "\n🔧 Creating schema and indexes..."
        
        def mgmt = graph.openManagement()
        
        // Create labels
        if (!mgmt.containsVertexLabel("YCSBVertex")) {
            mgmt.makeVertexLabel("YCSBVertex").make()
            println "🆕 Created vertex label: YCSBVertex"
        }
        if (!mgmt.containsEdgeLabel("YCSBEdge")) {
            mgmt.makeEdgeLabel("YCSBEdge").make()
            println "🆕 Created edge label: YCSBEdge"
        }
        
        // Add searchKey to both lists
        VK.add("searchKey")
        EK.add("searchKey")
        
        // Add _count to both lists
        VK.add("_count")
        EK.add("_count")
        
        // Create a dummy property for counting (always set to 1)
        def countKey = mgmt.getPropertyKey("_count")
        if (!countKey) {
            countKey = mgmt.makePropertyKey("_count").dataType(Integer.class).cardinality(org.janusgraph.core.Cardinality.SINGLE).make()
            println "🆕 Created counting property key: _count (Integer)"
        }
        
        // Create composite index for fast counting of vertices
        def vCountIndexName = "vCountIndex"
        if (!mgmt.getGraphIndex(vCountIndexName)) {
            mgmt.buildIndex(vCountIndexName, Vertex.class)
                .addKey(countKey)
                .buildCompositeIndex()
            println "📊 Created vertex count index: ${vCountIndexName}"
        }
        
        // Create composite index for fast counting of edges  
        def eCountIndexName = "eCountIndex"
        if (!mgmt.getGraphIndex(eCountIndexName)) {
            mgmt.buildIndex(eCountIndexName, Edge.class)
                .addKey(countKey)
                .buildCompositeIndex()
            println "📊 Created edge count index: ${eCountIndexName}"
        }
        
        // Create vertex property keys AND their indexes
        VK.each { key ->
            def propKey = mgmt.getPropertyKey(key)
            if (!propKey) {
                propKey = mgmt.makePropertyKey(key).dataType(String.class).make()
                println "🆕 Created vertex property key: ${key}"
                
                // Create mixed index for searchKey using Elasticsearch
                if (key == "searchKey") {
                    def mixedIndexName = "v_${key}_mixed"
                    if (!mgmt.getGraphIndex(mixedIndexName)) {
                        mgmt.buildIndex(mixedIndexName, Vertex.class)
                            .addKey(propKey, Mapping.TEXT.asParameter())
                            .buildMixedIndex("search")
                        println "📊 Created mixed index (Elasticsearch): ${mixedIndexName}"
                    }
                }
                // Create composite index for _id (exact match)
                else if (key == "_id") {
                    def indexName = "v_${key}_composite"
                    if (!mgmt.getGraphIndex(indexName)) {
                        mgmt.buildIndex(indexName, Vertex.class)
                            .addKey(propKey)
                            .buildCompositeIndex()
                        println "📊 Created composite index: ${indexName}"
                    }
                }
            }
        }
        
        // Create edge property keys AND their indexes
        EK.each { key ->
            def propKey = mgmt.getPropertyKey(key)
            if (!propKey) {
                propKey = mgmt.makePropertyKey(key).dataType(String.class).make()
                println "🆕 Created edge property key: ${key}"
                
                // Create mixed index for searchKey using Elasticsearch
                if (key == "searchKey") {
                    def mixedIndexName = "e_${key}_mixed"
                    if (!mgmt.getGraphIndex(mixedIndexName)) {
                        mgmt.buildIndex(mixedIndexName, Edge.class)
                            .addKey(propKey, Mapping.TEXT.asParameter())
                            .buildMixedIndex("search")
                        println "📊 Created mixed index (Elasticsearch): ${mixedIndexName}"
                    }
                }
                // Create composite indexes for commonly queried edge properties (exact match)
                else if (key == "_id" || key == "_type" || key == "_inV" || key == "_outV") {
                    def indexName = "e_${key}_composite"
                    if (!mgmt.getGraphIndex(indexName)) {
                        mgmt.buildIndex(indexName, Edge.class)
                            .addKey(propKey)
                            .buildCompositeIndex()
                        println "📊 Created composite index: ${indexName}"
                    }
                }
            }
        }
        
        mgmt.commit()
        println "✅ Schema and indexes created"
    }

    createSchemaAndIndexes(vertexKeys, edgeKeys)

    // --- Load vertices ---
    println "\n📋 Loading vertices..."
    def jsonSlurper = new JsonSlurper()
    def vertexJson = jsonSlurper.parse(vertexFileObj)
    println "Found ${vertexJson.size()} vertices to process"

    vertexJson.each { obj ->
        try {
            def vertex = g.addV("YCSBVertex")
            obj.each { key, value ->
                if (key == "_id" && value != null) {
                    vertex.property(T.id, value.toString())
                }
                if (value != null) {
                    vertex.property(key.toString(), value.toString())
                }
            }
            // Add count property for fast counting
            vertex.property("_count", 1)
            def v = vertex.next()
            vertexMap[obj["_id"]] = v
            vertexCounter++
            if (vertexCounter % batchSize == 0) {
                graph.tx().commit()
                println "🔄 Committed ${vertexCounter} vertices..."
            }
        } catch (Exception e) {
            println "❌ Vertex error ${obj['_id']}: ${e.message}"
        }
    }
    graph.tx().commit()
    println "✅ Loaded ${vertexCounter} vertices"

    // --- Load edges ---
    println "\n📋 Loading edges..."
    def edgeJson = jsonSlurper.parse(edgeFileObj)
    println "Found ${edgeJson.size()} edges to process"

    edgeJson.each { obj ->
        try {
            def outV = vertexMap[obj["_outV"]]
            def inV  = vertexMap[obj["_inV"]]
            if (outV && inV) {
                def inVertex = g.V(inV).next()
                def edge = g.V(outV).addE("YCSBEdge").to(inVertex)
                obj.each { key, value ->
                    if (value != null) edge.property(key, value.toString())
                }
                // Add count property for fast counting
                edge.property("_count", 1)
                edge.next()
                edgeCounter++
                if (edgeCounter % batchSize == 0) {
                    graph.tx().commit()
                    println "🔄 Committed ${edgeCounter} edges..."
                }
            } else {
                skippedEdges++
            }
        } catch (Exception e) {
            skippedEdges++
            println "❌ Edge error ${obj['_id']}: ${e.message}"
        }
    }
    graph.tx().commit()
    println "✅ Loaded ${edgeCounter} edges"
    if (skippedEdges > 0) println "⚠️ Skipped ${skippedEdges} edges"

    // --- ⭐ ENABLE ALL INDEXES ---
    def enableIndexes = { ->
        println "\n🔧 Enabling all indexes..."
        
        // Close transactions and wait for locks
        try {
            graph.getOpenTransactions().each { tx ->
                try { if (tx.isOpen()) tx.commit() } catch (Exception e) {}
            }
        } catch (Exception e) {}
        
        println "⏳ Waiting 10 seconds for locks to clear..."
        Thread.sleep(10000)
        
        def mgmt = graph.openManagement()
        def allIndexes = mgmt.getGraphIndexes(Vertex.class) + mgmt.getGraphIndexes(Edge.class)
        
        allIndexes.each { idx ->
            def indexName = idx.name()
            def firstKey = idx.getFieldKeys()[0]
            def status = idx.getIndexStatus(firstKey)
            
            println "Index ${indexName}: ${status}"
            
            if (status.toString() == 'INSTALLED') {
                println "  🔄 Registering ${indexName}..."
                try {
                    def future = mgmt.updateIndex(idx, SchemaAction.REGISTER_INDEX)
                    mgmt.commit()
                    future.get()
                    
                    // Reopen and reindex
                    Thread.sleep(5000)
                    mgmt = graph.openManagement()
                    idx = mgmt.getGraphIndex(indexName)
                    status = idx.getIndexStatus(firstKey)
                    
                    if (status.toString() == 'REGISTERED') {
                        println "  🔄 Reindexing ${indexName}..."
                        future = mgmt.updateIndex(idx, SchemaAction.REINDEX)
                        mgmt.commit()
                        future.get()
                        println "  ✅ ${indexName} enabled"
                    }
                    
                    mgmt = graph.openManagement()
                } catch (Exception e) {
                    println "  ⚠️ Error enabling ${indexName}: ${e.message}"
                    try { mgmt.rollback() } catch (Exception re) {}
                    mgmt = graph.openManagement()
                }
            }
        }
        
        if (mgmt.isOpen()) mgmt.rollback()
    }
    
    enableIndexes()

    // --- Final status check ---
    println "\n📊 Final Index Status:"
    def mgmt = graph.openManagement()
    def allIndexes = mgmt.getGraphIndexes(Vertex.class) + mgmt.getGraphIndexes(Edge.class)
    allIndexes.each { idx ->
        def status = idx.getIndexStatus(idx.getFieldKeys()[0])
        def emoji = status.toString() == 'ENABLED' ? '✅' : '⏳'
        println "${emoji} ${idx.name()}: ${status}"
    }
    mgmt.rollback()

    // --- Summary ---
    println "\n📊 === LOAD SUMMARY ==="
    println "📈 Vertices loaded: ${vertexCounter}"
    println "🔗 Edges loaded: ${edgeCounter}"
    println "⚠️ Skipped edges: ${skippedEdges}"
    println "🎉 Preload complete!"

} catch (Exception e) {
    println "💥 Fatal error: ${e.message}"
    e.printStackTrace()
    if (graph?.tx()?.isOpen()) graph.tx().rollback()
} finally {
    try {
        if (graph) {
            try {
                graph.getOpenTransactions().each { tx ->
                    try { if (tx.isOpen()) tx.rollback() } catch (Exception e) {}
                }
            } catch (Exception e) {}
            
            try {
                graph.close()
                println "✅ Graph closed"
            } catch (Exception e) {
                if (!e.message?.contains("already been closed")) {
                    println "⚠️ Close warning: ${e.message}"
                }
            }
        }
    } catch (Exception e) {}
}