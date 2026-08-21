import {
  CanvasDocument,
  CanvasEdge,
  CanvasSide,
  CanvasTextNode,
  CanvasViewport,
  cloneCanvasDocument,
  cloneCanvasEdge,
  cloneCanvasTextNode
} from '../model/CanvasModel';
import { validateCanvasDocument } from '../model/CanvasValidation';
import {
  CanvasPoint,
  getCanvasNodeAnchor
} from './FreeCanvasGeometry';
import {
  distanceToCanvasBezierCurve,
  getCanvasEdgeScreenCurve
} from './CanvasEdgeGeometry';

export type CanvasAlignment =
  'left' | 'horizontalCenter' | 'right' | 'top' | 'verticalCenter' | 'bottom';
export type CanvasArrangement = 'row' | 'column';
export type CanvasDistribution = 'horizontal' | 'vertical';

export interface CanvasConnectionTarget {
  readonly nodeId: string;
  readonly side: CanvasSide;
}

export interface CanvasCopyResult {
  readonly document: CanvasDocument;
  readonly nodeIds: ReadonlyArray<string>;
  readonly edgeIds: ReadonlyArray<string>;
}

export type CanvasEditingErrorCode = 'INVALID_SELECTION' | 'IDENTIFIER_CONFLICT';

export class CanvasEditingError extends Error {
  readonly code: CanvasEditingErrorCode;

  constructor(code: CanvasEditingErrorCode, message: string) {
    super(message);
    this.code = code;
  }
}

const DEFAULT_ARRANGE_GAP: number = 48;
const DEFAULT_AUTO_HORIZONTAL_GAP: number = 96;
const DEFAULT_AUTO_VERTICAL_GAP: number = 48;

function compareCanvasIds(left: string, right: string): number {
  if (left < right) {
    return -1;
  }
  return left > right ? 1 : 0;
}

function selectedIdSet(document: CanvasDocument, nodeIds: ReadonlyArray<string>): Set<string> {
  const available = new Set<string>(document.nodes.map((node: CanvasTextNode): string => node.id));
  const selected = new Set<string>();
  for (let index = 0; index < nodeIds.length; index++) {
    if (!available.has(nodeIds[index])) {
      throw new CanvasEditingError('INVALID_SELECTION', `Canvas node does not exist: ${nodeIds[index]}`);
    }
    selected.add(nodeIds[index]);
  }
  return selected;
}

/**
 * Resolves one cyclic node's depth from the already-assigned graph: prefer the
 * deepest assigned predecessor + 1 so the cycle spreads below its entry point;
 * fall back to the shallowest assigned successor when only outgoing edges reach
 * the acyclic part. Returns NaN while no assigned neighbour exists yet.
 */
function resolveCyclicDepth(predecessors: ReadonlyArray<string>,
  targets: ReadonlyArray<string>, depth: Map<string, number>): number {
  let resolved = Number.NaN;
  for (let index = 0; index < predecessors.length; index++) {
    const value = depth.get(predecessors[index]);
    if (value !== undefined) {
      resolved = Number.isNaN(resolved) ? value + 1 : Math.max(resolved, value + 1);
    }
  }
  if (Number.isNaN(resolved)) {
    for (let index = 0; index < targets.length; index++) {
      const value = depth.get(targets[index]);
      if (value !== undefined) {
        resolved = Number.isNaN(resolved) ? value : Math.min(resolved, value);
      }
    }
  }
  return resolved;
}

