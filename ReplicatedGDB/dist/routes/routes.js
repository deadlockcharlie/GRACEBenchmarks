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
exports.getGraph = getGraph;
exports.addVertex = addVertex;
exports.addEdge = addEdge;
exports.deleteVertex = deleteVertex;
exports.deleteEdge = deleteEdge;
exports.setVertexProperty = setVertexProperty;
exports.setEdgeProperty = setEdgeProperty;
exports.removeVertexProperty = removeVertexProperty;
exports.removeEdgeProperty = removeEdgeProperty;
const logging_1 = require("../helpers/logging");
const app_1 = require("../app");
function getGraph(_req, res) {
    return __awaiter(this, void 0, void 0, function* () {
        try {
            const result = yield app_1.graph.getGraph();
            res.status(200).json(result);
        }
        catch (err) {
            logging_1.logger.error(`Error fetching graph ${err}`);
            res.status(500).json(`Error fetching graph ${err}`);
        }
    });
}
function addVertex(req, res) {
    return __awaiter(this, void 0, void 0, function* () {
        try {
            const { label, properties } = req.body;
            const result = yield app_1.graph.addVertex(label, properties, false);
            logging_1.logger.info(`Vertex added: ${JSON.stringify({
                label: label,
                properties: properties,
            })}`);
            res.status(200).json({
                label: label,
                properties: properties,
            });
        }
        catch (err) {
            logging_1.logger.error(`Error adding vertex ${err}`);
            res.status(500).json(`Error adding vertex ${err}`);
        }
    });
}
function addEdge(req, res) {
    return __awaiter(this, void 0, void 0, function* () {
        try {
            const { relationType, sourcePropName, sourcePropValue, targetPropName, targetPropValue, properties, } = req.body;
            yield app_1.graph.addEdge(relationType, sourcePropName, sourcePropValue, targetPropName, targetPropValue, properties, false);
            logging_1.logger.info(`Edge Added ${JSON.stringify({
                relationType: relationType,
                sourcePropName: sourcePropName,
                sourcePropValue: sourcePropValue,
                targetPropName: targetPropName,
                targetPropValue: targetPropValue,
                properties: properties,
            })}`);
            res.status(200).json({
                relationType: relationType,
                sourcePropName: sourcePropName,
                sourcePropValue: sourcePropValue,
                targetPropName: targetPropName,
                targetPropValue: targetPropValue,
                properties: properties,
            });
        }
        catch (err) {
            logging_1.logger.error(`Error adding edge ${err}`);
            res.status(500).json(`Error adding edge ${err}`);
        }
    });
}
function deleteVertex(req, res) {
    return __awaiter(this, void 0, void 0, function* () {
        try {
            const id = req.body.id; // you can pass label via query
            yield app_1.graph.removeVertex(id, false);
            logging_1.logger.info(`Vertex deleted: ${JSON.stringify({ id: id })}`);
            res.status(200).json({ id: id });
        }
        catch (err) {
            logging_1.logger.error(`Error removing vertex ${err}`);
            res.status(500).json(`Error removing vertex ${err}`);
        }
    });
}
function deleteEdge(req, res) {
    return __awaiter(this, void 0, void 0, function* () {
        try {
            const id = req.body.id;
            yield app_1.graph.removeEdge(id, false);
            logging_1.logger.info(`Edge deleted: ${JSON.stringify({ id: id })}`);
            res.status(200).json({ id: id });
        }
        catch (err) {
            logging_1.logger.error(`Error deleting edge ${err}`);
            res.status(500).json(`Error deleting edge ${err}`);
        }
    });
}
function setVertexProperty(req, res) {
    return __awaiter(this, void 0, void 0, function* () {
        try {
            const { id, key, value } = req.body;
            yield app_1.graph.setVertexProperty(id, key, value, false);
            logging_1.logger.info(`Vertex property set: ${JSON.stringify({ id, key, value })}`);
            res.status(200).json({ id, key, value });
        }
        catch (err) {
            logging_1.logger.error(`Error setting vertex property ${err}`);
            res.status(500).json(`Error setting vertex property ${err}`);
        }
    });
}
function setEdgeProperty(req, res) {
    return __awaiter(this, void 0, void 0, function* () {
        try {
            const { id, key, value } = req.body;
            yield app_1.graph.setEdgeProperty(id, key, value, false);
            logging_1.logger.info(`Edge property set: ${JSON.stringify({ id, key, value })}`);
            res.status(200).json({ id, key, value });
        }
        catch (err) {
            logging_1.logger.error(`Error setting edge property ${err}`);
            res.status(500).json(`Error setting edge property ${err}`);
        }
    });
}
function removeVertexProperty(req, res) {
    return __awaiter(this, void 0, void 0, function* () {
        try {
            const { id, key } = req.body;
            yield app_1.graph.removeVertexProperty(id, key, false);
            logging_1.logger.info(`Vertex property removed: ${JSON.stringify({ id, key })}`);
            res.status(200).json({ id, key });
        }
        catch (err) {
            logging_1.logger.error(`Error removing vertex property ${err}`);
            res.status(500).json(`Error removing vertex property ${err}`);
        }
    });
}
function removeEdgeProperty(req, res) {
    return __awaiter(this, void 0, void 0, function* () {
        try {
            const { id, key } = req.body;
            yield app_1.graph.removeEdgeProperty(id, key, false);
            logging_1.logger.info(`Edge property removed: ${JSON.stringify({ id, key })}`);
            res.status(200).json({ id, key });
        }
        catch (err) {
            logging_1.logger.error(`Error removing edge property ${err}`);
            res.status(500).json(`Error removing edge property ${err}`);
        }
    });
}
//# sourceMappingURL=routes.js.map