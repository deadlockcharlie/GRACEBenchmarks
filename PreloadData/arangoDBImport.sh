#!/bin/bash
echo "Importing data from CSVs into arangodb"

REPLICA_COUNT=$2
WRITE_CONCERN=$((REPLICA_COUNT / 2 + 1))

arangosh --server.endpoint "${1}" --server.authentication false --javascript.execute-string "db._createDatabase('ycsb');"
arangosh --server.endpoint "${1}" --server.authentication false --javascript.execute-string "db._useDatabase('ycsb'); db._createDocumentCollection('vertices', {replicationFactor: $REPLICA_COUNT, writeConcern: $WRITE_CONCERN}); db._createEdgeCollection('edges', {replicationFactor: $REPLICA_COUNT, writeConcern: $WRITE_CONCERN});"

arangosh --server.endpoint "${1}" --server.authentication false --javascript.execute-string "
db._useDatabase('ycsb');
db.vertices.ensureIndex({type: 'persistent', fields: ['id']});
db.vertices.ensureIndex({type: 'persistent', fields: ['searchKey']});
db.edges.ensureIndex({type: 'persistent', fields: ['id']});
db.edges.ensureIndex({type: 'persistent', fields: ['_from']});
db.edges.ensureIndex({type: 'persistent', fields: ['_to']});
db.edges.ensureIndex({type: 'persistent', fields: ['searchKey']});
"


arangoimport --server.endpoint "${1}" --server.database "ycsb" --file "/var/lib/arangodb/import/vertices.csv" --type csv --collection "vertices"  --overwrite true  --translate "_id=_key" --server.authentication false

arangoimport --server.endpoint "${1}" --server.database "ycsb" --file "/var/lib/arangodb/import/edges.csv" --type csv --collection "edges" --create-collection-type "edge"  --overwrite true  --from-collection-prefix "vertices" --to-collection-prefix "vertices" --server.authentication false --translate "_id=_key" --translate "_outV=_from" --translate "_inV=_to" --translate "_id=id" 