import { describe, expect, it } from '@ohos/hypium';
import {
  CanvasDocument,
  CanvasEditingError,
  CanvasTextNode,
  alignCanvasNodes,
  arrangeCanvasNodes,
  autoArrangeCanvasNodes,
  copyCanvasSelection,
  deleteCanvasSelection,
  distributeCanvasNodes,
  getCanvasBezierPointAt,
  getCanvasEdgeScreenCurve,
  findCanvasConnectionTarget,
  findCanvasEdgeAt
} from '@ohos/mind-elixir';

function editNode(id: string, x: number, y: number, width: number = 100,
  height: number = 100): CanvasTextNode {
  return { id, type: 'text', text: id, x, y, width, height };
}

function editingDocument(): CanvasDocument {
  return {
    nodes: [
      editNode('a', 0, 0),
      editNode('b', 200, 100, 50, 80),
      editNode('c', 500, 300),
      editNode('untouched', 900, 700)
    ],
    edges: [
      { id: 'a-b', fromNode: 'a', fromSide: 'right', toNode: 'b', toSide: 'left' },
      { id: 'b-c', fromNode: 'b', toNode: 'c' }
    ],
    cardnote: { schemaVersion: 1, viewport: { x: 10, y: 20, scale: 1 } }
  };
}

export default function canvasEditingGeometryTest() {
  describe('canvasEditingGeometryTest', () => {
    it('alignsOnlySelectedNodesWithIntegerCoordinates', 0, () => {
      const source = editingDocument();
      const aligned = alignCanvasNodes(source, ['a', 'b', 'c'], 'horizontalCenter');
      expect(aligned.nodes[0].x).assertEqual(250);
      expect(aligned.nodes[1].x).assertEqual(275);
      expect(aligned.nodes[2].x).assertEqual(250);
      expect(aligned.nodes[3].x).assertEqual(900);
      expect(source.nodes[0].x).assertEqual(0);
    });

    it('arrangesRowsAndColumnsDeterministically', 0, () => {
      const source = editingDocument();
      const row = arrangeCanvasNodes(source, ['c', 'a', 'b'], 'row', 20);
      const column = arrangeCanvasNodes(source, ['c', 'a', 'b'], 'column', 10);
      expect(row.nodes[0].x).assertEqual(0);
      expect(row.nodes[1].x).assertEqual(120);
      expect(row.nodes[2].x).assertEqual(190);
      expect(row.nodes[2].y).assertEqual(0);
      expect(column.nodes[0].y).assertEqual(0);
      expect(column.nodes[1].y).assertEqual(110);
      expect(column.nodes[2].y).assertEqual(200);
    });

    it('distributesMiddleNodesWithoutMovingEndpoints', 0, () => {
      const distributed = distributeCanvasNodes(editingDocument(), ['a', 'b', 'c'], 'horizontal');
      expect(distributed.nodes[0].x).assertEqual(0);
      expect(distributed.nodes[1].x).assertEqual(275);
      expect(distributed.nodes[2].x).assertEqual(500);
      expect(distributed.nodes[3].x).assertEqual(900);
    });

    it('copiesSelectedNodesAndInternalEdges', 0, () => {
      const copied = copyCanvasSelection(editingDocument(), ['a', 'b'], 'copy-1', 24);
      expect(copied.nodeIds.length).assertEqual(2);
      expect(copied.edgeIds.length).assertEqual(1);
      expect(copied.document.nodes.length).assertEqual(6);
      expect(copied.document.edges.length).assertEqual(3);
      expect(copied.document.nodes[4].id).assertEqual('a-copy-1');
      expect(copied.document.nodes[4].x).assertEqual(24);
      expect(copied.document.edges[2].fromNode).assertEqual('a-copy-1');
      expect(copied.document.edges[2].toNode).assertEqual('b-copy-1');
    });

    it('deletesNodesAndOnlyTheirConnectedEdges', 0, () => {
      const deleted = deleteCanvasSelection(editingDocument(), ['b']);
      expect(deleted.nodes.length).assertEqual(3);
      expect(deleted.edges.length).assertEqual(0);
      expect(deleted.nodes.some((node: CanvasTextNode): boolean => node.id === 'a')).assertEqual(true);
      expect(deleted.nodes.some((node: CanvasTextNode): boolean => node.id === 'c')).assertEqual(true);
    });

    it('deletesSelectedEdgeWithoutDeletingEitherNode', 0, () => {
      const deleted = deleteCanvasSelection(editingDocument(), [], 'a-b');
      expect(deleted.nodes.length).assertEqual(4);
      expect(deleted.edges.length).assertEqual(1);
      expect(deleted.edges[0].id).assertEqual('b-c');
    });

    it('rejectsCopyIdentifierConflicts', 0, () => {
      const first = copyCanvasSelection(editingDocument(), ['a'], 'copy-1').document;
      let code = '';
      try {
        copyCanvasSelection(first, ['a'], 'copy-1');
      } catch (error) {
        if (error instanceof CanvasEditingError) {
          code = error.code;
        }
      }
      expect(code).assertEqual('IDENTIFIER_CONFLICT');
    });

    it('copiesDifferentEdgesWithConflictingGeneratedIds', 0, () => {
      const conflicting: CanvasDocument = {
        nodes: [editNode('a', 0, 0), editNode('b', 200, 100, 50, 80)],
        edges: [
          { id: 'a-b', fromNode: 'a', fromSide: 'right', toNode: 'b', toSide: 'left' },
          { id: 'a-b-copy-1', fromNode: 'b', toNode: 'a' }
        ],
        cardnote: { schemaVersion: 1, viewport: { x: 0, y: 0, scale: 1 } }
      };
      let code = '';
      try {
        copyCanvasSelection(conflicting, ['a', 'b'], 'copy-1');
      } catch (error) {
        if (error instanceof CanvasEditingError) {
          code = error.code;
        }
      }
      expect(code).assertEqual('IDENTIFIER_CONFLICT');
    });

    it('findsTopmostConnectionTargetAndNearestSide', 0, () => {
      const target = findCanvasConnectionTarget(editingDocument(), { x: 10, y: 20, scale: 1 },
        { x: 210, y: 160 });
      expect(target?.nodeId).assertEqual('b');
      expect(target?.side).assertEqual('left');
    });

    it('hitTestsEdgesInScreenCoordinates', 0, () => {
      const source = editingDocument();
      const curve = getCanvasEdgeScreenCurve(source.nodes[0], 'right', source.nodes[1], 'left',
        { x: 10, y: 20, scale: 1 });
      const midpoint = getCanvasBezierPointAt(curve, 0.5);
      const edge = findCanvasEdgeAt(source, { x: 10, y: 20, scale: 1 }, midpoint, 12);
      expect(edge?.id).assertEqual('a-b');
      const missing = findCanvasEdgeAt(source, { x: 10, y: 20, scale: 1 }, { x: 800, y: 600 }, 10);
      expect(missing === undefined).assertEqual(true);
    });

    it('hitTestsEdgesAfterViewportScaleAndTranslation', 0, () => {
      const edge = findCanvasEdgeAt(editingDocument(), { x: 20, y: 40, scale: 2 }, { x: 320, y: 230 }, 20);
      expect(edge?.id).assertEqual('a-b');
    });

    it('autoArrangesGraphLayersDeterministically', 0, () => {
      const source: CanvasDocument = {
        nodes: [
          editNode('d', 600, 600),
          editNode('c', 400, 400),
          editNode('b', 200, 200),
          editNode('a', 0, 0),
          editNode('untouched', 900, 700)
        ],
        edges: [
          { id: 'a-b', fromNode: 'a', toNode: 'b' },
          { id: 'a-c', fromNode: 'a', toNode: 'c' },
          { id: 'b-d', fromNode: 'b', toNode: 'd' }
        ]
      };
      const arranged = autoArrangeCanvasNodes(source, ['d', 'c', 'b', 'a']);
      expect(arranged.nodes[3].x).assertEqual(0);
      expect(arranged.nodes[2].x).assertEqual(196);
      expect(arranged.nodes[1].x).assertEqual(196);
      expect(arranged.nodes[0].x).assertEqual(392);
      expect(arranged.nodes[4].x).assertEqual(900);
      expect(JSON.stringify(autoArrangeCanvasNodes(source, ['d', 'c', 'b', 'a'])))
        .assertEqual(JSON.stringify(arranged));
    });

    it('autoArrangesCyclesWithoutOverlappingOrChangingUnselectedNodes', 0, () => {
      const source: CanvasDocument = {
        nodes: [editNode('a', 100, 100), editNode('b', 200, 200), editNode('fixed', 700, 500)],
        edges: [{ id: 'a-b', fromNode: 'a', toNode: 'b' }, { id: 'b-a', fromNode: 'b', toNode: 'a' }]
      };
      const arranged = autoArrangeCanvasNodes(source, ['b', 'a']);
      expect(arranged.nodes[0].x).assertEqual(100);
      expect(arranged.nodes[0].y).assertEqual(100);
      expect(arranged.nodes[1].x).assertEqual(296);
      expect(arranged.nodes[1].y).assertEqual(100);
      expect(arranged.nodes[2].x).assertEqual(700);
      expect(arranged.nodes[2].y).assertEqual(500);
    });

    it('spreadsCycleBelowItsEntryNodeDepth', 0, () => {
      const source: CanvasDocument = {
        nodes: [editNode('r', 0, 0), editNode('a', 500, 500), editNode('b', 800, 800)],
        edges: [
          { id: 'r-a', fromNode: 'r', toNode: 'a' },
          { id: 'a-b', fromNode: 'a', toNode: 'b' },
          { id: 'b-a', fromNode: 'b', toNode: 'a' }
        ]
      };
      const arranged = autoArrangeCanvasNodes(source, ['b', 'a', 'r']);
      expect(arranged.nodes[0].id).assertEqual('r');
      expect(arranged.nodes[0].x).assertEqual(0);
      expect(arranged.nodes[1].x).assertEqual(196);
      expect(arranged.nodes[2].x).assertEqual(392);
    });
  });
}
