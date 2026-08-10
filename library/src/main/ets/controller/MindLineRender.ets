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

import { Arrow, CanvasSize, Coordinate, NodeObj, NodeOption, LayoutDirection } from '../model/NodeObj';
import { MindElixirCore } from './MindElixirCore';
import { NodeGeometry } from './NodeGeometry';
import { NodeHelper } from '../controller/NodeHelper';
import { UtilsManager } from '../utils/UtilsManager';

export class MindLineRender {
  private static instanceMap = new Map<string, MindLineRender>();
  private context: CanvasRenderingContext2D | OffscreenCanvasRenderingContext2D | null = null;
  private nodes: NodeObj[] | null = null;
  private mind: MindElixirCore | null = null;
  private options: NodeOption | null = null;
  private nodeHelper: NodeHelper | null = null;

  private constructor() {
  }

  public static createInstance(id: string): MindLineRender {
    if (!MindLineRender.instanceMap.has(id)) {
      MindLineRender.instanceMap.set(id, new MindLineRender());
    }
    return MindLineRender.instanceMap.get(id)!;
  }

  public static getInstance(id: string): MindLineRender | null {
    return MindLineRender.instanceMap.get(id) || null;
  }

  public static removeInstance(id: string): boolean {
    return MindLineRender.instanceMap.delete(id);
  }

  /**
   * 初始化画线渲染器
   * @param ctx 画布上下文
   * @param mind 思维导图核心实例
   */
  public init(ctx: CanvasRenderingContext2D | OffscreenCanvasRenderingContext2D, mind: MindElixirCore): void {
    this.context = ctx;
    this.mind = mind;
    this.nodeHelper = UtilsManager.getNodeHelper(mind.getInstanceId());
    this.nodes = this.nodeHelper!.getFlatNodes();
    this.options = this.mind.getMindOptions();
    this.reRender();
  }

  /** Refresh line geometry after the core recalculates its mutable node tree. */
  public refresh(): void {
    if (!this.nodeHelper || !this.mind) {
      return;
    }
    this.nodes = this.nodeHelper.getFlatNodes();
    this.options = this.mind.getMindOptions();
    this.reRender();
  }

  /**
   * 重新渲染所有连接线
   */
  private reRender(): void {
    if (!this.context || !this.mind || !this.nodes) {
      return;
    }

    const canvasSize: CanvasSize = this.nodeHelper!.getCanvasSize();
    this.context.clearRect(0, 0, Number(canvasSize.width), Number(canvasSize.height));

    // 绘制所有节点连接线
    this.drawNodeConnections();

    // 绘制箭头连接线
    this.drawArrowConnections();
  }

  /**
   * 绘制所有节点之间的连接线
   */
  private drawNodeConnections(): void {
    const nodes = this.nodes!;
    for (const node of nodes) {
      if (node?.parent !== undefined && node.parent?.expanded) {
        this.drawNodeConnection(node.parent, node);
      }
    }
  }

  /**
   * 绘制单个节点连接线
   * @param parent 父节点
   * @param child 子节点
   */
  private drawNodeConnection(parent: NodeObj, child: NodeObj): void {
    if (!this.context) {
      return;
    }
    const isCurve = this.options?.nodeShape === 'curve';
    isCurve ? this.drawCurvedConnector(parent, child) : this.drawStraightConnector(parent, child);
  }

  /**
   * 绘制所有箭头连接线
   */
  private drawArrowConnections(): void {
    const arrows = this.nodeHelper!.getArrowsData();
    for (const arrow of arrows) {
      this.drawLink(arrow);
    }
  }

  /**
   * 绘制曲线连接线
   * @param parent 父节点
   * @param child 子节点
   */
  private drawCurvedConnector(parent: NodeObj, child: NodeObj): void {
    const ctx = this.context!;
    const layout = this.options?.layout;
    const point = this.getStartEndPoint(parent, child);
    const start = point[0];
    const end = point[1];
    const control = this.getControlPoint(start, end)!;
    ctx.beginPath();
    ctx.setLineDash([10, 0]);
    ctx.moveTo(start.x, start.y);
    if (layout === LayoutDirection.TOP || layout === LayoutDirection.BOTTOM) {
      ctx.quadraticCurveTo(control.x, control.y, end.x, end.y);
    } else {
      ctx.bezierCurveTo(start.x, start.y, control.x, end.y, end.x, end.y);
    }
    this.applyLineStyle(parent);
    ctx.stroke();
  }

