import {
  CARDNOTE_CANVAS_SCHEMA_VERSION,
  CanvasDocument,
  CanvasEdge,
  CanvasEdgeEnd,
  CanvasSide,
  CanvasTextNode,
  CanvasViewport,
  CardNoteCanvasExtension
} from './CanvasModel';

export type CanvasValidationErrorCode =
  'INVALID_DOCUMENT' |
  'INVALID_NODE' |
  'UNSUPPORTED_NODE_TYPE' |
  'DUPLICATE_NODE_ID' |
  'INVALID_EDGE' |
  'DUPLICATE_EDGE_ID' |
  'DANGLING_EDGE' |
  'INVALID_CARDNOTE_EXTENSION';

export class CanvasValidationError extends Error {
  readonly code: CanvasValidationErrorCode;

  constructor(code: CanvasValidationErrorCode, message: string) {
    super(message);
    this.code = code;
  }
}

const DOCUMENT_FIELDS: Set<string> = new Set<string>(['nodes', 'edges', 'cardnote']);
const TEXT_NODE_FIELDS: Set<string> = new Set<string>([
  'id', 'type', 'text', 'x', 'y', 'width', 'height', 'color'
]);
const EDGE_FIELDS: Set<string> = new Set<string>([
  'id', 'fromNode', 'fromSide', 'fromEnd', 'toNode', 'toSide', 'toEnd', 'label', 'color'
]);
const CARDNOTE_FIELDS: Set<string> = new Set<string>(['schemaVersion', 'viewport']);
const VIEWPORT_FIELDS: Set<string> = new Set<string>(['x', 'y', 'scale']);

function fail(code: CanvasValidationErrorCode, message: string): never {
  throw new CanvasValidationError(code, message);
}

