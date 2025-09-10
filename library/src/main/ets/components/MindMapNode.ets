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

import { NodeObj } from '../model/NodeObj';
import { MindMapNodeComponent } from './MindMapNodeComponent';
import { MindElixirCore } from '../controller/MindElixirCore';

@Component
export default struct MindMapNode {
  @Link model: MindElixirCore;
  @Prop node: NodeObj; // 绑定节点数据
  @Link selectedNodeId: string; // 当前选中的节点ID
  @Link isDoubleClickAndEditing: boolean; //是否修改（双击）
  @Link isStartDrop: boolean;
  @Link dragNodeId: string;

  build() {
    Stack() {
      MindMapNodeComponent({
        model: this.model,
        node: this.node,
        selectedNodeId: this.selectedNodeId,
        isDoubleClickAndEditing: this.isDoubleClickAndEditing,
        isStartDrop: this.isStartDrop,
        dragNodeId: this.dragNodeId
      });
      if (this.node.children) {
        ForEach(this.node.children, (item: NodeObj) => {
          if (item.level! == 1 || (item.level! > 1 && item.parent!.expanded!)) {
            MindMapNode({
              model: this.model,
              node: item,
              selectedNodeId: this.selectedNodeId,
              isDoubleClickAndEditing: this.isDoubleClickAndEditing,
              isStartDrop: this.isStartDrop,
              dragNodeId: this.dragNodeId
            });
          }
        });
      }
    };
  }
}