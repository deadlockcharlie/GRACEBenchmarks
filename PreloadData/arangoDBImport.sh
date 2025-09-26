echo "Importing data from CSVs into arangodb"

arangoimport --server.endpoint "${1}" --server.database "ycsb" --file "/var/lib/arangodb/import/vertices.csv" --type csv --collection "vertices" --create-collection true --overwrite true --create-database true --translate "_id=_key" --server.authentication false

arangoimport --server.endpoint "${1}" --server.database "ycsb" --file "/var/lib/arangodb/import/edges.csv" --type csv --collection "edges" --create-collection-type "edge" --create-collection true --overwrite true --create-database true --translate "_outV=_from" --translate "_inV=_to" --translate "_id=id" --from-collection-prefix "vertices" --to-collection-prefix "vertices" --server.authentication false