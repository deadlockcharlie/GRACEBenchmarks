To run this experiment, you are required to first spin up two datacenters.
Ensure you are in the EventualConsistencyExperiment directory before beginning the setup. 

Deploying the infrastructure
-----
Spin up DC1: `docker compose -f Dockerfiles/JanusgraphDC1 up -d`

Once the deployment is ready, check that the nodes in the dc are up `docker exec scylla1 nodetool status`. Wait until all nodes show status `UN` (Up/Normal)

Then spin up DC2: `docker compose -f Dockerfiles/JanusgraphDC2 up -d`

Check the status of DC2. `docker exec scylla4 nodetool status`

At this point, you should observe two datacenters `dc1` and `dc2` with 3 nodes each. All the nodes should have status `UN`. 

Creating the schema in Janusgraph
-----
Now, we need to setup the schemas for janusgraph and ensure it is replicated across datacenters. 
To do this, start a janusgraph container. Then, execute the following. 

1. First, start a gremlin shell: `docker exec -it janusgraph-dc1 /bin/bash`
2. Start a gremlin console: `bin/gremlin.sh`
3. Connect to the running janusgraph instance: `graph = JanusGraphFactory.open('conf/janusgraph-cql.properties')`
4. Initialise a management object: `mgmt = graph.openManagement()`
`

Now we can create the properties for the schema:

1. `mgmt.makePropertyKey("name").dataType(String.class).make()`
2. `mgmt.makePropertyKey("value").dataType(Integer.class).make()`
3. `mgmt.makePropertyKey("last_updated_by").dataType(String.class).make()`
4. `mgmt.makePropertyKey("update_timestamp").dataType(Integer.class).make()`
5. `mgmt.makePropertyKey("update_count").dataType(Integer.class).make()`
5. `mgmt.makeVertexLabel("person").make()`

use `:q` to exit the gremlin shell.
then `exit` to exit the shell.

Setup latency between datacenters
-----
To simulate network latency between the two datacenters, we will use `tc` (traffic control) command to add latency to the network interface of the ScyllaDB nodes in DC2.

`./setup-latency.sh`

Executing the Experiment
-----
To run the eventual consistency experiment, execute the following command from the Root directory:

`python3 scripts/benchmarks/DivergenceInjection.py`