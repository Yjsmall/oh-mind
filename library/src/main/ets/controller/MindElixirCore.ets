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

import {
  Arrow,
  DragOrientation,
  LayoutDirection,
  MindElixirData,
  MoveDirection,
  NodeObj,
  NodeOption,
} from '../model/NodeObj';
import { MindMapEventEmitter } from '../controller/MindMapEvents';
import { MindLineRender } from '../controller/MindLineRender';
import { NodeHelper } from '../controller/NodeHelper';
import { CanvasPositionUtils } from '../utils/CanvasPositionUtils';
import { ZoomUtils } from '../utils/ZoomUtils';
import { ShortcutManager } from './ShortcutManager';
import { UtilsManager } from '../utils/UtilsManager';
import { generateId, deepClone } from '../utils/Tools';
import { i18n } from '@kit.LocalizationKit';

const DEFAULT_OPTIONS: NodeOption = {
  locale: 'zh',
  draggable: false,
  editable: false,
  toolBar: false,
  allowUndo: false,
  contextMenu: false,
  collapsible: false,
  siblingAlignment: false,
  mindInViewport: false,
  layout: LayoutDirection.RIGHT,
  nodeShape: 'line',
  nodeSpacing: {
    horizontal: 50,
    vertical: 30
  },
  nodeStyle: {
    fontSize: 20,
    fontFamily: 'HarmonyOS Sans',
    color: '#333',
    background: '#fff',
    fontWeight: 'normal',
    border: { width: 2 },
    maxWidth: 200,
    padding: 10
  },
  lineStyle: {
    width: 2,
    color: '#e64553'
  }
};


export class MindElixirCore {
  private mindElixirData: MindElixirData | null = null;
  private instanceId: string;
  private nodeHelper: NodeHelper;
  private originMindElixirData: MindElixirData | null = null;
  private options: NodeOption = DEFAULT_OPTIONS;
  private history: MindElixirData[] = []; // 历史记录栈（存储过去状态）
  private future: MindElixirData[] = []; // 重做栈（存储被撤销的状态）
  private maxHistorySteps: number = 50;
  private selectedNodeId: string = ''; // 当前选中节点ID
  private isLink: boolean = false;
  private bidirectional?: boolean;
  private linkStartNodeId: string = '';
  private positionCtrl: CanvasPositionUtils;
  private zoomCtrl: ZoomUtils;
  private shortcutManager: ShortcutManager;

  constructor(options: NodeOption) {
    this.options = this.mergeOptions(options);
    this.instanceId = generateId();
    this.nodeHelper = new NodeHelper(this);
    this.positionCtrl = new CanvasPositionUtils(this);
    this.zoomCtrl = new ZoomUtils();
    this.shortcutManager = new ShortcutManager(this);
    UtilsManager.registerUtils(this.instanceId, this.zoomCtrl, this.positionCtrl, this.nodeHelper,
      this.shortcutManager);
    i18n.System.setAppPreferredLanguage(this.options.locale);
  }

