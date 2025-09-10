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

import { ZoomUtils } from '../utils/ZoomUtils';
import { CanvasPositionUtils } from '../utils/CanvasPositionUtils';
import { NodeHelper } from '../controller/NodeHelper';
import { ShortcutManager } from '../controller/ShortcutManager';

export class UtilsManager {
  private static zoomUtilsMap = new Map<string, ZoomUtils>();
  private static positionUtilsMap = new Map<string, CanvasPositionUtils>();
  private static nodeHelpersMap = new Map<string, NodeHelper>();
  private static shortcutsManager = new Map<string, ShortcutManager>();

  /**
   * 注册工具类实例
   */
  static registerUtils(instanceId: string, zoomUtils: ZoomUtils, positionUtils: CanvasPositionUtils,
    nodeHelpers: NodeHelper, shortcutManager: ShortcutManager): void {
    UtilsManager.zoomUtilsMap.set(instanceId, zoomUtils);
    UtilsManager.positionUtilsMap.set(instanceId, positionUtils);
    UtilsManager.nodeHelpersMap.set(instanceId, nodeHelpers);
    UtilsManager.shortcutsManager.set(instanceId, shortcutManager);
  }

  /**
   * 获取缩放工具
   */
  static getZoomUtils(instanceId: string): ZoomUtils | null {
    return UtilsManager.zoomUtilsMap.get(instanceId) || null;
  }

  /**
   * 获取位置工具
   */
  static getPositionUtils(instanceId: string): CanvasPositionUtils | null {
    return UtilsManager.positionUtilsMap.get(instanceId) || null;
  }

  /**
   * 获取节点工具
   */
  static getNodeHelper(instanceId: string): NodeHelper | null {
    return UtilsManager.nodeHelpersMap.get(instanceId) || null;
  }

  /**
   * 获取快捷键工具
   */
  static getShortcutManager(instanceId: string): ShortcutManager | null {
    return UtilsManager.shortcutsManager.get(instanceId) || null;
  }

  /**
   * 移除工具类实例
   */
  static removeUtils(instanceId: string): void {
    UtilsManager.zoomUtilsMap.delete(instanceId);
    UtilsManager.positionUtilsMap.delete(instanceId);
    UtilsManager.nodeHelpersMap.delete(instanceId);
    UtilsManager.shortcutsManager.delete(instanceId);
  }


  /**
   * 清空所有工具类实例
   */
  static clearAllUtils(): void {
    UtilsManager.zoomUtilsMap.clear();
    UtilsManager.positionUtilsMap.clear();
    UtilsManager.nodeHelpersMap.clear();
    UtilsManager.shortcutsManager.clear();
  }
}