function assignCanvasLayerDepth(nodeIds: ReadonlyArray<string>,
  outgoing: Map<string, string[]>, incoming: Map<string, number>): Map<string, number> {
  const depth = new Map<string, number>();
  const remaining = new Map<string, number>();
  const queue: string[] = [];
  nodeIds.forEach((id: string): void => {
    const count = incoming.get(id) ?? 0;
    remaining.set(id, count);
    if (count === 0) {
      depth.set(id, 0);
      queue.push(id);
    }
  });
  queue.sort(compareCanvasIds);
  while (queue.length > 0) {
    const id = queue.shift()!;
    outgoing.get(id)!.forEach((target: string): void => {
      depth.set(target, Math.max(depth.get(target) ?? 0, depth.get(id)! + 1));
      const count = remaining.get(target)! - 1;
      remaining.set(target, count);
      if (count === 0) {
        queue.push(target);
        queue.sort(compareCanvasIds);
      }
    });
  }
  const incomingEdges = new Map<string, string[]>();
  nodeIds.forEach((id: string): void => {
    incomingEdges.set(id, []);
  });
  nodeIds.forEach((id: string): void => {
    outgoing.get(id)!.forEach((target: string): void => {
      incomingEdges.get(target)!.push(id);
    });
  });
  const cyclic: string[] = nodeIds.filter((id: string): boolean => !depth.has(id))
    .sort(compareCanvasIds);
  while (cyclic.length > 0) {
    let seeded = false;
    for (let index = 0; index < cyclic.length; index++) {
      const id = cyclic[index];
      const resolved = resolveCyclicDepth(incomingEdges.get(id)!, outgoing.get(id)!, depth);
      if (!Number.isNaN(resolved)) {
        depth.set(id, resolved);
        seeded = true;
      }
    }
    if (!seeded) {
      // A cycle with no edge to the acyclic part: anchor its first node at the
      // root layer and let the next pass spread the rest of the cycle from it.
      depth.set(cyclic[0], 0);
    }
    for (let index = cyclic.length - 1; index >= 0; index--) {
      if (depth.has(cyclic[index])) {
        cyclic.splice(index, 1);
      }
    }
  }
  return depth;
}

function cloneWithNodes(document: CanvasDocument, nodes: ReadonlyArray<CanvasTextNode>): CanvasDocument {
  const copy = cloneCanvasDocument(document);
  const candidate: CanvasDocument = {
    nodes: nodes.map((node: CanvasTextNode): CanvasTextNode => cloneCanvasTextNode(node)),
    edges: copy.edges,
    cardnote: copy.cardnote
  };
  validateCanvasDocument(candidate);
  return cloneCanvasDocument(candidate);
}

function mapSelectedNodes(document: CanvasDocument, selected: Set<string>,
  transform: (node: CanvasTextNode) => CanvasTextNode): CanvasDocument {
  return cloneWithNodes(document, document.nodes.map((node: CanvasTextNode): CanvasTextNode =>
    selected.has(node.id) ? transform(node) : cloneCanvasTextNode(node)));
}

function sortedSelectedNodes(document: CanvasDocument, selected: Set<string>,
  horizontal: boolean): CanvasTextNode[] {
  return document.nodes.filter((node: CanvasTextNode): boolean => selected.has(node.id))
    .map((node: CanvasTextNode): CanvasTextNode => cloneCanvasTextNode(node))
    .sort((left: CanvasTextNode, right: CanvasTextNode): number => {
      const primary = horizontal ? left.x - right.x : left.y - right.y;
      if (primary !== 0) {
        return primary;
      }
      const secondary = horizontal ? left.y - right.y : left.x - right.x;
      return secondary === 0 ? compareCanvasIds(left.id, right.id) : secondary;
    });
}

function replacePositions(document: CanvasDocument, positions: Map<string, CanvasPoint>): CanvasDocument {
  return cloneWithNodes(document, document.nodes.map((node: CanvasTextNode): CanvasTextNode => {
    const point = positions.get(node.id);
    if (point === undefined) {
      return cloneCanvasTextNode(node);
    }
    return {
      id: node.id,
      type: node.type,
      text: node.text,
      x: Math.round(point.x),
      y: Math.round(point.y),
      width: node.width,
      height: node.height,
      color: node.color
    };
  }));
}

export function alignCanvasNodes(document: CanvasDocument, nodeIds: ReadonlyArray<string>,
  alignment: CanvasAlignment): CanvasDocument {
  const selected = selectedIdSet(document, nodeIds);
  const nodes = document.nodes.filter((node: CanvasTextNode): boolean => selected.has(node.id));
  if (nodes.length < 2) {
    return cloneCanvasDocument(document);
  }
  const left = Math.min(...nodes.map((node: CanvasTextNode): number => node.x));
  const top = Math.min(...nodes.map((node: CanvasTextNode): number => node.y));
  const right = Math.max(...nodes.map((node: CanvasTextNode): number => node.x + node.width));
  const bottom = Math.max(...nodes.map((node: CanvasTextNode): number => node.y + node.height));
  return mapSelectedNodes(document, selected, (node: CanvasTextNode): CanvasTextNode => {
    let x = node.x;
    let y = node.y;
    switch (alignment) {
      case 'left':
        x = left;
        break;
      case 'horizontalCenter':
        x = (left + right - node.width) / 2;
        break;
      case 'right':
        x = right - node.width;
        break;
      case 'top':
        y = top;
        break;
      case 'verticalCenter':
        y = (top + bottom - node.height) / 2;
        break;
      case 'bottom':
        y = bottom - node.height;
        break;
    }
    return {
      id: node.id,
      type: node.type,
      text: node.text,
      x: Math.round(x),
      y: Math.round(y),
      width: node.width,
      height: node.height,
      color: node.color
    };
  });
}

