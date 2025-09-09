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

import { MindElixirData } from '@ohos/mind-elixir';

const mindElixirData: MindElixirData = {
  nodeData: {
    id: "vertical-root",
    topic: "中心主题",
    expanded: true,
    children: [
      {
        topic: "第一层分支第一层分支第一层分",
        id: "level1-branch1",
        expanded: true,
        children: [
          {
            topic: "第二层子节点A",
            id: "level2-nodeA",
            expanded: true,
            lineStyle: {
              width: 10,
              color: '#0f0'
            },
            children: [
              {
                topic: "第三层详细内容",
                id: "level3-detail1",
                expanded: true,
                children: [
                  {
                    topic: "第四层功能模块",
                    id: "level4-module1",
                    expanded: true,
                    children: [
                      {
                        topic: "第五层具体实现",
                        id: "level5-implementation1",
                      },
                      {
                        topic: "第五层扩展功能",
                        id: "level5-extension1",
                      }
                    ]
                  }
                ]
              }
            ]
          }
        ]
      },
      {
        topic: "第一层分支2",
        id: "level1-branch2",
        expanded: true,
        children: [
          {
            topic: "第二层子节点B",
            id: "level2-nodeB",
            expanded: true,
            children: [
              {
                topic: "第三层技术架构",
                id: "level3-architecture",
                expanded: true,
                children: [
                  {
                    topic: "第四层数据库设计",
                    id: "level4-database",
                    expanded: true,
                    children: [
                      {
                        topic: "第五层表结构",
                        id: "level5-table-structure",
                      },
                      {
                        topic: "第五层缓存策略",
                        id: "level5-cache-strategy",
                      }
                    ]
                  }
                ],
                style: {
                  width: 130,
                  background: '#f00',
                  color: '#fff',
                  border: {
                    width: 1,
                    radius: 30,
                    color: '#000',
                  }
                }
              }
            ]
          }
        ]
      },
      {
        topic: "第一层分支3",
        id: "level1-branch3",
        expanded: true,
        children: [
          {
            topic: "第二层子节点C",
            id: "level2-nodeC",
            expanded: true,
            children: [
              {
                topic: "第三层用户界面",
                id: "level3-ui",
                expanded: true,
                children: [
                  {
                    topic: "第四层组件设计",
                    id: "level4-components",
                    expanded: true,
                    children: [
                      {
                        topic: "第五层按钮组件",
                        id: "level5-button-component",
                      },
                      {
                        topic: "第五层表单组件",
                        id: "level5-form-component",
                      }
                    ]
                  }
                ]
              }
            ]
          }
        ]
      }
    ],
    style: {
      background: '#f00',
      color: '#fff',
      fontWeight: 900,
      fontSize: 32,
      padding: 20
    }
  },
};

export default mindElixirData;
