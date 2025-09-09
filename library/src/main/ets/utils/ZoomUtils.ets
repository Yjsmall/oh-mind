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

export class ZoomUtils {
  private currentScale: number = 1.0;
  private minScale: number = 0.1;
  private maxScale: number = 5.0;
  private sensitivity: number = 0.1;
  private onScaleChange: ((scale: number) => void) | null = null;

  /**
   * 构造函数，每个实例独立的缩放控制器
   * @param initialScale 初始缩放比例，默认1.0
   * @param minScale 最小缩放比例，默认0.1
   * @param maxScale 最大缩放比例，默认5.0
   * @param sensitivity 缩放灵敏度，默认0.1
   */
  constructor(
    initialScale: number = 1.0,
    minScale: number = 0.1,
    maxScale: number = 5.0,
    sensitivity: number = 0.1
  ) {
    this.currentScale = this.clampScale(initialScale);
    this.minScale = minScale;
    this.maxScale = maxScale;
    this.sensitivity = sensitivity;
  }

  /**
   * 设置缩放变化回调
   */
  setOnScaleChange(callback: (scale: number) => void): void {
    this.onScaleChange = callback;
  }

  /**
   * 放大
   */
  zoomIn(): void {
    const newScale = this.clampScale(this.currentScale + this.sensitivity);
    this.setScale(newScale);
  }

  /**
   * 缩小
   */
  zoomOut(): void {
    const newScale = this.clampScale(this.currentScale - this.sensitivity);
    this.setScale(newScale);
  }

  /**
   * 重置缩放
   */
  reset(): void {
    this.setScale(1.0);
  }

  /**
   * 设置缩放灵敏度
   */
  setSensitivity(sensitivity: number): void {
    this.sensitivity = Math.max(0.01, sensitivity);
  }

  /**
   * 获取当前缩放比例
   */
  getScale(): number {
    return this.currentScale;
  }

  /**
   * 获取缩放灵敏度
   */
  getSensitivity(): number {
    return this.sensitivity;
  }

  /**
   * 设置缩放比例
   */
  setScale(scale: number): void {
    const clampedScale = this.clampScale(scale);
    if (this.currentScale !== clampedScale) {
      this.currentScale = clampedScale;
      this.notifyScaleChange();
    }
  }

  /**
   * 限制缩放比例在有效范围内
   */
  private clampScale(scale: number): number {
    return Math.max(this.minScale, Math.min(this.maxScale, scale));
  }

  /**
   * 通知缩放变化
   */
  private notifyScaleChange(): void {
    if (this.onScaleChange) {
      this.onScaleChange(this.currentScale);
    }
  }
}