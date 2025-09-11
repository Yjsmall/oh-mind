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
import { CanvasSize, NodeObj, NodeOption, NodeStyle, LayoutDirection, Coordinate } from '../model/NodeObj';
import { MindLineRender } from '../controller/MindLineRender';
import { NodeHelper } from '../controller/NodeHelper';
import { UtilsManager } from '../utils/UtilsManager';
import { GlobalContext } from '../utils/GlobalContext';

const FOLD_BTN_WIDTH: number = 20;

export class MindMapRenderer {
  private mind: MindElixirCore;
  private offscreenCanvas: OffscreenCanvas;
  private context: OffscreenCanvasRenderingContext2D;
  private nodes: NodeObj[] = [];
  private nodeHelper: NodeHelper;
  private options: NodeOption | null = null;
  private nodeStyles: NodeStyle = {};

  /**
   * 构造函数
   * @param model 思维导图核心实例
   */
  constructor(model: MindElixirCore) {
    this.mind = model;
    this.options = this.mind.getMindOptions();
    this.nodeHelper = UtilsManager.getNodeHelper(this.mind.getInstanceId())!;
    const canvasSize: CanvasSize = this.nodeHelper.getCanvasSize();
    this.offscreenCanvas = new OffscreenCanvas(Number(canvasSize.width), Number(canvasSize.height));
    const context = this.offscreenCanvas.getContext('2d');
    if (!context) {
      throw new Error('Failed to get 2d context from OffscreenCanvas');
    }
    this.context = context;
    this.getStyles();
  }

  /**
   * 获取节点样式
   */
  private getStyles(): void {
    const modelStyles = this.mind.getMindOptions();
    this.nodeStyles.fontSize = modelStyles.nodeStyle?.fontSize || 16;
    this.nodeStyles.fontFamily = modelStyles.nodeStyle?.fontFamily || 'HarmonyOS Sans';
    this.nodeStyles.color = modelStyles.nodeStyle?.color || '#000';
    this.nodeStyles.background = modelStyles.nodeStyle?.background || Color.Transparent;
    this.nodeStyles.fontWeight = modelStyles.nodeStyle?.fontWeight || 'normal';
    this.nodeStyles.border = modelStyles.nodeStyle?.border || { width: 0, radius: 20 };
  }

  /**
   * 计算选中状态的边框样式
   */
  private getBorderStyle(node: NodeObj): BorderOptions {
    const isSelected = this.mind.getSelectedNodeId() === node.id;
    const borderWidth = this.nodeStyles.border?.width !== undefined ? Number(this.nodeStyles.border.width) : 0;
    return {
      width: isSelected ? 3 : (node.level! <= 1 ? 2 : borderWidth),
      color: isSelected ? '#1890FF' : this.nodeStyles?.border?.color,
      radius: this.nodeStyles.border?.radius !== undefined ? Number(this.nodeStyles.border.radius) : 20
    };
  }

  /**
   * 初始化并绘制整个思维导图
   * @param width 可选画布宽度
   * @param height 可选画布高度
   */
  public init(width?: number, height?: number): void {
    this.nodes = this.nodeHelper.getFlatNodes();

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
    const ctx = this.context;
    // 首先清空画布
    ctx.clearRect(0, 0, this.offscreenCanvas.width, this.offscreenCanvas.height);
    // 设置白色背景
    ctx.fillStyle = '#ffffff'; // 白色
    ctx.fillRect(0, 0, this.offscreenCanvas.width, this.offscreenCanvas.height);
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

    // 绘制节点背景和边框
    this.drawNodeBackground(node, x, y, width, height);

    // 绘制文本
    this.drawNodeText(node, x, y, width, height);


    // 绘制折叠指示器
    if (!node.expanded && node.children!.length > 0 && node.level! >= 1) {
      this.drawFoldIndicator(node, x, y, width, height);
    }

    // 恢复状态
    ctx.restore();
  }

  /**
   * 绘制节点背景和边框
   */
  private drawNodeBackground(node: NodeObj, x: number, y: number, width: number, height: number): void {
    const ctx = this.context;
    const borderStyle = this.getBorderStyle(node);
    const borderRadius = borderStyle.radius || 20;

    // 绘制背景
    ctx.fillStyle = (node.style?.background || this.nodeStyles.background) as string || '';
    this.drawRoundedRect(ctx, x, y, width, height, borderRadius as number);
    ctx.fill();

    // 绘制边框
    if (borderStyle.width && borderStyle.width > 0) {
      ctx.strokeStyle = (borderStyle.color as string) || '';
      ctx.lineWidth = borderStyle.width as number;
      this.drawRoundedRect(ctx, x, y, width, height, borderRadius as number);
      ctx.stroke();
    }
  }