export function arrangeCanvasNodes(document: CanvasDocument, nodeIds: ReadonlyArray<string>,
  arrangement: CanvasArrangement, gap: number = DEFAULT_ARRANGE_GAP): CanvasDocument {
  const selected = selectedIdSet(document, nodeIds);
  const horizontal = arrangement === 'row';
  const nodes = sortedSelectedNodes(document, selected, horizontal);
  if (nodes.length < 2) {
    return cloneCanvasDocument(document);
  }
  const originX = Math.min(...nodes.map((node: CanvasTextNode): number => node.x));
  const originY = Math.min(...nodes.map((node: CanvasTextNode): number => node.y));
  let cursor = horizontal ? originX : originY;
  const positions = new Map<string, CanvasPoint>();
  for (let index = 0; index < nodes.length; index++) {
    const node = nodes[index];
    positions.set(node.id, horizontal ? { x: cursor, y: originY } : { x: originX, y: cursor });
    cursor += (horizontal ? node.width : node.height) + gap;
  }
  return replacePositions(document, positions);
}

export function distributeCanvasNodes(document: CanvasDocument, nodeIds: ReadonlyArray<string>,
  distribution: CanvasDistribution): CanvasDocument {
  const selected = selectedIdSet(document, nodeIds);
  const horizontal = distribution === 'horizontal';
  const nodes = sortedSelectedNodes(document, selected, horizontal);
  if (nodes.length < 3) {
    return cloneCanvasDocument(document);
  }
  const first = nodes[0];
  const last = nodes[nodes.length - 1];
  let middleSize = 0;
  for (let index = 1; index < nodes.length - 1; index++) {
    middleSize += horizontal ? nodes[index].width : nodes[index].height;
  }
  const span = horizontal ? last.x - (first.x + first.width) : last.y - (first.y + first.height);
  const gap = Math.max(0, (span - middleSize) / (nodes.length - 1));
  let cursor = horizontal ? first.x + first.width + gap : first.y + first.height + gap;
  const positions = new Map<string, CanvasPoint>();
  for (let index = 1; index < nodes.length; index++) {
    const node = nodes[index];
    positions.set(node.id, horizontal ? { x: cursor, y: node.y } : { x: node.x, y: cursor });
    cursor += (horizontal ? node.width : node.height) + gap;
  }
  return replacePositions(document, positions);
}

export function deleteCanvasSelection(document: CanvasDocument, nodeIds: ReadonlyArray<string>,
  edgeId: string | undefined = undefined): CanvasDocument {
  const selected = selectedIdSet(document, nodeIds);
  const copy = cloneCanvasDocument(document);
  const candidate: CanvasDocument = {
    nodes: copy.nodes.filter((node: CanvasTextNode): boolean => !selected.has(node.id)),
    edges: copy.edges.filter((edge: CanvasEdge): boolean => edge.id !== edgeId &&
      !selected.has(edge.fromNode) && !selected.has(edge.toNode)),
    cardnote: copy.cardnote
  };
  validateCanvasDocument(candidate);
  return cloneCanvasDocument(candidate);
}

