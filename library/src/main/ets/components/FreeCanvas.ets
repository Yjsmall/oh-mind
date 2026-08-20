import { KeyCode } from '@kit.InputKit';
import {
  CanvasDocument,
  CanvasTextNode,
  CanvasViewport,
  cloneCanvasDocument,
  resolveCanvasEdgeToEnd
} from '../model/CanvasModel';
import { serializeCanvasJson } from '../codec/CanvasJsonCodec';
import {
  CanvasNodePosition,
  CanvasPoint,
  CanvasRect,
  CanvasResizeHandle,
  fitCanvasViewport,
  getCanvasNodeAnchor,
  moveCanvasNodes,
  normalizeCanvasRect,
  panCanvasViewport,
  replaceCanvasNode,
  resizeCanvasNode,
  resolveCanvasViewport,
  screenToWorld,
  selectNodesInCanvasRect,
  setDocumentCanvasViewport,
  worldToScreen,
  zoomCanvasViewportAt
} from '../geometry/FreeCanvasGeometry';
import {
  FreeCanvasController,
  FreeCanvasControllerBinding,
  FreeCanvasInteractionMode
} from '../controller/FreeCanvasController';

const RESIZE_HANDLE_SIZE: number = 12;
const RESIZE_HANDLE_HALF: number = RESIZE_HANDLE_SIZE / 2;
const NODE_CORNER_RADIUS: number = 6;
const DEFAULT_NODE_BACKGROUND: string = '#FFFFFFFF';
const DEFAULT_NODE_BORDER: string = '#FFD7DCE2';
const SELECTED_NODE_BORDER: string = '#FF146C94';
const EDGE_COLOR: string = '#FF68717D';
const MARQUEE_FILL: string = '#18146C94';
const MARQUEE_BORDER: string = '#FF146C94';
const EMPTY_DOCUMENT: CanvasDocument = { nodes: [], edges: [] };

export type FreeCanvasChangeReason = 'viewport' | 'nodeMove' | 'nodeResize' | 'keyboardNudge';

export interface FreeCanvasChangeEvent {
  readonly reason: FreeCanvasChangeReason;
  readonly document: CanvasDocument;
  readonly selectedNodeIds: ReadonlyArray<string>;
}

class DefaultFreeCanvasNodeContext {
}

@Builder
function DefaultFreeCanvasNode(node: CanvasTextNode, _context: Object) {
  Text(node.text)
    .width('100%')
    .height('100%')
    .padding(12)
    .fontSize(14)
    .fontColor('#FF20252B')
    .textAlign(TextAlign.Start)
    .maxLines(100)
    .textOverflow({ overflow: TextOverflow.Ellipsis })
}

const DEFAULT_NODE_BUILDER: WrappedBuilder<[CanvasTextNode, Object]> = wrapBuilder(DefaultFreeCanvasNode);

function nodeBackground(color: string | undefined): string {
  switch (color) {
    case '1':
      return '#FFFFE4E6';
    case '2':
      return '#FFFFEDD5';
    case '3':
      return '#FFFEF9C3';
    case '4':
      return '#FFDCFCE7';
    case '5':
      return '#FFE0F2FE';
    case '6':
      return '#FFEDE9FE';
    default:
      return color ?? DEFAULT_NODE_BACKGROUND;
  }
}

@ComponentV2
export struct FreeCanvas {
  @Require @Param document: CanvasDocument = EMPTY_DOCUMENT;
  @Param controller: FreeCanvasController = new FreeCanvasController();
  @Param nodeContentBuilder: WrappedBuilder<[CanvasTextNode, Object]> = DEFAULT_NODE_BUILDER;
  @Param nodeContentContext: Object = new DefaultFreeCanvasNodeContext();
  @Event onChangeComplete: (event: FreeCanvasChangeEvent) => void = (): void => {
  };

