import { describe, expect, it } from '@ohos/hypium';
import {
  CanvasDocument,
  CanvasPoint,
  CanvasTextNode,
  CanvasViewport,
  FreeCanvasController,
  FreeCanvasControllerBinding,
  FreeCanvasInteractionMode,
  fitCanvasViewport,
  getCanvasNodeAnchor,
  moveCanvasNodes,
  normalizeCanvasRect,
  resizeCanvasNode,
  screenToWorld,
  selectNodesInCanvasRect,
  setDocumentCanvasViewport,
  worldToScreen,
  zoomCanvasViewportAt
} from '@ohos/mind-elixir';

class ControllerProbe implements FreeCanvasControllerBinding {
  fitCount: number = 0;
  resetCount: number = 0;
  clearCount: number = 0;
  mode: FreeCanvasInteractionMode = 'select';

  readonly fitContent = (): void => {
    this.fitCount++;
  };
  readonly resetViewport = (): void => {
    this.resetCount++;
  };
  readonly setInteractionMode = (mode: FreeCanvasInteractionMode): void => {
    this.mode = mode;
  };
  readonly clearSelection = (): void => {
    this.clearCount++;
  };
  readonly canUndo = (): boolean => false;
  readonly canRedo = (): boolean => false;
  readonly undo = (): boolean => false;
  readonly redo = (): boolean => false;
  readonly copySelection = (): boolean => false;
  readonly deleteSelection = (): boolean => false;
  readonly alignSelection = (): boolean => false;
  readonly arrangeSelection = (): boolean => false;
  readonly distributeSelection = (): boolean => false;
  readonly autoArrange = (): boolean => false;
  readonly addTextNode = (): boolean => false;
  readonly editSelectedNode = (): boolean => false;
  readonly commitNodeEdit = (): boolean => false;
  readonly cancelNodeEdit = (): boolean => false;
  readonly setSelectedNodesColor = (): boolean => false;
  readonly reorderSelectedNode = (): boolean => false;
  readonly activateSelectedNode = (): boolean => false;
  readonly retrySave = (): boolean => false;
  readonly setSelectedEdgeLabel = (): boolean => false;
  readonly setSelectedEdgeDirection = (): boolean => false;
}

function node(id: string, x: number, y: number, width: number = 200, height: number = 100): CanvasTextNode {
  return { id, type: 'text', text: id, x, y, width, height };
}

export default function freeCanvasGeometryTest() {
  describe('freeCanvasGeometryTest', () => {
    it('roundTripsWorldAndScreenCoordinates', 0, () => {
      const viewport: CanvasViewport = { x: 40, y: -20, scale: 1.5 };
      const screen = worldToScreen({ x: 100, y: 60 }, viewport);
      const world = screenToWorld(screen, viewport);
      expect(screen.x).assertEqual(190);
      expect(screen.y).assertEqual(70);
      expect(world.x).assertEqual(100);
      expect(world.y).assertEqual(60);
    });

    it('keepsZoomAnchorStableAndClampsScale', 0, () => {
      const before: CanvasViewport = { x: 10, y: 20, scale: 1 };
      const anchor: CanvasPoint = { x: 110, y: 120 };
      const worldBefore = screenToWorld(anchor, before);
      const after = zoomCanvasViewportAt(before, anchor, 20);
      const worldAfter = screenToWorld(anchor, after);
      expect(after.scale).assertEqual(4);
      expect(worldAfter.x).assertEqual(worldBefore.x);
      expect(worldAfter.y).assertEqual(worldBefore.y);
    });

    it('fitsContentIntoContainerWithPadding', 0, () => {
      const viewport = fitCanvasViewport([node('a', 100, 50, 200, 100)], { width: 500, height: 300 }, 50);
      expect(viewport.scale).assertEqual(2);
      expect(viewport.x).assertEqual(-150);
      expect(viewport.y).assertEqual(-50);
    });

    it('normalizesMarqueeAndSelectsIntersectingNodes', 0, () => {
      const rect = normalizeCanvasRect({ x: 250, y: 150 }, { x: 50, y: 25 });
      const selected = selectNodesInCanvasRect([
        node('a', 0, 0, 100, 100),
        node('b', 300, 0, 100, 100)
      ], rect);
      expect(rect.x).assertEqual(50);
      expect(rect.y).assertEqual(25);
      expect(selected.length).assertEqual(1);
      expect(selected[0]).assertEqual('a');
    });

    it('movesOnlySelectedNodesUsingIntegerCoordinates', 0, () => {
      const document: CanvasDocument = { nodes: [node('a', 0, 0), node('b', 300, 0)], edges: [] };
      const moved = moveCanvasNodes(document, [{ id: 'a', x: 0, y: 0 }], { x: 10.6, y: -4.4 });
      expect(moved.nodes[0].x).assertEqual(11);
      expect(moved.nodes[0].y).assertEqual(-4);
      expect(moved.nodes[1].x).assertEqual(300);
      expect(document.nodes[0].x).assertEqual(0);
    });

    it('resizesAllEightDirectionsAndHonorsMinimumSize', 0, () => {
      const source = node('a', 100, 100, 200, 100);
      const northWest = resizeCanvasNode(source, 'nw', { x: 30, y: 20 });
      const eastLimited = resizeCanvasNode(source, 'e', { x: -500, y: 0 });
      expect(northWest.x).assertEqual(130);
      expect(northWest.y).assertEqual(120);
      expect(northWest.width).assertEqual(170);
      expect(northWest.height).assertEqual(80);
      expect(eastLimited.width).assertEqual(80);
      expect(source.width).assertEqual(200);
    });

    it('resolvesExplicitAndAutomaticEdgeAnchors', 0, () => {
      const left = node('left', 0, 0, 100, 100);
      const right = node('right', 300, 0, 100, 100);
      const explicit = getCanvasNodeAnchor(left, 'bottom', right);
      const automatic = getCanvasNodeAnchor(left, undefined, right);
      expect(explicit.x).assertEqual(50);
      expect(explicit.y).assertEqual(100);
      expect(automatic.x).assertEqual(100);
      expect(automatic.y).assertEqual(50);
    });

    it('setsViewportWithoutMutatingDocument', 0, () => {
      const document: CanvasDocument = { nodes: [node('a', 0, 0)], edges: [] };
      const updated = setDocumentCanvasViewport(document, { x: 5, y: 6, scale: 1.5 });
      expect(updated.cardnote?.viewport.x).assertEqual(5);
      expect(updated.cardnote?.viewport.scale).assertEqual(1.5);
      expect(document.cardnote === undefined).assertEqual(true);
    });

    it('routesCommandsOnlyWhileControllerIsBound', 0, () => {
      const controller = new FreeCanvasController();
      const probe = new ControllerProbe();
      controller.bind(probe);
      controller.fitContent();
      controller.resetViewport();
      controller.setInteractionMode('pan');
      controller.clearSelection();
      expect(probe.fitCount).assertEqual(1);
      expect(probe.resetCount).assertEqual(1);
      expect(probe.mode).assertEqual('pan');
      expect(probe.clearCount).assertEqual(1);
      controller.unbind(probe);
      controller.fitContent();
      expect(probe.fitCount).assertEqual(1);
    });
  });
}
