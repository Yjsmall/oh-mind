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
    it('pansCanvasWithQuickEmptyDragWithoutModeButtons', 0, async () => {
      const driver = Driver.create();
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

    it('selectsNodeOnSingleTapAndDeselectsOnEmptyClick', 0, async () => {
      const driver = Driver.create();
      let source = await component(driver, 'free-canvas-node-source');
      await source.click();
      await driver.delayMs(UI_SETTLE_MS);
      const toolbar = await component(driver, 'free-canvas-node-toolbar');
      const toolbarBounds = await toolbar.getBounds();
      expect(toolbarBounds.right - toolbarBounds.left > 0).assertEqual(true);

      const canvas = await component(driver, 'free-canvas');
      const canvasBounds = await canvas.getBounds();
      await driver.click(canvasBounds.right - 20, canvasBounds.top + 20);
      await driver.delayMs(UI_SETTLE_MS);
      const tools = await driver.findComponents(ON.id('free-canvas-node-toolbar'));
      expect(tools.length).assertEqual(0);
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

    it('dragsSelectedNodeAndResizesItsCard', 0, async () => {
      const driver = Driver.create();
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
      const edgeToolbar = await component(driver, 'free-canvas-edge-toolbar');
      await (await edgeToolbar.scrollSearch(ON.id('free-canvas-edge-color-5'))).click();
      const customColor = await edgeToolbar.scrollSearch(ON.id('free-canvas-edge-color-custom'));
      await customColor.inputText('#2367A8');
      await (await edgeToolbar.scrollSearch(ON.id('free-canvas-edge-color-apply'))).click();

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
      await driver.delayMs(UI_SETTLE_MS);
      await (await component(driver, 'free-canvas-copy')).click();
      await driver.delayMs(UI_SETTLE_MS);
      expect((await component(driver, 'free-canvas-node-source-copy-1')) !== undefined).assertEqual(true);
      await (await component(driver, 'toolbar-undo')).click();
      await driver.delayMs(UI_SETTLE_MS);
      const copies = await driver.findComponents(ON.id('free-canvas-node-source-copy-1'));
      expect(copies.length).assertEqual(0);
    });

    it('createsEditsStylesAndActivatesTextNode', 0, async () => {
      const driver = Driver.create();
      await (await component(driver, 'toolbar-add')).click();
      let editor = await component(driver, 'free-canvas-node-editor');
      await editor.inputText('# Device note');
      await (await component(driver, 'free-canvas-node-edit-save')).click();
      await driver.delayMs(UI_SETTLE_MS);

      await (await component(driver, 'free-canvas-node-edit')).click();
      editor = await component(driver, 'free-canvas-node-editor');
      await editor.inputText('# Device note v2');
      await (await component(driver, 'free-canvas-node-edit-save')).click();
      await driver.delayMs(UI_SETTLE_MS);
      expect((await driver.findComponents(ON.id('free-canvas-node-editor'))).length).assertEqual(0);

      await (await component(driver, 'free-canvas-node-color')).click();
      await driver.delayMs(UI_SETTLE_MS);
      await (await component(driver, 'free-canvas-node-color-5')).click();
      await driver.delayMs(UI_SETTLE_MS);
      await (await component(driver, 'free-canvas-node-more')).click();
      await driver.delayMs(UI_SETTLE_MS);
      await (await component(driver, 'free-canvas-node-top')).click();
      await (await component(driver, 'free-canvas-node-activate')).click();
      expect((await component(driver, 'node-activation-status')) !== undefined).assertEqual(true);
    });

    it('retainsFailedDraftAndRetriesSave', 0, async () => {
      const driver = Driver.create();
      await (await component(driver, 'free-canvas-node-source')).click();
      await (await component(driver, 'toolbar-fail-next-save')).click();
      await (await component(driver, 'free-canvas-node-color')).click();
      await driver.delayMs(UI_SETTLE_MS);
      await (await component(driver, 'free-canvas-node-color-4')).click();
      await driver.delayMs(UI_SETTLE_MS);
      await (await component(driver, 'free-canvas-save-retry')).click();
      await driver.delayMs(UI_SETTLE_MS);
      expect((await driver.findComponents(ON.id('free-canvas-save-retry'))).length).assertEqual(0);
    });

    it('multiSelectsMovesAndDeletesWholeSelection', 0, async () => {
      const driver = Driver.create();
      await (await component(driver, 'toolbar-multiselect')).click();
      await (await component(driver, 'free-canvas-node-source')).click();
      await (await component(driver, 'free-canvas-node-idea')).click();
      await driver.delayMs(UI_SETTLE_MS);
      const toolbar = await component(driver, 'free-canvas-node-toolbar');
      const toolbarBounds = await toolbar.getBounds();
      expect(toolbarBounds.right - toolbarBounds.left > 0).assertEqual(true);

      let source = await component(driver, 'free-canvas-node-source');
      const bounds = await source.getBounds();
      await driver.drag((bounds.left + bounds.right) / 2, (bounds.top + bounds.bottom) / 2,
        (bounds.left + bounds.right) / 2 + 40, (bounds.top + bounds.bottom) / 2 + 10, 600);
      await driver.delayMs(UI_SETTLE_MS);
      source = await component(driver, 'free-canvas-node-source');
      const moved = await source.getBounds();
      expect(moved.left > bounds.left).assertEqual(true);
      const idea = await component(driver, 'free-canvas-node-idea');
      const movedIdea = await idea.getBounds();
      expect(movedIdea.left > bounds.left).assertEqual(true);

      await (await component(driver, 'free-canvas-delete')).click();
      await driver.delayMs(UI_SETTLE_MS);
      expect((await driver.findComponents(ON.id('free-canvas-node-source'))).length).assertEqual(0);
      expect((await driver.findComponents(ON.id('free-canvas-node-idea'))).length).assertEqual(0);
    });
  });
}