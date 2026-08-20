import {
  CARDNOTE_CANVAS_SCHEMA_VERSION,
  CanvasDocument,
  CanvasEdge,
  CanvasTextNode,
  CanvasViewport,
  CardNoteCanvasExtension,
  cloneCanvasDocument,
  cloneCanvasEdge,
  cloneCanvasTextNode,
  cloneCanvasViewport
} from '../model/CanvasModel';
import { validateCanvasDocument } from '../model/CanvasValidation';

export type CanvasCommandErrorCode =
  'NODE_ALREADY_EXISTS' |
  'NODE_NOT_FOUND' |
  'EDGE_ALREADY_EXISTS' |
  'EDGE_NOT_FOUND' |
  'IDENTIFIER_MISMATCH' |
  'INVALID_NODE_INDEX';

export class CanvasCommandError extends Error {
  readonly code: CanvasCommandErrorCode;

  constructor(code: CanvasCommandErrorCode, message: string) {
    super(message);
    this.code = code;
  }
}

export interface AddCanvasNodeCommand {
  readonly kind: 'addNode';
  readonly node: CanvasTextNode;
  readonly index?: number;
}

export interface UpdateCanvasNodeCommand {
  readonly kind: 'updateNode';
  readonly nodeId: string;
  readonly node: CanvasTextNode;
}

export interface RemoveCanvasNodeCommand {
  readonly kind: 'removeNode';
  readonly nodeId: string;
}

export interface ReorderCanvasNodeCommand {
  readonly kind: 'reorderNode';
  readonly nodeId: string;
  readonly index: number;
}

export interface AddCanvasEdgeCommand {
  readonly kind: 'addEdge';
  readonly edge: CanvasEdge;
}

export interface UpdateCanvasEdgeCommand {
  readonly kind: 'updateEdge';
  readonly edgeId: string;
  readonly edge: CanvasEdge;
}

export interface RemoveCanvasEdgeCommand {
  readonly kind: 'removeEdge';
  readonly edgeId: string;
}

export interface SetCanvasViewportCommand {
  readonly kind: 'setViewport';
  readonly viewport: CanvasViewport;
}

export interface ClearCanvasViewportCommand {
  readonly kind: 'clearViewport';
}

export type CanvasCommand =
  AddCanvasNodeCommand |
  UpdateCanvasNodeCommand |
  RemoveCanvasNodeCommand |
  ReorderCanvasNodeCommand |
  AddCanvasEdgeCommand |
  UpdateCanvasEdgeCommand |
  RemoveCanvasEdgeCommand |
  SetCanvasViewportCommand |
  ClearCanvasViewportCommand;

function fail(code: CanvasCommandErrorCode, message: string): never {
  throw new CanvasCommandError(code, message);
}

function findNodeIndex(nodes: CanvasTextNode[], nodeId: string): number {
  return nodes.findIndex((node: CanvasTextNode): boolean => node.id === nodeId);
}

function findEdgeIndex(edges: CanvasEdge[], edgeId: string): number {
  return edges.findIndex((edge: CanvasEdge): boolean => edge.id === edgeId);
}

function assertInsertIndex(index: number, length: number): void {
  if (!Number.isInteger(index) || index < 0 || index > length) {
    fail('INVALID_NODE_INDEX', `Canvas node insertion index is out of range: ${index}`);
  }
}

function assertReorderIndex(index: number, length: number): void {
  if (!Number.isInteger(index) || index < 0 || index >= length) {
    fail('INVALID_NODE_INDEX', `Canvas node reorder index is out of range: ${index}`);
  }
}

