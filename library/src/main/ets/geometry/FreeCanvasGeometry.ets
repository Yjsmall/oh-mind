import {
  CARDNOTE_CANVAS_SCHEMA_VERSION,
  CanvasDocument,
  CanvasSide,
  CanvasTextNode,
  CanvasViewport,
  cloneCanvasDocument,
  cloneCanvasTextNode
} from '../model/CanvasModel';

export const FREE_CANVAS_MIN_SCALE: number = 0.1;
export const FREE_CANVAS_MAX_SCALE: number = 2.5;
export const FREE_CANVAS_MIN_NODE_WIDTH: number = 80;
export const FREE_CANVAS_MIN_NODE_HEIGHT: number = 48;
export const FREE_CANVAS_FIT_PADDING: number = 48;

export interface CanvasPoint {
  readonly x: number;
  readonly y: number;
}

export interface CanvasRect {
  readonly x: number;
  readonly y: number;
  readonly width: number;
  readonly height: number;
}

export interface CanvasSize {
  readonly width: number;
  readonly height: number;
}

export type CanvasResizeHandle = 'n' | 'ne' | 'e' | 'se' | 's' | 'sw' | 'w' | 'nw';

export interface CanvasNodePosition {
  readonly id: string;
  readonly x: number;
  readonly y: number;
}

function clamp(value: number, minimum: number, maximum: number): number {
  return Math.max(minimum, Math.min(maximum, value));
}

export function clampCanvasScale(scale: number): number {
  return clamp(scale, FREE_CANVAS_MIN_SCALE, FREE_CANVAS_MAX_SCALE);
}

export function resolveCanvasViewport(document: CanvasDocument): CanvasViewport {
  if (document.cardnote !== undefined) {
    return {
      x: document.cardnote.viewport.x,
      y: document.cardnote.viewport.y,
      scale: clampCanvasScale(document.cardnote.viewport.scale)
    };
  }
  return { x: 0, y: 0, scale: 1 };
}

export function worldToScreen(point: CanvasPoint, viewport: CanvasViewport): CanvasPoint {
  return {
    x: viewport.x + point.x * viewport.scale,
    y: viewport.y + point.y * viewport.scale
  };
}

export function screenToWorld(point: CanvasPoint, viewport: CanvasViewport): CanvasPoint {
  return {
    x: (point.x - viewport.x) / viewport.scale,
    y: (point.y - viewport.y) / viewport.scale
  };
}

export function panCanvasViewport(viewport: CanvasViewport, offsetX: number, offsetY: number): CanvasViewport {
  return {
    x: viewport.x + offsetX,
    y: viewport.y + offsetY,
    scale: viewport.scale
  };
}

export function zoomCanvasViewportAt(viewport: CanvasViewport, screenPoint: CanvasPoint,
  requestedScale: number): CanvasViewport {
  return zoomCanvasViewportBetweenPoints(viewport, screenPoint, screenPoint, requestedScale);
}

export function zoomCanvasViewportBetweenPoints(viewport: CanvasViewport, initialScreenPoint: CanvasPoint,
  currentScreenPoint: CanvasPoint, requestedScale: number): CanvasViewport {
  const scale = clampCanvasScale(requestedScale);
  const worldPoint = screenToWorld(initialScreenPoint, viewport);
  return {
    x: currentScreenPoint.x - worldPoint.x * scale,
    y: currentScreenPoint.y - worldPoint.y * scale,
    scale
  };
}

export function zoomCanvasViewportByWheel(viewport: CanvasViewport, screenPoint: CanvasPoint,
  deltaY: number): CanvasViewport {
  const scale = Number((viewport.scale * Math.exp(-deltaY * 0.0015)).toFixed(2));
  return zoomCanvasViewportAt(viewport, screenPoint, scale);
}

export function normalizeCanvasRect(start: CanvasPoint, end: CanvasPoint): CanvasRect {
  const x = Math.min(start.x, end.x);
  const y = Math.min(start.y, end.y);
  return {
    x,
    y,
    width: Math.max(start.x, end.x) - x,
    height: Math.max(start.y, end.y) - y
  };
}

export function getCanvasContentBounds(nodes: ReadonlyArray<CanvasTextNode>): CanvasRect | undefined {
  if (nodes.length === 0) {
    return undefined;
  }
  let left = nodes[0].x;
  let top = nodes[0].y;
  let right = nodes[0].x + nodes[0].width;
  let bottom = nodes[0].y + nodes[0].height;
  for (let index = 1; index < nodes.length; index++) {
    const node = nodes[index];
    left = Math.min(left, node.x);
    top = Math.min(top, node.y);
    right = Math.max(right, node.x + node.width);
    bottom = Math.max(bottom, node.y + node.height);
  }
  return { x: left, y: top, width: right - left, height: bottom - top };
}

export function fitCanvasViewport(nodes: ReadonlyArray<CanvasTextNode>, container: CanvasSize,
  padding: number = FREE_CANVAS_FIT_PADDING): CanvasViewport {
  const bounds = getCanvasContentBounds(nodes);
  if (bounds === undefined || container.width <= 0 || container.height <= 0) {
    return { x: 0, y: 0, scale: 1 };
  }
  const availableWidth = Math.max(1, container.width - padding * 2);
  const availableHeight = Math.max(1, container.height - padding * 2);
  const widthScale = bounds.width === 0 ? FREE_CANVAS_MAX_SCALE : availableWidth / bounds.width;
  const heightScale = bounds.height === 0 ? FREE_CANVAS_MAX_SCALE : availableHeight / bounds.height;
  const scale = clampCanvasScale(Math.min(widthScale, heightScale));
  return {
    x: (container.width - bounds.width * scale) / 2 - bounds.x * scale,
    y: (container.height - bounds.height * scale) / 2 - bounds.y * scale,
    scale
  };
}

