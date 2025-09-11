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

import { MindElixirCore } from '../controller/MindElixirCore';
import { PopupEventsUtils } from '../utils/PopupUtils';
import { NodeObj } from '../model/NodeObj';
import { NodeHelper } from '../controller/NodeHelper';
import { UtilsManager } from '../utils/UtilsManager';

@Component
export default struct TagsPopup {
  @Link model: MindElixirCore;
  @State tagStr: string = '';
  @State allTags: string[] = [];
  @State uptNode: NodeObj | null = this.model.getSelectedNode();
  private nodeHelper: NodeHelper = UtilsManager.getNodeHelper(this.model.getInstanceId())!;

  aboutToAppear(): void {
    if (this.uptNode!.tags) {
      this.tagStr = this.uptNode!.tags.join(',');
    }
    this.getAllTags();
  }

  /**
   * 获取所有的Tags
   * @returns 去重后的Tags数组
   */
  public getAllTags() {
    const flatNodes = this.nodeHelper.getFlatNodes();
    let allTags: string[] = [];
    if (flatNodes!) {
      flatNodes.forEach((item: NodeObj) => {
        if (item.tags!) {
          allTags.push(...item.tags);
        }
      });
    }
    this.allTags = Array.from(new Set(allTags));
  }

  build() {
    //   弹出框
    Column() {
      Column() {
        Text('标签')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .width('100%')
          .height(40)
          .lineHeight(40)
          .margin({ left: 30 });

        Column() {
          TextArea({
            text: this.tagStr!!,
            placeholder: '多个标签请用半角逗号隔开'
          })
            .fontSize(20)
            .fontColor('#ff4f4e4e')
            .placeholderFont({ size: 20 })
            .placeholderColor('#b6b6b6')
            .backgroundColor('#fff')
            .onChange((val) => {
              this.tagStr = val;
            });

        }.layoutWeight(1);

        Divider().height(1).width('90%').backgroundColor('#000');

        Column() {
          Flex({ wrap: FlexWrap.Wrap }) {
            if (this.allTags?.length) {
              ForEach(this.allTags, (item: string) => {
                Text(item)
                  .fontSize(14)
                  .width('auto')
                  .backgroundColor('#e8e8e8')
                  .borderRadius('50%')
                  .padding(5)
                  .margin({ top: 10, left: 10 })
                  .onClick(() => {
                    // 判断原tags中是否已经存在
                    if (!this.tagStr.split(',').includes(item)) {
                      if (this.tagStr.length === 0) {
                        this.tagStr += item;
                      } else {
                        this.tagStr += (',' + item);
                      }
                    }
                  });
              });
            }
          }.width('100%').height('100%');
        }.height(80).width('90%').clip(true);

      }
      .constraintSize({ maxWidth: 500, maxHeight: 300 })
      .width('70%')
      .height('40%')
      .padding({ top: 20, bottom: 20 })
      .backgroundColor('#fff')
      .border({ width: 1, color: '#e2e2e2' })
      .borderRadius(20)
      .shadow({
        radius: 20,
        color: '#f4f4f4',
        offsetX: 0,
        offsetY: 0
      })
      .onClick(() => {
      });

    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height('100%')
    .position({ top: 0, left: 0 })
    .onClick(() => {
      if (this.uptNode) {
        this.uptNode.tags = [];
        this.tagStr.split(',').forEach((item) => {
          if (item) {
            this.uptNode?.tags?.push(item);
          }
        });
        this.uptNode.tags = Array.from(new Set(this.uptNode.tags));
        this.model.updateNode(this.uptNode);
      }
      this.tagStr = '';
      PopupEventsUtils.getInstance().close();
    });
  }
}