export function applyCanvasCommand(document: CanvasDocument, command: CanvasCommand): CanvasDocument {
  validateCanvasDocument(document);
  const nodes = document.nodes.map((node: CanvasTextNode): CanvasTextNode => cloneCanvasTextNode(node));
  const edges = document.edges.map((edge: CanvasEdge): CanvasEdge => cloneCanvasEdge(edge));
  let cardnote: CardNoteCanvasExtension | undefined = document.cardnote === undefined ? undefined : {
    schemaVersion: document.cardnote.schemaVersion,
    viewport: cloneCanvasViewport(document.cardnote.viewport)
  };

  switch (command.kind) {
    case 'addNode': {
      if (findNodeIndex(nodes, command.node.id) >= 0) {
        fail('NODE_ALREADY_EXISTS', `Canvas node already exists: ${command.node.id}`);
      }
      const node = cloneCanvasTextNode(command.node);
      if (command.index === undefined) {
        nodes.push(node);
      } else {
        assertInsertIndex(command.index, nodes.length);
        nodes.splice(command.index, 0, node);
      }
      break;
    }
    case 'updateNode': {
      const nodeIndex = findNodeIndex(nodes, command.nodeId);
      if (nodeIndex < 0) {
        fail('NODE_NOT_FOUND', `Canvas node does not exist: ${command.nodeId}`);
      }
      if (command.nodeId !== command.node.id) {
        fail('IDENTIFIER_MISMATCH', 'Canvas node identifiers cannot be changed by updateNode');
      }
      nodes[nodeIndex] = cloneCanvasTextNode(command.node);
      break;
    }
    case 'removeNode': {
      const nodeIndex = findNodeIndex(nodes, command.nodeId);
      if (nodeIndex < 0) {
        fail('NODE_NOT_FOUND', `Canvas node does not exist: ${command.nodeId}`);
      }
      nodes.splice(nodeIndex, 1);
      for (let edgeIndex = edges.length - 1; edgeIndex >= 0; edgeIndex--) {
        if (edges[edgeIndex].fromNode === command.nodeId || edges[edgeIndex].toNode === command.nodeId) {
          edges.splice(edgeIndex, 1);
        }
      }
      break;
    }
    case 'reorderNode': {
      const nodeIndex = findNodeIndex(nodes, command.nodeId);
      if (nodeIndex < 0) {
        fail('NODE_NOT_FOUND', `Canvas node does not exist: ${command.nodeId}`);
      }
      assertReorderIndex(command.index, nodes.length);
      const removed = nodes.splice(nodeIndex, 1);
      nodes.splice(command.index, 0, removed[0]);
      break;
    }
    case 'addEdge': {
      if (findEdgeIndex(edges, command.edge.id) >= 0) {
        fail('EDGE_ALREADY_EXISTS', `Canvas edge already exists: ${command.edge.id}`);
      }
      edges.push(cloneCanvasEdge(command.edge));
      break;
    }
    case 'updateEdge': {
      const edgeIndex = findEdgeIndex(edges, command.edgeId);
      if (edgeIndex < 0) {
        fail('EDGE_NOT_FOUND', `Canvas edge does not exist: ${command.edgeId}`);
      }
      if (command.edgeId !== command.edge.id) {
        fail('IDENTIFIER_MISMATCH', 'Canvas edge identifiers cannot be changed by updateEdge');
      }
      edges[edgeIndex] = cloneCanvasEdge(command.edge);
      break;
    }
    case 'removeEdge': {
      const edgeIndex = findEdgeIndex(edges, command.edgeId);
      if (edgeIndex < 0) {
        fail('EDGE_NOT_FOUND', `Canvas edge does not exist: ${command.edgeId}`);
      }
      edges.splice(edgeIndex, 1);
      break;
    }
    case 'setViewport': {
      cardnote = {
        schemaVersion: CARDNOTE_CANVAS_SCHEMA_VERSION,
        viewport: cloneCanvasViewport(command.viewport)
      };
      break;
    }
    case 'clearViewport': {
      cardnote = undefined;
      break;
    }
  }

  const candidate: CanvasDocument = {
    nodes,
    edges,
    cardnote
  };
  validateCanvasDocument(candidate);
  return cloneCanvasDocument(candidate);
}

export function applyCanvasTransaction(document: CanvasDocument, commands: CanvasCommand[]): CanvasDocument {
  let candidate = cloneCanvasDocument(document);
  validateCanvasDocument(candidate);
  for (let index = 0; index < commands.length; index++) {
    candidate = applyCanvasCommand(candidate, commands[index]);
  }
  return cloneCanvasDocument(candidate);
}
