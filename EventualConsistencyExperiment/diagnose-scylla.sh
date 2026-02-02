#!/bin/bash

echo "====================================="
echo "ScyllaDB Multi-DC Diagnostic Script"
echo "====================================="
echo ""

# Check if containers are running
echo "1. Checking container status..."
for i in 1 4; do
    if docker ps | grep -q "scylla${i}"; then
        echo "  ✓ scylla${i} is running"
    else
        echo "  ✗ scylla${i} is NOT running"
    fi
done
echo ""

# Check cluster status from DC1
echo "2. Checking cluster status from DC1 (scylla1)..."
docker exec scylla1 nodetool status
echo ""

# Check datacenter configuration
echo "3. Checking datacenter configuration..."
echo "   DC1 nodes (scylla1, scylla2, scylla3):"
for i in 1; do
    dc=$(docker exec scylla${i} nodetool info | grep "Data Center" | awk '{print $4}')
    rack=$(docker exec scylla${i} nodetool info | grep "Rack" | awk '{print $3}')
    echo "     scylla${i}: DC=$dc, Rack=$rack"
done

echo "   DC2 nodes (scylla4, scylla5, scylla6):"
for i in 4; do
    dc=$(docker exec scylla${i} nodetool info | grep "Data Center" | awk '{print $4}')
    rack=$(docker exec scylla${i} nodetool info | grep "Rack" | awk '{print $3}')
    echo "     scylla${i}: DC=$dc, Rack=$rack"
done
echo ""

# Check keyspace replication
echo "4. Checking keyspace replication strategies..."
docker exec scylla1 cqlsh -e "DESCRIBE KEYSPACES;"
echo ""

echo "5. Checking 'janusgraph' keyspace (if it exists)..."
if docker exec scylla1 cqlsh -e "DESCRIBE KEYSPACE janusgraph;" 2>/dev/null; then
    echo "   ✓ janusgraph keyspace exists"
else
    echo "   ✗ janusgraph keyspace does not exist or not accessible"
fi
echo ""

# Check network latency
echo "6. Testing network latency between DCs..."
echo "   From DC1 to DC2:"
for i in 1; do
    for j in 4; do
        latency=$(docker exec scylla${i}-netem ping -c 1 scylla${j} 2>/dev/null | grep "time=" | sed 's/.*time=\([0-9.]*\).*/\1/')
        if [ -n "$latency" ]; then
            echo "     scylla${i} -> scylla${j}: ${latency}ms"
        else
            echo "     scylla${i} -> scylla${j}: FAILED"
        fi
    done
done
echo ""

# Check if netem containers exist
echo "7. Checking netem containers..."
for i in 1 4; do
    if docker ps | grep -q "scylla${i}-netem"; then
        echo "  ✓ scylla${i}-netem exists"
    else
        echo "  ✗ scylla${i}-netem does NOT exist"
    fi
done
echo ""

# Check Gremlin server connectivity
echo "8. Checking Gremlin server connectivity..."
echo "   Testing port 8182 (should be Gremlin on DC1):"
if nc -z localhost 8182 2>/dev/null; then
    echo "     ✓ Port 8182 is open"
else
    echo "     ✗ Port 8182 is closed"
fi

echo "   Testing port 8183 (should be Gremlin on DC2):"
if nc -z localhost 8183 2>/dev/null; then
    echo "     ✓ Port 8183 is open"
else
    echo "     ✗ Port 8183 is closed"
fi
echo ""

# Provide recommendations
echo "====================================="
echo "RECOMMENDATIONS:"
echo "====================================="
echo ""

# Check if we see both DCs
dc_count=$(docker exec scylla1 nodetool status 2>/dev/null | grep -E "^(DC|Datacenter)" | wc -l)
if [ "$dc_count" -lt 2 ]; then
    echo "⚠️  CRITICAL: Only one datacenter detected!"
    echo "   Action: Check DC1.properties and DC2.properties files"
    echo "   Both should have different 'dc' values (e.g., 'dc1' and 'dc2')"
    echo ""
fi

# Check UN status
un_count=$(docker exec scylla1 nodetool status 2>/dev/null | grep "^UN" | wc -l)
if [ "$un_count" -ne 2 ]; then
    echo "⚠️  WARNING: Not all nodes are UP and Normal (UN)"
    echo "   Current UN nodes: $un_count (expected: 2)"
    echo "   Action: Wait for cluster to stabilize or check logs"
    echo ""
fi

echo "✓ Diagnostics complete!"
echo ""
echo "Next steps:"
echo "1. Verify both datacenters are visible in cluster status"
echo "2. Check keyspace replication strategy includes both DCs"
echo "3. Ensure Gremlin servers connect to their respective DCs"
echo "4. Verify network latency is applied between DCs"