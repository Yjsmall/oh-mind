import { describe, expect, it } from '@ohos/hypium';
import {
  CanvasDocument,
  CanvasNodePosition,
  CanvasTextNode,
  resolveCanvasAlignmentGuides
} from '@ohos/mind-elixir';

function node(id: string, x: number, y: number, width: number = 100,
  height: number = 100): CanvasTextNode {
  return { id, type: 'text', text: id, x, y, width, height };
}

function position(id: string, x: number, y: number): CanvasNodePosition {
  return { id, x, y };
}

export default function canvasAlignmentGeometryTest() {
  describe('canvasAlignmentGeometryTest', () => {
    it('snapsMatchingEdgesWithinThreshold', 0, () => {
      const document: CanvasDocument = {
        nodes: [
          node('moving', 0, 0, 200, 100),
          node('target', 500, 300, 100, 100)
        ],
        edges: []
      };
      const result = resolveCanvasAlignmentGuides([position('moving', 0, 0)],
        { x: 404, y: 204 }, document.nodes, 8);
      expect(result.delta.x).assertEqual(400);
      expect(result.delta.y).assertEqual(300);
      expect(result.guides.length).assertEqual(2);
      expect(result.guides[0].axis).assertEqual('x');
      expect(result.guides[0].kind).assertEqual('right');
      expect(result.guides[0].position).assertEqual(500);
      expect(result.guides[1].axis).assertEqual('y');
      expect(result.guides[1].kind).assertEqual('top');
      expect(result.guides[1].position).assertEqual(400);
    });

    it('ignoresDeltasBeyondThreshold', 0, () => {
      const document: CanvasDocument = {
        nodes: [
          node('moving', 0, 0, 200, 100),
          node('target', 500, 300, 100, 100)
        ],
        edges: []
      };
      const result = resolveCanvasAlignmentGuides([position('moving', 0, 0)],
        { x: 390, y: 290 }, document.nodes, 8);
      expect(result.delta.x).assertEqual(390);
      expect(result.delta.y).assertEqual(290);
      expect(result.guides.length).assertEqual(0);
    });

    it('usesNearestTargetWhenSpatialDistancesAreClose', 0, () => {
      const nearDocument: CanvasDocument = {
        nodes: [
          node('moving', 0, 0, 100, 100),
          node('near', 200, 0, 100, 100),
          node('far', 400, 400, 100, 100)
        ],
        edges: []
      };
      const result = resolveCanvasAlignmentGuides(
        [position('moving', 0, 0)], { x: 96, y: 0 }, nearDocument.nodes, 8);
      expect(result.delta.x).assertEqual(100);
      expect(result.guides.length).assertEqual(1);
      expect(result.guides[0].position).assertEqual(200);
    });

    it('roundsFractionalDeltasAndSnapOffsets', 0, () => {
      const document: CanvasDocument = {
        nodes: [
          node('moving', 0, 0, 100, 100),
          node('target', 200, 0, 100, 100)
        ],
        edges: []
      };
      const result = resolveCanvasAlignmentGuides(
        [position('moving', 0, 0)], { x: 96.4, y: 12.6 }, document.nodes, 8);
      expect(result.delta.x).assertEqual(100);
      expect(result.delta.y).assertEqual(13);
      expect(result.guides.length).assertEqual(1);
    });

    it('keepsOnlyTheDominantAxisWhenBothAxesCouldSnap', 0, () => {
      const document: CanvasDocument = {
        nodes: [
          node('moving', 0, 0, 200, 100),
          node('xTarget', 500, 400, 100, 100),
          node('yTarget', 700, 300, 100, 100)
        ],
        edges: []
      };
      const result = resolveCanvasAlignmentGuides([position('moving', 0, 0)],
        { x: 404, y: 304 }, document.nodes, 8);
      expect(result.guides.length).assertEqual(1);
      if (result.guides[0].axis === 'x') {
        expect(result.delta.x).assertEqual(400);
        expect(result.delta.y).assertEqual(304);
      } else {
        expect(result.delta.x).assertEqual(404);
        expect(result.delta.y).assertEqual(300);
      }
    });
  });
}
