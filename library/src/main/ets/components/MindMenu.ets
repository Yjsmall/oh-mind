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
import { NodeObj, MoveDirection, MenuOptionItem } from '../model/NodeObj';


@Component
export struct MindMenuItem {
  @Link model: MindElixirCore;
  @Prop currentNode: NodeObj;
  @State menuOptions: MenuOptionItem[] = [
    {
      value: $r('app.string.add_child'),
      level: 0,
      action: () => {
        this.model.add(this.currentNode.id);
      },
      id: 'add_child',
    },
    {
      value: $r('app.string.add_tags'),
      level: 0,
      action: () => {
        PopupEventsUtils.getInstance().open();
      },
      id: 'add_tags',
    },
    {
      value: $r('app.string.add_parent'),
      level: 1,
      action: () => {
        this.model.addParent(this.currentNode.id);
      },
      id: 'add_parent',
    },
    {
      value: $r('app.string.add_sibling'),
      level: 1,
      action: () => {
        this.model.addSibling(this.currentNode.id);
      },
      id: 'add_sibling',
    },
    {
      value: $r('app.string.remove_node'),
      level: 1,
      action: () => {
        this.model.remove(this.currentNode.id);
      },
      id: 'remove_node',
    },
    {
      value: $r('app.string.move_up'),
      level: 1,
      action: () => {
        this.model.move(this.currentNode.id, MoveDirection.UP);
      },
      id: 'move_up',
    },
    {
      value: $r('app.string.move_down'),
      level: 1,
      action: () => {
        this.model.move(this.currentNode.id, MoveDirection.DOWN);
      },
      id: 'move_down',
    },
    {
      value: this.currentNode.expanded ? $r('app.string.fold_node') : $r('app.string.expanded_node'),
      level: 0,
      action: () => {
        this.currentNode.expanded ? this.model.foldNode(this.currentNode.id) :
        this.model.expandedNode(this.currentNode.id);
      },
      id: 'fold_or_expanded',
    },
    {
      value: $r('app.string.link'),
      level: 0,
      action: () => {
        this.model.startLink(this.currentNode.id, true);
      },
      id: 'link',
    },
    {
      value: $r('app.string.bidirectional_link'),
      level: 0,
      action: () => {
        this.model.startLink(this.currentNode.id, true, true);
      },
      id: 'bidirectional_link',
    }
  ];

  @Styles
  MenuItemStyles() {
    .padding({ left: 8 })
    .width(200)
    .height(50)
    .backgroundColor('#fff');
  }

  @Styles
  MenuItemFocused() {
    .width(200)
    .height(50)
    .backgroundColor('#ccc');
  }

  aboutToAppear(): void {
    this.menuOptions = this.menuOptions.filter((item) => {
      if (this.currentNode.level! < 1) {
        return item.level === 0;
      }
      if (item.id === 'fold_or_expanded') {
        return !!this.currentNode?.children?.length;
      }
      return true;
    });
  }

  build() {
    Column() {
      ForEach(this.menuOptions, (item: MenuOptionItem, index: number) => {
        Text(item.value)
          .onClick(() => {
            item.action();
          })
          .fontSize(20)
          .stateStyles({
            normal: this.MenuItemStyles,
            focused: this.MenuItemFocused
          });
        Divider().height(1).visibility(index === this.menuOptions.length - 1 ? Visibility.None : Visibility.Visible);
      });
    };
  }
}