  /**
   * 绘制直线连接线
   * @param parent 父节点
   * @param child 子节点
   */
  private drawStraightConnector(parent: NodeObj, child: NodeObj): void {
    const ctx = this.context!;
    const point = this.getStartEndPoint(parent, child);
    const start = point[0];
    const end = point[1];
    ctx.beginPath();
    ctx.setLineDash([10, 0]);
    ctx.moveTo(start.x, start.y);
    const layout = this.options?.layout;
    if (layout === LayoutDirection.TOP || layout === LayoutDirection.BOTTOM) {
      const verticalSpacing = this.options?.nodeSpacing?.vertical || 20;
      const shift = layout === LayoutDirection.TOP ? -verticalSpacing / 2 : verticalSpacing / 2;
      ctx.lineTo(start.x, start.y + shift);
      ctx.lineTo(end.x, start.y + shift);
      ctx.lineTo(end.x, end.y);
    } else {
      const horizontalSpacing = this.options?.nodeSpacing?.horizontal || 30;
      const shift = layout === LayoutDirection.LEFT ? -horizontalSpacing / 2 : horizontalSpacing / 2;
      ctx.lineTo(start.x + shift, start.y);
      ctx.lineTo(start.x + shift, end.y);
      ctx.lineTo(end.x, end.y);
    }
    this.applyLineStyle(parent);
    ctx.stroke();
  }

  /**
   * 应用线条样式
   * @param node 节点
   */
  private applyLineStyle(node: NodeObj): void {
    const ctx = this.context!;
    ctx.strokeStyle = node.lineStyle?.color ?? this.options?.lineStyle?.color ?? '';
    ctx.lineWidth = node.lineStyle?.width ?? this.options?.lineStyle?.width ?? 2;
  }

  /**
   * 获取连接线的起点和终点
   * @param parent 父节点
   * @param child 子节点
   * @returns 起点和终点坐标
   */
  private getStartEndPoint(parent: NodeObj, child: NodeObj): [Coordinate, Coordinate] {
    const layout = this.options?.layout;
    switch (layout) {
      case LayoutDirection.LEFT:
        return [
          NodeGeometry.getLeftAnchor(parent),
          NodeGeometry.getRightAnchor(child)
        ];
      case LayoutDirection.RIGHT:
        return [
          NodeGeometry.getRightAnchor(parent),
          NodeGeometry.getLeftAnchor(child)
        ];
      case LayoutDirection.TOP:
        return [
          NodeGeometry.getTopAnchor(parent),
          NodeGeometry.getBottomAnchor(child)
        ];
      case LayoutDirection.BOTTOM:
      default:
        return [
          NodeGeometry.getBottomAnchor(parent),
          NodeGeometry.getTopAnchor(child)
        ];
    }
  }

  /**
   * 获取控制点坐标
   * @param start 起点
   * @param end 终点
   * @returns 控制点坐标
   */
  private getControlPoint(start: Coordinate, end: Coordinate): Coordinate {
    const layout = this.options?.layout;
    if (layout === LayoutDirection.LEFT || layout === LayoutDirection.RIGHT) {
      return NodeGeometry.getControlXPoint(start, end);
    } else {
      return NodeGeometry.getControlYPoint(start, end);
    }
  }

  /**
   * 绘制链接线
   * @param arrow 箭头对象
   */
  private drawLink(arrow: Arrow): void {
    const startNode = this.nodeHelper?.findNodeById(this.nodeHelper.getTreeNodeData(), arrow.from)!;
    const endNode = this.nodeHelper?.findNodeById(this.nodeHelper.getTreeNodeData(), arrow.to)!;
    if (!startNode || !endNode) {
      return;
    }
    let start: Coordinate = {
      x: startNode.x! + startNode.width!,
      y: startNode.y! + (startNode.height!) / 2
    };
    let end: Coordinate = {
      x: endNode.x! + endNode.width!,
      y: endNode.y! + (endNode.height!) / 2
    };
    arrow.start = start;
    arrow.end = end;
    arrow.delta1 = {
      x: start.x! + 100,
      y: start.y!
    };
    arrow.delta2 = {
      x: end.x! + 100,
      y: end.y!
    };
    this.drawBezierCurve(arrow.start!, arrow.end!, arrow.delta1, arrow.delta2);
    if (arrow.bidirectional) {
      this.drawArrow(arrow.end!, arrow.start!, arrow.delta2, arrow.delta1, 1);
    }
    this.drawArrow(arrow.start!, arrow.end!, arrow.delta1, arrow.delta2, 1);
    arrow.position = this.getPointOnCurve(arrow.start!, arrow.end!, arrow.delta1, arrow.delta2, 0.5);
  }

