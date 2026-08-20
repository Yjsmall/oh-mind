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
  });
}
