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
    editable: false,
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
  private initializedData: MindElixirData = JSON.parse(JSON.stringify(mindElixirData));

  aboutToAppear(): void {
    this.initializedData.nodeData?.children?.push({
      topic: "<a href='pages/Medicine'>点击</a>我可以跳转到<a href='pages/Medicine'>中药页面</a>，请试试吧！",
      id: "go_medicine_page",
      linkStyle: {
        color: '#f00',
      },
      onLinkClick: (text:string) => {
        const regex = /href\s*=\s*([^\s>]+)/i;
        const match = text.match(regex);
        if (match && match[1]) {
          const url = match[1].replace(/'/g, '');
          this.getUIContext().getRouter().pushUrl({
            url,
          });
        }
      }
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