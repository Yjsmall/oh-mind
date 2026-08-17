/*
 * Copyright (C) 2025 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import {
  DragOrientation,
  LayoutDirection,
  MindElixirCore,
  MindElixirData,
  MoveDirection,
  NodeObj
} from '@ohos/mind-elixir';
import { GlobalContext } from '@ohos/mind-elixir/src/main/ets/utils/GlobalContext';
import { MeasureOptions, MeasureUtils, UIContext } from '@kit.ArkUI';

class TestMeasureUtils extends MeasureUtils {
  measureTextSize(_options: MeasureOptions): SizeOptions {
    return { width: 100, height: 20 };
  }
}

class TestUIContext extends UIContext {
  private readonly testMeasureUtils: MeasureUtils = new TestMeasureUtils();

  getMeasureUtils(): MeasureUtils {
    return this.testMeasureUtils;
  }

  px2vp(value: number): number {
    return value;
  }
}

function createMindData(): MindElixirData {
  return {
    nodeData: {
      id: 'root',
      topic: 'root',
      children: [
        { id: 'a', topic: 'node-a', children: [] },
        { id: 'b', topic: 'node-b', children: [] }
      ]
    },
    arrows: []
  };
}

function findNodeById(node: NodeObj | null | undefined, id: string): NodeObj | null {
  if (!node) {
    return null;
  }
  if (node.id === id) {
    return node;
  }
  if (node.children) {
    for (const child of node.children) {
      const result = findNodeById(child, id);
      if (result) {
        return result;
      }
    }
  }
  return null;
}

function findNodeByTopic(node: NodeObj | null | undefined, topic: string): NodeObj | null {
  if (!node) {
    return null;
  }
  if (node.topic === topic) {
    return node;
  }
  if (node.children) {
    for (const child of node.children) {
      const result = findNodeByTopic(child, topic);
      if (result) {
        return result;
      }
    }
  }
  return null;
}

export default function localUnitTest() {
  describe('localUnitTest', () => {
    // Defines a test suite. Two parameters are supported: test suite name and test suite function.
    beforeAll(() => {
      // Presets an action, which is performed only once before all test cases of the test suite start.
      // This API supports only one parameter: preset action function.
      GlobalContext.getInstance().setUiContext(new TestUIContext());
    });
    beforeEach(() => {
      // Presets an action, which is performed before each unit test case starts.
      // The number of execution times is the same as the number of test cases defined by **it**.
      // This API supports only one parameter: preset action function.
    });
    afterEach(() => {
      // Presets a clear action, which is performed after each unit test case ends.
      // The number of execution times is the same as the number of test cases defined by **it**.
      // This API supports only one parameter: clear action function.
    });
    afterAll(() => {
      // Presets a clear action, which is performed after all test cases of the test suite end.
      // This API supports only one parameter: clear action function.
    });
    it('assertContain', 0, () => {
      // Defines a test case. This API supports three parameters: test case name, filter parameter, and test case function.
      let a = 'abc';
      let b = 'b';
      // Defines a variety of assertion methods, which are used to declare expected boolean conditions.
      expect(a).assertContain(b);
      expect(a).assertEqual(a);
    });
    it('keepsInputDataImmutable', 0, () => {
      const data: MindElixirData = {
        nodeData: {
          id: 'root',
          topic: 'root',
          children: [{ id: 'child', topic: 'child' }]
        }
      };
      const snapshot = JSON.stringify(data);
      const model = new MindElixirCore({ locale: 'zh' });

      model.init(data);

      expect(JSON.stringify(data)).assertEqual(snapshot);
      model.destroy();
    });
    it('keepsCoreEditingCommandsEquivalent', 0, () => {
      const model = new MindElixirCore({ locale: 'zh' });
      model.init(createMindData());

      expect(model.add('a', 'a-child')).assertEqual(true);
      expect(findNodeById(model.getData()?.nodeData, 'a')?.children?.length).assertEqual(1);
      expect(model.updateNode({ id: 'a', topic: 'node-a-updated' })).assertEqual(true);
      expect(findNodeById(model.getData()?.nodeData, 'a')?.topic).assertEqual('node-a-updated');
      expect(model.remove(findNodeById(model.getData()?.nodeData, 'a')?.children?.[0].id!)).assertEqual(true);
      expect(findNodeById(model.getData()?.nodeData, 'a')?.children?.length).assertEqual(0);

      const childCount = model.getData()?.nodeData.children?.length ?? 0;
      expect(model.addSibling('a', true)).assertEqual(true);
      expect(model.getData()?.nodeData.children?.length).assertEqual(childCount + 1);
      expect(model.addParent('b', 'node-b-parent')).assertEqual(true);
      expect(findNodeByTopic(model.getData()?.nodeData, 'node-b-parent') !== null).assertEqual(true);
      expect(findNodeById(model.getData()?.nodeData, 'b') !== null).assertEqual(true);

      model.destroy();
    });
    it('keepsSelectionLayoutDragAndLinkCommandsEquivalent', 0, () => {
      const model = new MindElixirCore({ locale: 'zh' });
      model.init(createMindData());

      expect(model.selectNode('a')).assertEqual(true);
      expect(model.getSelectedNodeId()).assertEqual('a');
      expect(model.getSelectedNode()?.topic).assertEqual('node-a');
      model.foldNode('a');
      expect(findNodeById(model.getData()?.nodeData, 'a')?.expanded).assertEqual(false);
      model.expandedNode('a');
      expect(findNodeById(model.getData()?.nodeData, 'a')?.expanded).assertEqual(true);

      model.setMindDirection(LayoutDirection.LEFT);
      expect(model.getMindDirection()).assertEqual(LayoutDirection.LEFT);
      model.setScaleVal(1.5);
      expect(model.getScaleVal()).assertEqual(1.5);

      model.startLink('a', true, true);
      expect(model.hasLinkedNode()).assertEqual(true);
      model.renderLink('b');
      expect(model.getData()?.arrows?.length).assertEqual(1);
      expect(model.getData()?.arrows?.[0].bidirectional).assertEqual(true);
      const arrowId = model.getData()?.arrows?.[0].id!;
      model.updateLinkLabel(arrowId, 'a-to-b');
      expect(model.getData()?.arrows?.[0].label).assertEqual('a-to-b');
      model.startLink('', false);
      expect(model.hasLinkedNode()).assertEqual(false);

      expect(model.move('a', MoveDirection.DOWN)).assertEqual(true);
      expect(model.getData()?.nodeData.children?.[1].id).assertEqual('a');
      model.moveNodeToTargetNode('a', 'b', DragOrientation.MIDDLE);
      expect(findNodeById(model.getData()?.nodeData, 'b')?.children?.[0].id).assertEqual('a');
      model.setDragStatusForSubtree('b', false);
      expect(findNodeById(model.getData()?.nodeData, 'b')?.isCantDrag).assertEqual(true);
      expect(findNodeById(model.getData()?.nodeData, 'a')?.isCantDrag).assertEqual(true);
      model.setDragStatusForSubtree('b', true);
      expect(findNodeById(model.getData()?.nodeData, 'b')?.isCantDrag).assertEqual(false);
      expect(findNodeById(model.getData()?.nodeData, 'a')?.isCantDrag).assertEqual(false);

      model.destroy();
    });
    it('keepsUndoAndRedoEquivalent', 0, () => {
      const model = new MindElixirCore({ locale: 'zh', allowUndo: true });
      model.init(createMindData());
      expect(model.add('a', 'undo-child')).assertEqual(true);
      expect(findNodeById(model.getData()?.nodeData, 'a')?.children?.length).assertEqual(1);

      expect(model.undo()).assertEqual(true);
      expect(findNodeById(model.getData()?.nodeData, 'a')?.children?.length).assertEqual(0);
      expect(model.redo()).assertEqual(true);
      expect(findNodeById(model.getData()?.nodeData, 'a')?.children?.length).assertEqual(1);

      model.destroy();
    });
    it('isolatesOptionsBetweenMindMapInstances', 0, () => {
      const customized = new MindElixirCore({
        locale: 'zh',
        nodeSpacing: { horizontal: 5, vertical: 6 },
        nodeStyle: { fontSize: 44 },
        lineStyle: { width: 9 }
      });
      const defaults = new MindElixirCore({ locale: 'zh' });

      expect(customized.getMindOptions().nodeStyle?.fontSize).assertEqual(44);
      expect(defaults.getMindOptions().nodeSpacing?.horizontal).assertEqual(50);
      expect(defaults.getMindOptions().nodeSpacing?.vertical).assertEqual(30);
      expect(defaults.getMindOptions().nodeStyle?.fontSize).assertEqual(20);
      expect(defaults.getMindOptions().lineStyle?.width).assertEqual(2);

      customized.destroy();
      defaults.destroy();
    });
  });
}
