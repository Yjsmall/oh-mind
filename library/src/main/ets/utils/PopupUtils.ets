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

export class PopupEventsUtils {
  private static instance: PopupEventsUtils;
  private isShowTagsPopup: boolean = false;
  private onPopStatusChange: ((status: boolean) => void) | null = null;

  /**
   * 私有构造函数，确保单例模式
   */
  private constructor() {
  }

  /**
   * 获取单例实例
   */
  public static getInstance(): PopupEventsUtils {
    if (!PopupEventsUtils.instance) {
      PopupEventsUtils.instance = new PopupEventsUtils();
    }
    return PopupEventsUtils.instance;
  }

  /**
   * 设置状态变化回调
   */
  setOnPopupStatusChange(callback: (status: boolean) => void): void {
    this.onPopStatusChange = callback;
  }

  /**
   * 更新状态（用于点击按钮或者保存后的实时更新）
   */
  updatePopupStatus(status: boolean): void {
    this.isShowTagsPopup = status;
    this.notifyPopupStatusChange();
  }

  /**
   * 通知位置变化
   */
  private notifyPopupStatusChange(): void {
    if (this.onPopStatusChange) {
      this.onPopStatusChange(this.isShowTagsPopup);
    }
  }

  // 获取是否展示标签弹窗
  getPopupStatus(): boolean {
    return this.isShowTagsPopup;
  }

  open() {
    this.updatePopupStatus(true);
  }

  close() {
    this.updatePopupStatus(false);
  }
}