export function copyCanvasSelection(document: CanvasDocument, nodeIds: ReadonlyArray<string>,
  namespace: string, offset: number = 24): CanvasCopyResult {
  const selected = selectedIdSet(document, nodeIds);
  if (selected.size === 0 || namespace.length === 0) {
    throw new CanvasEditingError('INVALID_SELECTION', 'Canvas copy requires selected nodes and a namespace');
  }
  const existingNodeIds = new Set<string>(document.nodes.map((node: CanvasTextNode): string => node.id));
  const existingEdgeIds = new Set<string>(document.edges.map((edge: CanvasEdge): string => edge.id));
  const reservedNodeIds = new Set<string>(existingNodeIds);
  const reservedEdgeIds = new Set<string>(existingEdgeIds);
  const copiedNodeIds: string[] = [];
  const copiedEdgeIds: string[] = [];
  const idMap = new Map<string, string>();
  const nodes = document.nodes.map((node: CanvasTextNode): CanvasTextNode => cloneCanvasTextNode(node));
  const edges = document.edges.map((edge: CanvasEdge): CanvasEdge => cloneCanvasEdge(edge));
  document.nodes.forEach((node: CanvasTextNode): void => {
    if (!selected.has(node.id)) {
      return;
    }
    const id = node.id + '-' + namespace;
    if (reservedNodeIds.has(id)) {
      throw new CanvasEditingError('IDENTIFIER_CONFLICT', `Canvas copy node ID already exists: ${id}`);
    }
    existingNodeIds.add(id);
    reservedNodeIds.add(id);
    idMap.set(node.id, id);
    copiedNodeIds.push(id);
    nodes.push({
      id,
      type: node.type,
      text: node.text,
      x: node.x + offset,
      y: node.y + offset,
      width: node.width,
      height: node.height,
      color: node.color
    });
  });
  document.edges.forEach((edge: CanvasEdge): void => {
    if (!selected.has(edge.fromNode) || !selected.has(edge.toNode)) {
      return;
    }
    const id = edge.id + '-' + namespace;
    if (reservedEdgeIds.has(id)) {
      throw new CanvasEditingError('IDENTIFIER_CONFLICT', `Canvas copy edge ID already exists: ${id}`);
    }
    existingEdgeIds.add(id);
    reservedEdgeIds.add(id);
    copiedEdgeIds.push(id);
    edges.push({
      id,
      fromNode: idMap.get(edge.fromNode)!,
      fromSide: edge.fromSide,
      fromEnd: edge.fromEnd,
      toNode: idMap.get(edge.toNode)!,
      toSide: edge.toSide,
      toEnd: edge.toEnd,
      label: edge.label,
      color: edge.color
    });
  });
  const copy = cloneCanvasDocument(document);
  const candidate: CanvasDocument = { nodes, edges, cardnote: copy.cardnote };
  validateCanvasDocument(candidate);
  return { document: cloneCanvasDocument(candidate), nodeIds: copiedNodeIds, edgeIds: copiedEdgeIds };
}

export function nearestCanvasNodeSide(node: CanvasTextNode, point: CanvasPoint): CanvasSide {
  const distances: number[] = [
    Math.abs(point.y - node.y),
    Math.abs(point.x - (node.x + node.width)),
    Math.abs(point.y - (node.y + node.height)),
    Math.abs(point.x - node.x)
  ];
  const sides: CanvasSide[] = ['top', 'right', 'bottom', 'left'];
  let nearest = 0;
  for (let index = 1; index < distances.length; index++) {
    if (distances[index] < distances[nearest]) {
      nearest = index;
    }
  }
  return sides[nearest];
}

export function findCanvasConnectionTarget(document: CanvasDocument, viewport: CanvasViewport,
  screenPoint: CanvasPoint, excludedNodeId: string | undefined = undefined): CanvasConnectionTarget | undefined {
  const worldPoint: CanvasPoint = {
    x: (screenPoint.x - viewport.x) / viewport.scale,
    y: (screenPoint.y - viewport.y) / viewport.scale
  };
  for (let index = document.nodes.length - 1; index >= 0; index--) {
    const node = document.nodes[index];
    if (node.id === excludedNodeId || worldPoint.x < node.x || worldPoint.x > node.x + node.width ||
      worldPoint.y < node.y || worldPoint.y > node.y + node.height) {
      continue;
    }
    return { nodeId: node.id, side: nearestCanvasNodeSide(node, worldPoint) };
  }
  return undefined;
}

