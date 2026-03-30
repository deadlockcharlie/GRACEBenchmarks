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
exports.graph = exports.driver = exports.yjsProvider = exports.ydoc = exports.app = void 0;
const express_1 = __importDefault(require("express"));
const cookie_parser_1 = __importDefault(require("cookie-parser"));
const http_errors_1 = __importDefault(require("http-errors"));
const http_1 = __importDefault(require("http"));
const path_1 = __importDefault(require("path"));
exports.app = (0, express_1.default)();
let preloadDone = false;
exports.app.use(express_1.default.json());
exports.app.use(express_1.default.urlencoded({ extended: false }));
exports.app.use((0, cookie_parser_1.default)());
exports.app.use(express_1.default.static(path_1.default.join(__dirname, "public")));
exports.app.use((req, res, next) => {
    res.set("Connection", "close");
    next();
});
const logging_1 = require("./helpers/logging");
// Setup for prometheus
const prom_client_1 = __importDefault(require("prom-client"));
const register = new prom_client_1.default.Registry();
prom_client_1.default.collectDefaultMetrics({ register });
const httpRequests = new prom_client_1.default.Counter({
    name: "http_requests_total",
    help: "Total number of HTTP requests",
});
register.registerMetric(httpRequests);
// Setup YJS
const yjs_1 = __importDefault(require("yjs"));
const ws_1 = __importDefault(require("ws"));
// Set global WebSocket for y-websocket before importing it
global.WebSocket = ws_1.default;
const y_websocket_1 = require("y-websocket");
exports.ydoc = new yjs_1.default.Doc();
const wsUri = process.env.WS_URI || "ws://yjs-provider:1234";
logging_1.logger.info(`Connecting to Y.js provider at: ${wsUri}`);
exports.yjsProvider = new y_websocket_1.WebsocketProvider(wsUri, "GraceSyncKey", exports.ydoc);
// Add connection event handlers
exports.yjsProvider.on('status', (event) => {
    logging_1.logger.info(`Y.js WebSocket status: ${event.status}`);
});
exports.yjsProvider.on('connection-close', () => {
    logging_1.logger.warn('Y.js WebSocket connection closed');
});
exports.yjsProvider.on('connection-error', (error) => {
    logging_1.logger.error(`Y.js WebSocket connection error: ${error}`);
});
// Setup Database
const germlinDriver_1 = require("./drivers/germlinDriver");
const memgraphDriver_1 = require("./drivers/memgraphDriver");
const ArangoDBDriver_1 = require("./drivers/ArangoDBDriver");
const MongoDBDriver_1 = require("./drivers/MongoDBDriver");
// Log critical environment variables
logging_1.logger.info(`DATABASE: ${process.env.DATABASE}`);
logging_1.logger.info(`DATABASE_URI: ${process.env.DATABASE_URI}`);
logging_1.logger.info(`WS_URI: ${process.env.WS_URI}`);
logging_1.logger.info(`LOG_LEVEL: ${process.env.LOG_LEVEL}`);
logging_1.logger.info(`DC_ID: ${process.env.DC_ID}`);
const dbname = process.env.DATABASE;
logging_1.logger.info(`Database specified ${dbname}`);
switch (dbname) {
    case "NEO4J":
    case "MEMGRAPH":
        exports.driver = new memgraphDriver_1.MemGraphDriver();
        break;
    case "JANUSGRAPH":
        exports.driver = new germlinDriver_1.GremlinDriver();
        break;
    case "ARANGODB":
        exports.driver = new ArangoDBDriver_1.ArangoDBDriver();
        break;
    case "MONGODB":
        exports.driver = new MongoDBDriver_1.MongoDBDriver();
        break;
    default:
        logging_1.logger.error("No database specified in configuration. Cannot initialize driver.");
        process.exit(1);
        break;
}
// Setup graph
const GraphManager_1 = require("./graph/GraphManager");
const Graph_1 = require("./graph/Graph");
const GraphManager = new GraphManager_1.Graph();
exports.graph = new Graph_1.Vertex_Edge(exports.ydoc);
const requests_1 = require("./schemas/requests");
//Setup application routes
const express_validator_1 = require("express-validator");
const routes_1 = require("./routes/routes");
{
    exports.app.post("/reset", (req, res) => __awaiter(void 0, void 0, void 0, function* () {
        exports.graph.GVertices.clear();
        exports.graph.GEdges.clear();
        res.status(200).json({ status: "Graph reset successful" });
    }));
    exports.app.get("/getVertex", (req, res) => __awaiter(void 0, void 0, void 0, function* () {
        const id = req.query.id;
        const vertex = exports.graph.getVertex(id);
        if (vertex) {
            res.status(200).json(vertex);
        }
        else {
            res.status(404).json({ error: "Vertex not found" });
        }
    }));
    exports.app.get('/ready', (req, res) => {
        if (preloadDone)
            res.sendStatus(200);
        else
            res.sendStatus(503); // 503 = Service Unavailable
    });
    exports.app.get('/health', (req, res) => {
        res.json({
            preloadDone,
            yjsConnected: exports.yjsProvider.wsconnected,
            yjsSynced: exports.yjsProvider.synced,
            wsUri: process.env.WS_URI,
            database: process.env.DATABASE,
            podName: process.env.POD_NAME
        });
    });
    exports.app.get("/api/getGraph", (req, res) => __awaiter(void 0, void 0, void 0, function* () {
        yield (0, routes_1.getGraph)(req, res);
    }));
    exports.app.post("/api/addVertex", (0, express_validator_1.checkSchema)(requests_1.VertexSchema, ["body"]), (req, res) => __awaiter(void 0, void 0, void 0, function* () {
        const validation = (0, express_validator_1.validationResult)(req);
        if (!validation.isEmpty()) {
            logging_1.logger.error(`Add Vertex Malformed request rejected: ${JSON.stringify(validation.array())}`);
            res.status(500).json("Malformed request.");
        }
        else {
            yield (0, routes_1.addVertex)(req, res);
        }
    }));
    exports.app.post("/api/deleteVertex", (0, express_validator_1.checkSchema)(requests_1.deleteVertexSchema, ["body"]), (req, res) => __awaiter(void 0, void 0, void 0, function* () {
        const validation = (0, express_validator_1.validationResult)(req);
        if (!validation.isEmpty()) {
            logging_1.logger.error(`Delete Vertex Malformed request rejected: ${JSON.stringify(validation.array())}`);
            res.status(500).json("Malformed request.");
        }
        else {
            yield (0, routes_1.deleteVertex)(req, res);
        }
    }));
    exports.app.post("/api/addEdge", (0, express_validator_1.checkSchema)(requests_1.EdgeSchema, ["body"]), (req, res) => __awaiter(void 0, void 0, void 0, function* () {
        const validation = (0, express_validator_1.validationResult)(req);
        if (!validation.isEmpty()) {
            logging_1.logger.error(`Add Edge Malformed request rejected: ${JSON.stringify(validation.array())}`);
            res.status(500).json("Malformed request.");
        }
        else {
            yield (0, routes_1.addEdge)(req, res);
        }
    }));
    exports.app.post("/api/deleteEdge", (0, express_validator_1.checkSchema)(requests_1.deleteEdgeSchema, ["body"]), (req, res) => __awaiter(void 0, void 0, void 0, function* () {
        const validation = (0, express_validator_1.validationResult)(req);
        if (!validation.isEmpty()) {
            logging_1.logger.error(`Delete Edge Malformed request rejected: ${JSON.stringify(validation.array())}`);
            res.status(500).json("Malformed request.");
        }
        else {
            yield (0, routes_1.deleteEdge)(req, res);
        }
    }));
    exports.app.post("/api/setVertexProperty", (0, express_validator_1.checkSchema)(requests_1.setVertexPropertySchema, ["body"]), (req, res) => __awaiter(void 0, void 0, void 0, function* () {
        const validation = (0, express_validator_1.validationResult)(req);
        if (!validation.isEmpty()) {
            logging_1.logger.error(`Set Vertex Property Malformed request rejected: ${JSON.stringify(validation.array())}`);
            res.status(500).json("Malformed request.");
        }
        else {
            yield (0, routes_1.setVertexProperty)(req, res);
        }
    }));
    exports.app.post("/api/setEdgeProperty", (0, express_validator_1.checkSchema)(requests_1.setEdgePropertySchema, ["body"]), (req, res) => __awaiter(void 0, void 0, void 0, function* () {
        const validation = (0, express_validator_1.validationResult)(req);
        if (!validation.isEmpty()) {
            logging_1.logger.error(`Set Edge Property Malformed request rejected: ${JSON.stringify(validation.array())}`);
            res.status(500).json("Malformed request.");
        }
        else {
            yield (0, routes_1.setEdgeProperty)(req, res);
        }
    }));
    exports.app.post("/api/removeVertexProperty", (0, express_validator_1.checkSchema)(requests_1.removeVertexPropertySchema, ["body"]), (req, res) => __awaiter(void 0, void 0, void 0, function* () {
        const validation = (0, express_validator_1.validationResult)(req);
        if (!validation.isEmpty()) {
            logging_1.logger.error(`Remove Vertex Property Malformed request rejected: ${JSON.stringify(validation.array())}`);
            res.status(500).json("Malformed request.");
        }
        else {
            yield (0, routes_1.removeVertexProperty)(req, res);
        }
    }));
    exports.app.post("/api/removeEdgeProperty", (0, express_validator_1.checkSchema)(requests_1.removeEdgePropertySchema, ["body"]), (req, res) => __awaiter(void 0, void 0, void 0, function* () {
        const validation = (0, express_validator_1.validationResult)(req);
        if (!validation.isEmpty()) {
            logging_1.logger.error(`Remove Edge Property Malformed request rejected: ${JSON.stringify(validation.array())}`);
            res.status(500).json("Malformed request.");
        }
        else {
            yield (0, routes_1.removeEdgeProperty)(req, res);
        }
    }));
    // catch 404 and forward to error handler
    exports.app.use(function (req, res, next) {
        next((0, http_errors_1.default)(404));
    });
}
// error handler
exports.app.use(function (err, req, res, next) {
    // set locals, only providing error in development
    res.locals.message = err.message;
    res.locals.error = req.app.get("env") === "development" ? err : {};
    // render the error page
    res.status(err.status || 500);
    res.send("error");
});
/**
 * Normalize a port into a number, string, or false.
 */