  @Local private draftDocument: CanvasDocument = EMPTY_DOCUMENT;
  @Local private selectedNodeIds: string[] = [];
  @Local private primaryNodeId: string = '';
  @Local private interactionMode: FreeCanvasInteractionMode = 'select';
  @Local private marqueeRect: CanvasRect | undefined = undefined;
  @Local private renderRevision: number = 0;
  @Local private containerWidth: number = 0;
  @Local private containerHeight: number = 0;

  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private inputSnapshotJson: string = '';
  private panStartViewport: CanvasViewport = { x: 0, y: 0, scale: 1 };
  private pinchStartViewport: CanvasViewport = { x: 0, y: 0, scale: 1 };
  private marqueeStart: CanvasPoint = { x: 0, y: 0 };
  private dragStartPositions: CanvasNodePosition[] = [];
  private resizeStartNode: CanvasTextNode | undefined = undefined;
  private axisChanged: boolean = false;
  private readonly controllerBinding: FreeCanvasControllerBinding = {
    fitContent: (): void => this.fitContent(),
    resetViewport: (): void => this.resetViewport(),
    setInteractionMode: (mode: FreeCanvasInteractionMode): void => this.setInteractionMode(mode),
    clearSelection: (): void => this.clearSelection()
  };

  aboutToAppear(): void {
    this.acceptInputDocument();
    this.controller.bind(this.controllerBinding);
  }

  aboutToDisappear(): void {
    this.controller.unbind(this.controllerBinding);
  }

  @Monitor('document')
  private onDocumentChanged(): void {
    this.acceptInputDocument();
  }

  @Monitor('renderRevision')
  private onRenderRevisionChanged(): void {
    this.drawEdges();
  }

  private acceptInputDocument(): void {
    const json = serializeCanvasJson(this.document);
    if (json === this.inputSnapshotJson) {
      return;
    }
    this.inputSnapshotJson = json;
    this.draftDocument = cloneCanvasDocument(this.document);
    this.selectedNodeIds = this.selectedNodeIds.filter((nodeId: string): boolean =>
      this.draftDocument.nodes.some((node: CanvasTextNode): boolean => node.id === nodeId));
    if (!this.selectedNodeIds.includes(this.primaryNodeId)) {
      this.primaryNodeId = this.selectedNodeIds.length === 0 ? '' : this.selectedNodeIds[0];
    }
    this.refresh();
  }

  private refresh(): void {
    this.renderRevision++;
    this.drawEdges();
  }

  private viewport(): CanvasViewport {
    return resolveCanvasViewport(this.draftDocument);
  }

  private updateViewport(viewport: CanvasViewport): void {
    this.draftDocument = setDocumentCanvasViewport(this.draftDocument, viewport);
    this.refresh();
  }

  private fitContent(): void {
    const viewport = fitCanvasViewport(this.draftDocument.nodes, {
      width: this.containerWidth,
      height: this.containerHeight
    });
    this.updateViewport(viewport);
    this.emitChange('viewport');
  }

  private resetViewport(): void {
    this.updateViewport({ x: 0, y: 0, scale: 1 });
    this.emitChange('viewport');
  }

  private setInteractionMode(mode: FreeCanvasInteractionMode): void {
    this.interactionMode = mode;
    this.marqueeRect = undefined;
  }

  private clearSelection(): void {
    this.selectedNodeIds = [];
    this.primaryNodeId = '';
  }

  private emitChange(reason: FreeCanvasChangeReason): void {
    this.inputSnapshotJson = serializeCanvasJson(this.draftDocument);
    this.onChangeComplete({
      reason,
      document: cloneCanvasDocument(this.draftDocument),
      selectedNodeIds: this.selectedNodeIds.slice()
    });
  }

