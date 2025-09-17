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

import { NodeObj, NodeSize, LayoutDirection, CanvasSize, Bounds } from '../model/NodeObj';
import { TextMeasureUtils } from '../utils/TextMeasureUtils';
import { MindElixirCore } from './MindElixirCore';
import { UtilsManager } from '../utils/UtilsManager';
import { CanvasPositionUtils } from '../utils/CanvasPositionUtils';
import { NodeHelper } from '../controller/NodeHelper';

export class MindMapLayout {
  // 布局常量配置
  private static readonly CANVAS_PADDING = 100;
  private static readonly TAGS_WIDTH = 24;
  private static horizontalGap = 100;
  private static verticalGap = 50;
  private static textPadding = 10;
  private static layoutDirection = LayoutDirection.RIGHT;
  private static siblingAlignment: boolean = true;
  private static maxWidth: number = 200;

  /**
   * 计算节点布局并返回画布大小
   */
  static calculate(root: NodeObj, model: MindElixirCore): CanvasSize {
    if (!root) {
      return { width: 200, height: 200 };
    }

    const options = model.getMindOptions();
    const positionCtrl: CanvasPositionUtils = UtilsManager.getPositionUtils(model.getInstanceId())!;

    // 配置参数
    MindMapLayout.horizontalGap = options.nodeSpacing!.horizontal;
    MindMapLayout.verticalGap = options.nodeSpacing!.vertical;
    MindMapLayout.layoutDirection = options!.layout ?? LayoutDirection.RIGHT;
    MindMapLayout.textPadding = options!.nodeStyle?.padding ?? 10;
    MindMapLayout.siblingAlignment = options!.siblingAlignment ?? true;
    MindMapLayout.maxWidth = options!.nodeStyle?.maxWidth ?? 200;

    // 1. 测量所有节点尺寸
    MindMapLayout.measureNodes(root);
    if (MindMapLayout.siblingAlignment) {
      MindMapLayout.alignSiblingWidths(root);
    }
    MindMapLayout.calculateSubtreeSizes(root);

    // 2. 检查是否有保存的根节点位置
    const nodeHelper: NodeHelper = UtilsManager.getNodeHelper(model.getInstanceId())!;
    const savedRootPosition = nodeHelper.getRootPosition();
    let rootX: number, rootY: number;

    const canvasSize = nodeHelper.getCanvasSize();
    MindMapLayout.layoutNode(root, 1, 1, 0, MindMapLayout.layoutDirection);
    const tempBounds = MindMapLayout.calculateBounds(root);
    const tempCanvasSize: CanvasSize = {
      width: tempBounds.maxX - tempBounds.minX + 2 * MindMapLayout.CANVAS_PADDING,
      height: tempBounds.maxY - tempBounds.minY + 2 * MindMapLayout.CANVAS_PADDING
    };
    const isCanvasChange = (tempCanvasSize.width > canvasSize.width) || (tempCanvasSize.height > canvasSize.height);
    if (savedRootPosition && !isCanvasChange) {
      rootX = savedRootPosition.x;
      rootY = savedRootPosition.y;
      MindMapLayout.layoutNode(root, rootX, rootY, 0, MindMapLayout.layoutDirection);
      return canvasSize;
    } else {
      rootX = -tempBounds.minX + MindMapLayout.CANVAS_PADDING;
      rootY = -tempBounds.minY + MindMapLayout.CANVAS_PADDING;
      nodeHelper.setRootPosition(rootX, rootY);
      MindMapLayout.layoutNode(root, rootX, rootY, 0, MindMapLayout.layoutDirection);
      positionCtrl.setMindContentSize(tempCanvasSize.width, tempCanvasSize.height);
      return tempCanvasSize;
    }
  }

  /**
   * 测量节点基本尺寸
   */
  private static measureNodes(node: NodeObj): void {
    const nodeSize = TextMeasureUtils.getInstance()
      .measureText(node.topic, node.style?.fontSize ?? 20, node.style?.maxWidth ?? MindMapLayout.maxWidth);
    const padding = node.style?.padding ?? MindMapLayout.textPadding;
    node.width = nodeSize.width + 2 * padding;
    if (node.tags?.length) {
      node.width = nodeSize.width + 2 * padding + MindMapLayout.TAGS_WIDTH;
    }
    node.height = nodeSize.height + 2 * padding;
    // 递归测量子节点
    if (node.children?.length && node.expanded !== false) {
      for (const child of node.children) {
        MindMapLayout.measureNodes(child);
      }
    }
  }


