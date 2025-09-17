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
import { CanvasPosition, CanvasSize, NodeObj, Arrow, NodeOption } from '../model/NodeObj';
import MindMapNode from './MindMapNode';
import MindMapLines from './MindMapLines';
import { MindMapEventEmitter } from '../controller/MindMapEvents';
import { ZoomUtils } from '../utils/ZoomUtils';
import { CanvasPositionUtils } from '../utils/CanvasPositionUtils';
import { NodeHelper } from '../controller/NodeHelper';
import { ShortcutManager } from '../controller/ShortcutManager';
import { UtilsManager } from '../utils/UtilsManager';
import { MindArrowLabel } from './MindArrowLabel';

@Entry
@Component
export default struct MindMapPage {
  @Link model: MindElixirCore;
  @State rootNode: NodeObj | null = null;
  @State arrows: Arrow[] = [];
  @State selectedNodeId: string = '';
  @State flatNodes: NodeObj[] = [];
  private panOption: PanGestureOptions = new PanGestureOptions({ direction: PanDirection.All });
  private positionCtrl: CanvasPositionUtils = UtilsManager.getPositionUtils(this.model.getInstanceId())!;
  private zoomCtrl: ZoomUtils = UtilsManager.getZoomUtils(this.model.getInstanceId())!;
  private nodeHelper: NodeHelper = UtilsManager.getNodeHelper(this.model.getInstanceId())!;
  private shortcutManager: ShortcutManager = UtilsManager.getShortcutManager(this.model.getInstanceId())!;
  private options: NodeOption | null = null;
  @State isDoubleClickAndEditing: boolean = false;
  @State canvasSize: CanvasSize | null = null;
  @State canvasRefreshFlag: boolean = false;
  @State zoomScale: number = 1;
  @State arrowLabelEdit: boolean = false;
  @State dragNodeId: string = '';
  @State isStartDrop: boolean = false;
  @State canvasPosition: CanvasPosition = {
    offsetX: 0,
    offsetY: 0,
    positionX: 0,
    positionY: 0
  };
  @State initialZoomScale: number = 1;

  aboutToAppear() {
    this.initializeMind();
  }

  aboutToDisappear(): void {
    this.model.destroy();
  }

  private initializeMind() {
    this.rootNode = this.nodeHelper.getTreeNodeData();
    this.flatNodes = this.nodeHelper.getFlatNodes();
    this.arrows = this.nodeHelper.getArrowsData();
    this.options = this.model.getMindOptions();
    this.initCanvasSize();

    MindMapEventEmitter.onNodeUpdated(() => {
      this.rootNode = this.nodeHelper.getTreeNodeData();
      this.flatNodes = this.nodeHelper.getFlatNodes();
      this.arrows = this.nodeHelper.getArrowsData();
    });

    MindMapEventEmitter.onCanvasUpdated(() => {
      this.initCanvasSize();
      this.canvasRefreshFlag = !this.canvasRefreshFlag;
    });

    this.zoomCtrl.setOnScaleChange((scale: number) => {
      this.zoomScale = scale;
    });

    this.positionCtrl.setOnPositionChange((position: CanvasPosition) => {
      this.canvasPosition = position;
    });
  }

  initCanvasSize() {
    this.canvasSize = this.nodeHelper.getCanvasSize();
  }

  build() {
    Column() {
      Stack() {
        // 1. Canvas 绘制连接线
        MindMapLines({
          model: this.model,
          canvasRefreshFlag: this.canvasRefreshFlag,
          canvasSize: this.canvasSize
        });

        Column() {
          // 2. 渲染思维导图节点
          if (this.rootNode) {
            MindMapNode({
              model: this.model,
              node: this.rootNode,
              selectedNodeId: this.selectedNodeId,
              isDoubleClickAndEditing: this.isDoubleClickAndEditing,
              isStartDrop: this.isStartDrop,
              dragNodeId: this.dragNodeId
            })
              .width('100%')
              .height('100%');

            // 3. 渲染箭头标签
            ForEach(this.arrows, (item: Arrow) => {
              MindArrowLabel({
                model: this.model,
                arrowData: item,
                selectedNodeId: this.selectedNodeId,
                arrowLabelEdit: this.arrowLabelEdit
              });
            });
          }
        }
        .focusable(true)
        .focusOnTouch(true)
        .onKeyEvent((event: KeyEvent) => {
          this.shortcutManager!.handleKeyEvent(event);
        });
      }
      .width(this.canvasSize?.width)
      .height(this.canvasSize?.height)
      .position({ x: this.canvasPosition.offsetX, y: this.canvasPosition.offsetY })
      .scale({ x: this.zoomScale, y: this.zoomScale });
    }
    .onClick(() => {
      this.selectedNodeId = '';
      this.isDoubleClickAndEditing = false;
      this.arrowLabelEdit = false;
      this.model.selectNode("");
    })
    .width('100%')
    .height('100%')
    .onAreaChange((old, newValue) => {
      this.positionCtrl.setContainerSize(Number(newValue.width), Number(newValue.height));
      if (this.options?.mindInViewport) {
        this.positionCtrl.adjustZoomToFitContainer();
      }
    })
    .gesture(
      GestureGroup(GestureMode.Parallel,
        PanGesture(this.panOption)
          .onActionStart(() => {
            this.positionCtrl.saveCurrentPosition();
          })
          .onActionUpdate((event: GestureEvent) => {
            if (event) {
              const currentPosition = this.positionCtrl.getPosition();
              const speedFactor = Math.max(0.3, Math.min(1.5, 1 / this.zoomScale));
              const newOffsetX = currentPosition.positionX + event.offsetX * speedFactor;
              const newOffsetY = currentPosition.positionY + event.offsetY * speedFactor;
              this.positionCtrl.updatePosition(newOffsetX, newOffsetY);
            }
          })
          .onActionEnd(() => {
            this.positionCtrl.saveCurrentPosition();
          }),
        PinchGesture({ fingers: 2 })
          .onActionStart(() => {
            this.initialZoomScale = this.zoomScale;
          })
          .onActionUpdate((event: GestureEvent) => {
            if (event && event.scale) {
              let newScale = this.initialZoomScale * event.scale;
              newScale = Math.max(0.1, Math.min(5, newScale));
              this.zoomCtrl.setScale(newScale);
            }
          }))
    );
  }
}