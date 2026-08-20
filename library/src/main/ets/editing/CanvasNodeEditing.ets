import { applyCanvasCommand } from '../commands/CanvasCommand';
import {
  CanvasDocument,
  CanvasTextNode,
  cloneCanvasDocument,
  cloneCanvasTextNode
} from '../model/CanvasModel';
import { CanvasPoint } from '../geometry/FreeCanvasGeometry';

export type CanvasNodeLayerAction = 'backward' | 'forward' | 'bottom' | 'top';

function findNode(document: CanvasDocument, nodeId: string): CanvasTextNode | undefined {
  return document.nodes.find((node: CanvasTextNode): boolean => node.id === nodeId);
}

export function addCanvasTextNode(document: CanvasDocument, nodeId: string, position: CanvasPoint,
  text: string = '', width: number = 240, height: number = 160): CanvasDocument {
  const node: CanvasTextNode = {
    id: nodeId,
    type: 'text',
    text,
    x: Math.round(position.x),
    y: Math.round(position.y),
    width: Math.round(width),
    height: Math.round(height)
  };
  return applyCanvasCommand(document, { kind: 'addNode', node });
}

export function updateCanvasNodeText(document: CanvasDocument, nodeId: string, text: string): CanvasDocument {
  const node = findNode(document, nodeId);
  if (node === undefined || node.text === text) {
    return cloneCanvasDocument(document);
  }
  return applyCanvasCommand(document, {
    kind: 'updateNode',
    nodeId,
    node: {
      id: node.id,
      type: node.type,
      text,
      x: node.x,
      y: node.y,
      width: node.width,
      height: node.height,
      color: node.color
    }
  });
}

export function setCanvasNodesColor(document: CanvasDocument, nodeIds: ReadonlyArray<string>,
  color?: string): CanvasDocument {
  const selected = nodeIds.filter((nodeId: string, index: number, values: ReadonlyArray<string>): boolean =>
    values.indexOf(nodeId) === index);
  if (selected.length === 0) {
    return cloneCanvasDocument(document);
  }
  const nodes = document.nodes.map((node: CanvasTextNode): CanvasTextNode => {
    if (!selected.includes(node.id)) {
      return cloneCanvasTextNode(node);
    }
    return {
      id: node.id,
      type: node.type,
      text: node.text,
      x: node.x,
      y: node.y,
      width: node.width,
      height: node.height,
      color
    };
  });
  return cloneCanvasDocument({ nodes, edges: document.edges, cardnote: document.cardnote });
}

export function reorderCanvasNode(document: CanvasDocument, nodeId: string,
  action: CanvasNodeLayerAction): CanvasDocument {
  const index = document.nodes.findIndex((node: CanvasTextNode): boolean => node.id === nodeId);
  if (index < 0 || document.nodes.length < 2) {
    return cloneCanvasDocument(document);
  }
  let target = index;
  switch (action) {
    case 'backward':
      target = Math.max(0, index - 1);
      break;
    case 'forward':
      target = Math.min(document.nodes.length - 1, index + 1);
      break;
    case 'bottom':
      target = 0;
      break;
    case 'top':
      target = document.nodes.length - 1;
      break;
  }
  if (target === index) {
    return cloneCanvasDocument(document);
  }
  return applyCanvasCommand(document, { kind: 'reorderNode', nodeId, index: target });
}
