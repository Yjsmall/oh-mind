import {
  CanvasNodePosition,
  CanvasPoint,
  CanvasRect
} from './FreeCanvasGeometry';
import { CanvasTextNode } from '../model/CanvasModel';

export type CanvasAlignmentGuideKind =
  | 'bottom'
  | 'centerX'
  | 'centerY'
  | 'left'
  | 'right'
  | 'top';

export interface CanvasAlignmentGuide {
  readonly axis: 'x' | 'y';
  readonly kind: CanvasAlignmentGuideKind;
  readonly position: number;
}

export interface CanvasAlignmentResult {
  readonly delta: CanvasPoint;
  readonly guides: ReadonlyArray<CanvasAlignmentGuide>;
}

interface CanvasAnchor {
  readonly kind: CanvasAlignmentGuideKind;
  readonly value: number;
  readonly spatialDistance: number;
}

interface AxisSnap {
  readonly kind: CanvasAlignmentGuideKind;
  readonly offset: number;
  readonly position: number;
  readonly spatialDistance: number;
}

export const FREE_CANVAS_ALIGNMENT_THRESHOLD_VP: number = 8;

function movingBounds(startingPositions: ReadonlyArray<CanvasNodePosition>,
  movingNodes: ReadonlyArray<CanvasTextNode>): CanvasRect | undefined {
  const positionById = new Map<string, CanvasNodePosition>();
  startingPositions.forEach((position: CanvasNodePosition): void => {
    positionById.set(position.id, position);
  });
  let left = Number.POSITIVE_INFINITY;
  let top = Number.POSITIVE_INFINITY;
  let right = Number.NEGATIVE_INFINITY;
  let bottom = Number.NEGATIVE_INFINITY;
  movingNodes.forEach((node: CanvasTextNode): void => {
    const position = positionById.get(node.id);
    if (position === undefined) {
      return;
    }
    left = Math.min(left, position.x);
    top = Math.min(top, position.y);
    right = Math.max(right, position.x + node.width);
    bottom = Math.max(bottom, position.y + node.height);
  });
  if (left === Number.POSITIVE_INFINITY) {
    return undefined;
  }
  return { x: left, y: top, width: right - left, height: bottom - top };
}

function normalizeNode(node: CanvasTextNode): CanvasRect {
  return { x: node.x, y: node.y, width: node.width, height: node.height };
}

function boundsDistance(first: CanvasRect, second: CanvasRect): number {
  const firstCenterX = first.x + first.width / 2;
  const firstCenterY = first.y + first.height / 2;
  const secondCenterX = second.x + second.width / 2;
  const secondCenterY = second.y + second.height / 2;
  return Math.hypot(firstCenterX - secondCenterX, firstCenterY - secondCenterY);
}

function verticalAnchors(bounds: CanvasRect, spatialDistance: number): CanvasAnchor[] {
  return [
    { kind: 'left', value: bounds.x, spatialDistance },
    { kind: 'centerX', value: bounds.x + bounds.width / 2, spatialDistance },
    { kind: 'right', value: bounds.x + bounds.width, spatialDistance }
  ];
}

function horizontalAnchors(bounds: CanvasRect, spatialDistance: number): CanvasAnchor[] {
  return [
    { kind: 'top', value: bounds.y, spatialDistance },
    { kind: 'centerY', value: bounds.y + bounds.height / 2, spatialDistance },
    { kind: 'bottom', value: bounds.y + bounds.height, spatialDistance }
  ];
}

function resolveAxisSnap(movingAnchors: CanvasAnchor[], targetAnchors: CanvasAnchor[],
  threshold: number, includeZeroOffset: boolean = true): AxisSnap | undefined {
  let best: AxisSnap | undefined = undefined;
  for (const movingAnchor of movingAnchors) {
    for (const targetAnchor of targetAnchors) {
      const offset = targetAnchor.value - movingAnchor.value;
      const distance = Math.abs(offset);
      if (distance > threshold || (distance === 0 && !includeZeroOffset)) {
        continue;
      }
      const isBetter = best === undefined ||
        targetAnchor.spatialDistance < best.spatialDistance - 10 ||
        (Math.abs(targetAnchor.spatialDistance - best.spatialDistance) <= 10 &&
          distance < Math.abs(best.offset));
      if (isBetter) {
        best = {
          kind: targetAnchor.kind,
          offset,
          position: targetAnchor.value,
          spatialDistance: targetAnchor.spatialDistance
        };
      }
    }
  }
  return best;
}

function isVerticalKind(kind: CanvasAlignmentGuideKind): boolean {
  return kind === 'left' || kind === 'centerX' || kind === 'right';
}

function resolveDominantAxisSnap(moved: CanvasRect, targetAnchors: CanvasAnchor[],
  threshold: number): AxisSnap | undefined {
  const xSnap = resolveAxisSnap(verticalAnchors(moved, 0), targetAnchors.filter(
    (anchor: CanvasAnchor): boolean => isVerticalKind(anchor.kind)), threshold, true);
  const ySnap = resolveAxisSnap(horizontalAnchors(moved, 0), targetAnchors.filter(
    (anchor: CanvasAnchor): boolean => !isVerticalKind(anchor.kind)), threshold, true);
  if (xSnap === undefined) {
    return ySnap;
  }
  if (ySnap === undefined) {
    return xSnap;
  }
  return xSnap.spatialDistance <= ySnap.spatialDistance ? xSnap : ySnap;
}

export function resolveCanvasAlignmentGuides(startingPositions: ReadonlyArray<CanvasNodePosition>,
  delta: CanvasPoint, nodes: ReadonlyArray<CanvasTextNode>,
  threshold: number = FREE_CANVAS_ALIGNMENT_THRESHOLD_VP): CanvasAlignmentResult {
  const normalizedDelta: CanvasPoint = { x: Math.round(delta.x), y: Math.round(delta.y) };
  const movingIdSet = new Set<string>();
  startingPositions.forEach((position: CanvasNodePosition): void => {
    movingIdSet.add(position.id);
  });
  const movingNodes = nodes.filter((node: CanvasTextNode): boolean => movingIdSet.has(node.id));
  const targetNodes = nodes.filter((node: CanvasTextNode): boolean => !movingIdSet.has(node.id));
  const moving = movingBounds(startingPositions, movingNodes);
  if (moving === undefined || targetNodes.length === 0) {
    return { delta, guides: [] };
  }
  const moved: CanvasRect = {
    x: moving.x + normalizedDelta.x,
    y: moving.y + normalizedDelta.y,
    width: moving.width,
    height: moving.height
  };
  const targetAnchors: CanvasAnchor[] = [];
  targetNodes.forEach((node: CanvasTextNode): void => {
    const bounds = normalizeNode(node);
    const spatialDistance = boundsDistance(moved, bounds);
    targetAnchors.push(...verticalAnchors(bounds, spatialDistance));
    targetAnchors.push(...horizontalAnchors(bounds, spatialDistance));
  });
  const snap = resolveDominantAxisSnap(moved, targetAnchors, threshold);
  const guides: CanvasAlignmentGuide[] = [];
  if (snap !== undefined) {
    guides.push({
      axis: isVerticalKind(snap.kind) ? 'x' : 'y',
      kind: snap.kind,
      position: snap.position
    });
  }
  return {
    delta: {
      x: Math.round(normalizedDelta.x + (snap !== undefined && isVerticalKind(snap.kind) ? snap.offset : 0)),
      y: Math.round(normalizedDelta.y + (snap !== undefined && !isVerticalKind(snap.kind) ? snap.offset : 0))
    },
    guides
  };
}