  private selectNode(nodeId: string, event: ClickEvent): void {
    const toggle = event.getModifierKeyState?.(['Ctrl']) === true ||
      event.getModifierKeyState?.(['Shift']) === true;
    if (toggle) {
      if (this.selectedNodeIds.includes(nodeId)) {
        this.selectedNodeIds = this.selectedNodeIds.filter((id: string): boolean => id !== nodeId);
        if (this.primaryNodeId === nodeId) {
          this.primaryNodeId = this.selectedNodeIds.length === 0 ? '' : this.selectedNodeIds[0];
        }
      } else {
        this.selectedNodeIds = this.selectedNodeIds.concat([nodeId]);
        this.primaryNodeId = nodeId;
      }
      return;
    }
    this.selectedNodeIds = [nodeId];
    this.primaryNodeId = nodeId;
  }

  private prepareNodeDrag(nodeId: string): void {
    if (!this.selectedNodeIds.includes(nodeId)) {
      this.selectedNodeIds = [nodeId];
      this.primaryNodeId = nodeId;
    }
    this.dragStartPositions = this.draftDocument.nodes
      .filter((node: CanvasTextNode): boolean => this.selectedNodeIds.includes(node.id))
      .map((node: CanvasTextNode): CanvasNodePosition => ({ id: node.id, x: node.x, y: node.y }));
  }

  private updateNodeDrag(event: GestureEvent): void {
    const scale = this.viewport().scale;
    this.draftDocument = moveCanvasNodes(this.draftDocument, this.dragStartPositions, {
      x: event.offsetX / scale,
      y: event.offsetY / scale
    });
    this.refresh();
  }

  private endNodeDrag(): void {
    if (this.dragStartPositions.length === 0) {
      return;
    }
    this.dragStartPositions = [];
    this.emitChange('nodeMove');
  }

  private cancelNodeDrag(): void {
    if (this.dragStartPositions.length === 0) {
      return;
    }
    this.draftDocument = moveCanvasNodes(this.draftDocument, this.dragStartPositions, { x: 0, y: 0 });
    this.dragStartPositions = [];
    this.refresh();
  }

  private beginResize(node: CanvasTextNode): void {
    this.resizeStartNode = node;
  }

  private updateResize(handle: CanvasResizeHandle, event: GestureEvent): void {
    if (this.resizeStartNode === undefined) {
      return;
    }
    const scale = this.viewport().scale;
    const resized = resizeCanvasNode(this.resizeStartNode, handle, {
      x: event.offsetX / scale,
      y: event.offsetY / scale
    });
    this.draftDocument = replaceCanvasNode(this.draftDocument, resized);
    this.refresh();
  }

  private endResize(): void {
    if (this.resizeStartNode === undefined) {
      return;
    }
    this.resizeStartNode = undefined;
    this.emitChange('nodeResize');
  }

  private cancelResize(): void {
    if (this.resizeStartNode === undefined) {
      return;
    }
    this.draftDocument = replaceCanvasNode(this.draftDocument, this.resizeStartNode);
    this.resizeStartNode = undefined;
    this.refresh();
  }

  private beginBackgroundPan(event: GestureEvent): void {
    this.panStartViewport = this.viewport();
    if (this.interactionMode === 'select') {
      this.marqueeStart = screenToWorld({ x: event.fingerList[0].localX, y: event.fingerList[0].localY },
        this.panStartViewport);
      this.marqueeRect = { x: this.marqueeStart.x, y: this.marqueeStart.y, width: 0, height: 0 };
    }
  }

  private updateBackgroundPan(event: GestureEvent): void {
    if (this.interactionMode === 'pan') {
      this.updateViewport(panCanvasViewport(this.panStartViewport, event.offsetX, event.offsetY));
      return;
    }
    const current = screenToWorld({
      x: event.fingerList[0].localX,
      y: event.fingerList[0].localY
    }, this.panStartViewport);
    this.marqueeRect = normalizeCanvasRect(this.marqueeStart, current);
    this.selectedNodeIds = selectNodesInCanvasRect(this.draftDocument.nodes, this.marqueeRect);
    this.primaryNodeId = this.selectedNodeIds.length === 0 ? '' : this.selectedNodeIds[this.selectedNodeIds.length - 1];
  }

