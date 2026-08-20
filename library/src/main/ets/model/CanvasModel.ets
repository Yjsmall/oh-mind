export type CanvasNodeType = 'text';
export type CanvasSide = 'top' | 'right' | 'bottom' | 'left';
export type CanvasEdgeEnd = 'none' | 'arrow';

export const JSON_CANVAS_DEFAULT_FROM_END: CanvasEdgeEnd = 'none';
export const JSON_CANVAS_DEFAULT_TO_END: CanvasEdgeEnd = 'arrow';
export const CARDNOTE_CANVAS_SCHEMA_VERSION: number = 1;

export interface CanvasTextNode {
  readonly id: string;
  readonly type: CanvasNodeType;
  readonly text: string;
  readonly x: number;
  readonly y: number;
  readonly width: number;
  readonly height: number;
  readonly color?: string;
}

export interface CanvasEdge {
  readonly id: string;
  readonly fromNode: string;
  readonly fromSide?: CanvasSide;
  readonly fromEnd?: CanvasEdgeEnd;
  readonly toNode: string;
  readonly toSide?: CanvasSide;
  readonly toEnd?: CanvasEdgeEnd;
  readonly label?: string;
  readonly color?: string;
}

export interface CanvasViewport {
  readonly x: number;
  readonly y: number;
  readonly scale: number;
}

export interface CardNoteCanvasExtension {
  readonly schemaVersion: number;
  readonly viewport: CanvasViewport;
}

export interface CanvasDocument {
  readonly nodes: ReadonlyArray<CanvasTextNode>;
  readonly edges: ReadonlyArray<CanvasEdge>;
  readonly cardnote?: CardNoteCanvasExtension;
}

export function cloneCanvasTextNode(node: CanvasTextNode): CanvasTextNode {
  return {
    id: node.id,
    type: node.type,
    text: node.text,
    x: node.x,
    y: node.y,
    width: node.width,
    height: node.height,
    color: node.color
  };
}

export function cloneCanvasEdge(edge: CanvasEdge): CanvasEdge {
  return {
    id: edge.id,
    fromNode: edge.fromNode,
    fromSide: edge.fromSide,
    fromEnd: edge.fromEnd,
    toNode: edge.toNode,
    toSide: edge.toSide,
    toEnd: edge.toEnd,
    label: edge.label,
    color: edge.color
  };
}

export function cloneCanvasViewport(viewport: CanvasViewport): CanvasViewport {
  return {
    x: viewport.x,
    y: viewport.y,
    scale: viewport.scale
  };
}

export function resolveCanvasEdgeFromEnd(edge: CanvasEdge): CanvasEdgeEnd {
  return edge.fromEnd ?? JSON_CANVAS_DEFAULT_FROM_END;
}

export function resolveCanvasEdgeToEnd(edge: CanvasEdge): CanvasEdgeEnd {
  return edge.toEnd ?? JSON_CANVAS_DEFAULT_TO_END;
}

export function cloneCanvasDocument(document: CanvasDocument): CanvasDocument {
  return {
    nodes: document.nodes.map((node: CanvasTextNode): CanvasTextNode => cloneCanvasTextNode(node)),
    edges: document.edges.map((edge: CanvasEdge): CanvasEdge => cloneCanvasEdge(edge)),
    cardnote: document.cardnote === undefined ? undefined : {
      schemaVersion: document.cardnote.schemaVersion,
      viewport: cloneCanvasViewport(document.cardnote.viewport)
    }
  };
}