  /**
   * 合并配置项，使用默认值填充未提供的配置
   * @param userOptions 用户传入的配置项
   * @returns 合并后的完整配置项
   */
  private mergeOptions(userOptions?: NodeOption): NodeOption {
    // Each core instance owns an independent option graph. Reusing the constant
    // directly leaks nested option changes between separate mind maps.
    const mergedOptions: NodeOption = deepClone(DEFAULT_OPTIONS);
    if (!userOptions) {
      return mergedOptions;
    }
    if (userOptions.locale !== undefined) {
      mergedOptions.locale = userOptions.locale;
    }
    if (userOptions.draggable !== undefined) {
      mergedOptions.draggable = userOptions.draggable;
    }
    if (userOptions.editable !== undefined) {
      mergedOptions.editable = userOptions.editable;
    }
    if (userOptions.toolBar !== undefined) {
      mergedOptions.toolBar = userOptions.toolBar;
    }
    if (userOptions.allowUndo !== undefined) {
      mergedOptions.allowUndo = userOptions.allowUndo;
    }
    if (userOptions.contextMenu !== undefined) {
      mergedOptions.contextMenu = userOptions.contextMenu;
    }
    if (userOptions.collapsible !== undefined) {
      mergedOptions.collapsible = userOptions.collapsible;
    }
    if (userOptions.layout !== undefined) {
      mergedOptions.layout = userOptions.layout;
    }
    if (userOptions.nodeShape !== undefined) {
      mergedOptions.nodeShape = userOptions.nodeShape;
    }
    if (userOptions.siblingAlignment !== undefined) {
      mergedOptions.siblingAlignment = userOptions.siblingAlignment;
    }
    if (userOptions.mindInViewport !== undefined) {
      mergedOptions.mindInViewport = userOptions.mindInViewport;
    }
    // 合并节点间距配置
    if (userOptions.nodeSpacing) {
      if (userOptions.nodeSpacing?.horizontal !== undefined) {
        mergedOptions.nodeSpacing!.horizontal = userOptions.nodeSpacing.horizontal;
      }
      if (userOptions.nodeSpacing?.vertical !== undefined) {
        mergedOptions.nodeSpacing!.vertical = userOptions.nodeSpacing.vertical;
      }
    }

    // 合并节点样式配置
    if (userOptions.nodeStyle) {
      if (userOptions.nodeStyle.fontSize !== undefined) {
        mergedOptions.nodeStyle!.fontSize = userOptions.nodeStyle.fontSize;
      }
      if (userOptions.nodeStyle.fontFamily !== undefined) {
        mergedOptions.nodeStyle!.fontFamily = userOptions.nodeStyle.fontFamily;
      }
      if (userOptions.nodeStyle.color !== undefined) {
        mergedOptions.nodeStyle!.color = userOptions.nodeStyle.color;
      }
      if (userOptions.nodeStyle.background !== undefined) {
        mergedOptions.nodeStyle!.background = userOptions.nodeStyle.background;
      }
      if (userOptions.nodeStyle.fontWeight !== undefined) {
        mergedOptions.nodeStyle!.fontWeight = userOptions.nodeStyle.fontWeight;
      }
      if (userOptions.nodeStyle.fontSize !== undefined) {
        mergedOptions.nodeStyle!.fontSize = userOptions.nodeStyle.fontSize;
      }
      if (userOptions.nodeStyle.border !== undefined) {
        mergedOptions.nodeStyle!.border = userOptions.nodeStyle.border;
      }
      if (userOptions.nodeStyle.maxWidth !== undefined) {
        mergedOptions.nodeStyle!.maxWidth = userOptions.nodeStyle.maxWidth;
      }
      if (userOptions.nodeStyle.padding !== undefined) {
        mergedOptions.nodeStyle!.padding = userOptions.nodeStyle.padding;
      }
    }

    if (userOptions.lineStyle) {
      if (userOptions.lineStyle.width !== undefined) {
        mergedOptions.lineStyle!.width = userOptions.lineStyle.width;
      }
      if (userOptions.lineStyle.color !== undefined) {
        mergedOptions.lineStyle!.color = userOptions.lineStyle.color;
      }
    }
    return mergedOptions;
  }

  /**
   * 获取思维导图配置项
   * @returns 实例ID字符串
   */
  public getMindOptions(): NodeOption {
    return this.options;
  }


  /**
   * 获取实例ID
   * @returns 实例ID字符串
   */
  public getInstanceId(): string {
    return this.instanceId;
  }

  /**
   * 初始化思维导图数据
   * @param mindElixirData 思维导图数据对象
   */
  public init(mindElixirData: MindElixirData): void {
    if (!mindElixirData) {
      return;
    }
    // State management V2 passes @Param objects by reference. Keep the public
    // input immutable and perform all layout mutations on an internal copy.
    this.mindElixirData = deepClone(mindElixirData);
    this.originMindElixirData = deepClone(this.mindElixirData);
    this.nodeHelper.calculateNodePosition(this.mindElixirData);
    this.initCanvas();
    this.notifyUpdate();
    if (this.options.allowUndo) {
      this.recordHistory();
    }
    if (!this.originMindElixirData?.arrows) {
      this.originMindElixirData!.arrows = [];
    }
  }


