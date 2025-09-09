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

import { NodeObj, CanvasSize } from '../model/NodeObj';
import { MindLineRender } from '../controller/MindLineRender';
import { MindElixirCore } from '../controller/MindElixirCore';
import { MindMapEventEmitter } from '../controller/MindMapEvents';

@Component
export default struct MindMapLines {
  @Link model: MindElixirCore;
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private canvasContext: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  @Prop canvasSize: CanvasSize | null;
  @Prop canvasRefreshFlag: boolean;

  build() {
    Canvas(this.canvasContext)
      .width(this.canvasSize?.width)
      .height(this.canvasSize?.height)
      .position({ x: 0, y: 0 })
      .onReady(() => {
        MindLineRender.createInstance(this.model.getInstanceId()).init(this.canvasContext!, this.model);
      })
      .key(`canvas_${this.canvasRefreshFlag}`);
  }
}