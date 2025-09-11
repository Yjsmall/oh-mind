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

export type Uid = string;

export enum LayoutDirection {
  LEFT = 0, // 左侧布局
  RIGHT = 1, // 右侧布局
  TOP = 2,       // 上方布局（纵向）
  BOTTOM = 3,    // 下方布局（纵向）
}

export enum MoveDirection {
  UP = 0, // 向上移动
  DOWN = 1, // 向下移动
}

export enum DragOrientation {
  TOP = 0, // 放在目标节点的前面
  MIDDLE = 1, // 放在目标节点的子节点中
  BOTTOM = 2 //放在目标节点的后面
}

export interface NodeOption {
  locale?: string;
  draggable?: boolean;
  editable?: boolean;
  toolBar?: boolean;
  allowUndo?: boolean;
  contextMenu?: boolean;
  layout?: LayoutDirection;
  nodeShape?: 'curve' | 'line';
  nodeSpacing?: NodeSpacing;
  nodeStyle?: NodeStyle;
  siblingAlignment?: boolean;
  mindInViewport?: boolean;
  lineStyle?: lineStyle;
}

export interface  NodeSpacing {
  horizontal: number;
  vertical: number;
}

export interface NodeStyle {
  fontSize?: number;
  fontFamily?: string | Resource;
  color?: string | number;
  background?: ResourceColor;
  fontWeight?: string | number | FontWeight;
  width?: number;
  border?: BorderOptions;
  maxWidth?: number;
  padding?: number;
}

export interface MindElixirData {
  nodeData: NodeObj;
  arrows?: Arrow[];
}

export interface NodeObj {
  topic: string;
  id: Uid;
  style?: NodeStyle;
  children?: NodeObj[];
  tags?: string[];
  expanded?: boolean;
  direction?: LayoutDirection;
  parent?: NodeObj;
  x?: number;
  y?: number;
  level?: number;
  width?: number;
  height?: number;
  subtreeWidth?: number;
  subtreeHeight?: number;
  isCantDrag?: boolean;
  arrow?: Arrow;
  lineStyle?: lineStyle
}

export interface lineStyle {
  width: number;
  color?: string | number;
}

export interface Arrow {
  id: string;
  label: string;
  from: string;
  to: string;
  delta1?: Coordinate;
  delta2?: Coordinate;
  start?: Coordinate;
  end?: Coordinate;
  bidirectional?: boolean;
  position?: Coordinate;
}

export interface Coordinate {
  x: number;
  y: number;
}

export interface NodeSize {
  width: number,
  height: number
}

// 定义画布尺寸类型
export interface CanvasSize {
  width: number;
  height: number;
}

// 定义布局结果类型
export interface LayoutResult {
  canvasSize: CanvasSize;
  nodes: NodeObj[];
}

export interface Bounds {
  minX: number;
  maxX: number;
  minY: number;
  maxY: number;
}

export interface ParentNode {
  parent: NodeObj;
  index: number;
}

export interface WindowRect {
  width: number;
  height: number;
}

export interface TextSize {
  width: number;
  height: number;
}

export interface CanvasPosition {
  offsetX: number;
  offsetY: number;
  positionX: number;
  positionY: number;
}

export interface FlatNodeObj {
  node: NodeObj;
  parent?: NodeObj;
}

export interface MenuOptionItem {
  value: ResourceStr;
  level: number;
  action: () => void;
  id: string;
}
