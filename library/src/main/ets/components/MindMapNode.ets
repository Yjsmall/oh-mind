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

@ComponentV2
export default struct MindMapNode {
  @Require @Param model: MindElixirCore;
  @Require @Param node: NodeObj;
  @Param selectedNodeId: string = '';
  @Param isDoubleClickAndEditing: boolean = false;
  @Param isStartDrop: boolean = false;
  @Param dragNodeId: string = '';
  @Param renderVersion: number = 0;
  @Event onNodeSelectionChange: (nodeId: string) => void = () => {
  };
  @Event onNodeEditingChange: (isEditing: boolean) => void = () => {
  };
  @Event onDragStateChange: (isDragging: boolean, dragNodeId: string) => void = () => {
  };

  build() {
    Stack() {
      MindMapNodeComponent({
        model: this.model,
        node: this.node,
        selectedNodeId: this.selectedNodeId,
        isDoubleClickAndEditing: this.isDoubleClickAndEditing,
        isStartDrop: this.isStartDrop,
        dragNodeId: this.dragNodeId,
        renderVersion: this.renderVersion,
        onNodeSelectionChange: (nodeId: string) => this.onNodeSelectionChange(nodeId),
        onNodeEditingChange: (isEditing: boolean) => this.onNodeEditingChange(isEditing),
        onDragStateChange: (isDragging: boolean, dragNodeId: string) =>
          this.onDragStateChange(isDragging, dragNodeId)
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
              dragNodeId: this.dragNodeId,
              renderVersion: this.renderVersion,
              onNodeSelectionChange: (nodeId: string) => this.onNodeSelectionChange(nodeId),
              onNodeEditingChange: (isEditing: boolean) => this.onNodeEditingChange(isEditing),
              onDragStateChange: (isDragging: boolean, dragNodeId: string) =>
                this.onDragStateChange(isDragging, dragNodeId)
            });
          }
        }, (item: NodeObj) => item.id);
      }
    };
  }
}
