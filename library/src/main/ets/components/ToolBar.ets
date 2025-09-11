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

import { ZoomUtils } from '../utils/ZoomUtils';
import { MindElixirCore } from '../controller/MindElixirCore';
import { UtilsManager } from '../utils/UtilsManager';


interface MenuItem {
  image: Resource,
  action: () => void,
  angle?: number
}

@Component
export default struct MenuBar {
  @Link model: MindElixirCore;
  private zoomCtrl: ZoomUtils = UtilsManager.getZoomUtils(this.model.getInstanceId())!;
  // 定义菜单项数据
  private menuItems: Array<MenuItem> = [
    {
      image: $r("app.media.location"),
      action: () => {
        this.model.resetPosition();
      }
    },
    {
      image: $r("app.media.reduce"),
      action: () => {
        this.zoomCtrl.zoomOut();
      }
    },
    {
      image: $r("app.media.add"),
      action: () => {
        this.zoomCtrl.zoomIn();
      }
    },
    {
      image: $r("app.media.left"),
      action: () => {
        this.model.setMindDirection(0);
      },
      angle: 0
    },
    {
      image: $r("app.media.left"),
      action: () => {
        this.model.setMindDirection(1);
      },
      angle: 180
    },
    {
      image: $r("app.media.left"),
      action: () => {
        this.model.setMindDirection(2);
      },
      angle: 90
    },
    {
      image: $r("app.media.left"),
      action: () => {
        this.model.setMindDirection(3);
      },
      angle: 270
    }
  ];

  build() {
    Row() {
      ForEach(this.menuItems, (item: MenuItem, index: number) => {
        Image(item.image)
          .height(30)
          .width(30)
          .rotate({ angle: item.angle ?? 0 })
          .onClick(item.action)
          .margin({ left: index === 0 ? 0 : 10 });
      });
    }
    .height(50)
    .justifyContent(FlexAlign.SpaceAround)
    .position({ bottom: 50, right: 50 })
    .border({ width: 2, color: '#ffa09f9f' })
    .backgroundColor('#fff')
    .padding(10);
  }
}