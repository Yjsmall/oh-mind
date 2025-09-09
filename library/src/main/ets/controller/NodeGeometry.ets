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

import { NodeObj, Coordinate } from '../model/NodeObj';

export class NodeGeometry {
  /**
   * 获取节点右侧连接点（父→子连线起点）
   * 始终返回节点右侧中间位置
   */
  static getRightAnchor(node: NodeObj): Coordinate {
    return {
      x: (node.x || 0) + (node.width || 120),
      y: (node.y || 0) + (node.height || 40) / 2
    };
  }

  /**
   * 获取节点左侧连接点（子→父连线终点）
   * 始终返回节点左侧中间位置
   */
  static getLeftAnchor(node: NodeObj): Coordinate {
    return {
      x: node.x || 0,
      y: (node.y || 0) + (node.height || 40) / 2
    };
  }

  /**
   * 获取节点上侧连接点
   * 始终返回节点上侧中间位置
   */
  static getTopAnchor(node: NodeObj): Coordinate {
    return {
      x: (node.x || 0) + (node.width || 120) / 2,
      y: node.y || 0
    };
  }

  /**
   * 获取节点下侧连接点
   * 始终返回节点下侧中间位置
   */
  static getBottomAnchor(node: NodeObj): Coordinate {
    return {
      x: (node.x || 0) + (node.width || 120) / 2,
      y: (node.y || 0) + (node.height || 40)
    };
  }

  /**
   * 计算水平方向控制点（用于左右布局）
   */
  static getControlXPoint(start: Coordinate, end: Coordinate): Coordinate {
    const controlOffset = Math.abs(end.x - start.x) * 0.5;
    return {
      x: start.x + (end.x > start.x ? controlOffset : -controlOffset),
      y: start.y
    };
  }

  /**
   * 计算垂直方向控制点（用于上下布局）
   * 修复：同时考虑水平和垂直方向的偏移
   */
  static getControlYPoint(start: Coordinate, end: Coordinate): Coordinate {
    const verticalOffset = Math.abs(end.y - start.y) * 0.3;
    const horizontalOffset = Math.abs(end.x - start.x) * 0.7;
    return {
      x: start.x + (end.x > start.x ? horizontalOffset : -horizontalOffset),
      y: start.y + (end.y > start.y ? verticalOffset : -verticalOffset)
    };
  }


  /**
   * 获取节点中心点坐标
   * 可用于其他计算
   */
  static getCenterPoint(node: NodeObj): Coordinate {
    return {
      x: (node.x || 0) + (node.width || 120) / 2,
      y: (node.y || 0) + (node.height || 40) / 2
    };
  }
}