#!/bin/bash
echo "Importing data from CSVs into mongodb"

mongoimport -d grace -c vertices --type csv --file  "/var/lib/mongodb/import/vertices.csv" --headerline --host "${1}"

mongoimport -d grace -c edges --type csv --file  "/var/lib/mongodb/import/edges.csv" --headerline --host "${1}"