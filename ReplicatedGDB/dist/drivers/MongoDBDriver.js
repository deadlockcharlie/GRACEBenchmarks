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
exports.MongoDBDriver = void 0;
const driver_1 = require("./driver");
const logging_1 = require("../helpers/logging");
const mongodb_1 = require("mongodb");
class MongoDBDriver extends driver_1.DatabaseDriver {
    constructor() {
        super();
        const uri = process.env.DATABASE_URI;
        this.client = new mongodb_1.MongoClient(uri, {
            serverApi: {
                version: mongodb_1.ServerApiVersion.v1,
                strict: true,
                deprecationErrors: true,
            },
            maxPoolSize: 50,
            minPoolSize: 10,
            maxIdleTimeMS: 30000,
        });
        // Single initialization chain
        this.isReady = this.initialize();
    }
    initialize() {
        return __awaiter(this, void 0, void 0, function* () {
            try {
                yield this.client.connect();
                yield this.client.db("admin").command({ ping: 1 });
                logging_1.logger.info("Connected to MongoDB database.");
                // Get database reference
                this.db = this.client.db('grace');
                // Check and create collections in parallel
                const collections = yield this.db.listCollections().toArray();
                const collectionNames = new Set(collections.map(c => c.name));
                const createPromises = [];
                if (!collectionNames.has('vertices')) {
                    createPromises.push(this.db.createCollection('vertices'));
                }
                if (!collectionNames.has('edges')) {
                    createPromises.push(this.db.createCollection('edges'));
                }
                yield Promise.all(createPromises);
                // Cache collection references
                this.verticesCollection = this.db.collection('vertices');
                this.edgesCollection = this.db.collection('edges');
                // // Create indexes for better query performance
                // await Promise.all([
                //     this.verticesCollection.createIndex({ "properties.id": 1 }, { unique: true, sparse: true }),
                //     this.edgesCollection.createIndex({ "properties.id": 1 }, { unique: true, sparse: true }),
                //     this.edgesCollection.createIndex({ "source.propValue": 1 }),
                //     this.edgesCollection.createIndex({ "target.propValue": 1 }),
                // ]);
                logging_1.logger.warn("Preload data flag is " + process.env.PRELOAD);
                if (process.env.PRELOAD === "True") {
                    logging_1.logger.info("Materializing data from the db to the middleware");
                    // Preloading logic would go here
                }
                logging_1.logger.info("MongoDBDriver initialized.");
            }
            catch (e) {
                logging_1.logger.error("Error connecting to MongoDB database:", e);
                throw e;
            }
        });
    }
    ensureReady() {
        return __awaiter(this, void 0, void 0, function* () {
            yield this.isReady;
        });
    }
    getGraph() {
        return __awaiter(this, void 0, void 0, function* () {
            yield this.ensureReady();
            return this.verticesCollection.find({}).limit(50).toArray();
        });
    }
    addVertex(labels, properties) {
        return __awaiter(this, void 0, void 0, function* () {
            yield this.ensureReady();
            try {
                const result = yield this.verticesCollection.insertOne({
                    _id: properties.id,
                    labels: labels,
                    // remove _id from properties
                    properties: properties,
                    createdAt: new Date()
                });
                logging_1.logger.info("Vertex added with id: " + result.insertedId);
                return result;
            }
            catch (err) {
                logging_1.logger.error("Error in add vertex: " + err);
                throw err;
            }
        });
    }
    addEdge(relationLabels, sourcePropName, sourcePropValue, targetPropName, targetPropValue, properties) {
        return __awaiter(this, void 0, void 0, function* () {
            yield this.ensureReady();
            try {
                const result = yield this.edgesCollection.insertOne({
                    _id: properties.id,
                    relationLabels,
                    source: { propName: sourcePropName, propValue: sourcePropValue },
                    target: { propName: targetPropName, propValue: targetPropValue },
                    properties: properties,
                    createdAt: new Date()
                });
                logging_1.logger.info("Edge added with id: " + result.insertedId);
                return result;
            }
            catch (err) {
                logging_1.logger.error("Error in add edge: " + err);
                throw err;
            }
        });
    }
    deleteVertex(id) {
        return __awaiter(this, void 0, void 0, function* () {
            yield this.ensureReady();
            try {
                // Delete vertex by _id
                const result = yield this.verticesCollection.deleteOne({ _id: parseInt(id) });
                if (result.deletedCount === 0) {
                    logging_1.logger.warn("No vertex found with id: " + id);
                }
                else {
                    logging_1.logger.info("Vertex deleted with id: " + id);
                }
                return result;
            }
            catch (err) {
                logging_1.logger.error("Error in delete vertex: " + err);
                throw err;
            }
        });
    }
    deleteEdge(properties, remote) {
        return __awaiter(this, void 0, void 0, function* () {
            yield this.ensureReady();
            try {
                const result = yield this.edgesCollection.deleteOne({ _id: parseInt(properties.id) });
                if (result.deletedCount === 0) {
                    logging_1.logger.warn("No edge found with id: " + properties.id);
                }
                else {
                    logging_1.logger.info("Edge deleted with id: " + properties.id);
                }
                return result;
            }
            catch (err) {
                logging_1.logger.error("Error in delete edge: " + err);
                throw err;
            }
        });
    }
    setVertexProperty(vid, key, value) {
        return __awaiter(this, void 0, void 0, function* () {
            yield this.ensureReady();
            try {
                const result = yield this.verticesCollection.updateOne({ _id: parseInt(vid) }, {
                    $set: {
                        [key]: value,
                        updatedAt: new Date()
                    }
                });
                if (result.matchedCount === 0) {
                    throw new Error(`Vertex with id ${vid} not found.`);
                }
                logging_1.logger.info(`Property ${key} set to ${value} for vertex with id ${vid}`);
                return result;
            }
            catch (err) {
                logging_1.logger.error("Error in set vertex property: " + err);
                throw err;
            }
        });
    }
    setEdgeProperty(eid, key, value) {
        return __awaiter(this, void 0, void 0, function* () {
            yield this.ensureReady();
            try {
                const result = yield this.edgesCollection.updateOne({ _id: parseInt(eid) }, {
                    $set: {
                        [key]: value,
                        updatedAt: new Date()
                    }
                });
                if (result.matchedCount === 0) {
                    throw new Error(`Edge with id ${eid} not found.`);
                }
                logging_1.logger.info(`Property ${key} set to ${value} for edge with id ${eid}`);
                return result;
            }
            catch (err) {
                logging_1.logger.error("Error in set edge property: " + err);
                throw err;
            }
        });
    }
    removeVertexProperty(vid, key) {
        return __awaiter(this, void 0, void 0, function* () {
            yield this.ensureReady();
            try {
                const result = yield this.verticesCollection.updateOne({ _id: parseInt(vid) }, {
                    $unset: { [key]: "" },
                    $set: { updatedAt: new Date() }
                });
                if (result.matchedCount === 0) {
                    throw new Error(`Vertex with id ${vid} not found.`);
                }
                logging_1.logger.info(`Property ${key} removed for vertex with id ${vid}`);
                return result;
            }
            catch (err) {
                logging_1.logger.error("Error in remove vertex property: " + err);
                throw err;
            }
        });
    }
    removeEdgeProperty(eid, key) {
        return __awaiter(this, void 0, void 0, function* () {
            yield this.ensureReady();
            try {
                const result = yield this.edgesCollection.updateOne({ _id: parseInt(eid) }, {
                    $unset: { [key]: "" },
                    $set: { updatedAt: new Date() }
                });
                if (result.matchedCount === 0) {
                    throw new Error(`Edge with id ${eid} not found.`);
                }
                logging_1.logger.info(`Property ${key} removed for edge with id ${eid}`);
                return result;
            }
            catch (err) {
                logging_1.logger.error("Error in remove edge property: " + err);
                throw err;
            }
        });
    }
    close() {
        return __awaiter(this, void 0, void 0, function* () {
            yield this.client.close();
            logging_1.logger.info("MongoDB connection closed.");
        });
    }
}
exports.MongoDBDriver = MongoDBDriver;
//# sourceMappingURL=MongoDBDriver.js.map