  private endBackgroundPan(): void {
    if (this.interactionMode === 'pan') {
      this.emitChange('viewport');
    }
    this.marqueeRect = undefined;
  }

  private cancelBackgroundPan(): void {
    if (this.interactionMode === 'pan') {
      this.updateViewport(this.panStartViewport);
    }
    this.marqueeRect = undefined;
  }

  private beginPinch(): void {
    this.pinchStartViewport = this.viewport();
  }

  private updatePinch(event: GestureEvent): void {
    this.updateViewport(zoomCanvasViewportAt(this.pinchStartViewport, {
      x: event.pinchCenterX,
      y: event.pinchCenterY
    }, this.pinchStartViewport.scale * event.scale));
  }

  private endPinch(): void {
    this.emitChange('viewport');
  }

  private cancelPinch(): void {
    this.updateViewport(this.pinchStartViewport);
  }

  private handleAxis(event: AxisEvent): void {
    if (event.action === AxisAction.BEGIN) {
      this.axisChanged = false;
      return;
    }
    if (event.action === AxisAction.UPDATE) {
      const viewport = this.viewport();
      const vertical = event.getVerticalAxisValue();
      if (vertical === 0) {
        return;
      }
      const factor: number = vertical > 0 ? 0.9 : 1.1;
      this.updateViewport(zoomCanvasViewportAt(viewport, { x: event.x, y: event.y }, viewport.scale * factor));
      this.axisChanged = true;
      return;
    }
    if (event.action === AxisAction.END && this.axisChanged) {
      this.axisChanged = false;
      this.emitChange('viewport');
    }
  }

  private handleKey(event: KeyEvent): boolean {
    if (event.type !== KeyType.Down || this.selectedNodeIds.length === 0) {
      return false;
    }
    let deltaX = 0;
    let deltaY = 0;
    const distance: number = event.getModifierKeyState?.(['Shift']) === true ? 10 : 1;
    switch (event.keyCode) {
      case KeyCode.KEYCODE_DPAD_LEFT:
        deltaX = -distance;
        break;
      case KeyCode.KEYCODE_DPAD_RIGHT:
        deltaX = distance;
        break;
      case KeyCode.KEYCODE_DPAD_UP:
        deltaY = -distance;
        break;
      case KeyCode.KEYCODE_DPAD_DOWN:
        deltaY = distance;
        break;
      default:
        return false;
    }
    const positions = this.draftDocument.nodes
      .filter((node: CanvasTextNode): boolean => this.selectedNodeIds.includes(node.id))
      .map((node: CanvasTextNode): CanvasNodePosition => ({ id: node.id, x: node.x, y: node.y }));
    this.draftDocument = moveCanvasNodes(this.draftDocument, positions, { x: deltaX, y: deltaY });
    this.refresh();
    this.emitChange('keyboardNudge');
    return true;
  }

  private findNode(nodeId: string): CanvasTextNode | undefined {
    return this.draftDocument.nodes.find((node: CanvasTextNode): boolean => node.id === nodeId);
  }

  private nodeScreenRect(node: CanvasTextNode): CanvasRect {
    const viewport = this.viewport();
    const origin = worldToScreen({ x: node.x, y: node.y }, viewport);
    return {
      x: origin.x,
      y: origin.y,
      width: node.width * viewport.scale,
      height: node.height * viewport.scale
    };
  }

  private handleScreenPoint(node: CanvasTextNode, handle: CanvasResizeHandle): CanvasPoint {
    const rect = this.nodeScreenRect(node);
    let x = rect.x + rect.width / 2;
    let y = rect.y + rect.height / 2;
    if (handle.includes('w')) {
      x = rect.x;
    } else if (handle.includes('e')) {
      x = rect.x + rect.width;
    }
    if (handle.includes('n')) {
      y = rect.y;
    } else if (handle.includes('s')) {
      y = rect.y + rect.height;
    }
    return { x, y };
  }

