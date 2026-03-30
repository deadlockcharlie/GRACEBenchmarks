"use strict";
//Adding unique id generator - UUID, append serverid, or smth else
//removing dangling edges
//pre condition that source and target are edges
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
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
exports.Vertex_Edge = void 0;
const Y = __importStar(require("yjs"));
const app_1 = require("../app");
const logging_1 = require("../helpers/logging");
// export type Listener = {
//   addVertex: (id: string) => void;
//   deleteVertex: (id: string) => void;
//   addEdge: (id: string, edge: EdgeInformation) => void;
//   deleteEdge: (id: string, edge: EdgeInformation) => void;
// };
class Vertex_Edge {
    // private listener: Listener;
    constructor(ydoc) {
        this.ydoc = ydoc;
        this.GVertices = ydoc.getMap("GVertices");
        this.GEdges = ydoc.getMap("GEdges");
        // this.listener = listener;
        this.setupObservers();
    }
    getGraph() {
        return __awaiter(this, void 0, void 0, function* () {
            const result = { vertices: this.GVertices.size, edges: this.GEdges.size };
            return result;
        });
    }
    checkInvariants() {
        return __awaiter(this, void 0, void 0, function* () {
            //todo: implement invariants here
            //1: Every post has a creation date.
            //2. Comments on a message are restricted to forums. 
            //3. A comment can only be posted by a forum member.
            //4. A person has a unique IP Address. 
            //5. Forum members can only view posts created after their joining date. 
        });
    }
    addVertex(labels_1, properties_1, remote_1) {
        return __awaiter(this, arguments, void 0, function* (labels, properties, remote, preload = false) {
            const existingVertex = this.GVertices.get(properties.id);
            // Prevent duplicate entries if not remote
            if (existingVertex && !remote) {
                throw new Error(`Vertex with id "${properties.id}" already exists`);
            }
            // Update the database
            if (!preload) {
                yield app_1.driver.addVertex(labels, properties);
            }
            // Only update local structures if not a remote sync
            if (!remote) {
                const vertex = {
                    id: properties.id,
                    labels,
                    properties: properties,
                };
                this.GVertices.set(properties.id, vertex);
                // this.listener.addVertex(properties.id);
            }
        });
    }
    removeVertex(id, remote) {
        return __awaiter(this, void 0, void 0, function* () {
            try {
                // update the database
                yield app_1.driver.deleteVertex(id);
                const exists = this.GVertices.get(id);
                if (!exists && !remote) {
                    throw new Error(`Vertex with id "${id}" does not exist`);
                }
                if (!remote) {
                    // vertex and associated link data
                    this.GVertices.delete(id);
                    // this.listener.deleteVertex(id);
                }
            }
            catch (err) {
                throw err;
            }
        });
    }
    addEdge(relationType_1, sourcePropName_1, sourcePropValue_1, targetPropName_1, targetPropValue_1, properties_1, remote_1) {
        return __awaiter(this, arguments, void 0, function* (relationType, sourcePropName, sourcePropValue, targetPropName, targetPropValue, properties, remote, preload = false) {
            const edgeId = properties.id;
            if (this.GVertices.get(sourcePropValue) == undefined ||
                this.GVertices.get(targetPropValue) == undefined) {
                throw new Error("Source and/or target vertex do not exist. Edge: " +
                    sourcePropValue +
                    " " +
                    targetPropValue);
            }
            const existingEdge = this.GEdges.get(edgeId);
            //Dont allow duplicates if we are not remote
            if (existingEdge && !remote) {
                logging_1.logger.info(JSON.stringify(existingEdge));
                throw new Error(`Edge with id "${edgeId}" already exists`);
            }
            if (!preload) {
                yield app_1.driver.addEdge(relationType, sourcePropName, sourcePropValue, targetPropName, targetPropValue, properties);
            }
            //adding it the yjs list
            const edge = {
                id: edgeId,
                sourcePropName,
                sourcePropValue,
                targetPropName,
                targetPropValue,
                properties: new Y.Map(Object.entries(properties)),
                relationType,
            };
            if (!remote) {
                this.GEdges.set(edgeId, edge);
                // this.listener.addEdge(edgeId, edge);
            }
        });
    }
    removeEdge(id, remote) {
        return __awaiter(this, void 0, void 0, function* () {
            const edge = this.GEdges.get(id);
            if (edge == undefined && !remote) {
                throw new Error("Edge with this id does not exist");
            }
            else {
                yield app_1.driver.deleteEdge(id);
                if (!remote) {
                    if (edge == undefined) {
                        throw Error("Undefined Edge");
                    }
                    // this.listener.deleteEdge(edge.id, edge);
                    this.GEdges.delete(id);
                }
            }
        });
    }
    setVertexProperty(vid, key, value, remote) {
        return __awaiter(this, void 0, void 0, function* () {
            const vertex = this.GVertices.get(vid);
            if (vertex == undefined && !remote) {
                throw new Error("Vertex with id " + vid + " does not exist");
            }
            else {
                yield app_1.driver.setVertexProperty(vid, key, value);
                if (!remote) {
                    vertex.properties[key] = value;
                    this.GVertices.set(vid, vertex);
                }
            }
        });
    }
    setEdgeProperty(eid, key, value, remote) {
        return __awaiter(this, void 0, void 0, function* () {
            const edge = this.GEdges.get(eid);
            if (edge == undefined && !remote) {
                throw new Error("Edge with id " + eid + " does not exist");
            }
            else {
                yield app_1.driver.setEdgeProperty(eid, key, value);
                if (!remote) {
                    edge.properties[key] = value;
                    this.GEdges.set(eid, edge);
                }
            }
        });
    }
    removeVertexProperty(vid, key, remote) {
        return __awaiter(this, void 0, void 0, function* () {
            const vertex = this.GVertices.get(vid);
            if (vertex == undefined && !remote) {
                throw new Error("Vertex with id " + vid + " does not exist");
            }
            else {
                yield app_1.driver.removeVertexProperty(vid, key);
                if (!remote) {
                    delete vertex.properties[key];
                    this.GVertices.set(vid, vertex);
                }
            }
        });
    }
    removeEdgeProperty(eid, key, remote) {
        return __awaiter(this, void 0, void 0, function* () {
            const edge = this.GEdges.get(eid);
            if (edge == undefined && !remote) {
                throw new Error("Edge with id " + eid + " does not exist");
            }
            else {
                yield app_1.driver.removeEdgeProperty(eid, key);
                if (!remote) {
                    delete edge.properties[key];
                    this.GEdges.set(eid, edge);
                }
            }
        });
    }
    setupObservers() {
        this.GVertices.observe((event, transaction) => {
            if (!transaction.local) {
                event.changes.keys.forEach((change, key) => {
                    logging_1.logger.error("Remote vertex update observed", JSON.stringify(change));
                    if (change.action === "add" || change.action === "update") {
                        logging_1.logger.info("Remote update observed " + transaction);
                        const vertex = this.GVertices.get(key);
                        if (vertex) {
                            this.addVertex(vertex.labels, vertex.properties, true).catch(logging_1.logger.error);
                        }
                    }
                    else if (change.action === "delete" && !transaction) {
                        const oldValue = change.oldValue;
                        this.removeVertex(oldValue.properties.id, true).catch(logging_1.logger.error);
                    }
                });
            }
        });
        this.GEdges.observe((event, transaction) => {
            if (!transaction.local) {
                event.changes.keys.forEach((change, key) => {
                    if (change.action === "add" || change.action === "update") {
                        const edge = this.GEdges.get(key);
                        if (edge) {
                            this.addEdge(edge.relationType, edge.sourcePropName, edge.sourcePropValue, edge.targetPropName, edge.targetPropValue, edge.properties, true).catch(console.error);
                        }
                    }
                    else if (change.action === "delete") {
                        const oldValue = change.oldValue;
                        this.removeEdge(oldValue.id, true).catch(console.error);
                    }
                });
            }
        });
    }
    getVertex(id) {
        return this.GVertices.get(id);
    }
}
exports.Vertex_Edge = Vertex_Edge;
//# sourceMappingURL=Graph.js.map