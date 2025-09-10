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

import emitter from '@ohos.events.emitter';

export enum MindMapEvent {
  NODE_UPDATED = 1,
  CANVAS_UPDATED = 2
}

export class MindMapEventEmitter {
  // 注册节点更新监听器
  static onNodeUpdated(callback: (eventData: emitter.EventData) => void): void {
    const innerEvent: emitter.InnerEvent = {
      eventId: MindMapEvent.NODE_UPDATED,
      priority: emitter.EventPriority.HIGH
    };
    emitter.on(innerEvent, callback);
  }

  // 移除节点更新监听器
  static offNodeUpdated(callback?: (eventData: emitter.EventData) => void): void {
    emitter.off(MindMapEvent.NODE_UPDATED, callback);
  }

  // 触发节点更新事件
  static emitNodeUpdated(data?: object): void {
    const innerEvent: emitter.InnerEvent = {
      eventId: MindMapEvent.NODE_UPDATED,
      priority: emitter.EventPriority.HIGH
    };
    emitter.emit(innerEvent, { data });
  }

  // 注册Canvas更新监听器
  static onCanvasUpdated(callback: (eventData: emitter.EventData) => void): void {
    const innerEvent: emitter.InnerEvent = {
      eventId: MindMapEvent.CANVAS_UPDATED,
      priority: emitter.EventPriority.HIGH
    };
    emitter.on(innerEvent, callback);
  }

  // 移除节点更新监听器
  static offCanvasUpdated(callback?: (eventData: emitter.EventData) => void): void {
    emitter.off(MindMapEvent.CANVAS_UPDATED, callback);
  }

  // 触发节点更新事件
  static emitCanvasUpdated(data?: object): void {
    const innerEvent: emitter.InnerEvent = {
      eventId: MindMapEvent.CANVAS_UPDATED,
      priority: emitter.EventPriority.HIGH
    };
    emitter.emit(innerEvent, { data });
  }
}