  /**
   * 绘制贝塞尔曲线
   * @param start 起点
   * @param end 终点
   * @param controlPoint1 控制点1
   * @param controlPoint2 控制点2
   */
  private drawBezierCurve(start: Coordinate, end: Coordinate, controlPoint1: Coordinate,
    controlPoint2: Coordinate): void {
    if (!this.context) {
      return;
    }
    const ctx = this.context;
    ctx.beginPath();
    ctx.setLineDash([10, 5]);
    ctx.moveTo(start.x, start.y);
    ctx.bezierCurveTo(
      controlPoint1.x, controlPoint1.y,
      controlPoint2.x, controlPoint2.y,
      end.x, end.y
    );

    this.applyDefaultLineStyle();
    ctx.stroke();
  }

  /**
   * 应用默认线条样式
   */
  private applyDefaultLineStyle(): void {
    const ctx = this.context!;
    ctx.fillStyle = this.options?.lineStyle?.color!;
    ctx.lineWidth = this.options?.lineStyle?.width!;
  }

  /**
   * 计算贝塞尔曲线上的点
   * @param start 起点
   * @param end 终点
   * @param controlPoint1 控制点1
   * @param controlPoint2 控制点2
   * @param t 参数t (0-1)
   * @returns 曲线上的点坐标
   */
  private getPointOnCurve(start: Coordinate, end: Coordinate, controlPoint1: Coordinate,
    controlPoint2: Coordinate, t: number): Coordinate {
    const x = Math.pow(1 - t, 3) * start.x +
      3 * Math.pow(1 - t, 2) * t * controlPoint1.x +
      3 * (1 - t) * t * t * controlPoint2.x +
      t * t * t * end.x;

    const y = Math.pow(1 - t, 3) * start.y +
      3 * Math.pow(1 - t, 2) * t * controlPoint1.y +
      3 * (1 - t) * t * t * controlPoint2.y +
      t * t * t * end.y;
    return { x, y };
  }

  /**
   * 计算曲线在t点的切线角度
   * @param start 起点
   * @param end 终点
   * @param controlPoint1 控制点1
   * @param controlPoint2 控制点2
   * @param t 参数t (0-1)
   * @returns 切线角度
   */
  private getTangentAngle(start: Coordinate, end: Coordinate, controlPoint1: Coordinate,
    controlPoint2: Coordinate, t: number): number {
    const dx = 3 * Math.pow(1 - t, 2) * (controlPoint1.x - start.x) +
      6 * (1 - t) * t * (controlPoint2.x - controlPoint1.x) +
      3 * t * t * (end.x - controlPoint2.x);

    const dy = 3 * Math.pow(1 - t, 2) * (controlPoint1.y - start.y) +
      6 * (1 - t) * t * (controlPoint2.y - controlPoint1.y) +
      3 * t * t * (end.y - controlPoint2.y);

    return Math.atan2(dy, dx);
  }

  /**
   * 绘制箭头
   * @param start 起点
   * @param end 终点
   * @param controlPoint1 控制点1
   * @param controlPoint2 控制点2
   * @param t 参数t (0-1)
   */
  private drawArrow(start: Coordinate, end: Coordinate, controlPoint1: Coordinate,
    controlPoint2: Coordinate, t: number): void {
    if (!this.context) {
      return;
    }

    const ctx = this.context;
    const angle = this.getTangentAngle(start, end, controlPoint1, controlPoint2, t);

    ctx.save();
    ctx.translate(end.x, end.y);
    ctx.rotate(angle);

    this.applyDefaultLineStyle();

    ctx.beginPath();
    ctx.moveTo(0, 0);
    ctx.lineTo(-10, -5);
    ctx.lineTo(-10, 5);
    ctx.closePath();
    ctx.fill();

    ctx.restore();
  }

  /**
   * 获取当前实例的上下文
   * @returns 画布上下文
   */
  public getCanvasContext(): CanvasRenderingContext2D | OffscreenCanvasRenderingContext2D | null {
    return this.context;
  }
}