  /**
   * 绘制节点文本
   */
  private drawNodeText(node: NodeObj, x: number, y: number, width: number, height: number): void {
    const ctx = this.context;
    const uiContext: UIContext | null = GlobalContext.getInstance().getUiContext()!;
    const textColor = node.style?.color || this.nodeStyles.color || '#000';
    const fontSize = uiContext.vp2px(node.style?.fontSize || this.nodeStyles.fontSize || 16);
    const fontFamily = node.style?.fontFamily || this.nodeStyles.fontFamily || 'HarmonyOS Sans';
    const fontWeight = node.style?.fontWeight || this.nodeStyles.fontWeight || 'normal';

    ctx.fillStyle = textColor;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.font = `${fontWeight} ${fontSize}px ${fontFamily}`;

    // 文本溢出处理
    const maxTextWidth = width - 16;
    let displayText = node.topic;

    if (ctx.measureText(node.topic).width > maxTextWidth) {
      let truncatedText = node.topic;
      while (truncatedText.length > 0 && ctx.measureText(truncatedText + '...').width > maxTextWidth) {
        truncatedText = truncatedText.slice(0, -1);
      }
      displayText = truncatedText + '...';
    }

    ctx.fillText(displayText, x + width / 2, y + height / 2);
  }

  /**
   * 绘制折叠指示器
   */
  private drawFoldIndicator(node: NodeObj, x: number, y: number, width: number, height: number): void {
    const ctx = this.context;
    const layout = this.options?.layout ?? LayoutDirection.RIGHT;
    const foldBtnPoint = this.getFoldBtnPoint(node, layout);

    // 绘制连接线
    ctx.beginPath();

    if (layout === LayoutDirection.LEFT) {
      ctx.moveTo(x, y + height / 2);
      ctx.lineTo(foldBtnPoint.x + FOLD_BTN_WIDTH / 2, y + height / 2);
    } else if (layout === LayoutDirection.RIGHT) {
      ctx.moveTo(x + width, y + height / 2);
      ctx.lineTo(foldBtnPoint.x - FOLD_BTN_WIDTH / 2, y + height / 2);
    } else if (layout === LayoutDirection.TOP) {
      ctx.moveTo(x + width / 2, y);
      ctx.lineTo(x + width / 2, foldBtnPoint.y + FOLD_BTN_WIDTH / 2);
    } else if (layout === LayoutDirection.BOTTOM) {
      ctx.moveTo(x + width / 2, y + height);
      ctx.lineTo(x + width / 2, foldBtnPoint.y - FOLD_BTN_WIDTH / 2);
    }

    ctx.lineWidth = 3;
    ctx.strokeStyle = '#ffa500';
    ctx.stroke();

    // 绘制圆形指示器
    const centerX: number = foldBtnPoint.x;
    const centerY: number = foldBtnPoint.y;
    const radius = 10;

    ctx.beginPath();
    ctx.arc(centerX, centerY, radius, 0, Math.PI * 2);
    ctx.fillStyle = '#fff';
    ctx.fill();
    ctx.strokeStyle = '#ffa500';
    ctx.lineWidth = 3;
    ctx.stroke();

    // 设置文字样式
    ctx.font = '12px HarmonyOS Sans';
    ctx.fillStyle = '#000000';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';

    // 在圆心位置绘制文字
    const text = this.nodeHelper.getAllChildrenNumber(node) + '';
    ctx.fillText(text, centerX, centerY);
  }

  /**
   * 获取折叠按钮位置
   */
  private getFoldBtnPoint(node: NodeObj, layout: LayoutDirection): Coordinate {
    try {
      if (layout === LayoutDirection.LEFT) {
        return {
          x: node.x! - FOLD_BTN_WIDTH / 2,
          y: node.y! + (node.height!) / 2 - FOLD_BTN_WIDTH / 2
        };
      } else if (layout === LayoutDirection.RIGHT) {
        return {
          x: node.x! + node.width! - FOLD_BTN_WIDTH / 2,
          y: node.y! + (node.height!) / 2 - FOLD_BTN_WIDTH / 2
        };
      } else if (layout === LayoutDirection.TOP) {
        return {
          x: node.x! + (node.width!) / 2 - FOLD_BTN_WIDTH / 2,
          y: node.y! - FOLD_BTN_WIDTH / 2
        };
      } else if (layout === LayoutDirection.BOTTOM) {
        return {
          x: node.x! + (node.width!) / 2 - FOLD_BTN_WIDTH / 2,
          y: node.y! + (node.height!) - FOLD_BTN_WIDTH / 2
        };
      } else {
        return {
          x: node.x! + node.width! - FOLD_BTN_WIDTH / 2,
          y: node.y! + (node.height!) / 2 - FOLD_BTN_WIDTH / 2
        };
      }
    } catch (e) {
      console.error('node data error');
      return { x: 0, y: 0 };
    }
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
    this.nodes = [];
  }
}