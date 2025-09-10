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

import { MindElixir, MindElixirCore, MindElixirData, NodeOption, LayoutDirection } from '@ohos/mind-elixir';
import mindElixirData from '../model/MindElixirData2';

@Entry
@Component
struct Index{
  private mindOption: NodeOption = {
    locale: 'zh',
    draggable: true,
    editable: true,
    toolBar: true,
    allowUndo: true,
    contextMenu: true,
    layout: LayoutDirection.TOP,
    nodeShape: 'line',
    nodeSpacing: {
      horizontal: 80,
      vertical: 80
    },
    nodeStyle: {
      fontSize: 20,
      fontFamily: 'HarmonyOS Sans',
      color: '#333',
      background: '#fff',
      fontWeight: 'normal',
      border: {
        width: 1,
        radius: 0,
        color: '#000',
      },
      maxWidth: 200,
      padding: 5
    },
    lineStyle: {
      width: 2,
      color: '#e64553'
    }
  };
  @State model: MindElixirCore = new MindElixirCore(this.mindOption);
  private initializedData: MindElixirData = mindElixirData;

  build() {
    Flex() {
      MindElixir({ model: this.model, data: this.initializedData })
        .height('100%')
        .width('100%');
    }
    .height('100%')
    .width('100%');
  }
}