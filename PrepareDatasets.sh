if [ ! -f $DATA_DIRECTORY/yeast.json ]; then 
curl https://zenodo.org/records/15571202/files/yeast.json?download=1 > $DATA_DIRECTORY/yeast.json
fi

if [ ! -f $DATA_DIRECTORY/mico.json ]; then 
curl https://zenodo.org/records/15571202/files/mico.json?download=1 > $DATA_DIRECTORY/mico.json
fi
if [ ! -f $DATA_DIRECTORY/ldbc.json ]; then 
curl https://zenodo.org/records/15571202/files/ldbc.json?download=1 > $DATA_DIRECTORY/ldbc.json
fi
if [ ! -f $DATA_DIRECTORY/frbo.json ]; then 
curl https://zenodo.org/records/15571202/files/freebase_org.json?download=1 > $DATA_DIRECTORY/frbo.json
fi
if [ ! -f $DATA_DIRECTORY/frbs.json ]; then 
curl https://zenodo.org/records/15571202/files/freebase_small.json?download=1 > $DATA_DIRECTORY/frbs.json
fi
if [ ! -f $DATA_DIRECTORY/frbm.json ]; then 
curl https://zenodo.org/records/15571202/files/freebase_medium.json?download=1 > $DATA_DIRECTORY/frbm.json
fi
cp $ROOT_DIRECTORY/workloadGenerator.py $DATA_DIRECTORY/
cp $ROOT_DIRECTORY/jsontoCSV.py $DATA_DIRECTORY/

cd $DATA_DIRECTORY 


if [ ! -f ${DATASET_NAME}_load_vertices.json ] || [ ! -f ${DATASET_NAME}_load_edges.json ]; then 
    python3 workloadGenerator.py --input $DATASET_NAME.json --out-prefix $DATASET_NAME --split 0.8 --shards $(nproc --all)
fi

python3 jsontoCSV.py ${DATASET_NAME}_load_vertices.json ${DATASET_NAME}_load_edges.json 

