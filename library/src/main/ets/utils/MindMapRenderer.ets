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

import { MindElixirCore } from '../controller/MindElixirCore';
import { CanvasSize, NodeObj } from '../model/NodeObj';
import { MindLineRender } from '../controller/MindLineRender';
import { GlobalContext } from '../utils/GlobalContext';
import { fileIo as fs } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import common from '@ohos.app.ability.common';
import { NodeHelper } from '../controller/NodeHelper';
import { UtilsManager } from '../utils/UtilsManager';

export class MindMapRenderer {
  private mind: MindElixirCore;
  private offscreenCanvas: OffscreenCanvas;
  private context: OffscreenCanvasRenderingContext2D;
  private nodes: NodeObj[] = [];
  private nodeHelper: NodeHelper;


  /**
   * 构造函数
   * @param model 思维导图核心实例
   */
  constructor(model: MindElixirCore) {
    this.mind = model;
   this.nodeHelper = UtilsManager.getNodeHelper(this.mind.getInstanceId())!;
    const canvasSize: CanvasSize =  this.nodeHelper.getCanvasSize();
    this.offscreenCanvas = new OffscreenCanvas(Number(canvasSize.width), Number(canvasSize.height));
    const context = this.offscreenCanvas.getContext('2d');
    if (!context) {
      throw new Error('Failed to get 2d context from OffscreenCanvas');
    }
    this.context = context;
  }

  /**
   * 初始化并绘制整个思维导图
   * @param width 可选画布宽度
   * @param height 可选画布高度
   */
  public init(width?: number, height?: number): void {
    this.nodes =  this.nodeHelper.getFlatNodes();

    // 如果指定了新的宽高，重新创建画布
    if (width && height) {
      this.offscreenCanvas = new OffscreenCanvas(width, height);
      const context = this.offscreenCanvas.getContext('2d');
      if (context) {
        this.context = context;
      }
    }

    this.clearCanvas();
    this.drawLines();
    this.drawNodes();
  }

  /**
   * 清空画布
   */
  private clearCanvas(): void {
    this.context.clearRect(0, 0, this.offscreenCanvas.width, this.offscreenCanvas.height);
  }

  /**
   * 绘制连接线
   */
  private drawLines(): void {
    MindLineRender.createInstance(this.mind!.getInstanceId()).init(this.context, this.mind!);
  }

  /**
   * 绘制节点
   */
  private drawNodes(): void {
    this.nodes.forEach(node => {
      if (node.level! == 0 || node.level! == 1 || (node.level! > 1 && node.parent!.expanded!)) {
        this.drawNode(node);
      }
    });
  }

  /**
   * 绘制单个节点
   */
  private drawNode(node: NodeObj): void {
    if (!node.x || !node.y) {
      return;
    }

    const ctx = this.context;
    const x = node.x!;
    const y = node.y!;
    const width = node.width!;
    const height = node.height!;

    // 保存当前状态
    ctx.save();

    // 为 level < 2 的节点绘制边框
    if (node.level !== undefined && node.level < 2) {
      this.drawNodeBorder(node, x, y, width, height);
    }
    const uiContext: UIContext = GlobalContext.getInstance().getUiContext()!;

    // 绘制文本
    ctx.fillStyle = node.style?.color || '#000';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.font = `${uiContext.vp2px(Number(node.style?.fontSize) || 20)}px HarmonyOS Sans`;
    ctx.fillText(node.topic, x + width / 2, y + height / 2);

    // 绘制标签
    if (node.tags && node.tags.length > 0) {
      this.drawTags(node, x, y, width, height);
    }

    // 绘制折叠节点
    if (!node.expanded && node.children!.length > 0 && node.level! >= 1) {
      this.drawFoldNode(node, x, y, width, height);
    }

    // 恢复状态
    ctx.restore();
  }

  /**
   * 绘制折叠节点
   */
  private drawFoldNode(node: NodeObj, x: number, y: number, width: number, height: number): void {
    // 绘制连接线
    const ctx = this.context;
    ctx.beginPath();
    ctx.moveTo(x + width, y + height / 2);
    ctx.lineTo(x + width + 10, y + height / 2);
    ctx.lineWidth = 3;
    ctx.strokeStyle = Color.Orange;
    ctx.stroke();

    // 绘制节点数量
    const centerX = x + width + 20;
    const centerY = y + height / 2;
    const radius = 10;

    // 开始绘制路径
    ctx.beginPath();
    ctx.arc(centerX, centerY, radius, 0, Math.PI * 2);
    ctx.fillStyle = '#fff';
    ctx.fill();
    ctx.strokeStyle = 'Color.Orange';
    ctx.lineWidth = 3;
    ctx.stroke();

    // 设置文字样式
    ctx.font = '12px sans-serif';
    ctx.fillStyle = '#000000';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';

    // 在圆心位置绘制文字
    const nodeHelper: NodeHelper = UtilsManager.getNodeHelper(this.mind.getInstanceId())!;
    const text = nodeHelper.getAllChildrenNumber(node) + '';
    ctx.fillText(text, centerX, centerY);
  }

