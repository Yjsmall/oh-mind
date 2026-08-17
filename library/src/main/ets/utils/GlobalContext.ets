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

import common from '@ohos.app.ability.common';
import { UIContext } from '@kit.ArkUI';

export class GlobalContext {
  private static instance: GlobalContext;
  private context: common.Context | null = null;
  private uiContext: UIContext | null = null;

  public static getInstance(): GlobalContext {
    if (!GlobalContext.instance) {
      GlobalContext.instance = new GlobalContext();
    }
    return GlobalContext.instance;
  }

  setContext(context: common.Context): void {
    this.context = context;
  }

  getContext(): common.Context | null {
    return this.context;
  }

  setUiContext(context: UIContext): void {
    this.uiContext = context;
  }

  getUiContext(): UIContext | null {
    return this.uiContext;
  }
}
