"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.removeEdgePropertySchema = exports.removeVertexPropertySchema = exports.setEdgePropertySchema = exports.setVertexPropertySchema = exports.deleteEdgeSchema = exports.deleteVertexSchema = exports.EdgeSchema = exports.VertexSchema = void 0;
exports.VertexSchema = {
    label: {
        notEmpty: true,
    },
    "properties.id": {
        notEmpty: true,
    },
};
exports.EdgeSchema = {
    sourcePropName: { notEmpty: true },
    sourcePropValue: { notEmpty: true },
    targetPropName: { notEmpty: true },
    targetPropValue: { notEmpty: true },
    relationType: { notEmpty: true },
    "properties.id": {
        notEmpty: true,
    },
};
exports.deleteVertexSchema = {
    id: { notEmpty: true },
};
exports.deleteEdgeSchema = {
    id: { notEmpty: true },
};
exports.setVertexPropertySchema = {
    id: { notEmpty: true },
    key: { notEmpty: true },
    value: { notEmpty: true },
};
exports.setEdgePropertySchema = {
    id: { notEmpty: true },
    key: { notEmpty: true },
    value: { notEmpty: true },
};
exports.removeVertexPropertySchema = {
    id: { notEmpty: true },
    key: { notEmpty: true },
};
exports.removeEdgePropertySchema = {
    id: { notEmpty: true },
    key: { notEmpty: true },
};
//# sourceMappingURL=requests.js.map