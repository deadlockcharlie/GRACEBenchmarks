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
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.GremlinDriver = void 0;
const driver_1 = require("./driver");
const gremlin_1 = __importDefault(require("gremlin"));
const graph_1 = require("gremlin/lib/structure/graph");
const logging_1 = require("../helpers/logging");
const ws_1 = require("ws");
class GremlinDriver extends driver_1.DatabaseDriver {
    constructor() {
        super();
        console.log("Initializing Gremlin server connection on: " + process.env.DATABASE_URI);
        try {
            const ws = new ws_1.WebSocket(process.env.DATABASE_URI + "/gremlin", {
                rejectUnauthorized: false,
            });
            const dc = new gremlin_1.default.driver.DriverRemoteConnection(process.env.DATABASE_URI + "/gremlin", { webSocket: ws });
            const graph = new graph_1.Graph();
            this.driver = graph.traversal().withRemote(dc);
            console.log("Gremlin server connection initialized");
        }
        catch (err) {
            logging_1.logger.error(err);
            process.exit(1);
        }
    }
    getGraph() {
        return __awaiter(this, void 0, void 0, function* () {
            try {
                const result = yield this.driver.V().sample(50).toList();
                return result;
            }
            catch (err) {
                logging_1.logger.error("getGraph: " + err);
            }
        });
    }
    addVertex(labels, properties) {
        return __awaiter(this, void 0, void 0, function* () {
            logging_1.logger.info("Adding vertex");
            try {
                const traversal = this.driver.addV('Node');
                traversal.property('Labels', labels);
                logging_1.logger.info(traversal);
                for (const [key, value] of Object.entries(properties)) {
                    traversal.property(key, value);
                }
                logging_1.logger.info(traversal);
                const result = yield traversal.next();
                logging_1.logger.info(result);
            }
            catch (err) {
                logging_1.logger.error("addVertex: " + err);
                throw err;
            }
        });
    }
    deleteVertex(id) {
        try {
            (() => __awaiter(this, void 0, void 0, function* () {
                yield this.driver
                    .V()
                    .has("id", id)
                    .as("v")
                    .bothE()
                    .drop()
                    .select("v")
                    .drop()
                    .iterate();
            }))();
        }
        catch (err) {
            logging_1.logger.error(err);
            throw new err();
        }
    }
    addEdge(relationLabels, sourcePropName, sourcePropValue, targetPropName, targetPropValue, properties) {
        try {
            const traversal = this.driver
                .V()
                .has(targetPropName, targetPropValue)
                .as("target")
                .V()
                .has(sourcePropName, sourcePropValue)
                .addE()
                .property('Label', relationLabels)
                .to("target");
            for (const [key, value] of Object.entries(properties)) {
                traversal.property(key, value);
            }
            (() => __awaiter(this, void 0, void 0, function* () {
                const result = yield traversal.next();
            }))();
        }
        catch (err) {
            logging_1.logger.error("addEdge: " + err);
            throw new err;
        }
    }
    deleteEdge(properties) {
        try {
            (() => __awaiter(this, void 0, void 0, function* () {
                this.driver
                    .E()
                    .has("id", properties.id)
                    .drop()
                    .iterate();
            }))();
        }
        catch (err) {
            logging_1.logger.error("deleteEdge: " + err);
            throw new err();
        }
    }
    setVertexProperty(vid, key, value) {
        return __awaiter(this, void 0, void 0, function* () {
            try {
                logging_1.logger.info(`Setting vertex property: ${key}=${value} for vertex ID: ${vid}`);
                const result = yield this.driver
                    .V(vid)
                    .property(key, value)
                    .next();
                logging_1.logger.info(`Property set successfully: ${result}`);
                return result;
            }
            catch (err) {
                logging_1.logger.error(`setVertexProperty: ${err}`);
                throw err;
            }
        });
    }
    setEdgeProperty(eid, key, value) {
        return __awaiter(this, void 0, void 0, function* () {
            try {
                logging_1.logger.info(`Setting edge property: ${key}=${value} for edge ID: ${eid}`);
                const result = yield this.driver
                    .E(eid)
                    .property(key, value)
                    .next();
                logging_1.logger.info(`Property set successfully: ${result}`);
                return result;
            }
            catch (err) {
                logging_1.logger.error(`setEdgeProperty: ${err}`);
                throw err;
            }
        });
    }
    removeVertexProperty(vid, key) {
        return __awaiter(this, void 0, void 0, function* () {
            try {
                logging_1.logger.info(`Removing vertex property: ${key} for vertex ID: ${vid}`);
                const result = yield this.driver
                    .V(vid)
                    .properties(key)
                    .drop()
                    .next();
                logging_1.logger.info(`Property removed successfully: ${result}`);
                return result;
            }
            catch (err) {
                logging_1.logger.error(`removeVertexProperty: ${err}`);
                throw err;
            }
        });
    }
    removeEdgeProperty(eid, key) {
        return __awaiter(this, void 0, void 0, function* () {
            try {
                logging_1.logger.info(`Removing edge property: ${key} for edge ID: ${eid}`);
                const result = yield this.driver
                    .E(eid)
                    .properties(key)
                    .drop()
                    .next();
                logging_1.logger.info(`Property removed successfully: ${result}`);
                return result;
            }
            catch (err) {
                logging_1.logger.error(`removeEdgeProperty: ${err}`);
                throw err;
            }
        });
    }
}
exports.GremlinDriver = GremlinDriver;
//# sourceMappingURL=germlinDriver.js.map