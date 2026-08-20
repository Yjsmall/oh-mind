import { describe, expect, it } from '@ohos/hypium';
import {
  CanvasDocument,
  CanvasTextNode,
  fitCanvasViewport,
  moveCanvasNodes,
  normalizeCanvasRect,
  panCanvasViewport,
  resizeCanvasNode,
  selectNodesInCanvasRect,
  zoomCanvasViewportAt
} from '@ohos/mind-elixir';

function testNode(id: string, x: number, y: number, width: number = 200,
  height: number = 100): CanvasTextNode {
  return { id, type: 'text', text: id, x, y, width, height };
}

export default function freeCanvasInteractionTest() {
  describe('FreeCanvasInteractionDeviceTest', () => {
    it('pansViewportByCompletedGestureOffset', 0, () => {
      const viewport = panCanvasViewport({ x: 10, y: 20, scale: 1 }, 35, -12);
      expect(viewport.x).assertEqual(45);
      expect(viewport.y).assertEqual(8);
    });

    it('zoomsAtPinchCenterAndFitsContent', 0, () => {
      const zoomed = zoomCanvasViewportAt({ x: 0, y: 0, scale: 1 }, { x: 100, y: 100 }, 2);
      const fitted = fitCanvasViewport([testNode('a', 0, 0, 200, 100)], { width: 400, height: 300 }, 50);
      expect(zoomed.x).assertEqual(-100);
      expect(zoomed.y).assertEqual(-100);
      expect(fitted.scale).assertEqual(1.5);
    });

    it('marqueeSelectsEveryIntersectingNode', 0, () => {
      const marquee = normalizeCanvasRect({ x: 250, y: 160 }, { x: -10, y: -10 });
      const selected = selectNodesInCanvasRect([
        testNode('a', 0, 0),
        testNode('b', 180, 80),
        testNode('c', 500, 500)
      ], marquee);
      expect(selected.length).assertEqual(2);
      expect(selected[0]).assertEqual('a');
      expect(selected[1]).assertEqual('b');
    });

    it('dragsMultipleNodesAsOneCompletedOperation', 0, () => {
      const document: CanvasDocument = {
        nodes: [testNode('a', 0, 0), testNode('b', 300, 100)],
        edges: []
      };
      const moved = moveCanvasNodes(document, [
        { id: 'a', x: 0, y: 0 },
        { id: 'b', x: 300, y: 100 }
      ], { x: 24, y: -8 });
      expect(moved.nodes[0].x).assertEqual(24);
      expect(moved.nodes[1].x).assertEqual(324);
      expect(moved.nodes[1].y).assertEqual(92);
    });

    it('resizesCardsFromEdgesAndCorners', 0, () => {
      const southEast = resizeCanvasNode(testNode('a', 10, 20), 'se', { x: 40, y: 30 });
      const north = resizeCanvasNode(testNode('a', 10, 20), 'n', { x: 0, y: 20 });
      expect(southEast.width).assertEqual(240);
      expect(southEast.height).assertEqual(130);
      expect(north.y).assertEqual(40);
      expect(north.height).assertEqual(80);
    });
  });
}
