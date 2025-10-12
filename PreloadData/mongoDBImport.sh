#!/bin/bash
echo "Importing data from CSVs into mongodb"

mongoimport -d grace -c vertices --type csv --file  "/var/lib/mongodb/import/vertices.csv" --headerline --host "${1}"

mongoimport -d grace -c edges --type csv --file  "/var/lib/mongodb/import/edges.csv" --headerline --host "${1}"

echo "Creating indexes on MongoDB collections..."

mongosh --host "${1}" --eval '
db = db.getSiblingDB("grace");

// Index on "id" field in vertices collection
db.vertices.createIndex({ id: 1 }, { unique: true, sparse: true});
db.vertices.createIndex({ searchKey: 1 });

// Index on "source" and "target" fields in edges collection
db.edges.createIndex({ _outV: 1 });
db.edges.createIndex({ _inV: 1 });
db.edges.createIndex({ searchKey: 1 });

// Optional: compound index for faster edge lookups
db.edges.createIndex({ _outV: 1, _inV: 1 });
'