function isObject(value: Object): boolean {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function assertAllowedFields(value: Object, allowedFields: Set<string>, path: string,
  code: CanvasValidationErrorCode): void {
  const keys = Object.keys(value);
  for (let index = 0; index < keys.length; index++) {
    if (!allowedFields.has(keys[index])) {
      fail(code, `${path} contains unsupported field: ${keys[index]}`);
    }
  }
}

function isNonEmptyString(value: string): boolean {
  return typeof value === 'string' && value.length > 0;
}

function isOptionalString(value: string | undefined): boolean {
  return value === undefined || typeof value === 'string';
}

function isCanvasSide(value: CanvasSide | undefined): boolean {
  return value === undefined || value === 'top' || value === 'right' || value === 'bottom' || value === 'left';
}

function isCanvasEdgeEnd(value: CanvasEdgeEnd | undefined): boolean {
  return value === undefined || value === 'none' || value === 'arrow';
}

function validateNode(node: CanvasTextNode, index: number): void {
  const path = `nodes[${index}]`;
  if (!isObject(node)) {
    fail('INVALID_NODE', `${path} must be an object`);
  }

  const nodeType: string = node.type;
  if (nodeType === 'file' || nodeType === 'link' || nodeType === 'group') {
    fail('UNSUPPORTED_NODE_TYPE', `${path} uses unsupported node type: ${nodeType}`);
  }
  assertAllowedFields(node, TEXT_NODE_FIELDS, path, 'INVALID_NODE');
  if (!isNonEmptyString(node.id) || nodeType !== 'text' || typeof node.text !== 'string' ||
    !Number.isInteger(node.x) || !Number.isInteger(node.y) || !Number.isInteger(node.width) ||
    !Number.isInteger(node.height) || node.width <= 0 || node.height <= 0 ||
    !isOptionalString(node.color)) {
    fail('INVALID_NODE', `${path} is not a valid JSON Canvas text node`);
  }
}

function validateEdge(edge: CanvasEdge, index: number): void {
  const path = `edges[${index}]`;
  if (!isObject(edge)) {
    fail('INVALID_EDGE', `${path} must be an object`);
  }
  assertAllowedFields(edge, EDGE_FIELDS, path, 'INVALID_EDGE');
  if (!isNonEmptyString(edge.id) || !isNonEmptyString(edge.fromNode) || !isNonEmptyString(edge.toNode) ||
    !isCanvasSide(edge.fromSide) || !isCanvasSide(edge.toSide) || !isCanvasEdgeEnd(edge.fromEnd) ||
    !isCanvasEdgeEnd(edge.toEnd) || !isOptionalString(edge.label) || !isOptionalString(edge.color)) {
    fail('INVALID_EDGE', `${path} is not a valid JSON Canvas edge`);
  }
}

function validateViewport(viewport: CanvasViewport): void {
  if (!isObject(viewport)) {
    fail('INVALID_CARDNOTE_EXTENSION', 'cardnote.viewport must be an object');
  }
  assertAllowedFields(viewport, VIEWPORT_FIELDS, 'cardnote.viewport', 'INVALID_CARDNOTE_EXTENSION');
  if (typeof viewport.x !== 'number' || !Number.isFinite(viewport.x) ||
    typeof viewport.y !== 'number' || !Number.isFinite(viewport.y) ||
    typeof viewport.scale !== 'number' || !Number.isFinite(viewport.scale) || viewport.scale <= 0) {
    fail('INVALID_CARDNOTE_EXTENSION', 'cardnote.viewport is invalid');
  }
}

function validateCardNoteExtension(cardnote: CardNoteCanvasExtension): void {
  if (!isObject(cardnote)) {
    fail('INVALID_CARDNOTE_EXTENSION', 'cardnote must be an object');
  }
  assertAllowedFields(cardnote, CARDNOTE_FIELDS, 'cardnote', 'INVALID_CARDNOTE_EXTENSION');
  if (!Number.isInteger(cardnote.schemaVersion) || cardnote.schemaVersion !== CARDNOTE_CANVAS_SCHEMA_VERSION) {
    fail('INVALID_CARDNOTE_EXTENSION', `Unsupported cardnote schemaVersion: ${cardnote.schemaVersion}`);
  }
  validateViewport(cardnote.viewport);
}

export function validateCanvasDocument(document: CanvasDocument): void {
  if (!isObject(document)) {
    fail('INVALID_DOCUMENT', 'Canvas document must be an object');
  }
  assertAllowedFields(document, DOCUMENT_FIELDS, 'document', 'INVALID_DOCUMENT');

  const nodes: ReadonlyArray<CanvasTextNode> = document.nodes === undefined ? [] : document.nodes;
  const edges: ReadonlyArray<CanvasEdge> = document.edges === undefined ? [] : document.edges;
  if (!Array.isArray(nodes) || !Array.isArray(edges)) {
    fail('INVALID_DOCUMENT', 'Canvas nodes and edges must be arrays when present');
  }

  const nodeIds = new Set<string>();
  for (let index = 0; index < nodes.length; index++) {
    const node: CanvasTextNode = nodes[index];
    validateNode(node, index);
    if (nodeIds.has(node.id)) {
      fail('DUPLICATE_NODE_ID', `Duplicate Canvas node id: ${node.id}`);
    }
    nodeIds.add(node.id);
  }

  const edgeIds = new Set<string>();
  for (let index = 0; index < edges.length; index++) {
    const edge: CanvasEdge = edges[index];
    validateEdge(edge, index);
    if (edgeIds.has(edge.id)) {
      fail('DUPLICATE_EDGE_ID', `Duplicate Canvas edge id: ${edge.id}`);
    }
    if (!nodeIds.has(edge.fromNode) || !nodeIds.has(edge.toNode)) {
      fail('DANGLING_EDGE', `Canvas edge ${edge.id} references a missing node`);
    }
    edgeIds.add(edge.id);
  }

  if (document.cardnote !== undefined) {
    validateCardNoteExtension(document.cardnote);
  }
}
