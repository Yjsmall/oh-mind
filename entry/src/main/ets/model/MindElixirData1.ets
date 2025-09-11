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
    id: 'me-root',
    topic: 'HTML structure',
    "style": {
      background: '#f00',
      color: '#fff',
      fontWeight: 900,
      fontSize: 32,
      padding: 20
    },
    children: [
      {
        topic: 'div.map-container',
        id: '33905a6bde6512e4',
        expanded: true,
        children: [
          {
            topic: 'div.map-canvas',
            id: '33905d3c66649e8f',
            tags: ['A special case of a `grp` tag'],
            expanded: true,
            children: [
              {
                topic: 'me-root',
                id: '33906b754897b9b9',
                tags: ['A special case of a `t` tag'],
                expanded: true,
                children: [{ topic: 'ME-TPC', id: '33b5cbc93b9968ab' }],
              },
              {
                topic: 'children.box',
                id: '33906db16ed7f956',
                expanded: true,
                children: [
                  {
                    topic: 'grp(group)',
                    id: '33907d9a3664cc8a',
                    expanded: true,
                    children: [
                      {
                        topic: 't(top)',
                        id: '3390856d09415b95',
                        expanded: true,
                        "style": {
                          width: 130,
                          background: '#f00',
                          color: '#fff',
                          border: {
                            width: 1,
                            radius: 30,
                            color: '#000',
                          }
                        },
                        children: [
                          {
                            topic: 'tpc(topic)',
                            id: '33908dd36c7d32c5',
                            expanded: true,
                            children: [
                              { topic: 'text', id: '3391630d4227e248' },
                              { topic: 'icons', id: '33916d74224b141f' },
                              { topic: 'tags', id: '33916421bfff1543' },
                            ],
                            tags: ['E() function return'],
                          },
                          {
                            topic: 'epd(expander)',
                            id: '33909032ed7b5e8e',
                            tags: ['If had child'],
                          },
                        ],
                        tags: ['createParent retun'],
                      },
                      {
                        topic: 'me-children',
                        id: '339087e1a8a5ea68',
                        expanded: true,
                        children: [
                          {
                            topic: 'me-wrapper',
                            id: '3390930112ea7367',
                            tags: ['what add node actually do is to append grp tag to children'],
                          },
                          { topic: 'grp...', id: '3390940a8c8380a6' },
                        ],
                        tags: ['layoutChildren return'],
                      },
                      { topic: 'svg.subLines', id: '33908986b6336a4f' },
                    ],
                    tags: ['have child'],
                  },
                  {
                    topic: 'me-wrapper',
                    id: '339081c3c5f57756',
                    expanded: true,
                    children: [
                      {
                        topic: 'ME-PARENT',
                        id: '33b6160ec048b997',
                        expanded: true,
                        children: [{ topic: 'ME-TPC', id: '33b616f9fe7763fc' }],
                      },
                    ],
                    tags: ['no child'],
                  },
                  { topic: 'grp...', id: '33b61346707af71a' },
                ],
              },
              { topic: 'svg.lines', id: '3390707d68c0779d' },
              { topic: 'svg.linkcontroller', id: '339072cb6cf95295' },
              { topic: 'svg.topiclinks', id: '3390751acbdbdb9f' },
            ],
          },
          { topic: 'cmenu', id: '33905f95aeab942d' },
          { topic: 'toolbar.rb', id: '339060ac0343f0d7' },
          { topic: 'toolbar.lt', id: '3390622b29323de9' },
          { topic: 'nmenu', id: '3390645e6d7c2b4e' },
        ],
      },
    ],
  },
  arrows: [],
};

export default mindElixirData;