export function distanceToCanvasSegment(point: CanvasPoint, start: CanvasPoint, end: CanvasPoint): number {
  const deltaX = end.x - start.x;
  const deltaY = end.y - start.y;
  const lengthSquared = deltaX * deltaX + deltaY * deltaY;
  if (lengthSquared === 0) {
    return Math.hypot(point.x - start.x, point.y - start.y);
  }
  const projection = Math.max(0, Math.min(1,
    ((point.x - start.x) * deltaX + (point.y - start.y) * deltaY) / lengthSquared));
  const nearestX = start.x + projection * deltaX;
  const nearestY = start.y + projection * deltaY;
  return Math.hypot(point.x - nearestX, point.y - nearestY);
}

export function findCanvasEdgeAt(document: CanvasDocument, viewport: CanvasViewport, screenPoint: CanvasPoint,
  tolerance: number = 12): CanvasEdge | undefined {
  for (let index = document.edges.length - 1; index >= 0; index--) {
    const edge = document.edges[index];
    const fromNode = document.nodes.find((node: CanvasTextNode): boolean => node.id === edge.fromNode);
    const toNode = document.nodes.find((node: CanvasTextNode): boolean => node.id === edge.toNode);
    if (fromNode === undefined || toNode === undefined) {
      continue;
    }
    const curve = getCanvasEdgeScreenCurve(fromNode, edge.fromSide, toNode, edge.toSide, viewport);
    if (distanceToCanvasBezierCurve(screenPoint, curve) <= tolerance) {
      return cloneCanvasEdge(edge);
    }
  }
  return undefined;
}

export function autoArrangeCanvasNodes(document: CanvasDocument, nodeIds: ReadonlyArray<string>,
  horizontalGap: number = DEFAULT_AUTO_HORIZONTAL_GAP,
  verticalGap: number = DEFAULT_AUTO_VERTICAL_GAP): CanvasDocument {
  const selected = selectedIdSet(document, nodeIds);
  const nodes = document.nodes.filter((node: CanvasTextNode): boolean => selected.has(node.id))
    .map((node: CanvasTextNode): CanvasTextNode => cloneCanvasTextNode(node));
  if (nodes.length < 2) {
    return cloneCanvasDocument(document);
  }
  const indegree = new Map<string, number>();
  const outgoing = new Map<string, string[]>();
  nodes.forEach((node: CanvasTextNode): void => {
    indegree.set(node.id, 0);
    outgoing.set(node.id, []);
  });
  document.edges.forEach((edge: CanvasEdge): void => {
    if (!selected.has(edge.fromNode) || !selected.has(edge.toNode) || edge.fromNode === edge.toNode) {
      return;
    }
    outgoing.get(edge.fromNode)!.push(edge.toNode);
    indegree.set(edge.toNode, indegree.get(edge.toNode)! + 1);
  });
  outgoing.forEach((targets: string[]): void => {
    targets.sort();
  });
    const depth = assignCanvasLayerDepth(nodes.map((node: CanvasTextNode): string => node.id),
      outgoing, indegree);
  const layers = new Map<number, CanvasTextNode[]>();
  nodes.forEach((node: CanvasTextNode): void => {
    const layer = depth.get(node.id)!;
    if (!layers.has(layer)) {
      layers.set(layer, []);
    }
    layers.get(layer)!.push(node);
  });
  layers.forEach((layerNodes: CanvasTextNode[]): void => {
    layerNodes.sort((left: CanvasTextNode, right: CanvasTextNode): number => compareCanvasIds(left.id, right.id));
  });
  const originX = Math.min(...nodes.map((node: CanvasTextNode): number => node.x));
  const originY = Math.min(...nodes.map((node: CanvasTextNode): number => node.y));
  const layerIndexes = Array.from(layers.keys()).sort((left: number, right: number): number => left - right);
  const positions = new Map<string, CanvasPoint>();
  let x = originX;
  for (let layerIndex = 0; layerIndex < layerIndexes.length; layerIndex++) {
    const layerNodes = layers.get(layerIndexes[layerIndex])!;
    let y = originY;
    let layerWidth = 0;
    for (let nodeIndex = 0; nodeIndex < layerNodes.length; nodeIndex++) {
      const node = layerNodes[nodeIndex];
      positions.set(node.id, { x, y });
      y += node.height + verticalGap;
      layerWidth = Math.max(layerWidth, node.width);
    }
    x += layerWidth + horizontalGap;
  }
  return replacePositions(document, positions);
}
