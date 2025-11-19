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
import mindElixirData from '../model/MindElixirData';

@Entry
@Component
struct Index {
  private mindOption: NodeOption = {
    locale: 'zh',
    draggable: true,
    editable: true,
    toolBar: true,
    allowUndo: true,
    contextMenu: true,
    collapsible: true,
    siblingAlignment: true,
    mindInViewport: true,
    layout: LayoutDirection.RIGHT,
    nodeShape: 'line',
    nodeSpacing: {
      horizontal: 30,
      vertical: 30
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

  aboutToAppear(): void {
    this.initializedData.nodeData?.children?.push({
      topic: "点击我可以跳转到中药知识图谱页面，请试试吧！",
      id: "go_medicine_page",
      richText: [
        {
          text: '中药知识图谱',
          style: { color: '#ff0000', fontWeight: 'bold' },
          onClick: () => {
            this.getUIContext().getRouter().pushUrl({
              url: 'pages/Medicine',
            });
          }
        },
        {
          text: '试试',
          style: { color: '#ff00ff'},
          onClick: () => {
            this.getUIContext().getRouter().pushUrl({
              url: 'pages/Medicine',
            });
          }
        },
      ],
    });
  }

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