  /**
   * 刷新思维导图显示
   * @param mindElixirData 可选的思维导图数据，如果不传则使用当前数据
   */
  public refresh(mindElixirData?: MindElixirData): void {
    if (!mindElixirData) {
      mindElixirData = this.getData()!;
    }
    this.init(mindElixirData);
  }

  /**
   * 获取节点数据
   * @returns 节点数据对象或null
   */
  private getNodeData(): NodeObj | null {
    return this.originMindElixirData?.nodeData ?? null;
  }

  /**
   * 获取思维导图完整数据
   * @returns 思维导图数据对象或null
   */
  public getData(): MindElixirData | null {
    return this.originMindElixirData ?? null;
  }


  /**
   * 添加子节点
   * @param id 父节点ID
   * @param topic 节点文字内容
   * @returns 是否添加成功
   */
  public add(id: string, topic: string = 'new node'): boolean {
    const originNodeData = this.getNodeData();
    const parentNode = this.nodeHelper.findNodeById(originNodeData, id);
    if (!parentNode) {
      return false;
    }
    let newNode: NodeObj = {
      id: generateId(),
      topic,
      children: [],
      expanded: true
    };

    // 添加到父节点
    if (!parentNode.children) {
      parentNode.children = [];
    }
    parentNode.children.push(newNode);
    parentNode.expanded = true;
    this.selectNode(newNode.id);
    this.refresh();
    return true;
  }

  /**
   * 添加父节点
   * @param id 当前节点ID
   * @param topic 新父节点文字内容
   * @returns 是否添加成功
   */
  public addParent(id: string, topic: string = 'new node'): boolean {
    const originNodeData = this.getNodeData();
    // 查找当前节点及其父节点信息
    const currentParentResult = this.nodeHelper.findNodeAndParent(originNodeData, id);
    if (!currentParentResult) {
      return false;
    }

    const currentParent = currentParentResult.parent;
    const index = currentParentResult.index;
    const currentNode = currentParent.children![index];

    // 从原父节点移除当前节点
    currentParent.children!.splice(index, 1);

    // 创建新父节点（包含当前节点作为子节点）
    const newParent: NodeObj = {
      id: generateId(),
      topic,
      children: [currentNode],
      expanded: true
    };
    currentParent.children!.splice(index, 0, newParent);
    this.selectNode(newParent.id);
    this.refresh();
    return true;
  }

  /**
   * 添加兄弟节点
   * @param id 参考节点ID
   * @param isBefore 是否添加在前面
   * @returns 是否添加成功
   */
  public addSibling(id: string, isBefore?: boolean) {
    const originNodeData = this.getNodeData();
    const result = this.nodeHelper.findNodeAndParent(originNodeData, id);
    if (!result) {
      return false;
    }

    let newNode: NodeObj = {
      id: generateId(),
      topic: 'new node',
      children: [],
      expanded: true
    };

    result.parent.children!.splice(isBefore ? result.index : result.index + 1, 0, newNode);
    this.selectNode(newNode.id);
    this.refresh();
    return true;
  }

  /**
   * 删除节点
   * @param id 要删除的节点ID
   * @returns 是否删除成功
   */
  public remove(id: string): boolean {
    const originNodeData = this.getNodeData();
    // 如果要删除的是根节点
    if (!originNodeData || originNodeData.id === id) {
      return false;
    }

    // 查找要删除的节点及其父节点
    const result = this.nodeHelper.findNodeAndParent(originNodeData, id);
    const arrowIndex = this.originMindElixirData?.arrows?.findIndex(item => {
      return item.from === id || item.to === id;
    });
    if (arrowIndex !== undefined && arrowIndex !== -1) {
      this.originMindElixirData?.arrows?.splice(arrowIndex, 1);
      this.refresh();
    }
    if (!result) {
      return false;
    }

    // 从父节点的children中移除
    result.parent.children!.splice(result.index, 1);
    // 重新初始化
    this.refresh();
    return true;
  }