  /**
   * 绘制节点边框（针对 level < 3 的节点）
   */
  private drawNodeBorder(node: NodeObj, x: number, y: number, width: number, height: number): void {
    const ctx = this.context;
    const borderRadius = 20;
    const borderWidth = 2;

    // 设置边框样式
    ctx.strokeStyle = '#3366FF';
    ctx.lineWidth = borderWidth;

    // 绘制圆角矩形边框
    this.drawRoundedRect(ctx, x, y, width, height, borderRadius);
    ctx.stroke();
  }

  /**
   * 绘制圆角矩形
   */
  private drawRoundedRect(ctx: OffscreenCanvasRenderingContext2D, x: number, y: number, width: number, height: number,
    radius: number): void {
    ctx.beginPath();
    ctx.moveTo(x + radius, y);
    ctx.lineTo(x + width - radius, y);
    ctx.arcTo(x + width, y, x + width, y + radius, radius);
    ctx.lineTo(x + width, y + height - radius);
    ctx.arcTo(x + width, y + height, x + width - radius, y + height, radius);
    ctx.lineTo(x + radius, y + height);
    ctx.arcTo(x, y + height, x, y + height - radius, radius);
    ctx.lineTo(x, y + radius);
    ctx.arcTo(x, y, x + radius, y, radius);
    ctx.closePath();
  }

  /**
   * 绘制标签
   */
  private drawTags(node: NodeObj, x: number, y: number, width: number, height: number): void {
    const ctx = this.context;
    const tags = node.tags || [];
    const uiContext: UIContext = GlobalContext.getInstance().getUiContext()!;

    // 只显示前3个标签
    let displayTags: string[] = [];
    if (tags.length > 3) {
      let exceedNum = tags.length - 2;
      let lastTag = `+${exceedNum}`;
      displayTags = tags.slice(0, 2);
      displayTags.push(lastTag);
    } else {
      displayTags = tags;
    }

    displayTags.forEach((tag, index) => {
      // 保存当前上下文状态
      ctx.save();

      // 计算标签位置
      const PADDING = 5;
      const TAGS_HEIGHT = 25;

      let tagX = x;
      let tagY = y + height + PADDING;

      if (index > 0) {
        tagY = y + height + PADDING + (TAGS_HEIGHT + PADDING) * index;
      }

      const tagWidth = width;
      const tagHeight = TAGS_HEIGHT;
      const borderRadius = 10;

      // 绘制边框背景
      ctx.fillStyle = '#ffffff';
      ctx.strokeStyle = '#cccccc';
      ctx.lineWidth = 2;

      // 绘制圆角矩形
      this.drawRoundedRect(ctx, tagX, tagY, tagWidth, tagHeight, borderRadius);
      ctx.fill();
      ctx.stroke();

      // 设置文本样式
      ctx.fillStyle = '#000000';
      ctx.font = `${uiContext.vp2px(16)}px HarmonyOS Sans`;
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';

      // 计算文本位置
      const textX = tagX + tagWidth / 2;
      const textY = tagY + tagHeight / 2;

      // 文本溢出处理
      const maxTextWidth = tagWidth - 16;
      let displayText = tag;

      if (ctx.measureText(tag).width > maxTextWidth) {
        let truncatedText = tag;
        while (truncatedText.length > 0 && ctx.measureText(truncatedText + '...').width > maxTextWidth) {
          truncatedText = truncatedText.slice(0, -1);
        }
        displayText = truncatedText + '...';
      }

      // 绘制文本
      ctx.fillText(displayText, textX, textY);

      // 恢复上下文状态
      ctx.restore();
    });
  }

  /**
   * 导出为PNG
   */
  exportToPNG(): string {
    return this.context.toDataURL('image/png');
  }

  /**
   * 转换为ImageBitmap
   */
  transferToImageBitmap() {
    return this.context.transferToImageBitmap();
  }

  /**
   * 保存图像到文件
   */
  async saveImage(fileName: string = 'mindmap.png'): Promise<string> {
    try {
      const context: common.UIAbilityContext = GlobalContext.getInstance().getContext()!;
      const sandboxDir = context.filesDir;
      const filePath = sandboxDir + '/' + fileName;

      const dataURL = this.exportToPNG();
      const base64Data = dataURL.split(',')[1];

      const Base64Helper = new util.Base64Helper();
      const uint8Array: Uint8Array = Base64Helper.decodeSync(base64Data);
      const arrayBuffer: ArrayBuffer = uint8Array.buffer.slice(0, uint8Array.byteLength);

      const file = fs.openSync(filePath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
      await fs.write(file.fd, arrayBuffer);
      fs.closeSync(file.fd);
      return filePath;

    } catch (error) {
      console.error('Failed to save image:', error);
      throw new Error(`Failed to save image: ${error.message}`);
    }
  }

  /**
   * 获取画布上下文
   */
  getContext(): OffscreenCanvasRenderingContext2D {
    return this.context;
  }

  /**
   * 获取画布元素
   */
  getCanvas(): OffscreenCanvas {
    return this.offscreenCanvas;
  }

  /**
   * 调整画布大小
   */
  resize(width: number, height: number): void {
    this.offscreenCanvas = new OffscreenCanvas(width, height);
    const context = this.offscreenCanvas.getContext('2d');
    if (context) {
      this.context = context;
    }
    this.init();
  }

  /**
   * 销毁渲染器
   */
  destroy(): void {
    // 清理资源
    this.nodes = [];
    // 这里可以根据需要添加其他清理逻辑
  }
}