  private drawEdges(): void {
    if (this.containerWidth <= 0 || this.containerHeight <= 0) {
      return;
    }
    const viewport = this.viewport();
    this.context.clearRect(0, 0, this.containerWidth, this.containerHeight);
    this.context.lineWidth = 1.5;
    this.context.strokeStyle = EDGE_COLOR;
    this.context.fillStyle = EDGE_COLOR;
    this.context.font = '12vp sans-serif';
    for (let index = 0; index < this.draftDocument.edges.length; index++) {
      const edge = this.draftDocument.edges[index];
      const fromNode = this.findNode(edge.fromNode);
      const toNode = this.findNode(edge.toNode);
      if (fromNode === undefined || toNode === undefined) {
        continue;
      }
      const from = worldToScreen(getCanvasNodeAnchor(fromNode, edge.fromSide, toNode), viewport);
      const to = worldToScreen(getCanvasNodeAnchor(toNode, edge.toSide, fromNode), viewport);
      this.context.beginPath();
      this.context.moveTo(from.x, from.y);
      this.context.lineTo(to.x, to.y);
      this.context.stroke();
      if (resolveCanvasEdgeToEnd(edge) === 'arrow') {
        this.drawArrowHead(from, to);
      }
      if (edge.label !== undefined && edge.label.length > 0) {
        this.context.fillText(edge.label, (from.x + to.x) / 2 + 6, (from.y + to.y) / 2 - 6);
      }
    }
  }

  private drawArrowHead(from: CanvasPoint, to: CanvasPoint): void {
    const angle = Math.atan2(to.y - from.y, to.x - from.x);
    const size = 9;
    this.context.beginPath();
    this.context.moveTo(to.x, to.y);
    this.context.lineTo(to.x - size * Math.cos(angle - Math.PI / 6),
      to.y - size * Math.sin(angle - Math.PI / 6));
    this.context.lineTo(to.x - size * Math.cos(angle + Math.PI / 6),
      to.y - size * Math.sin(angle + Math.PI / 6));
    this.context.closePath();
    this.context.fill();
  }

  @Builder
  private NodeCard(node: CanvasTextNode) {
    Stack({ alignContent: Alignment.TopStart }) {
      this.nodeContentBuilder.builder(node, this.nodeContentContext)
    }
    .width(node.width)
    .height(node.height)
    .id('free-canvas-node-' + node.id)
    .backgroundColor(nodeBackground(node.color))
    .border({
      width: this.selectedNodeIds.includes(node.id) ? 2 : 1,
      color: this.selectedNodeIds.includes(node.id) ? SELECTED_NODE_BORDER : DEFAULT_NODE_BORDER,
      radius: NODE_CORNER_RADIUS
    })
    .shadow({ radius: 8, color: '#18000000', offsetX: 0, offsetY: 2 })
    .clip(true)
    .position({
      x: this.viewport().x + node.x * this.viewport().scale,
      y: this.viewport().y + node.y * this.viewport().scale
    })
    .scale({ x: this.viewport().scale, y: this.viewport().scale, centerX: 0, centerY: 0 })
    .onClick((event: ClickEvent): void => this.selectNode(node.id, event))
    .gesture(
      PanGesture({ fingers: 1, direction: PanDirection.All, distance: 1 })
        .onActionStart((): void => this.prepareNodeDrag(node.id))
        .onActionUpdate((event: GestureEvent): void => this.updateNodeDrag(event))
        .onActionEnd((): void => this.endNodeDrag())
        .onActionCancel((): void => this.cancelNodeDrag())
    )
  }

