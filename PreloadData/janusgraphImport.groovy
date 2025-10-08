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
        def mgmt = graph.openManagement()

        if(!mgmt.containsVertexLabel("YCSBVertex")) mgmt.makeVertexLabel("YCSBVertex").make()
        if(!mgmt.containsEdgeLabel("YCSBEdge")) mgmt.makeEdgeLabel("YCSBEdge").make()

        VK.add("searchKey")

        VK.each { key ->
            def propKey = mgmt.getPropertyKey(key)
            if ((!propKey)) {
                propKey = mgmt.makePropertyKey(key).dataType(String.class).make()
                println "🆕 Created vertex property key: ${key}"
                // if (key == "_id") {
                //     mgmt.buildIndex("vertexById", Vertex.class).addKey(propKey).buildCompositeIndex()
                //     println "📊 Composite index created for _id"
                // }
                if(key =="_id") {
                    mgmt.buildIndex("v_${key}_composite", Vertex.class)
                        .addKey(propKey).buildCompositeIndex()
                    // mgmt.buildIndex("v_${key}_mixed", Vertex.class)
                    //     .addKey(propKey, Mapping.TEXT.asParameter())
                    //     .buildMixedIndex("search")
                } 
                println "🔎 Mixed index created for vertex key: ${key}"
            }
        }

        EK.each { key ->
            def propKey = mgmt.getPropertyKey(key)
            if ((!propKey)) {
                propKey = mgmt.makePropertyKey(key).dataType(String.class).make()
                println "🆕 Created edge property key: ${key}"
                // if (key == "_id") {
                //     mgmt.buildIndex("edgeById", Edge.class).addKey(propKey).buildCompositeIndex()
                //     println "📊 Composite index created for edge _id"
                // }
                if(key =="_id" && key =="_type" && key =="_inV" && key =="_outV"){
                    mgmt.buildIndex("e_${key}_composite", Edge.class)
                        .addKey(propKey).buildCompositeIndex()
                    // mgmt.buildIndex("e_${key}_mixed", Edge.class)
                    //     .addKey(propKey, Mapping.TEXT.asParameter())
                    //     .buildMixedIndex("search")
                }
                println "🔎 Mixed index created for edge key: ${key}"
            }
        }

        mgmt.commit()
        println "✅ Schema + indexes committed"
    }

    createSchemaAndIndexes(vertexKeys, edgeKeys)

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

    // --- ⭐ FIX: Reindex everything after load ---
    def reindex = { ->
        def mgmt = graph.openManagement()
        def allIndexes = mgmt.getGraphIndexes(Vertex.class) + mgmt.getGraphIndexes(Edge.class)
        allIndexes.each { idx ->
            try {
                // println "🔄 Reindexing ${idx.name}..."
                mgmt.updateIndex(idx, SchemaAction.REINDEX).get()
            } catch (Exception e) {
                println "⚠️ Could not reindex ${e.message}"
            }
        }
        mgmt.commit()
        println "✅ Reindex step complete"
    }

    reindex()

    // --- Summary ---
    def totalVertices = g.V().count().next()
    def totalEdges = g.E().count().next()
    println "\n📊 === LOAD SUMMARY ==="
    println "📈 Vertices loaded: ${vertexCounter} (total: ${totalVertices})"
    println "🔗 Edges loaded: ${edgeCounter} (total: ${totalEdges})"
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
