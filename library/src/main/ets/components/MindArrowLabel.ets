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
import { Arrow } from '../model/NodeObj';

@Component
export struct MindArrowLabel {
  @Link model: MindElixirCore;
  @Prop arrowData: Arrow;
  @Link selectedNodeId: string; // 当前选中的节点ID
  @Link arrowLabelEdit: boolean;
  controller: TextInputController = new TextInputController();
  @State fontSize: number = 18;
  @State labelWidth: number = 0;
  @State labelHeight: number = this.fontSize;
  @State newLabel: string = this.arrowData.label;

  private estimateTextWidth(text: string, fontSize = 18) {
    const charWidth = 9.6;
    return text.length * charWidth / 2;
  }

  aboutToAppear(): void {
    this.labelWidth = this.estimateTextWidth(this.arrowData.label);
  }

  build() {
    if (this.arrowLabelEdit) {
      TextInput({ text: this.arrowData.label, controller: this.controller })
        .width('auto')
        .fontSize(this.fontSize)
        .fontColor(Color.Red)
        .height(30)
        .padding(0)
        .margin(0)
        .position({
          x: this.arrowData.position?.x! - this.labelWidth,
          y: this.arrowData.position?.y! - this.labelHeight
        })
        .onChange((value: string) => {
          this.newLabel = value;
        })
        .onBlur(() => {
          this.arrowLabelEdit = false;
          this.model.updateLinkLabel(this.arrowData.id, this.newLabel);
          this.labelWidth = this.estimateTextWidth(this.newLabel);
        });
    } else {
      Text(this.arrowData.label)
        .fontColor(Color.Red)
        .fontSize(this.fontSize)
        .padding(4)
        .margin(0)
        .border(this.selectedNodeId === this.arrowData.id ?
          { width: 2, color: '#aadffa', radius: 15 } : { width: 2, color: Color.Transparent })
        .position({
          x: this.arrowData.position?.x! - this.labelWidth,
          y: this.arrowData.position?.y! - this.labelHeight
        })
        .gesture(
          GestureGroup(GestureMode.Exclusive,
            TapGesture({ count: 2 }).onAction(() => {
              console.log("双击事件");
              this.arrowLabelEdit = true;
            }),
            TapGesture({ count: 1 }).onAction(() => {
              console.log("单击事件");
              this.selectedNodeId = this.arrowData.id;
              this.model.selectNode(this.selectedNodeId);
            })
          ));
    }
  }
}