function normalizePort(val) {
    var port = parseInt(val, 10);
    if (isNaN(port)) {
        // named pipe
        return val;
    }
    if (port >= 0) {
        // port number
        return port;
    }
    return false;
}
var port = normalizePort(process.env.PORT || "3000");
exports.app.set("port", port);
/**
 * Create HTTP server.
 */
var server = http_1.default.createServer(exports.app);
/**
 * Listen on provided port, on all network interfaces.
 */
server.listen(port);
server.on("error", onError);
server.on("listening", onListening);
function onError(error) {
    if (error.syscall !== "listen") {
        throw error;
    }
    var bind = typeof port === "string" ? "Pipe " + port : "Port " + port;
    // handle specific listen errors with friendly messages
    switch (error.code) {
        case "EACCES":
            console.error(bind + " requires elevated privileges");
            process.exit(1);
            break;
        case "EADDRINUSE":
            console.error(bind + " is already in use");
            process.exit(1);
            break;
        default:
            throw error;
    }
}
/**
 * Event listener for HTTP server "listening" event.
 */
const fs = require("fs");
const { chain } = require("stream-chain");
const { parser } = require("stream-json");
const { pick } = require("stream-json/filters/Pick");
const { streamArray } = require("stream-json/streamers/StreamArray");
const { once } = require("events");
function onListening() {
    return __awaiter(this, void 0, void 0, function* () {
        logging_1.logger.error(process.env.IS_PRELOAD_LEADER);
        if (process.env.IS_PRELOAD_LEADER == "Yes") {
            logging_1.logger.error("I am preloading leader. Handling the initialisation of PG-CRDT");
            // If the middleware crashes and restarts, it needs to reinitialise the database.
            try {
                let vertexFut = [];
                let edgeFut = [];
                // Load vertices from the file into YJS document
                const vertexPipeline = chain([
                    fs.createReadStream("/var/lib/grace/import/vertices.json"),
                    parser(),
                    streamArray(),
                ]);
                vertexPipeline.on("data", (_a) => __awaiter(this, [_a], void 0, function* ({ value }) {
                    value.id = value._id.toString();
                    // logger.info(JSON.stringify(value));
                    const vertex = {
                        id: value.id.toString(),
                        labels: ["YCSBVertex"],
                        properties: value,
                    };
                    exports.graph.GVertices.set(value.id, vertex);
                }));
                // Wait for final batch at the end of the stream
                yield vertexPipeline.on("end", () => __awaiter(this, void 0, void 0, function* () {
                    logging_1.logger.info("✅ All vertices inserted");
                    const edgePipeline = chain([
                        fs.createReadStream("/var/lib/grace/import/edges.json"),
                        parser(),
                        streamArray(),
                    ]);
                    edgePipeline.on("data", (_a) => __awaiter(this, [_a], void 0, function* ({ value }) {
                        value.id = value._id.toString();
                        //adding it the yjs list
                        const edge = {
                            id: value.id.toString(),
                            sourcePropName: "id",
                            sourcePropValue: value._outV.toString(),
                            targetPropName: "id",
                            targetPropValue: value._inV.toString(),
                            properties: new yjs_1.default.Map(Object.entries(value)),
                            relationType: ["YCSBEdge"],
                        };
                        exports.graph.GEdges.set(value.id, edge);
                    }));
                    yield once(edgePipeline, "end");
                    preloadDone = true;
                    let size = yjs_1.default.encodeStateAsUpdate(exports.ydoc).byteLength;
                    logging_1.logger.error(`✅ All edges inserted. Preload complete. Yjs document size is ${size} bytes`);
                }));
            }
            catch (e) {
                logging_1.logger.error("Exception when loading data from a file " + e);
            }
        }
        else {
            logging_1.logger.error("I am not the crdt preload leader. Waiting for remote updates");
        }
        var addr = server.address();
        var bind = typeof addr === "string" ? "pipe " + addr : "port " + addr.port;
        logging_1.logger.debug("Listening on " + bind);
    });
}
//# sourceMappingURL=app.js.map