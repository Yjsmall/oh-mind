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

import window from '@ohos.window';
import common from '@ohos.app.ability.common';
import { GlobalContext } from '../utils/GlobalContext';
import { WindowRect } from '../model/NodeObj';

export class WindowManager {
  private static instance: WindowManager;
  private window: window.Window | null = null;
  private cachedSize: WindowRect = { width: 1920, height: 1000 };

  public static getInstance(): WindowManager {
    if (!WindowManager.instance) {
      WindowManager.instance = new WindowManager();
    }
    return WindowManager.instance;
  }


  /**
   * 初始化
   */
  public static async initialize(): Promise<void> {
    try {
      const context: common.UIAbilityContext = GlobalContext.getInstance().getContext()!;
      const instance = WindowManager.getInstance();
      instance.window = await window.getLastWindow(context);
      const properties = await instance.window.getWindowProperties();
      instance.cachedSize = {
        width: Number(properties.drawableRect.width),
        height: Number(properties.drawableRect.height)
      };
    } catch (error) {
      console.error('Failed to get window size:', error);
    }
  }

  /**
   * 获取窗口尺寸
   */
  public static getWindowSize(): WindowRect {
    const windowSize = WindowManager.getInstance().cachedSize;
    const uiContext: UIContext = GlobalContext.getInstance().getUiContext()!;
    return {
      width: uiContext.px2vp(windowSize.width),
      height: uiContext.px2vp(windowSize.height)
    };
  }

  /**
   * 全屏窗口
   */
  public maximize(): void {
    this.window!.maximize();
  }

  /**
   * 恢复窗口
   */
  public recover(): void {
    this.window!.recover();
  }

  /**
   * 缩小窗口
   */
  public minimize(): void {
    this.window!.minimize();
  }
}