  /**
   * 拖拽节点时设置子节点拖拽状态
   * @param dragNodeId 拖拽的节点ID
   * @param isDraggable 是否可拖拽
   */
  public setDragStatusForSubtree(dragNodeId: string, isDraggable: boolean): void {
    const originNodeData = this.getNodeData();
    const dragNode = this.nodeHelper.findNodeById(originNodeData, dragNodeId);
    if (!dragNode) {
      return;
    }
    // 使用递归函数设置所有子节点的拖拽状态
    const setDragStatusRecursively = (node: NodeObj): void => {
      node.isCantDrag = !isDraggable;
      node.children?.forEach(child => setDragStatusRecursively(child));
    };
    setDragStatusRecursively(dragNode);
    this.refresh();
  }

  /**
   * 拖拽节点到目标节点
   * @param dragNodeId 拖拽的节点ID
   * @param targetNodeId 目标节点ID
   * @param orientation 放置方向
   */
  public moveNodeToTargetNode(dragNodeId: string, targetNodeId: string, orientation: DragOrientation): void {
    const originNodeData = this.getNodeData();
    // 查找拖拽元素
    const dragNodeResult = this.nodeHelper.findNodeAndParent(originNodeData, dragNodeId);

    if (dragNodeResult === null) {
      return;
    }
    // 拖拽出来的元素
    const dragNode = dragNodeResult.parent.children!.splice(dragNodeResult.index, 1);

    // 加入新的地方
    switch (orientation) {
      case DragOrientation.TOP:
        const targetNodeParent = this.nodeHelper.findNodeAndParent(originNodeData, targetNodeId);
        if (targetNodeParent === null) {
          return;
        }
        targetNodeParent.parent.children!.splice(targetNodeParent.index, 0, ...dragNode);
        break;
      case DragOrientation.MIDDLE:
        const targetNode = this.nodeHelper.findNodeById(originNodeData, targetNodeId)!;
        // 添加到父节点
        if (!targetNode.children) {
          targetNode.children = [];
        }
        // 添加到父节点，父节点需要展开
        targetNode.expanded = true;
        targetNode.children.push(...dragNode);
        break;
      case DragOrientation.BOTTOM:
        const targetNodeParent2 = this.nodeHelper.findNodeAndParent(originNodeData, targetNodeId);
        if (targetNodeParent2 === null) {
          return;
        }
        targetNodeParent2.parent.children!.splice(targetNodeParent2.index + 1, 0, ...dragNode);
        break;
      default:
        break;
    }

    // 重新初始化
    this.refresh();
  }

  /**
   * 同级节点上下移动
   * @param id 节点ID
   * @param direction 移动方向
   * @returns 是否移动成功
   */
  public move(id: string, direction: MoveDirection): boolean {
    const originNodeData = this.getNodeData();
    const result = this.nodeHelper.findNodeAndParent(originNodeData, id);
    if (!result) {
      return false;
    }
    let index: number;
    if (direction === MoveDirection.UP) {
      index = result.index - 1 < 0 ? result.parent.children!.length - 1 : result.index - 1;
    } else {
      index = result.index + 1 >= result.parent.children!.length ? 0 : result.index + 1;
    }
    let currentNode = result.parent.children!.splice(result.index, 1);

    result.parent.children!.splice(index, 0, ...currentNode);
    // 重新初始化
    this.refresh();
    return true;
  }

