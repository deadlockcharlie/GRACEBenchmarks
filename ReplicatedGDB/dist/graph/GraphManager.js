"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.Graph = void 0;
class Graph {
    constructor() {
        this.Graph = new Map();
    }
    addVertex(id) {
        this.Graph.set(id, new Array());
    }
    deleteVertex(id) {
        this.Graph.delete(id);
    }
    addEdge(id, edge) {
        const edgeArr = this.Graph.get(id);
        edgeArr === null || edgeArr === void 0 ? void 0 : edgeArr.push(edge);
    }
    deleteEdge(id, edge) {
        const edgeArr = this.Graph.get(id);
        const index = edgeArr === null || edgeArr === void 0 ? void 0 : edgeArr.findIndex(e => e.id == edge.id);
        if (typeof index === 'number' && index >= 0) {
            edgeArr === null || edgeArr === void 0 ? void 0 : edgeArr.splice(index, 1);
        }
    }
}
exports.Graph = Graph;
//# sourceMappingURL=GraphManager.js.map