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
import { CanvasSize, FlatNodeObj, MindElixirData, NodeObj, ParentNode, Coordinate, Arrow } from '../model/NodeObj';
import { MindMapLayout } from '../controller/LayoutCalculator';
import { generateId } from '../utils/Tools';


const DEFAULT_CANVAS_SIZE: CanvasSize = {
  width: 3000,
  height: 2000
}
export class NodeHelper {
  private mind: MindElixirCore;
  private treeNode: NodeObj | null = null;
  private flatNodes: NodeObj[] = [];
  private copyNode: NodeObj | null = null;
  private canvasSize: CanvasSize = DEFAULT_CANVAS_SIZE;
  private rootPosition: Coordinate | null = null;

  constructor(model: MindElixirCore) {
    this.mind = model;
  }

  /**
   * 初始化节点数据
   */
  public initNodeData(data: NodeObj): NodeObj {
    // 初始化当前节点
    if (data.x === undefined || data.x === null) {
      data.x = 0;
    }
    if (data.y === undefined || data.y === null) {
      data.y = 0;
    }
    if (data.width === undefined || data.width === null) {
      data.width = 0;
    }
    if (data.height === undefined || data.height === null) {
      data.height = 0;
    }
    if (data.subtreeWidth === undefined || data.subtreeWidth === null) {
      data.subtreeWidth = 0;
    }
    if (data.subtreeHeight === undefined || data.subtreeHeight === null) {
      data.subtreeHeight = 0;
    }
    if (data.expanded === undefined) {
      data.expanded = true;
    }

    // 递归初始化子节点
    if (data.children && data.children.length > 0) {
      for (let i = 0; i < data.children.length; i++) {
        data.children[i] = this.initNodeData(data.children[i]);
      }
    }
    this.treeNode = data;
    return data;
  }

  /**
   * 树形结构转扁平数组
   */
  public flattenTree(node: NodeObj): NodeObj[] {
    const result: NodeObj[] = [];
    const stack: FlatNodeObj[] = [];

    // 初始化栈
    stack.push({ node: node });

    while (stack.length > 0) {
      const current = stack.pop();
      if (!current) {
        continue;
      }

      // 显式读取属性
      const currentNode = current.node;
      const currentParent = current.parent;

      if (currentParent) {
        currentNode.parent = {
          id: currentParent.id,
          topic: currentParent.topic,
          direction: currentParent.direction,
          x: currentParent.x,
          y: currentParent.y,
          level: currentParent.level,
          expanded: currentParent.expanded ?? true,
          width: currentParent.width,
          height: currentParent.height,
          lineStyle: currentParent.lineStyle
        };
      }

      result.push(currentNode);

      // 处理子节点
      if (currentNode.children) {
        // 反向遍历维持顺序
        for (let i = currentNode.children.length - 1; i >= 0; i--) {
          stack.push({
            node: currentNode.children[i],
            parent: currentNode
          });
        }
      }
    }

    return result;
  }

  public calculateNodePosition(data: MindElixirData) {
    const nodeData: NodeObj = data.nodeData;
    const treeNode = this.initNodeData(nodeData);
    if (treeNode) {
      const canvasSize: CanvasSize = MindMapLayout.calculate(treeNode, this.mind);
      this.canvasSize = canvasSize;
      this.flatNodes = this.flattenTree(treeNode);
    }
  }

  public getTreeNodeData(): NodeObj | null {
    return this.treeNode ?? null;
  }

  /**
   * 获取箭头数据
   * @returns 箭头数据数组
   */
  public getArrowsData(): Arrow[] {
    const data = this.mind.getData();
    return data?.arrows || [];
  }


  // 获取扁平化节点
  public getFlatNodes(): NodeObj[] | [] {
    return this.flatNodes ?? [];
  }

  // 获取画布大小
  public getCanvasSize(): CanvasSize {
    return this.canvasSize ?? DEFAULT_CANVAS_SIZE;
  }

  // 重置方法，用于清除状态
  public reset(): void {
    this.treeNode = null;
    this.flatNodes = [];
    this.canvasSize = DEFAULT_CANVAS_SIZE;
  }

