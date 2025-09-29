echo "Importing data from CSVs into arangodb"

arangosh --server.endpoint "${1}" --server.authentication false --javascript.execute-string "db._createDatabase('ycsb');"
arangosh --server.endpoint "${1}" --server.authentication false --javascript.execute-string "db._useDatabase('ycsb'); db._createDocumentCollection('vertices', {replicationFactor: ${2}, writeConcern: 2}); db._createEdgeCollection('edges', {replicationFactor: ${2}, writeConcern: 2});"

arangoimport --server.endpoint "${1}" --server.database "ycsb" --file "/var/lib/arangodb/import/vertices.csv" --type csv --collection "vertices"  --overwrite true  --translate "_id=_key" --server.authentication false

arangoimport --server.endpoint "${1}" --server.database "ycsb" --file "/var/lib/arangodb/import/edges.csv" --type csv --collection "edges" --create-collection-type "edge"  --overwrite true  --from-collection-prefix "vertices" --to-collection-prefix "vertices" --server.authentication false --translate "_id=_key" --translate "_outV=_from" --translate "_inV=_to" --translate "_id=id" 