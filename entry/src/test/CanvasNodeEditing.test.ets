import { describe, expect, it } from '@ohos/hypium';
import {
  CanvasDocument,
  addCanvasTextNode,
  reorderCanvasNode,
  setCanvasNodesColor,
  updateCanvasNodeText
} from '@ohos/mind-elixir';

function documentWithNodes(): CanvasDocument {
  return {
    nodes: [
      { id: 'a', type: 'text', text: 'A', x: 0, y: 0, width: 200, height: 100 },
      { id: 'b', type: 'text', text: 'B', x: 240, y: 0, width: 200, height: 100 },
      { id: 'c', type: 'text', text: 'C', x: 480, y: 0, width: 200, height: 100 }
    ],
    edges: []
  };
}

export default function canvasNodeEditingTest() {
  describe('canvasNodeEditingTest', () => {
    it('addsAndEditsTextNodeWithoutMutatingInput', 0, () => {
      const source = documentWithNodes();
      const added = addCanvasTextNode(source, 'note', { x: 12.6, y: 19.4 }, '# Draft');
      const edited = updateCanvasNodeText(added, 'note', '# Saved');
      expect(source.nodes.length).assertEqual(3);
      expect(added.nodes[3].x).assertEqual(13);
      expect(added.nodes[3].y).assertEqual(19);
      expect(added.nodes[3].text).assertEqual('# Draft');
      expect(edited.nodes[3].text).assertEqual('# Saved');
    });

    it('colorsOnlySelectedNodes', 0, () => {
      const source = documentWithNodes();
      const colored = setCanvasNodesColor(source, ['a', 'c'], '5');
      expect(colored.nodes[0].color).assertEqual('5');
      expect(colored.nodes[1].color === undefined).assertEqual(true);
      expect(colored.nodes[2].color).assertEqual('5');
      expect(source.nodes[0].color === undefined).assertEqual(true);
    });

    it('usesNodeArrayAsBottomToTopLayerOrder', 0, () => {
      const source = documentWithNodes();
      const top = reorderCanvasNode(source, 'a', 'top');
      const backward = reorderCanvasNode(top, 'a', 'backward');
      const bottom = reorderCanvasNode(backward, 'a', 'bottom');
      expect(top.nodes[2].id).assertEqual('a');
      expect(backward.nodes[1].id).assertEqual('a');
      expect(bottom.nodes[0].id).assertEqual('a');
      expect(source.nodes[0].id).assertEqual('a');
    });
  });
}