export function nodeIntersectsCanvasRect(node: CanvasTextNode, rect: CanvasRect): boolean {
  return node.x < rect.x + rect.width && node.x + node.width > rect.x &&
    node.y < rect.y + rect.height && node.y + node.height > rect.y;
}

export function selectNodesInCanvasRect(nodes: ReadonlyArray<CanvasTextNode>, rect: CanvasRect): string[] {
  return nodes.filter((node: CanvasTextNode): boolean => nodeIntersectsCanvasRect(node, rect))
    .map((node: CanvasTextNode): string => node.id);
}

export function moveCanvasNodes(document: CanvasDocument, startingPositions: ReadonlyArray<CanvasNodePosition>,
  delta: CanvasPoint): CanvasDocument {
  const positionById = new Map<string, CanvasNodePosition>();
  startingPositions.forEach((position: CanvasNodePosition): void => {
    positionById.set(position.id, position);
  });
  const nodes = document.nodes.map((node: CanvasTextNode): CanvasTextNode => {
    const start = positionById.get(node.id);
    if (start === undefined) {
      return cloneCanvasTextNode(node);
    }
    return {
      id: node.id,
      type: node.type,
      text: node.text,
      x: Math.round(start.x + delta.x),
      y: Math.round(start.y + delta.y),
      width: node.width,
      height: node.height,
      color: node.color
    };
  });
  const candidate = cloneCanvasDocument(document);
  return { nodes, edges: candidate.edges, cardnote: candidate.cardnote };
}

export function resizeCanvasNode(node: CanvasTextNode, handle: CanvasResizeHandle,
  delta: CanvasPoint): CanvasTextNode {
  let left = node.x;
  let top = node.y;
  let right = node.x + node.width;
  let bottom = node.y + node.height;
  if (handle.includes('w')) {
    left = Math.min(node.x + delta.x, right - FREE_CANVAS_MIN_NODE_WIDTH);
  }
  if (handle.includes('e')) {
    right = Math.max(node.x + FREE_CANVAS_MIN_NODE_WIDTH, right + delta.x);
  }
  if (handle.includes('n')) {
    top = Math.min(node.y + delta.y, bottom - FREE_CANVAS_MIN_NODE_HEIGHT);
  }
  if (handle.includes('s')) {
    bottom = Math.max(node.y + FREE_CANVAS_MIN_NODE_HEIGHT, bottom + delta.y);
  }
  return {
    id: node.id,
    type: node.type,
    text: node.text,
    x: Math.round(left),
    y: Math.round(top),
    width: Math.round(right - left),
    height: Math.round(bottom - top),
    color: node.color
  };
}

export function replaceCanvasNode(document: CanvasDocument, replacement: CanvasTextNode): CanvasDocument {
  const copy = cloneCanvasDocument(document);
  return {
    nodes: copy.nodes.map((node: CanvasTextNode): CanvasTextNode =>
      node.id === replacement.id ? cloneCanvasTextNode(replacement) : cloneCanvasTextNode(node)),
    edges: copy.edges,
    cardnote: copy.cardnote
  };
}

export function setDocumentCanvasViewport(document: CanvasDocument, viewport: CanvasViewport): CanvasDocument {
  const copy = cloneCanvasDocument(document);
  return {
    nodes: copy.nodes,
    edges: copy.edges,
    cardnote: {
      schemaVersion: CARDNOTE_CANVAS_SCHEMA_VERSION,
      viewport: {
        x: viewport.x,
        y: viewport.y,
        scale: clampCanvasScale(viewport.scale)
      }
    }
  };
}

export function resolveCanvasNodeAnchorSide(node: CanvasTextNode, side: CanvasSide | undefined,
  toward: CanvasTextNode): CanvasSide {
  let resolvedSide = side;
  if (resolvedSide === undefined) {
    const nodeCenterX = node.x + node.width / 2;
    const nodeCenterY = node.y + node.height / 2;
    const towardCenterX = toward.x + toward.width / 2;
    const towardCenterY = toward.y + toward.height / 2;
    const horizontalDistance = towardCenterX - nodeCenterX;
    const verticalDistance = towardCenterY - nodeCenterY;
    if (Math.abs(horizontalDistance) >= Math.abs(verticalDistance)) {
      resolvedSide = horizontalDistance >= 0 ? 'right' : 'left';
    } else {
      resolvedSide = verticalDistance >= 0 ? 'bottom' : 'top';
    }
  }
  return resolvedSide;
}

export function getCanvasNodeAnchor(node: CanvasTextNode, side: CanvasSide | undefined,
  toward: CanvasTextNode): CanvasPoint {
  switch (resolveCanvasNodeAnchorSide(node, side, toward)) {
    case 'top':
      return { x: node.x + node.width / 2, y: node.y };
    case 'right':
      return { x: node.x + node.width, y: node.y + node.height / 2 };
    case 'bottom':
      return { x: node.x + node.width / 2, y: node.y + node.height };
    case 'left':
      return { x: node.x, y: node.y + node.height / 2 };
  }
}