  /**
   * 递归查找节点及其父节点
   * @param currentNode 当前搜索的节点
   * @param nodeId 要查找的节点ID
   * @param parent 父节点引用
   * @param index 在父节点children中的索引
   * @returns 父节点信息或null
   */
  public  findNodeAndParent(
    currentNode: NodeObj | null,
    nodeId: string,
    parent?: NodeObj,
    index?: number
  ): ParentNode | null {
    if (!currentNode) {
      return null;
    }
    // 检查当前节点是否匹配
    if (currentNode.id === nodeId && parent && index !== undefined) {
      return { parent, index };
    }

    // 检查子节点
    if (currentNode.children) {
      for (let i = 0; i < currentNode.children.length; i++) {
        const child = currentNode.children[i];
        const found = this.findNodeAndParent(child, nodeId, currentNode, i);
        if (found) {
          return found;
        }
      }
    }

    return null;
  }

  /**
   * 递归查找节点
   * @param currentNode 当前搜索的节点
   * @param nodeId 要查找的节点ID
   * @returns 找到的节点或null
   */
  public findNodeById(currentNode: NodeObj | null, nodeId: string): NodeObj | null {
    if (!currentNode) {
      return null;
    }
    if (currentNode.id === nodeId) {
      return currentNode;
    }

    if (currentNode.children) {
      for (const child of currentNode.children) {
        const found = this.findNodeById(child, nodeId);
        if (found) {
          return found;
        }
      }
    }

    return null;
  }


  /**
   * 复制或剪切节点
   * @param id 节点ID
   * @param isDelete 是否删除原节点（剪切操作）
   * @returns 是否操作成功
   */
  public copy(id: string, isDelete?: boolean): boolean {
    const originNodeData = this.mind.getData()?.nodeData!;
    const targetNode = this.findNodeById(originNodeData, id)!;
    if (isDelete) {
      this.copyNode = targetNode;
      this.mind.remove(id);
    } else {
      this.copyNode = JSON.parse(JSON.stringify(targetNode));
    }
    return true;
  }

  /**
   * 粘贴节点到指定父节点
   * @param id 父节点ID
   * @returns 是否粘贴成功
   */
  public pasting(id: string) {
    const originNodeData = this.mind.getData()?.nodeData!;
    if (!this.copyNode) {
      return false;
    }

    let newNodes: NodeObj[] = [];
    this.changNodeId([this.copyNode], newNodes);
    const parentNode = this.findNodeById(originNodeData, id);
    if (!parentNode) {
      return false;
    }
    // 添加到父节点
    if (!parentNode.children) {
      parentNode.children = [];
    }
    parentNode.children.push(newNodes[0]);
    parentNode.expanded = true;
    // 重新初始化
    this.mind.refresh();
    return true;
  }

  /**
   * 递归更改节点ID
   * @param nodes 节点数组
   * @param newArray 新节点数组
   */
  public changNodeId(nodes: NodeObj[], newArray: NodeObj[]) {
    nodes.forEach((item: NodeObj) => {
      let i: NodeObj = {
        topic: item.topic,
        id: generateId()
      };
      newArray.push(i);
      if (item.children) {
        i.children = [];
        this.changNodeId(item.children, i.children);
      }
    });
  }

  /**
   * 获取后代节点个数
   * @param selectNode 起始节点
   * @returns 后代节点数量
   */
  public getAllChildrenNumber(selectNode: NodeObj) {
    let count = 0;
    if (Array.isArray(selectNode.children)) {
      for (const child of selectNode.children) {
        count += 1 + this.getAllChildrenNumber(child);
      }
    }
    return count;
  }

  // 保存根节点位置
  public setRootPosition(x: number, y: number): void {
    this.rootPosition = { x, y };
  }

  // 获取根节点位置
  public getRootPosition(): Coordinate | null {
    return this.rootPosition;
  }

  // 清除根节点位置（当需要重新计算时）
  public clearRootPosition(): void {
    this.rootPosition = null;
  }
}