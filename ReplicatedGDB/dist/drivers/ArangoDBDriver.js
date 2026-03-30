"use strict";
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.ArangoDBDriver = void 0;
const logging_1 = require("../helpers/logging");
const driver_1 = require("./driver");
const arangojs_1 = require("arangojs");
class ArangoDBDriver extends driver_1.DatabaseDriver {
    constructor() {
        super();
        logging_1.logger.info("Connecting to ArangoDB on :", process.env.DATABASE_URI);
        this.driver = new arangojs_1.Database(process.env.DATABASE_URI);
        (() => __awaiter(this, void 0, void 0, function* () {
            const now = Date.now();
            yield this.driver.query((0, arangojs_1.aql) `RETURN ${now}`);
            const databases = yield this.driver.listDatabases();
            if (!databases.includes("grace")) {
                yield this.driver.createDatabase("grace");
            }
            try {
                this.vertices = this.driver.collection("vertices");
                this.edges = this.driver.collection("edges");
                if (!(yield this.vertices.exists())) {
                    logging_1.logger.info("creating vertex collection");
                    yield this.vertices.create();
                }
                if (!(yield this.edges.exists())) {
                    logging_1.logger.info("creating edge collection");
                    yield this.edges.create({ type: 3 }); //Edge collection type should have fields _to and _from which should be valid vertex IDs in the vertex collection.
                }
                logging_1.logger.info("Connected to the Database.");
            }
            catch (err) {
                logging_1.logger.error("Error creating colelctions : " + err);
            }
            logging_1.logger.warn("Preload data flag is " + process.env.PRELOAD);
            if (process.env.PRELOAD == "True") {
                logging_1.logger.info("Materializing data from the db to the middleware");
                //     (async () => {
                //     const session = this.driver.session();
                //     // for await (const batch of this.streamQuery(session, "MATCH (n) RETURN n")) {
                //     //   for (const record of batch) {
                //     //     const node = record.get("n");
                //     //     // logger.info(JSON.stringify(node));
                //     //     graph.addVertex(node.labels, node.properties, false, true);
                //     //   }
                //     // }
                //     // logger.info("✅ All vertices loaded")
                //     // for await (const batch of this.streamQuery(session, "MATCH (a)-[r]->(b) RETURN id(r) as id, id(a) as source, id(b) as target, r")) {
                //     //   for (const record of batch) {
                //     //     const node = record.get("r");
                //     //     // logger.info(JSON.stringify(node));
                //     //     graph.addEdge(["Edge"], ["Vertex"],"id", node.properties.source, ["Vertex"], "id", node.properties.target, node.properties, false, true);
                //     //   }
                //     // }
                //     // logger.info("✅ All Edges loaded")
                //     await session.close();
                //   })();
            }
        }))();
    }
    getGraph() {
        return __awaiter(this, void 0, void 0, function* () {
            const result = yield this.driver.query((0, arangojs_1.aql) `FOR v IN vertices LIMIT 50 RETURN v`);
            const data = yield result.all();
            // logger.info(JSON.stringify(result));
            return data;
        });
    }
    addVertex(labels, properties) {
        return __awaiter(this, void 0, void 0, function* () {
            logging_1.logger.info("Adding vertex");
            // const labelString = labels.join(":");
            //  // Build and execute Cypher query
            // const query = `CREATE (n:${labelString} $properties) RETURN n`;
            // const params = {properties: properties };
            try {
                yield this.vertices.save({ _key: properties.id, properties: properties });
            }
            catch (err) {
                logging_1.logger.error("Error in add vertex: " + err);
                throw err;
            }
        });
    }
    deleteVertex(id) {
        return __awaiter(this, void 0, void 0, function* () {
            try {
                yield this.vertices.remove(id);
            }
            catch (err) {
                logging_1.logger.error("Error in delete vertex: " + err);
                throw err;
            }
        });
    }
    addEdge(relationLabels, sourcePropName, sourcePropValue, targetPropName, targetPropValue, properties) {
        return __awaiter(this, void 0, void 0, function* () {
            try {
                yield this.edges.save({
                    _from: "vertices/" + sourcePropValue,
                    _to: "vertices/" + targetPropValue,
                    _key: properties.id,
                    properties: properties
                });
            }
            catch (err) {
                logging_1.logger.error("Error in add edge: " + err);
                throw err;
            }
        });
    }
    deleteEdge(id) {
        return __awaiter(this, void 0, void 0, function* () {
            try {
                yield this.edges.remove(id);
            }
            catch (err) {
                logging_1.logger.error("Error in delete edge: " + err);
                throw err;
            }
        });
    }
    setVertexProperty(vid, key, value) {
        return __awaiter(this, void 0, void 0, function* () {
            // const query = "MATCH (n {id: \""+vid+"\"}) SET n."+key+"=\""+ value+"\"  RETURN n;";
            // logger.info("Set vertex property query: "+ query);
            try {
                const vertex = yield this.vertices.document(vid);
                if (!vertex) {
                    throw new Error(`Vertex with id ${vid} not found.`);
                }
                const result = yield this.vertices.update(vid, { properties: Object.assign(Object.assign({}, vertex.properties), { [key]: value }) });
                logging_1.logger.info(`Property ${key} set to ${value} for vertex with id ${vid}`);
            }
            catch (err) {
                logging_1.logger.error("Error in set vertex property: " + err);
                throw err;
            }
        });
    }
    setEdgeProperty(eid, key, value) {
        return __awaiter(this, void 0, void 0, function* () {
            try {
                const edge = yield this.edges.document(eid);
                if (!edge) {
                    throw new Error(`Edge with id ${eid} not found.`);
                }
                const result = yield this.edges.update(eid, { properties: Object.assign(Object.assign({}, edge.properties), { [key]: value }) });
                logging_1.logger.info(`Property ${key} set to ${value} for edge with id ${eid}`);
            }
            catch (err) {
                logging_1.logger.error("Error in set edge property: " + err);
                throw err;
            }
        });
    }
    removeVertexProperty(vid, key) {
        return __awaiter(this, void 0, void 0, function* () {
            try {
                const vertex = yield this.vertices.document(vid);
                if (vertex.properties && vertex.properties[key] != undefined) {
                    // const updatedProperties= {...vertex.properties};
                    // delete updatedProperties[key];
                    // logger.info("Updated properties: "+ JSON.stringify(updatedProperties));
                    vertex.properties[key] = null;
                    const result = yield this.vertices.update(vid, vertex, { keepNull: false });
                }
                else {
                    throw new Error(`Property ${key} not found on vertex with id ${vid}`);
                }
                logging_1.logger.info(`Property ${key} removed from vertex with id ${vid}`);
            }
            catch (err) {
                logging_1.logger.error("Error in remove vertex property: " + err);
                throw err;
            }
        });
    }
    removeEdgeProperty(eid, key) {
        return __awaiter(this, void 0, void 0, function* () {
            try {
                const edge = yield this.edges.document(eid);
                if (edge.properties && edge.properties[key] != undefined) {
                    const updatedEdge = edge;
                    // const updatedProperties= {...edge.properties};
                    // updatedProperties[key] = null;
                    // delete updatedProperties[key];
                    updatedEdge.properties[key] = null;
                    logging_1.logger.info("Updated edge: " + JSON.stringify(updatedEdge));
                    yield this.edges.update(eid, updatedEdge, { keepNull: false });
                }
                else {
                    throw new Error(`Property ${key} not found on edge with id ${eid}`);
                }
                logging_1.logger.info(`Property ${key} removed from edge with id ${eid}`);
            }
            catch (err) {
                logging_1.logger.error("Error in remove edge property: " + err);
                throw err;
            }
        });
    }
}
exports.ArangoDBDriver = ArangoDBDriver;
//# sourceMappingURL=ArangoDBDriver.js.map