  @Builder
  private ResizeHandle(node: CanvasTextNode, handle: CanvasResizeHandle) {
    Rect()
      .width(RESIZE_HANDLE_SIZE)
      .height(RESIZE_HANDLE_SIZE)
      .id('free-canvas-resize-' + handle)
      .radius(2)
      .fill('#FFFFFFFF')
      .stroke(SELECTED_NODE_BORDER)
      .strokeWidth(2)
      .position({
        x: this.handleScreenPoint(node, handle).x - RESIZE_HANDLE_HALF,
        y: this.handleScreenPoint(node, handle).y - RESIZE_HANDLE_HALF
      })
      .gesture(
        PanGesture({ fingers: 1, direction: PanDirection.All, distance: 0 })
          .onActionStart((): void => this.beginResize(node))
          .onActionUpdate((event: GestureEvent): void => this.updateResize(handle, event))
          .onActionEnd((): void => this.endResize())
          .onActionCancel((): void => this.cancelResize())
      )
  }

  @Builder
  private PrimaryResizeHandles() {
    if (this.primaryNodeId.length > 0) {
      if (this.findNode(this.primaryNodeId) !== undefined) {
        this.ResizeHandle(this.findNode(this.primaryNodeId)!, 'nw')
        this.ResizeHandle(this.findNode(this.primaryNodeId)!, 'n')
        this.ResizeHandle(this.findNode(this.primaryNodeId)!, 'ne')
        this.ResizeHandle(this.findNode(this.primaryNodeId)!, 'e')
        this.ResizeHandle(this.findNode(this.primaryNodeId)!, 'se')
        this.ResizeHandle(this.findNode(this.primaryNodeId)!, 's')
        this.ResizeHandle(this.findNode(this.primaryNodeId)!, 'sw')
        this.ResizeHandle(this.findNode(this.primaryNodeId)!, 'w')
      }
    }
  }

  @Builder
  private Marquee() {
    if (this.marqueeRect !== undefined) {
      Rect()
        .width(this.marqueeRect.width * this.viewport().scale)
        .height(this.marqueeRect.height * this.viewport().scale)
        .fill(MARQUEE_FILL)
        .stroke(MARQUEE_BORDER)
        .strokeWidth(1)
        .position(worldToScreen({ x: this.marqueeRect.x, y: this.marqueeRect.y }, this.viewport()))
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Canvas(this.context)
        .width('100%')
        .height('100%')
        .hitTestBehavior(HitTestMode.None)
        .onReady((): void => this.drawEdges())

      ForEach(this.draftDocument.nodes.slice(), (node: CanvasTextNode) => {
        this.NodeCard(node)
      }, (node: CanvasTextNode): string => node.id)

      this.PrimaryResizeHandles()
      this.Marquee()
    }
    .width('100%')
    .height('100%')
    .id('free-canvas')
    .clip(true)
    .backgroundColor('#FFF5F7F9')
    .focusable(true)
    .focusOnTouch(true)
    .onClick((): void => this.clearSelection())
    .onKeyEvent((event: KeyEvent): boolean => this.handleKey(event))
    .onAxisEvent((event?: AxisEvent): void => {
      if (event !== undefined) {
        this.handleAxis(event);
      }
    })
    .onAreaChange((_oldArea: Area, newArea: Area): void => {
      this.containerWidth = Number(newArea.width);
      this.containerHeight = Number(newArea.height);
      this.refresh();
    })
    .gesture(
      GestureGroup(
        GestureMode.Parallel,
        PanGesture({ fingers: 1, direction: PanDirection.All, distance: 1 })
          .onActionStart((event: GestureEvent): void => this.beginBackgroundPan(event))
          .onActionUpdate((event: GestureEvent): void => this.updateBackgroundPan(event))
          .onActionEnd((): void => this.endBackgroundPan())
          .onActionCancel((): void => this.cancelBackgroundPan()),
        PinchGesture({ fingers: 2, distance: 2 })
          .onActionStart((): void => this.beginPinch())
          .onActionUpdate((event: GestureEvent): void => this.updatePinch(event))
          .onActionEnd((): void => this.endPinch())
          .onActionCancel((): void => this.cancelPinch())
      )
    )
  }
}