  /**
   * 对齐同级节点的宽度
   */
  private static alignSiblingWidths(root: NodeObj): void {
    const nodesByLevel = new Map<number, NodeObj[]>();
    const queue: NodeObj[] = [root];
    root.level = 0;

    // 按层级收集节点
    while (queue.length > 0) {
      const node = queue.shift()!;
      const level = node.level || 0;

      if (!nodesByLevel.has(level)) {
        nodesByLevel.set(level, []);
      }
      nodesByLevel.get(level)!.push(node);

      if (node.children && node.expanded !== false) {
        node.children.forEach(child => {
          child.level = level + 1;
          queue.push(child);
        });
      }
    }

    // 对每个层级设置相同宽度（跳过根节点）
    nodesByLevel.forEach((nodes, level) => {
      if (level === 0) return; // 跳过根节点

      let maxWidth = 0;
      // 找到该层级的最大宽度
      nodes.forEach(node => {
        if (node.width && node.width > maxWidth) {
          maxWidth = node.width;
        }
      });

      // 设置所有同级节点为相同宽度
      nodes.forEach(node => {
        node.width = maxWidth;
      });
    });
  }

  /**
   * 计算子树尺寸（使用对齐后的宽度）
   */
  private static calculateSubtreeSizes(node: NodeObj): void {
    // 初始化子树尺寸
    if (MindMapLayout.isHorizontalLayout()) {
      node.subtreeWidth = 0;
      node.subtreeHeight = node.height!;
    } else {
      node.subtreeWidth = node.width!;
      node.subtreeHeight = 0;
    }

    if (node.children?.length && node.expanded !== false) {
      // 先递归计算所有子节点的子树尺寸
      for (const child of node.children) {
        MindMapLayout.calculateSubtreeSizes(child);
      }

      if (MindMapLayout.isHorizontalLayout()) {
        // 水平布局：计算最大子宽度和总高度
        let maxChildWidth = 0;
        let totalChildrenHeight = 0;

        for (const child of node.children) {
          maxChildWidth = Math.max(maxChildWidth, child.subtreeWidth!);
          totalChildrenHeight += child.subtreeHeight!;
        }

        // 添加垂直间距
        totalChildrenHeight += MindMapLayout.verticalGap * (node.children.length - 1);

        // 更新父节点尺寸
        node.subtreeHeight = Math.max(node.height!, totalChildrenHeight);
        node.subtreeWidth = node.width! + maxChildWidth + MindMapLayout.horizontalGap;
      } else {
        // 垂直布局：计算最大子高度和总宽度
        let maxChildHeight = 0;
        let totalChildrenWidth = 0;

        for (const child of node.children) {
          maxChildHeight = Math.max(maxChildHeight, child.subtreeHeight!);
          totalChildrenWidth += child.subtreeWidth!;
        }

        // 添加水平间距
        totalChildrenWidth += MindMapLayout.horizontalGap * (node.children.length - 1);

        // 更新父节点尺寸
        node.subtreeWidth = Math.max(node.width!, totalChildrenWidth);
        node.subtreeHeight = node.height! + maxChildHeight + MindMapLayout.verticalGap;
      }
    }
  }


  /**
   * 核心布局方法
   */
  private static layoutNode(
    node: NodeObj,
    x: number,
    y: number,
    level: number,
    direction: number
  ): void {
    node.x = x;
    node.y = y;
    node.level = level;
    node.direction = direction;

    if (node.children?.length && node.expanded !== false) {
      switch (direction) {
        case LayoutDirection.RIGHT:
          MindMapLayout.layoutHorizontal(node, x, y, level, LayoutDirection.RIGHT);
          break;
        case LayoutDirection.LEFT:
          MindMapLayout.layoutHorizontal(node, x, y, level, LayoutDirection.LEFT);
          break;
        case LayoutDirection.TOP:
          MindMapLayout.layoutVertical(node, x, y, level, LayoutDirection.TOP);
          break;
        case LayoutDirection.BOTTOM:
          MindMapLayout.layoutVertical(node, x, y, level, LayoutDirection.BOTTOM);
          break;
      }
    }
  }