  /**
   * 更新节点属性
   * @param updatedNode 要更新的节点对象
   * @returns 是否更新成功
   */
  public updateNode(updatedNode: NodeObj): boolean {
    const nodeId: string = updatedNode.id;
    const originNodeData = this.getNodeData();
    // 查找要更新的节点（基于originNodeData）
    const target = this.nodeHelper.findNodeById(originNodeData, nodeId);
    if (!target) {
      return false;
    }
    // 保留原有子节点（如果不传子节点）
    if (updatedNode.children === undefined) {
      updatedNode.children = target.children;
    }

    // 手动更新属性（ArkTS 严格模式兼容）
    if (updatedNode.topic !== undefined) {
      target.topic = updatedNode.topic;
    }
    if (updatedNode.id !== undefined) {
      target.id = updatedNode.id;
    }
    if (updatedNode.style !== undefined) {
      target.style = updatedNode.style;
    }
    if (updatedNode.linkStyle !== undefined) {
      target.linkStyle = updatedNode.linkStyle;
    }
    if (updatedNode.children !== undefined) {
      target.children = updatedNode.children;
    }
    if (updatedNode.tags !== undefined) {
      target.tags = updatedNode.tags;
    }
    if (updatedNode.expanded !== undefined) {
      target.expanded = updatedNode.expanded;
    }
    if (updatedNode.direction !== undefined) {
      target.direction = updatedNode.direction;
    }
    if (updatedNode.parent !== undefined) {
      target.parent = updatedNode.parent;
    }
    if (updatedNode.x !== undefined) {
      target.x = updatedNode.x;
    }
    if (updatedNode.y !== undefined) {
      target.y = updatedNode.y;
    }
    if (updatedNode.level !== undefined) {
      target.level = updatedNode.level;
    }
    if (updatedNode.width !== undefined) {
      target.width = updatedNode.width;
    }
    if (updatedNode.height !== undefined) {
      target.height = updatedNode.height;
    }
    if (updatedNode.subtreeWidth !== undefined) {
      target.subtreeWidth = updatedNode.subtreeWidth;
    }
    if (updatedNode.subtreeHeight !== undefined) {
      target.subtreeHeight = updatedNode.subtreeHeight;
    }
    if (updatedNode.richText !== undefined) {
      target.richText = updatedNode.richText;
    }
    if (updatedNode.onLinkClick !== undefined) {
      target.onLinkClick = updatedNode.onLinkClick;
    }
    // 重新初始化
    this.refresh();
    return true;
  }

  /**
   * 开始创建链接
   * @param nodeId 起始节点ID
   * @param isLink 是否开始链接
   * @param bidirectional 是否双向链接
   */
  public startLink(nodeId: string, isLink: boolean, bidirectional?: boolean): void {
    if (!this.originMindElixirData?.nodeData) {
      return;
    }
    this.isLink = isLink;
    this.linkStartNodeId = nodeId;
    this.bidirectional = bidirectional;
  }

  /**
   * 渲染节点间的链接
   * @param endNodeId 结束节点ID
   */
  public renderLink(endNodeId: string): void {
    let newArrow: Arrow = {
      from: this.linkStartNodeId,
      to: endNodeId,
      label: 'Custom Link',
      id: generateId(),
      bidirectional: this.bidirectional
    };
    this.originMindElixirData?.arrows?.push(newArrow);
    this.refresh();
  }

  /**
   * 更改链接标签
   * @param arrowId 箭头ID
   * @param newLabel 新标签文本
   */
  public updateLinkLabel(arrowId: string, newLabel: string) {
    const arrow = this.originMindElixirData?.arrows?.find((item: Arrow) => item.id === arrowId);
    arrow!.label = newLabel;
    this.refresh();
  }


  /**
   * 通知更新事件
   */
  private notifyUpdate(): void {
    MindMapEventEmitter.emitNodeUpdated();
    MindMapEventEmitter.emitCanvasUpdated();
  }


  /**
   * 设置思维导图布局方向
   * @param direction 布局方向
   */
  public setMindDirection(direction: LayoutDirection) {
    this.nodeHelper.clearRootPosition();
    this.options.layout = direction;
    this.refresh();
    this.resetPosition();
  }

  /**
   * 获取思维导图布局方向
   * @returns 布局方向
   */
  public getMindDirection(): LayoutDirection {
    return this.options.layout ?? LayoutDirection.RIGHT;
  }

  /**
   * 设置缩放比例
   * @param value 缩放比例值
   */
  public setScaleVal(value: number) {
    this.zoomCtrl.setScale(value);
  }

  /**
   * 获取缩放比例
   * @returns 当前缩放比例
   */
  public getScaleVal() {
    return this.zoomCtrl.getScale();
  }

  /**
   * 放大
   */
  zoomIn(): void {
    this.zoomCtrl.zoomIn();
  }

  /**
   * 缩小
   */
  zoomOut(): void {
    this.zoomCtrl.zoomOut();
  }


  /**
   * 记录当前状态到历史记录栈
   */
  private recordHistory(): void {
    if (!this.originMindElixirData) {
      return;
    }

    // 记录贝当前状态
    const historyItem: MindElixirData =  deepClone(this.originMindElixirData) ;
    this.history.push(historyItem);

    // 限制历史记录数量
    if (this.history.length > this.maxHistorySteps) {
      this.history.shift(); // 移除最旧记录
    }
  }

