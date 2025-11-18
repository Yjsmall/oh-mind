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

@Entry
@Component
struct Project {
  private mindOption: NodeOption = {
    locale: 'zh',
    draggable: true,
    editable: true,
    toolBar: true,
    allowUndo: true,
    contextMenu: true,
    layout: LayoutDirection.RIGHT,
    nodeShape: 'line',
    mindInViewport: true,
    nodeSpacing: {
      horizontal: 50,
      vertical: 50
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
  private initializedData: MindElixirData = {
    nodeData: {
      id: "root",
      topic: "中药知识图谱",
      expanded: true,
      style: {
        background: "#4caf50",
        color: "#ffffff",
        fontWeight: "bold",
        fontSize: 24,
        padding: 16,
        border: {
          width: 2,
          radius: 12,
          color: "#388e3c"
        }
      },
      children: [
        {
          topic: "中药材分类",
          id: "herb-categories",
          expanded: true,
          style: {
            background: "#e8f5e9",
            color: "#2e7d32"
          },
          children: [
            {
              topic: "根茎类药材",
              id: "rhizome-herbs",
              expanded: true,
              style: {
                background: "#f1f8e9",
                color: "#558b2f"
              }
            },
            {
              topic: "花果类药材",
              id: "flower-fruit-herbs",
              expanded: true,
              style: {
                background: "#f3e5f5",
                color: "#7b1fa2"
              }
            },
            {
              topic: "叶类药材",
              id: "leaf-herbs",
              expanded: true,
              style: {
                background: "#e3f2fd",
                color: "#1565c0"
              }
            }
          ]
        },
        {
          topic: "经典中药方剂",
          id: "classic-prescriptions",
          expanded: true,
          style: {
            background: "#fff3e0",
            color: "#ef6c00"
          },
          children: [
            {
              topic: "四君子汤",
              id: "prescription-001",
              expanded: true,
              style: {
                background: "#fbe9e7",
                color: "#d84315"
              }
            },
            {
              topic: "六味地黄丸",
              id: "prescription-002",
              expanded: true,
              style: {
                background: "#e0f7fa",
                color: "#00838f"
              }
            }
          ]
        },
        {
          topic: "中药功效主治",
          id: "herb-effects",
          expanded: true,
          style: {
            background: "#e8eaf6",
            color: "#283593"
          },
          children: [
            {
              topic: "清热解毒类",
              id: "effect-cooling",
              expanded: true,
              style: {
                background: "#ffebee",
                color: "#c62828"
              }
            },
            {
              topic: "补气养血类",
              id: "effect-replenish",
              expanded: true,
              style: {
                background: "#fce4ec",
                color: "#ad1457"
              }
            }
          ]
        },
        {
          topic: "<a>返回首页</a>",
          id: "back",
          expanded: true,
          style: {
            color: '#000'
          },
          onLinkClick: (text:string) => {
            this.getUIContext().getRouter().back();
          }
        }
      ]
    }
  };

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