import { Component, Driver, ON } from '@kit.TestKit';
import { describe, expect, it } from '@ohos/hypium';

const UI_SETTLE_MS: number = 200;

async function component(driver: Driver, id: string): Promise<Component> {
  try {
    return await driver.waitForComponent(ON.id(id), 3000);
  } catch (_error) {
    throw new Error('Required UI component was not found: ' + id);
  }
}

export default function freeCanvasUiTest() {
  describe('FreeCanvasUiTest', () => {
    it('pansCanvasWithInjectedDrag', 0, async () => {
      const driver = Driver.create();
      await (await component(driver, 'toolbar-pan')).click();
      const canvas = await component(driver, 'free-canvas');
      const node = await component(driver, 'free-canvas-node-source');
      const canvasBounds = await canvas.getBounds();
      const before = await node.getBounds();
      await driver.drag(canvasBounds.left + 20, canvasBounds.bottom - 30,
        canvasBounds.left + 70, canvasBounds.bottom - 30, 600);
      await driver.delayMs(UI_SETTLE_MS);
      const after = await node.getBounds();
      expect(after.left > before.left).assertEqual(true);
    });

    it('pansCanvasWhenGestureStartsOnNodeInPanMode', 0, async () => {
      const driver = Driver.create();
      await (await component(driver, 'toolbar-pan')).click();
      let source = await component(driver, 'free-canvas-node-source');
      let before = await source.getBounds();
      await driver.drag((before.left + before.right) / 2, (before.top + before.bottom) / 2,
        (before.left + before.right) / 2 + 40, (before.top + before.bottom) / 2 + 10, 600);
      await driver.delayMs(UI_SETTLE_MS);
      source = await component(driver, 'free-canvas-node-source');
      const after = await source.getBounds();
      expect(after.left > before.left).assertEqual(true);
    });

    it('pinchesCanvasAroundItsCenter', 0, async () => {
      const driver = Driver.create();
      const canvas = await component(driver, 'free-canvas');
      const node = await component(driver, 'free-canvas-node-source');
      const before = await node.getBounds();
      await canvas.pinchOut(1.2);
      await driver.delayMs(UI_SETTLE_MS);
      const after = await node.getBounds();
      expect(after.right - after.left > before.right - before.left).assertEqual(true);
    });

    it('marqueeSelectsNodesFromEmptyCanvas', 0, async () => {
      const driver = Driver.create();
      await (await component(driver, 'toolbar-fit')).click();
      await (await component(driver, 'toolbar-select')).click();
      const canvas = await component(driver, 'free-canvas');
      const bounds = await canvas.getBounds();
      await driver.click(bounds.right - 10, bounds.bottom - 10);
      await driver.drag(bounds.right - 10, bounds.bottom - 10,
        bounds.left + 10, bounds.top + 10, 600);
      await driver.delayMs(UI_SETTLE_MS);
      const resizeHandle = await component(driver, 'free-canvas-resize-se');
      expect(await resizeHandle.isEnabled()).assertEqual(true);
    });

    it('dragsSelectedNodeAndResizesItsCard', 0, async () => {
      const driver = Driver.create();
      await (await component(driver, 'toolbar-select')).click();
      let node = await component(driver, 'free-canvas-node-source');
      await node.click();
      let before = await node.getBounds();
      await driver.drag((before.left + before.right) / 2, (before.top + before.bottom) / 2,
        (before.left + before.right) / 2 + 30, (before.top + before.bottom) / 2 + 20, 600);
      await driver.delayMs(UI_SETTLE_MS);
      node = await component(driver, 'free-canvas-node-source');
      const moved = await node.getBounds();
      expect(moved.left > before.left).assertEqual(true);

      const handle = await component(driver, 'free-canvas-resize-se');
      const handleCenter = await handle.getBoundsCenter();
      before = await node.getBounds();
      await driver.drag(handleCenter.x, handleCenter.y, handleCenter.x + 30, handleCenter.y + 20, 600);
      await driver.delayMs(UI_SETTLE_MS);
      const resized = await (await component(driver, 'free-canvas-node-source')).getBounds();
      expect(resized.right - resized.left > before.right - before.left).assertEqual(true);
      expect(resized.bottom - resized.top > before.bottom - before.top).assertEqual(true);
    });

    it('createsLabelsReconnectsAndDeletesEdge', 0, async () => {
      const driver = Driver.create();
      await (await component(driver, 'toolbar-fit')).click();
      await (await component(driver, 'toolbar-select')).click();
      const source = await component(driver, 'free-canvas-node-source');
      const idea = await component(driver, 'free-canvas-node-idea');
      await source.click();
      const anchor = await component(driver, 'free-canvas-anchor-right');
      const anchorCenter = await anchor.getBoundsCenter();
      const ideaBounds = await idea.getBounds();
      await driver.drag(anchorCenter.x, anchorCenter.y, ideaBounds.left + 4,
        (ideaBounds.top + ideaBounds.bottom) / 2, 600);
      await driver.delayMs(UI_SETTLE_MS);

      const label = await component(driver, 'free-canvas-edge-label');
      await label.inputText('new relation');
      await (await component(driver, 'free-canvas-edge-label-save')).click();
      await (await component(driver, 'free-canvas-edge-both')).click();

      const endpoint = await component(driver, 'free-canvas-edge-to');
      const endpointCenter = await endpoint.getBoundsCenter();
      const resultBounds = await (await component(driver, 'free-canvas-node-result')).getBounds();
      await driver.drag(endpointCenter.x, endpointCenter.y, resultBounds.left + 4,
        (resultBounds.top + resultBounds.bottom) / 2, 600);
      await driver.delayMs(UI_SETTLE_MS);
      expect((await component(driver, 'free-canvas-edge-to')) !== undefined).assertEqual(true);

      await (await component(driver, 'free-canvas-edge-delete')).click();
      await driver.delayMs(UI_SETTLE_MS);
      const edgeTools = await driver.findComponents(ON.id('free-canvas-edge-label'));
      expect(edgeTools.length).assertEqual(0);
    });

    it('copiesSelectionAndRestoresItWithUndo', 0, async () => {
      const driver = Driver.create();
      await (await component(driver, 'free-canvas-node-source')).click();
      const toolbar = await component(driver, 'main-toolbar');
      const copyButton = await toolbar.scrollSearch(ON.id('toolbar-copy'));
      await copyButton.click();
      await driver.delayMs(UI_SETTLE_MS);
      expect((await component(driver, 'free-canvas-node-source-copy-1')) !== undefined).assertEqual(true);
      const undoButton = await toolbar.scrollSearch(ON.id('toolbar-undo'));
      await undoButton.click();
      await driver.delayMs(UI_SETTLE_MS);
      const copies = await driver.findComponents(ON.id('free-canvas-node-source-copy-1'));
      expect(copies.length).assertEqual(0);
    });

    it('createsEditsStylesLayersAndActivatesTextNode', 0, async () => {
      const driver = Driver.create();
      await (await component(driver, 'toolbar-select')).click();
      const toolbar = await component(driver, 'main-toolbar');
      await (await toolbar.scrollSearch(ON.id('toolbar-add'))).click();
      const editor = await component(driver, 'free-canvas-node-editor');
      await editor.inputText('# Device note');
      await (await component(driver, 'free-canvas-node-edit-save')).click();
      await driver.delayMs(UI_SETTLE_MS);
      expect((await driver.findComponents(ON.id('free-canvas-node-editor'))).length).assertEqual(0);
      await (await component(driver, 'free-canvas-node-color-5')).click();
      await (await component(driver, 'free-canvas-node-top')).click();
      await (await component(driver, 'free-canvas-node-activate')).click();
      expect((await component(driver, 'node-activation-status')) !== undefined).assertEqual(true);
    });

    it('retainsFailedDraftAndRetriesSave', 0, async () => {
      const driver = Driver.create();
      await (await component(driver, 'toolbar-select')).click();
      await (await component(driver, 'free-canvas-node-source')).click();
      const toolbar = await component(driver, 'main-toolbar');
      await (await toolbar.scrollSearch(ON.id('toolbar-fail-next-save'))).click();
      await (await component(driver, 'free-canvas-node-color-4')).click();
      await driver.delayMs(UI_SETTLE_MS);
      await (await component(driver, 'free-canvas-save-retry')).click();
      await driver.delayMs(UI_SETTLE_MS);
      expect((await driver.findComponents(ON.id('free-canvas-save-retry'))).length).assertEqual(0);
    });
  });
}