  /**
   * 撤销到上一个状态
   * @returns 是否撤销成功
   */
  public undo(): boolean {
    // 1. 当前状态存入重做栈
    if (this.originMindElixirData) {
      this.future.push(deepClone(this.originMindElixirData));
    }

    // 最后一条数据为最新数据先剔除
    this.history.pop();
    const previousState = this.history.pop()!;
    this.nodeHelper.clearRootPosition(); // 清除保存的根节点位置
    this.init(previousState);
    return true;
  }

  /**
   * 重做被撤销的操作
   * @returns 是否重做成功
   */
  public redo(): boolean {
    if (this.future.length === 0) {
      return false;
    }
    // 2. 恢复未来状态（临时关闭历史记录）
    const nextState = this.future.pop()!;
    this.nodeHelper.clearRootPosition(); // 清除保存的根节点位置
    this.init(nextState);
    return true;
  }

  /**
   * 初始化画布
   */
  private initCanvas(): void {
    const canvasContext = MindLineRender.createInstance(this.getInstanceId()).getCanvasContext();
    if (canvasContext) {
      MindLineRender.createInstance(this.getInstanceId()).init(canvasContext, this);
    }
  }

  /**
   * 获取选中节点ID
   * @returns 选中节点ID或空字符串
   */
  public getSelectedNodeId(): string {
    return this.selectedNodeId ?? '';
  }

  /**
   * 获取选中节点数据
   * @returns 选中节点对象或null
   */
  public getSelectedNode(): NodeObj | null {
    const originNodeData = this.getNodeData();
    return this.nodeHelper.findNodeById(originNodeData, this.selectedNodeId);
  }

  /**
   * 设置选中节点
   * @param nodeId 节点ID或null（取消选中）
   * @returns 是否设置成功
   */
  public selectNode(nodeId: string): boolean {
    // 如果传入null，取消选中
    if (!nodeId) {
      this.selectedNodeId = '';
      return true;
    }
    // 验证节点是否存在
    if (this.originMindElixirData) {
      const originNodeData = this.getNodeData();
      const node = this.nodeHelper.findNodeById(originNodeData, nodeId);
      if (node) {
        this.selectedNodeId = nodeId;
        return true;
      }
    }
    return false;
  }


  /**
   * 展开节点及其所有子节点
   * @param selectNodeId 要展开的节点ID
   */
  public expandedNode(selectNodeId: string) {
    const selectNode = this.nodeHelper.findNodeById(this.getNodeData(), selectNodeId);
    if (selectNode) {
      // 递归展开所有子节点
      this.setExpandedRecursively(selectNode, true);
      this.refresh();
    }
  }

  /**
   * 折叠节点及其所有子节点
   * @param selectNodeId 要折叠的节点ID
   */
  public foldNode(selectNodeId: string) {
    const selectNode = this.nodeHelper.findNodeById(this.getNodeData(), selectNodeId);
    if (selectNode) {
      // 递归折叠所有子节点
      this.setExpandedRecursively(selectNode, false);
      this.refresh();
    }
  }

  /**
   * 递归设置节点及其所有子节点的展开状态
   * @param node 当前节点
   * @param expanded 展开状态
   */
  private setExpandedRecursively(node: NodeObj, expanded: boolean): void {
    // 设置当前节点的展开状态
    node.expanded = expanded;

    // 递归设置所有子节点的展开状态
    if (node.children && node.children.length > 0) {
      for (const child of node.children) {
        this.setExpandedRecursively(child, expanded);
      }
    }
  }

  /**
   * 重置画布位置到原点
   */
  resetPosition() {
    this.positionCtrl.resetToOrigin();
  }

  // 销毁时清理
  public destroy(): void {
    MindMapEventEmitter.offNodeUpdated();
    MindMapEventEmitter.offCanvasUpdated();
    UtilsManager.removeUtils(this.instanceId);
    MindLineRender.removeInstance(this.instanceId);
  }

  // 是否有正在连接的节点
  public hasLinkedNode(): boolean {
    return this.isLink;
  }
}
