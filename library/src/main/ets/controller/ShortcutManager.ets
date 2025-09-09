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

import { MindElixirCore } from './MindElixirCore';
import { ZoomUtils } from '../utils/ZoomUtils';
import { UtilsManager } from '../utils/UtilsManager';
import { NodeHelper } from '../controller/NodeHelper';

export class ShortcutManager {
  private mindElixir: MindElixirCore;
  private isEnabled: boolean = true;
  private keyHandlers: Map<string, () => void> = new Map();
  // 跟踪当前按下的修饰键
  private pressedModifiers: Set<string> = new Set();
  // 跟踪当前按下的非修饰键
  private pressedNonModifierKeys: Set<string> = new Set();
  // 防止重复触发的机制
  private processedKeys: Map<string, number> = new Map();
  // 防重复触发延迟(毫秒)
  private keyRepeatDelay: number = 300;
  private zoomCtrl: ZoomUtils | null = null;

  /**
   * 构造函数
   * @param mind 思维导图核心实例
   */
  constructor(mind: MindElixirCore) {
    this.mindElixir = mind;
    this.initializeKeyHandlers();
  }

  /**
   * 初始化快捷键处理器
   */
  private initializeKeyHandlers(): void {
    // 撤销
    this.keyHandlers.set('ctrl+keycode_z', () => this.mindElixir.undo());

    // 重做
    this.keyHandlers.set('ctrl+keycode_y', () => this.mindElixir.redo());

    // 插入兄弟节点
    this.keyHandlers.set('alt+keycode_enter', () => {
      const selectedId = this.mindElixir.getSelectedNodeId();
      if (selectedId) {
        this.mindElixir.addSibling(selectedId);
      }
    });

    // 向前插入兄弟节点
    this.keyHandlers.set('shift+keycode_enter', () => {
      const selectedId = this.mindElixir.getSelectedNodeId();
      if (selectedId) {
        this.mindElixir.addSibling(selectedId, true);
      }
    });

    // 插入子节点
    this.keyHandlers.set('keycode_tab', () => {
      const selectedId = this.mindElixir.getSelectedNodeId();
      if (selectedId) {
        this.mindElixir.add(selectedId);
      }
    });

    // 插入父节点
    this.keyHandlers.set('ctrl+keycode_enter', () => {
      const selectedId = this.mindElixir.getSelectedNodeId();
      if (selectedId) {
        this.mindElixir.addParent(selectedId);
      }
    });

    // 删除节点
    this.keyHandlers.set('keycode_del', () => {
      const selectedId = this.mindElixir.getSelectedNodeId();
      if (selectedId) {
        this.mindElixir.remove(selectedId);
      }
    });
    this.keyHandlers.set('keycode_forward_del', () => {
      const selectedId = this.mindElixir.getSelectedNodeId();
      if (selectedId) {
        this.mindElixir.remove(selectedId);
      }
    });

    // 复制
    this.keyHandlers.set('ctrl+keycode_c', () => {
      const nodeHelper: NodeHelper = UtilsManager.getNodeHelper(this.mindElixir.getInstanceId())!;
      const selectedId = this.mindElixir.getSelectedNodeId();
      if (selectedId) {
        nodeHelper.copy(selectedId);
      }
    });

    // 粘贴
    this.keyHandlers.set('ctrl+keycode_v', () => {
      const nodeHelper: NodeHelper = UtilsManager.getNodeHelper(this.mindElixir.getInstanceId())!;
      const selectedId = this.mindElixir.getSelectedNodeId();
      if (selectedId) {
        nodeHelper.pasting(selectedId);
      }
    });

    // 剪切
    this.keyHandlers.set('ctrl+keycode_x', () => {
      const nodeHelper: NodeHelper = UtilsManager.getNodeHelper(this.mindElixir.getInstanceId())!;
      const selectedId = this.mindElixir.getSelectedNodeId();
      if (selectedId) {
        nodeHelper.copy(selectedId, true);
      }
    });

    // 放大思维导图
    this.keyHandlers.set('ctrl+keycode_equals', () => {
      this.zoomCtrl = UtilsManager.getZoomUtils(this.mindElixir.getInstanceId())!;
      this.zoomCtrl.zoomIn();
      this.mindElixir.refresh();
    });

    // 缩小思维导图
    this.keyHandlers.set('ctrl+keycode_minus', () => {
      this.zoomCtrl = UtilsManager.getZoomUtils(this.mindElixir.getInstanceId())!;
      this.zoomCtrl.zoomOut();
      this.mindElixir.refresh();
    });

    // 重置思维导图
    this.keyHandlers.set('ctrl+keycode_0', () => {
      this.zoomCtrl = UtilsManager.getZoomUtils(this.mindElixir.getInstanceId())!;
      this.zoomCtrl.reset();
      this.mindElixir.refresh();
    });
  }

