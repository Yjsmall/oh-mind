import { describe, it, expect } from '@ohos/hypium';
import {
  CanvasCommand,
  CanvasCommandError,
  CanvasController,
  CanvasControllerError,
  CanvasDocument,
  CanvasTextNode,
  applyCanvasCommand,
  serializeCanvasJson
} from '@ohos/mind-elixir';

function node(id: string, x: number = 0): CanvasTextNode {
  return {
    id,
    type: 'text',
    text: id,
    x,
    y: 0,
    width: 200,
    height: 100
  };
}

function documentWithTwoNodes(): CanvasDocument {
  return {
    nodes: [node('a'), node('b', 300)],
    edges: []
  };
}

function expectCommandError(action: () => void, expectedCode: string): void {
  let caught = false;
  let actualCode = '';
  try {
    action();
  } catch (error) {
    caught = true;
    if (error instanceof CanvasCommandError || error instanceof CanvasControllerError) {
      actualCode = error.code;
    }
  }
  expect(caught).assertEqual(true);
  expect(actualCode).assertEqual(expectedCode);
}

export default function localUnitTest() {
  describe('canvasCoreTest', () => {
    it('appliesNodeCommandsWithoutMutatingInput', 0, () => {
      const source = documentWithTwoNodes();
      const sourceJson = serializeCanvasJson(source);
      const added = applyCanvasCommand(source, {
        kind: 'addNode',
        node: node('c', 600),
        index: 1
      });
      const updated = applyCanvasCommand(added, {
        kind: 'updateNode',
        nodeId: 'c',
        node: { id: 'c', type: 'text', text: '# changed', x: 610, y: 20, width: 240, height: 120 }
      });

      expect(serializeCanvasJson(source)).assertEqual(sourceJson);
      expect(updated.nodes[1].id).assertEqual('c');
      expect(updated.nodes[1].text).assertEqual('# changed');
      expect(updated.nodes[1].x).assertEqual(610);
    });

    it('createsUpdatesAndRemovesEdges', 0, () => {
      const controller = new CanvasController(documentWithTwoNodes());
      controller.execute({
        kind: 'addEdge',
        edge: { id: 'a-b', fromNode: 'a', toNode: 'b' }
      });
      controller.execute({
        kind: 'updateEdge',
        edgeId: 'a-b',
        edge: { id: 'a-b', fromNode: 'a', fromSide: 'right', toNode: 'b', toSide: 'left', label: 'next' }
      });

      expect(controller.getSnapshot().edges[0].label).assertEqual('next');
      controller.execute({ kind: 'removeEdge', edgeId: 'a-b' });
      expect(controller.getSnapshot().edges.length).assertEqual(0);
    });

    it('removesConnectedEdgesWithNode', 0, () => {
      const initial: CanvasDocument = {
        nodes: [node('a'), node('b', 300), node('c', 600)],
        edges: [
          { id: 'a-b', fromNode: 'a', toNode: 'b' },
          { id: 'b-c', fromNode: 'b', toNode: 'c' }
        ]
      };
      const controller = new CanvasController(initial);

      controller.execute({ kind: 'removeNode', nodeId: 'b' });

      expect(controller.getSnapshot().nodes.length).assertEqual(2);
      expect(controller.getSnapshot().edges.length).assertEqual(0);
    });

    it('reordersNodeZOrderAndPersistsViewport', 0, () => {
      const controller = new CanvasController(documentWithTwoNodes());
      controller.execute({ kind: 'reorderNode', nodeId: 'a', index: 1 });
      controller.execute({ kind: 'setViewport', viewport: { x: 12.5, y: -4, scale: 1.5 } });

      const snapshot = controller.getSnapshot();
      expect(snapshot.nodes[0].id).assertEqual('b');
      expect(snapshot.nodes[1].id).assertEqual('a');
      expect(snapshot.cardnote?.viewport.x).assertEqual(12.5);
      expect(snapshot.cardnote?.viewport.scale).assertEqual(1.5);

      controller.execute({ kind: 'clearViewport' });
      expect(controller.getSnapshot().cardnote === undefined).assertEqual(true);
    });

    it('recordsOneHistoryItemPerTransaction', 0, () => {
      const controller = new CanvasController(documentWithTwoNodes());
      const commands: CanvasCommand[] = [
        { kind: 'addNode', node: node('c', 600) },
        { kind: 'addEdge', edge: { id: 'b-c', fromNode: 'b', toNode: 'c' } },
        { kind: 'setViewport', viewport: { x: 10, y: 20, scale: 2 } }
      ];

      controller.executeTransaction(commands);
      expect(controller.getSnapshot().nodes.length).assertEqual(3);
      expect(controller.getSnapshot().edges.length).assertEqual(1);
      expect(controller.undo()).assertEqual(true);
      expect(serializeCanvasJson(controller.getSnapshot())).assertEqual(serializeCanvasJson(documentWithTwoNodes()));
      expect(controller.undo()).assertEqual(false);
      expect(controller.redo()).assertEqual(true);
      expect(controller.getSnapshot().nodes.length).assertEqual(3);
    });

    it('keepsSnapshotAndHistoryWhenTransactionFails', 0, () => {
      const controller = new CanvasController(documentWithTwoNodes());
      const before = serializeCanvasJson(controller.getSnapshot());
      const commands: CanvasCommand[] = [
        { kind: 'addNode', node: node('c', 600) },
        { kind: 'addEdge', edge: { id: 'c-missing', fromNode: 'c', toNode: 'missing' } }
      ];

      let caught = false;
      try {
        controller.executeTransaction(commands);
      } catch (_error) {
        caught = true;
      }

      expect(caught).assertEqual(true);
      expect(serializeCanvasJson(controller.getSnapshot())).assertEqual(before);
      expect(controller.canUndo()).assertEqual(false);
      expect(controller.canRedo()).assertEqual(false);
    });

    it('clearsRedoAfterNewOperation', 0, () => {
      const controller = new CanvasController(documentWithTwoNodes());
      controller.execute({ kind: 'addNode', node: node('c', 600) });
      expect(controller.undo()).assertEqual(true);
      expect(controller.canRedo()).assertEqual(true);

      controller.execute({ kind: 'setViewport', viewport: { x: 0, y: 0, scale: 1.25 } });
      expect(controller.canRedo()).assertEqual(false);
    });

    it('doesNotRecordNoOpTransactions', 0, () => {
      const controller = new CanvasController(documentWithTwoNodes());
      controller.execute({ kind: 'updateNode', nodeId: 'a', node: node('a') });

      expect(controller.canUndo()).assertEqual(false);
    });

    it('boundsHistoryAndResetsItWhenReplacingSnapshot', 0, () => {
      const controller = new CanvasController(documentWithTwoNodes(), { historyLimit: 1 });
      controller.execute({ kind: 'addNode', node: node('c', 600) });
      controller.execute({ kind: 'setViewport', viewport: { x: 1, y: 2, scale: 1.5 } });

      expect(controller.undo()).assertEqual(true);
      expect(controller.undo()).assertEqual(false);
      controller.replaceSnapshot({ nodes: [node('replacement')], edges: [] });
      expect(controller.canUndo()).assertEqual(false);
      expect(controller.canRedo()).assertEqual(false);
      expect(controller.getSnapshot().nodes[0].id).assertEqual('replacement');
    });

    it('returnsIndependentSnapshots', 0, () => {
      const controller = new CanvasController(documentWithTwoNodes());
      const first = controller.getSnapshot();
      const second = controller.getSnapshot();

      expect(first === second).assertEqual(false);
      expect(first.nodes === second.nodes).assertEqual(false);
      expect(first.nodes[0] === second.nodes[0]).assertEqual(false);
    });

    it('reportsCommandAndControllerErrors', 0, () => {
      const controller = new CanvasController(documentWithTwoNodes());
      expectCommandError((): void => {
        controller.execute({ kind: 'addNode', node: node('a') });
      }, 'NODE_ALREADY_EXISTS');
      expectCommandError((): void => {
        controller.execute({ kind: 'reorderNode', nodeId: 'a', index: 3 });
      }, 'INVALID_NODE_INDEX');
      expectCommandError((): void => {
        new CanvasController(documentWithTwoNodes(), { historyLimit: 0 });
      }, 'INVALID_HISTORY_LIMIT');
    });
  });
}