  /**
   * 水平布局（左右方向）
   */
  private static layoutHorizontal(node: NodeObj, x: number, y: number, level: number,
    direction: LayoutDirection.RIGHT | LayoutDirection.LEFT): void {
    const parentCenterY = y + (node.height!) / 2;

    if (node.children!.length === 1) {
      const child = node.children![0];
      const childCenterY = parentCenterY;
      const childY = childCenterY - (child.height!) / 2;
      const childX = direction === LayoutDirection.RIGHT ?
        x + node.width! + MindMapLayout.horizontalGap :
        x - MindMapLayout.horizontalGap - child.width!;

      MindMapLayout.layoutNode(child, childX, childY, level + 1,
        direction);
      return;
    }

    // 计算总高度
    let totalChildrenHeight = 0;
    for (const child of node.children!) {
      totalChildrenHeight += child.subtreeHeight!;
    }
    totalChildrenHeight += MindMapLayout.verticalGap * (node.children!.length - 1);

    let currentY = parentCenterY - totalChildrenHeight / 2;

    for (const child of node.children!) {
      const childCenterY = currentY + (child.subtreeHeight!) / 2;
      const childY = childCenterY - (child.height!) / 2;
      const childX = direction === LayoutDirection.RIGHT ?
        x + node.width! + MindMapLayout.horizontalGap :
        x - MindMapLayout.horizontalGap - child.width!;

      MindMapLayout.layoutNode(child, childX, childY, level + 1,
        direction);

      currentY += child.subtreeHeight! + MindMapLayout.verticalGap;
    }
  }

  /**
   * 垂直布局（上下方向）
   */
  private static layoutVertical(node: NodeObj, x: number, y: number, level: number,
    direction: LayoutDirection.BOTTOM | LayoutDirection.TOP): void {
    const parentCenterX = x + (node.width!) / 2;

    if (node.children!.length === 1) {
      const child = node.children![0];
      const childCenterX = parentCenterX;
      const childX = childCenterX - (child.width!) / 2;
      const childY = direction === LayoutDirection.BOTTOM ?
        y + node.height! + MindMapLayout.verticalGap :
        y - MindMapLayout.verticalGap - child.height!;

      MindMapLayout.layoutNode(child, childX, childY, level + 1,
        direction);
      return;
    }

    // 计算总宽度
    let totalChildrenWidth = 0;
    for (const child of node.children!) {
      totalChildrenWidth += child.subtreeWidth!;
    }
    totalChildrenWidth += MindMapLayout.horizontalGap * (node.children!.length - 1);

    let currentX = parentCenterX - totalChildrenWidth / 2;

    for (const child of node.children!) {
      const childCenterX = currentX + (child.subtreeWidth!) / 2;
      const childX = childCenterX - (child.width!) / 2;
      const childY = direction === LayoutDirection.BOTTOM ?
        y + node.height! + MindMapLayout.verticalGap :
        y - MindMapLayout.verticalGap - child.height!;

      MindMapLayout.layoutNode(child, childX, childY, level + 1,
        direction);

      currentX += child.subtreeWidth! + MindMapLayout.horizontalGap;
    }
  }

  /**
   * 判断是否为水平布局
   */
  private static isHorizontalLayout(): boolean {
    return MindMapLayout.layoutDirection === LayoutDirection.RIGHT ||
      MindMapLayout.layoutDirection === LayoutDirection.LEFT;
  }

  /**
   * 计算节点边界
   */
  private static calculateBounds(node: NodeObj): Bounds {
    const allNodes = MindMapLayout.flattenTree(node);
    const bounds: Bounds = {
      minX: Infinity,
      maxX: -Infinity,
      minY: Infinity,
      maxY: -Infinity
    };

    allNodes.forEach(n => {
      if (!n.x || !n.y || !n.width || !n.height) {
        return;
      }

      bounds.minX = Math.min(bounds.minX, n.x);
      bounds.maxX = Math.max(bounds.maxX, n.x + n.width);
      bounds.minY = Math.min(bounds.minY, n.y - n.height / 2);
      bounds.maxY = Math.max(bounds.maxY, n.y + n.height / 2);
    });

    // 处理单节点情况
    if (allNodes.length === 1) {
      return {
        minX: 0,
        maxX: node.width!,
        minY: 0,
        maxY: node.height!
      };
    }

    return bounds;
  }

  /**
   * 展平树结构为数组
   */
  private static flattenTree(root: NodeObj): NodeObj[] {
    const result: NodeObj[] = [];
    const stack: NodeObj[] = [root];

    while (stack.length) {
      const node = stack.pop()!;
      result.push(node);
      if (node.children?.length) {
        stack.push(...[...node.children].reverse());
      }
    }
    return result;
  }
}