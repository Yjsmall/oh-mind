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
import { CanvasPosition, CanvasSize } from '../model/NodeObj';
import { NodeHelper } from '../controller/NodeHelper';
import { UtilsManager } from '../utils/UtilsManager';

export class CanvasPositionUtils{
  private mindElixir: MindElixirCore;
  private currentPosition: CanvasPosition = {
    offsetX: 0,
    offsetY: 0,
    positionX: 0,
    positionY: 0
  };
  private containerSize: CanvasSize = {
    width: 200,
    height: 200
  };
  private mindContentSize: CanvasSize = {
    width: 200,
    height: 200
  };
  private onPositionChange: ((position: CanvasPosition) => void) | null = null;

  /**
   * 构造函数，每个思维导图实例都有自己的位置控制器
   */
  constructor(model: MindElixirCore) {
    this.mindElixir = model;
  }

  /**
   * 设置位置变化回调
   */
  setOnPositionChange(callback: (position: CanvasPosition) => void): void {
    this.onPositionChange = callback;
  }


  /**
   * 更新位置（用于拖拽过程中的实时更新）
   */
  updatePosition(offsetX: number, offsetY: number): void {
    this.currentPosition.offsetX = offsetX;
    this.currentPosition.offsetY = offsetY;
    this.notifyPositionChange();
  }

  /**
   * 保存当前位置（用于拖拽结束时的最终位置）
   */
  saveCurrentPosition(): void {
    this.currentPosition.positionX = this.currentPosition.offsetX;
    this.currentPosition.positionY = this.currentPosition.offsetY;
    this.notifyPositionChange();
  }

  /**
   * 重置到初始位置
   */
  resetToOrigin(): void {
    this.currentPosition.offsetX = 0;
    this.currentPosition.offsetY = 0;
    this.mindElixir.setScaleVal(1);
    const options = this.mindElixir.getMindOptions();
    if (options.mindInViewport) {
      this.adjustZoomToFitContainer();
    } else {
      this.updatePosition(this.currentPosition.offsetX, this.currentPosition.offsetY);
    }
  }

  /**
   * 获取当前位置
   */
  getPosition(): CanvasPosition {
    return this.currentPosition;
  }

  /**
   * 通知位置变化
   */
  private notifyPositionChange(): void {
    if (this.onPositionChange) {
      this.onPositionChange(this.currentPosition);
    }
  }


  /**
   * 设置组件容器大小值
   */
  setContainerSize(width: number, height: number): void {
    this.containerSize.width = width;
    this.containerSize.height = height;
  }

  /**
   * 获取组件容器大小值
   */
  getContainerSize(): CanvasSize {
    return this.containerSize;
  }

  /**
   * 设置思维导图大小值
   */
  setMindContentSize(width: number, height: number): void {
    this.mindContentSize.width = width;
    this.mindContentSize.height = height;
  }

  /**
   * 获取组件容器大小值
   */
  getMindContentSize(): CanvasSize {
    return this.mindContentSize;
  }

  /**
   * 将思维导图自适应屏幕
   */
  adjustZoomToFitContainer(): void {
    const nodeHelper: NodeHelper = UtilsManager.getNodeHelper(this.mindElixir.getInstanceId())!;
    const mindContentSize: CanvasSize = this.getMindContentSize();
    const containerSize: CanvasSize = this.getContainerSize();
    // 计算水平和垂直方向的缩放比例
    const scaleX = containerSize.width / mindContentSize.width;
    const scaleY = containerSize.height / mindContentSize.height;
    const scaleValue = Math.min(scaleX, scaleY, 2.0);
    const oldScale = this.mindElixir.getScaleVal();

    // 设置缩放比例
    this.mindElixir.setScaleVal(scaleValue);
    // 计算缩放导致的尺寸变化
    const canvasSize = nodeHelper.getCanvasSize();
    const widthChange = (canvasSize.width * oldScale - canvasSize.width * scaleValue) / 2;
    const heightChange = (canvasSize.height * oldScale - canvasSize.height * scaleValue) / 2;
    // 设置居中位置
    this.updatePosition(this.currentPosition.offsetX - widthChange,
      this.currentPosition.offsetY - heightChange);
    this.saveCurrentPosition();
  }
}