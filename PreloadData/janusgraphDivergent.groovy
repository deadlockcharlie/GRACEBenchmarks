import org.janusgraph.core.JanusGraphFactory
import org.janusgraph.core.JanusGraph

println "=== Creating schema for divergence experiment ==="

JanusGraph graph = null

try {
    if (args.size() < 1) {
        println "Usage: groovy schema_creation.groovy <configFile>"
        System.exit(1)
    }

    def propertiesDir = args[0]
    
    // --- CLEANUP FUNCTION ---
    def cleanupExistingInstances = { configPath ->
        println "\n🧹 Cleaning up existing instances..."
        JanusGraph tempGraph = null
        try {
            tempGraph = JanusGraphFactory.open(configPath)
            def mgmt = tempGraph.openManagement()
            def instances = mgmt.getOpenInstances()
            
            if (instances.size() > 0) {
                println "Found ${instances.size()} instance(s):"
                instances.each { instanceId ->
                    println "  ${instanceId}"
                    // Force close all non-current instances
                    if (!instanceId.contains("(current)")) {
                        try {
                            println "  🔄 Force closing: ${instanceId}"
                            mgmt.forceCloseInstance(instanceId)
                        } catch (Exception e) {
                            println "  ⚠️ Could not force close ${instanceId}: ${e.message}"
                        }
                    }
                }
                mgmt.commit()
            } else {
                println "No existing instances found"
                mgmt.rollback()
            }
        } catch (Exception e) {
            println "⚠️ Cleanup attempt failed (this may be OK): ${e.message}"
        } finally {
            if (tempGraph != null) {
                try {
                    tempGraph.close()
                } catch (Exception e) {}
            }
        }
        
        // Wait for cleanup
        println "⏳ Waiting 30 seconds for instance cleanup..."
        Thread.sleep(30000)
    }
    
    // Run cleanup first
    cleanupExistingInstances(propertiesDir)

    // Now open the graph
    println "\n🔹 Opening JanusGraph connection..."
    graph = JanusGraphFactory.open(propertiesDir)
    def g = graph.traversal()
    
    println "✅ Connected successfully"

    // Create schema
    println "\n🔧 Creating schema..."
    def mgmt = graph.openManagement()
    
    def ensureProperty = { name, type ->
        def existing = mgmt.getPropertyKey(name)
        if (existing == null) {
            println "  Creating property key: ${name}"
            mgmt.makePropertyKey(name).dataType(type).make()
        } else {
            println "  Property key exists: ${name}"
        }
    }
    
    def ensureVertexLabel = { name ->
        def existing = mgmt.getVertexLabel(name)
        if (existing == null) {
            println "  Creating vertex label: ${name}"
            mgmt.makeVertexLabel(name).make()
        } else {
            println "  Vertex label exists: ${name}"
        }
    }
    
    // Define schema elements
    ensureProperty("name", String.class)
    ensureProperty("age", Integer.class)
    ensureProperty("city", String.class)
    ensureProperty("source", String.class)
    ensureVertexLabel("Person")

    mgmt.commit()
    
    println "\n✅ Schema creation complete!"

} catch (Exception e) {
    println "\n❌ Error: ${e.message}"
    e.printStackTrace()
    System.exit(1)
} finally {
    if (graph != null) {
        try {
            // Close any open transactions
            graph.getOpenTransactions().each { tx ->
                if (tx.isOpen()) {
                    try { tx.rollback() } catch (Exception e) {}
                }
            }
            
            // Give pending operations time to complete
            println "⏳ Waiting for pending operations..."
            Thread.sleep(2000)
            
            // Close graph
            graph.close()
            println "✅ Graph connection closed"
        } catch (Exception e) {
            if (!e.message?.contains("already been closed")) {
                println "⚠️ Error during close: ${e.message}"
            }
        }
    }
}