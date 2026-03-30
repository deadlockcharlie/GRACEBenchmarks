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
var __await = (this && this.__await) || function (v) { return this instanceof __await ? (this.v = v, this) : new __await(v); }
var __asyncGenerator = (this && this.__asyncGenerator) || function (thisArg, _arguments, generator) {
    if (!Symbol.asyncIterator) throw new TypeError("Symbol.asyncIterator is not defined.");
    var g = generator.apply(thisArg, _arguments || []), i, q = [];
    return i = Object.create((typeof AsyncIterator === "function" ? AsyncIterator : Object).prototype), verb("next"), verb("throw"), verb("return", awaitReturn), i[Symbol.asyncIterator] = function () { return this; }, i;
    function awaitReturn(f) { return function (v) { return Promise.resolve(v).then(f, reject); }; }
    function verb(n, f) { if (g[n]) { i[n] = function (v) { return new Promise(function (a, b) { q.push([n, v, a, b]) > 1 || resume(n, v); }); }; if (f) i[n] = f(i[n]); } }
    function resume(n, v) { try { step(g[n](v)); } catch (e) { settle(q[0][3], e); } }
    function step(r) { r.value instanceof __await ? Promise.resolve(r.value.v).then(fulfill, reject) : settle(q[0][2], r); }
    function fulfill(value) { resume("next", value); }
    function reject(value) { resume("throw", value); }
    function settle(f, v) { if (f(v), q.shift(), q.length) resume(q[0][0], q[0][1]); }
};
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.Neo4jDriver = void 0;
const logging_1 = require("../helpers/logging");
const driver_1 = require("./driver");
const neo4j_driver_1 = __importDefault(require("neo4j-driver"));
class Neo4jDriver extends driver_1.DatabaseDriver {
    constructor() {
        super();
        logging_1.logger.info("Connecting to bolt on :", process.env.DATABASE_URI);
        this.driver = neo4j_driver_1.default.driver(process.env.DATABASE_URI, neo4j_driver_1.default.auth.basic(process.env.NEO4J_USER, process.env.NEO4J_PASSWORD));
        (() => __awaiter(this, void 0, void 0, function* () {
            yield this.driver.getServerInfo();
            logging_1.logger.info("Connected to the Database.");
        }))();
    }
    getGraph() {
        return __awaiter(this, void 0, void 0, function* () {
            const query = `MATCH (n) RETURN n LIMIT 50`;
            const params = null;
            try {
                const result = yield this.driver.executeQuery(query);
                return result;
            }
            catch (err) {
                logging_1.logger.error(err);
                throw err;
            }
        });
    }
    addVertex(labels, properties) {
        return __awaiter(this, void 0, void 0, function* () {
            logging_1.logger.info("Adding vertex");
            const labelString = labels.join(":");
            // Build and execute Cypher query
            const query = `CREATE (n:${labelString} $properties) RETURN n`;
            const params = { properties: properties };
            try {
                yield this.driver.executeQuery(query, params);
            }
            catch (err) {
                logging_1.logger.error("Error in add vertex: " + err);
                throw err;
            }
        });
    }
    deleteVertex(id) {
        return __awaiter(this, void 0, void 0, function* () {
            const query = "MATCH (n {id: \"" + id + "\"}) DELETE n";
            // logger.error("Delete vertex query: "+ query);
            try {
                yield this.driver.executeQuery(query, null);
            }
            catch (err) {
                logging_1.logger.error("Error in delete vertex: " + err);
                throw err;
            }
        });
    }
    addEdge(relationLabels, sourcePropName, sourcePropValue, targetPropName, targetPropValue, properties) {
        return __awaiter(this, void 0, void 0, function* () {
            const relationLabelString = relationLabels.join(":");
            const query = `
          MATCH (a {${sourcePropName}: "${sourcePropValue}"}), 
                (b {${targetPropName}: "${targetPropValue}"})
          CREATE (a)-[r:${relationLabelString}]->(b)
          SET r += $properties
          RETURN r;
            `;
            const params = {
                sourcePropName: sourcePropName,
                sourcePropValue: sourcePropValue,
                targetPropName: targetPropName,
                targetPropValue: targetPropValue,
                properties: properties,
            };
            try {
                yield this.driver.executeQuery(query, params);
            }
            catch (err) {
                logging_1.logger.error("Error in add edge: " + err);
                throw err;
            }
        });
    }
    deleteEdge(id) {
        return __awaiter(this, void 0, void 0, function* () {
            const query = "MATCH ()-[r {id: \"" + id + "\"}]-() DELETE r";
            logging_1.logger.info("Delete edge query: " + query);
            try {
                yield this.driver.executeQuery(query, null);
            }
            catch (err) {
                logging_1.logger.error("Error in delete edge: " + err);
                throw err;
            }
        });
    }
    setVertexProperty(vid, key, value) {
        return __awaiter(this, void 0, void 0, function* () {
            const query = "MATCH (n {id: \"" + vid + "\"}) SET n." + key + "=\"" + value + "\"  RETURN n;";
            logging_1.logger.info("Set vertex property query: " + query);
            try {
                const result = yield this.driver.executeQuery(query, null);
                if (result.records.length === 0) {
                    throw new Error(`Vertex with id ${vid} not found.`);
                }
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
            const query = "MATCH ()-[r {id: \"" + eid + "\"}]->() SET r." + key + "=\"" + value + "\"  RETURN r";
            try {
                const result = yield this.driver.executeQuery(query, null);
                if (result.records.length === 0) {
                    throw new Error(`Edge with id ${eid} not found.`);
                }
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
            const query = "MATCH (n {id: \"" + vid + "\"}) REMOVE n." + key + " RETURN n";
            try {
                const result = yield this.driver.executeQuery(query, null);
                if (result.records.length === 0) {
                    throw new Error(`Vertex with id ${vid} not found.`);
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
            const query = "MATCH ()-[r {id: \"" + eid + "\"}]->() REMOVE r." + key + " RETURN r";
            try {
                const result = yield this.driver.executeQuery(query, null);
                if (result.records.length === 0) {
                    throw new Error(`Edge with id ${eid} not found.`);
                }
                logging_1.logger.info(`Property ${key} removed from edge with id ${eid}`);
            }
            catch (err) {
                logging_1.logger.error("Error in remove edge property: " + err);
                throw err;
            }
        });
    }
    streamQuery(session_1, query_1) {
        return __asyncGenerator(this, arguments, function* streamQuery_1(session, query, batchSize = 10000) {
            let skip = 0;
            while (true) {
                const result = yield __await(this.driver.executeQuery(`${query} SKIP $skip LIMIT $limit`, { skip: neo4j_driver_1.default.int(skip), limit: neo4j_driver_1.default.int(batchSize) }));
                if (result.records.length === 0)
                    break;
                yield yield __await(result.records); // yield a batch of records
                skip += batchSize;
            }
        });
    }
}
exports.Neo4jDriver = Neo4jDriver;
//# sourceMappingURL=neo4jDriver.js.map