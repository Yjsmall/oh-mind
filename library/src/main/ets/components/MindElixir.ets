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

import MindMapPage from './MindMapPage';
import MenuBar from './ToolBar';
import TagsPopup from '../components/TagsPopup';
import { PopupEventsUtils } from '../utils/PopupUtils';
import { GlobalContext } from '../utils/GlobalContext';
import { WindowManager } from '../utils/WindowManager';
import { MindElixirCore } from '../controller/MindElixirCore';
import { MindElixirData } from '../model/NodeObj';

@Entry
@Component
export default struct MindElixir {
  @Link model: MindElixirCore;
  @Prop data: MindElixirData;
  @State isShowTagsPopup: boolean = false;
  @State showMenu: boolean = true;

  aboutToAppear(): void {
    GlobalContext.getInstance().setUiContext(this.getUIContext());
    WindowManager.initialize();
    this.model.init(this.data);
    const options = this.model.getMindOptions();
    this.showMenu = !!options.toolBar;

    const popEvent = PopupEventsUtils.getInstance();
    popEvent.setOnPopupStatusChange((status: boolean) => {
      this.isShowTagsPopup = status;
    });
  }

  build() {
    Column() {
      Scroll() {
        MindMapPage({ model: this.model });
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.White);

      if (this.isShowTagsPopup) {
        TagsPopup({ model: this.model });
      }

      if (this.showMenu) {
        MenuBar({ model: this.model });
      }

    }
    .width('100%')
    .height('100%');
  }
}