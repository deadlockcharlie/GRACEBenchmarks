import org.janusgraph.core.JanusGraphFactory
import org.janusgraph.core.schema.SchemaAction
import org.janusgraph.core.schema.Mapping
import org.apache.tinkerpop.gremlin.structure.T
import groovy.json.JsonSlurper

println "🎉 Starting JanusGraph JSON preload..."

// Top of the script
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
    
    // Ensure no open transactions before schema operations
    if (graph.tx().isOpen()) {
        graph.tx().commit()
    }

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

    // --- Schema setup ---
    def createSchemaAndIndexes = { VK, EK ->
        println "🔧 Starting schema creation..."
        
        // Step 1: Create vertex label
        def mgmt = graph.openManagement()
        try {
            if(!mgmt.containsVertexLabel("YCSBVertex")) {
                mgmt.makeVertexLabel("YCSBVertex").make()
                println "🆕 Created vertex label: YCSBVertex"
            }
            mgmt.commit()
            println "✅ Vertex label committed"
        } catch (Exception e) {
            println "⚠️ Vertex label creation error: ${e.message}"
            mgmt.rollback()
        }
        
        // Step 2: Create edge label separately
        mgmt = graph.openManagement()
        try {
            if(!mgmt.containsEdgeLabel("YCSBEdge")) {
                mgmt.makeEdgeLabel("YCSBEdge").make()
                println "🆕 Created edge label: YCSBEdge"
            }
            mgmt.commit()
            println "✅ Edge label committed"
        } catch (Exception e) {
            println "⚠️ Edge label creation error: ${e.message}"
            mgmt.rollback()
        }

        // Step 3: Create all vertex property keys in one batch
        VK.add("searchKey")
        mgmt = graph.openManagement()
        try {
            VK.each { key ->
                def propKey = mgmt.getPropertyKey(key)
                if (!propKey) {
                    mgmt.makePropertyKey(key).dataType(String.class).make()
                    println "🆕 Created vertex property key: ${key}"
                }
            }
            mgmt.commit()
            println "✅ Vertex properties committed"
        } catch (Exception e) {
            println "⚠️ Error creating vertex properties: ${e.message}"
            mgmt.rollback()
        }
        
        // Skip vertex indexes during bulk load for better performance
        println "⏭️ Skipping vertex index creation (create after bulk load)"

        // Step 4: Create all edge property keys in one batch
        EK.add("searchKey")
        mgmt = graph.openManagement()
        try {
            EK.each { key ->
                def propKey = mgmt.getPropertyKey(key)
                if (!propKey) {
                    mgmt.makePropertyKey(key).dataType(String.class).make()
                    println "🆕 Created edge property key: ${key}"
                }
            }
            mgmt.commit()
            println "✅ Edge properties committed"
        } catch (Exception e) {
            println "⚠️ Error creating edge properties: ${e.message}"
            mgmt.rollback()
        }
        
        // Skip edge indexes during bulk load for better performance
        println "⏭️ Skipping edge index creation (create after bulk load)"
        println "✅ Schema + indexes creation complete"
    }

    createSchemaAndIndexes(vertexKeys, edgeKeys)
    
    println "📝 Note: Create indexes after bulk load completes for better performance"

    // --- Load vertices ---
    def jsonSlurper = new JsonSlurper()
    def vertexJson = jsonSlurper.parse(vertexFileObj)
    println "📋 Found ${vertexJson.size()} vertices to process"

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
    println "✅ Finished loading ${vertexCounter} vertices"

    // --- Load edges ---
    def edgeJson = jsonSlurper.parse(edgeFileObj)
    println "📋 Found ${edgeJson.size()} edges to process"

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
    println "✅ Finished loading ${edgeCounter} edges"
    if (skippedEdges > 0) println "⚠️ Skipped ${skippedEdges} edges"

    // // --- ⭐ FIX: Reindex everything after load ---
    // def reindex = { ->
    //     def mgmt = graph.openManagement()
    //     def allIndexes = mgmt.getGraphIndexes(Vertex.class) + mgmt.getGraphIndexes(Edge.class)
    //     allIndexes.each { idx ->
    //         try {
    //             // println "🔄 Reindexing ${idx.name}..."
    //             mgmt.updateIndex(idx, SchemaAction.REINDEX).get()
    //         } catch (Exception e) {
    //             println "⚠️ Could not reindex ${e.message}"
    //         }
    //     }
    //     mgmt.commit()
    //     println "✅ Reindex step complete"
    // }

    // reindex()

    // --- Summary ---
    // def totalVertices = g.V().count().next()
    // def totalEdges = g.E().count().next()
    println "\n📊 === LOAD SUMMARY ==="
    println "📈 Vertices loaded: ${vertexCounter}"
    println "🔗 Edges loaded: ${edgeCounter}"
    println "⚠️ Skipped edges: ${skippedEdges}"
    println "🎉 JSON preload complete!"

} catch (Exception e) {
    println "💥 Fatal error: ${e.message}"
    e.printStackTrace()
    if (graph?.tx()?.isOpen()) graph.tx().rollback()
} finally {
    try {
        if (graph) graph.close()
    } catch (Exception ignore) {}
}