  /**
   * 处理键盘事件
   */
  public handleKeyEvent(event: KeyEvent): void {
    if (!this.isEnabled) {
      return;
    }

    const keyText = event.keyText.toLowerCase();
    const isModifier = this.isModifierKey(keyText);

    // 根据按键类型处理
    if (event.type === KeyType.Down) {
      this.handleKeyDown(event, isModifier);
    } else if (event.type === KeyType.Up) {
      this.handleKeyUp(event, isModifier);
    }
  }

  /**
   * 处理按键按下事件
   */
  private handleKeyDown(event: KeyEvent, isModifier: boolean): void {
    const keyText = event.keyText.toLowerCase();
    // 更新按键状态
    if (isModifier) {
      const normalizedModifier = this.normalizeModifierKey(keyText);
      if (normalizedModifier) {
        this.pressedModifiers.add(normalizedModifier);
      }
    } else {
      this.pressedNonModifierKeys.add(keyText);
    }

    // 只处理非修饰键的按下事件（修饰键单独按下时不触发）
    if (!isModifier) {
      const comboKey = this.getComboKey();

      // 检查是否是重复触发
      if (!this.isRepeatTrigger(comboKey)) {
        const handler = this.keyHandlers.get(comboKey);
        if (handler) {
          event.stopPropagation();
          this.processedKeys.set(comboKey, new Date().getTime());
          handler();
        }
      }
    }
  }

  /**
   * 处理按键松开事件
   */
  private handleKeyUp(event: KeyEvent, isModifier: boolean): void {
    const keyText = event.keyText.toLowerCase();
    // 更新按键状态
    if (isModifier) {
      const normalizedModifier = this.normalizeModifierKey(keyText);
      if (normalizedModifier) {
        this.pressedModifiers.delete(normalizedModifier);
      }
    } else {
      this.pressedNonModifierKeys.delete(keyText);

      // 当非修饰键松开时，清除对应的处理记录
      const comboKey = this.getComboKey();
      this.processedKeys.delete(comboKey);
    }
  }

  /**
   * 获取当前组合键字符串
   */
  private getComboKey(): string {
    const keys: string[] = [];

    // 添加按下的修饰键（按字母顺序排序以确保一致性）
    const sortedModifiers = Array.from(this.pressedModifiers).sort();
    sortedModifiers.forEach(modifier => {
      keys.push(modifier);
    });

    // 添加按下的非修饰键（如果有）
    const nonModifierKeys = Array.from(this.pressedNonModifierKeys);
    if (nonModifierKeys.length > 0) {
      // 通常只有一个非修饰键被按下，但为了安全起见取第一个
      keys.push(nonModifierKeys[0]);
    }
    return keys.join('+');
  }

  /**
   * 检查是否是重复触发
   */
  private isRepeatTrigger(comboKey: string): boolean {
    const currentTime = new Date().getTime();
    const lastProcessedTime = this.processedKeys.get(comboKey);

    // 如果这个组合键之前被处理过，且在防重复延迟时间内，认为是重复触发
    if (lastProcessedTime && (currentTime - lastProcessedTime) < this.keyRepeatDelay) {
      return true;
    }

    return false;
  }

  /**
   * 规范化修饰键名称
   */
  private normalizeModifierKey(keyText: string): string | null {
    const modifierMap: Record<string, string> = {
      'keycode_ctrl_left': 'ctrl',
      'keycode_ctrl_right': 'ctrl',
      'keycode_shift_left': 'shift',
      'keycode_shift_right': 'shift',
      'keycode_alt_left': 'alt',
      'keycode_alt_right': 'alt',
      'keycode_fn': 'fn',
      'keycode_meta_left': 'meta',
      'keycode_meta_right': 'meta'
    };

    return modifierMap[keyText] || null;
  }

  /**
   * 判断是否为修饰键
   */
  private isModifierKey(keyText: string): boolean {
    const modifierKeys = [
      'keycode_ctrl_left', 'keycode_ctrl_right',
      'keycode_shift_left', 'keycode_shift_right',
      'keycode_alt_left', 'keycode_alt_right',
      'keycode_fn', 'keycode_meta_left', 'keycode_meta_right'
    ];

    return modifierKeys.includes(keyText);
  }

  /**
   * 设置防重复触发延迟时间
   */
  public setKeyRepeatDelay(delay: number): void {
    this.keyRepeatDelay = delay;
  }

  /**
   * 启用/禁用快捷键
   */
  public setEnabled(enabled: boolean): void {
    this.isEnabled = enabled;

    // 禁用时清除所有按键状态
    if (!enabled) {
      this.clearAllKeyStates();
    }
  }

  /**
   * 清除所有按键状态
   */
  private clearAllKeyStates(): void {
    this.pressedModifiers.clear();
    this.pressedNonModifierKeys.clear();
    this.processedKeys.clear();
  }

  /**
   * 添加快捷键处理器
   */
  public addKeyHandler(combo: string, handler: () => void): void {
    this.keyHandlers.set(combo, handler);
  }

  /**
   * 移除快捷键处理器
   */
  public removeKeyHandler(combo: string): void {
    this.keyHandlers.delete(combo);
  }

  /**
   * 销毁实例
   */
  public destroy(): void {
    this.clearAllKeyStates();
    this.keyHandlers.clear();
  }
}