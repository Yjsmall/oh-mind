import { CanvasSide, CanvasTextNode, CanvasViewport } from '../model/CanvasModel';
import {
  CanvasPoint,
  getCanvasNodeAnchor,
  resolveCanvasNodeAnchorSide,
  worldToScreen
} from './FreeCanvasGeometry';

const EDGE_CURVE_FACTOR: number = 0.35;
const EDGE_CURVE_MIN_OFFSET: number = 40;
const EDGE_CURVE_MAX_OFFSET: number = 160;
const EDGE_HIT_TEST_SEGMENTS: number = 32;

export interface CanvasBezierCurve {
  readonly start: CanvasPoint;
  readonly startControl: CanvasPoint;
  readonly endControl: CanvasPoint;
  readonly end: CanvasPoint;
}

function sideVector(side: CanvasSide): CanvasPoint {
  switch (side) {
    case 'top':
      return { x: 0, y: -1 };
    case 'right':
      return { x: 1, y: 0 };
    case 'bottom':
      return { x: 0, y: 1 };
    case 'left':
      return { x: -1, y: 0 };
  }
}

export function createCanvasBezierCurve(start: CanvasPoint, startSide: CanvasSide,
  end: CanvasPoint, endSide: CanvasSide, coordinateScale: number = 1): CanvasBezierCurve {
  const distance = Math.max(Math.abs(end.x - start.x), Math.abs(end.y - start.y));
  const scale = Math.max(0, coordinateScale);
  const offset = Math.min(EDGE_CURVE_MAX_OFFSET * scale,
    Math.max(EDGE_CURVE_MIN_OFFSET * scale, Math.round(distance * EDGE_CURVE_FACTOR)));
  const startVector = sideVector(startSide);
  const endVector = sideVector(endSide);
  return {
    start,
    startControl: {
      x: start.x + startVector.x * offset,
      y: start.y + startVector.y * offset
    },
    endControl: {
      x: end.x + endVector.x * offset,
      y: end.y + endVector.y * offset
    },
    end
  };
}

export function getCanvasBezierPointAt(curve: CanvasBezierCurve, t: number): CanvasPoint {
  const oneMinusT = 1 - t;
  const coefficientA = oneMinusT * oneMinusT * oneMinusT;
  const coefficientB = 3 * oneMinusT * oneMinusT * t;
  const coefficientC = 3 * oneMinusT * t * t;
  const coefficientD = t * t * t;
  return {
    x: coefficientA * curve.start.x + coefficientB * curve.startControl.x +
      coefficientC * curve.endControl.x + coefficientD * curve.end.x,
    y: coefficientA * curve.start.y + coefficientB * curve.startControl.y +
      coefficientC * curve.endControl.y + coefficientD * curve.end.y
  };
}

export function getCanvasEdgeScreenCurve(fromNode: CanvasTextNode, fromSide: CanvasSide | undefined,
  toNode: CanvasTextNode, toSide: CanvasSide | undefined, viewport: CanvasViewport): CanvasBezierCurve {
  const resolvedFromSide = resolveCanvasNodeAnchorSide(fromNode, fromSide, toNode);
  const resolvedToSide = resolveCanvasNodeAnchorSide(toNode, toSide, fromNode);
  const worldCurve = createCanvasBezierCurve(
    getCanvasNodeAnchor(fromNode, resolvedFromSide, toNode), resolvedFromSide,
    getCanvasNodeAnchor(toNode, resolvedToSide, fromNode), resolvedToSide);
  return {
    start: worldToScreen(worldCurve.start, viewport),
    startControl: worldToScreen(worldCurve.startControl, viewport),
    endControl: worldToScreen(worldCurve.endControl, viewport),
    end: worldToScreen(worldCurve.end, viewport)
  };
}

function distanceToSegment(point: CanvasPoint, start: CanvasPoint, end: CanvasPoint): number {
  const deltaX = end.x - start.x;
  const deltaY = end.y - start.y;
  const lengthSquared = deltaX * deltaX + deltaY * deltaY;
  if (lengthSquared === 0) {
    return Math.hypot(point.x - start.x, point.y - start.y);
  }
  const projection = Math.max(0, Math.min(1,
    ((point.x - start.x) * deltaX + (point.y - start.y) * deltaY) / lengthSquared));
  return Math.hypot(point.x - (start.x + projection * deltaX),
    point.y - (start.y + projection * deltaY));
}

export function distanceToCanvasBezierCurve(point: CanvasPoint, curve: CanvasBezierCurve): number {
  let minimum = Number.POSITIVE_INFINITY;
  let previous = curve.start;
  for (let index = 1; index <= EDGE_HIT_TEST_SEGMENTS; index++) {
    const current = getCanvasBezierPointAt(curve, index / EDGE_HIT_TEST_SEGMENTS);
    minimum = Math.min(minimum, distanceToSegment(point, previous, current));
    previous = current;
  }
  return minimum;
}
