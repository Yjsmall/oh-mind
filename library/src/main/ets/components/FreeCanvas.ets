import { KeyCode } from '@kit.InputKit';
import {
  CanvasDocument,
  CanvasTextNode,
  CanvasEdge,
  CanvasEdgeEnd,
  CanvasSide,
  CanvasViewport,
  cloneCanvasDocument,
  resolveCanvasEdgeFromEnd,
  resolveCanvasEdgeToEnd
} from '../model/CanvasModel';
import { serializeCanvasJson } from '../codec/CanvasJsonCodec';
import { applyCanvasCommand } from '../commands/CanvasCommand';
import { CanvasController } from '../controller/CanvasController';
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
  CanvasAlignment,
  CanvasArrangement,
  CanvasConnectionTarget,
  CanvasDistribution,
  alignCanvasNodes,
  arrangeCanvasNodes,
  autoArrangeCanvasNodes,
  copyCanvasSelection,
  deleteCanvasSelection,
  distributeCanvasNodes,
  findCanvasConnectionTarget,
  findCanvasEdgeAt
} from '../geometry/CanvasEditingGeometry';
import {
  FreeCanvasController,
  FreeCanvasControllerBinding,
  FreeCanvasEdgeDirection,
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
const SELECTED_EDGE_COLOR: string = '#FFB54708';
const CONNECTION_DRAFT_COLOR: string = '#FF146C94';
const ANCHOR_SIZE: number = 14;
const ANCHOR_HALF: number = ANCHOR_SIZE / 2;
const EMPTY_DOCUMENT: CanvasDocument = { nodes: [], edges: [] };

export type FreeCanvasChangeReason =
  'viewport' | 'nodeMove' | 'nodeResize' | 'keyboardNudge' |
  'edgeAdd' | 'edgeUpdate' | 'edgeDelete' | 'edgeReconnect' |
  'copy' | 'delete' | 'align' | 'arrange' | 'distribute' | 'autoArrange' |
  'undo' | 'redo';

export interface FreeCanvasChangeEvent {
  readonly reason: FreeCanvasChangeReason;
  readonly document: CanvasDocument;
  readonly selectedNodeIds: ReadonlyArray<string>;
  readonly selectedEdgeId?: string;
}

interface CanvasConnectionDraft {
  readonly fixedPoint: CanvasPoint;
  readonly startMovingPoint: CanvasPoint;
  readonly movingPoint: CanvasPoint;
  readonly sourceNodeId: string;
  readonly sourceSide: CanvasSide;
  readonly reconnectEdgeId?: string;
  readonly reconnectEnd?: 'from' | 'to';
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

function edgeStroke(color: string | undefined): string {
  switch (color) {
    case '1':
      return '#FFE93147';
    case '2':
      return '#FFEC7500';
    case '3':
      return '#FFB88A00';
    case '4':
      return '#FF0E8A4B';
    case '5':
      return '#FF146C94';
    case '6':
      return '#FF7857B8';
    default:
      return color ?? EDGE_COLOR;
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
  @Local private selectedEdgeId: string = '';
  @Local private edgeLabelDraft: string = '';
  @Local private edgeLabelEditing: boolean = false;
  @Local private interactionMode: FreeCanvasInteractionMode = 'select';
  @Local private marqueeRect: CanvasRect | undefined = undefined;
  @Local private connectionDraft: CanvasConnectionDraft | undefined = undefined;
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
  private nodeDragStartDocument: CanvasDocument | undefined = undefined;
  private resizeStartDocument: CanvasDocument | undefined = undefined;
  private panStartDocument: CanvasDocument | undefined = undefined;
  private pinchStartDocument: CanvasDocument | undefined = undefined;
  private axisStartDocument: CanvasDocument | undefined = undefined;
  private historyController: CanvasController = new CanvasController();
  private copySequence: number = 0;
  private edgeSequence: number = 0;
  private axisChanged: boolean = false;
  private readonly controllerBinding: FreeCanvasControllerBinding = {
    fitContent: (): void => this.fitContent(),
    resetViewport: (): void => this.resetViewport(),
    setInteractionMode: (mode: FreeCanvasInteractionMode): void => this.setInteractionMode(mode),
    clearSelection: (): void => this.clearSelection(),
    canUndo: (): boolean => this.historyController.canUndo(),
    canRedo: (): boolean => this.historyController.canRedo(),
    undo: (): boolean => this.undo(),
    redo: (): boolean => this.redo(),
    copySelection: (): boolean => this.copySelection(),
    deleteSelection: (): boolean => this.deleteSelection(),
    alignSelection: (alignment: CanvasAlignment): boolean => this.alignSelection(alignment),
    arrangeSelection: (arrangement: CanvasArrangement): boolean => this.arrangeSelection(arrangement),
    distributeSelection: (distribution: CanvasDistribution): boolean => this.distributeSelection(distribution),
    autoArrange: (): boolean => this.autoArrange(),
    setSelectedEdgeLabel: (label: string): boolean => this.setSelectedEdgeLabel(label),
    setSelectedEdgeDirection: (direction: FreeCanvasEdgeDirection): boolean =>
      this.setSelectedEdgeDirection(direction)
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
    this.historyController.replaceSnapshot(this.draftDocument);
    this.selectedNodeIds = this.selectedNodeIds.filter((nodeId: string): boolean =>
      this.draftDocument.nodes.some((node: CanvasTextNode): boolean => node.id === nodeId));
    if (!this.selectedNodeIds.includes(this.primaryNodeId)) {
      this.primaryNodeId = this.selectedNodeIds.length === 0 ? '' : this.selectedNodeIds[0];
    }
    if (!this.draftDocument.edges.some((edge: CanvasEdge): boolean => edge.id === this.selectedEdgeId)) {
      this.selectedEdgeId = '';
      this.edgeLabelDraft = '';
    } else {
      this.edgeLabelDraft = this.selectedEdge()?.label ?? '';
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
    this.commitCandidate(setDocumentCanvasViewport(this.draftDocument, viewport), 'viewport');
  }

  private resetViewport(): void {
    this.commitCandidate(setDocumentCanvasViewport(this.draftDocument, { x: 0, y: 0, scale: 1 }), 'viewport');
  }

  private setInteractionMode(mode: FreeCanvasInteractionMode): void {
    this.interactionMode = mode;
    this.marqueeRect = undefined;
    this.connectionDraft = undefined;
  }

  private clearSelection(): void {
    this.selectedNodeIds = [];
    this.primaryNodeId = '';
    this.selectedEdgeId = '';
    this.edgeLabelDraft = '';
    this.edgeLabelEditing = false;
  }

  private emitChange(reason: FreeCanvasChangeReason): void {
    this.inputSnapshotJson = serializeCanvasJson(this.draftDocument);
    this.onChangeComplete({
      reason,
      document: cloneCanvasDocument(this.draftDocument),
      selectedNodeIds: this.selectedNodeIds.slice(),
      selectedEdgeId: this.selectedEdgeId.length === 0 ? undefined : this.selectedEdgeId
    });
  }

  private completeDraft(reason: FreeCanvasChangeReason, before: CanvasDocument | undefined): boolean {
    if (before === undefined || serializeCanvasJson(before) === serializeCanvasJson(this.draftDocument)) {
      return false;
    }
    this.historyController.commitSnapshot(this.draftDocument);
    this.emitChange(reason);
    return true;
  }

  private commitCandidate(candidate: CanvasDocument, reason: FreeCanvasChangeReason): boolean {
    const before = cloneCanvasDocument(this.draftDocument);
    if (serializeCanvasJson(before) === serializeCanvasJson(candidate)) {
      return false;
    }
    this.draftDocument = this.historyController.commitSnapshot(candidate);
    this.refresh();
    this.emitChange(reason);
    return true;
  }

  private filterSelection(): void {
    this.selectedNodeIds = this.selectedNodeIds.filter((nodeId: string): boolean =>
      this.draftDocument.nodes.some((node: CanvasTextNode): boolean => node.id === nodeId));
    if (!this.selectedNodeIds.includes(this.primaryNodeId)) {
      this.primaryNodeId = this.selectedNodeIds.length === 0 ? '' : this.selectedNodeIds[0];
    }
    if (!this.draftDocument.edges.some((edge: CanvasEdge): boolean => edge.id === this.selectedEdgeId)) {
      this.selectedEdgeId = '';
      this.edgeLabelDraft = '';
    } else {
      this.edgeLabelDraft = this.selectedEdge()?.label ?? '';
    }
  }

  private undo(): boolean {
    if (!this.historyController.undo()) {
      return false;
    }
    this.draftDocument = this.historyController.getSnapshot();
    this.filterSelection();
    this.refresh();
    this.emitChange('undo');
    return true;
  }

  private redo(): boolean {
    if (!this.historyController.redo()) {
      return false;
    }
    this.draftDocument = this.historyController.getSnapshot();
    this.filterSelection();
    this.refresh();
    this.emitChange('redo');
    return true;
  }

  private copySelection(): boolean {
    if (this.selectedNodeIds.length === 0) {
      return false;
    }
    let namespace = '';
    do {
      this.copySequence++;
      namespace = 'copy-' + this.copySequence;
    } while (this.draftDocument.nodes.some((node: CanvasTextNode): boolean =>
      this.selectedNodeIds.some((nodeId: string): boolean => node.id === nodeId + '-' + namespace)) ||
      this.draftDocument.edges.some((existingEdge: CanvasEdge): boolean =>
        this.draftDocument.edges.some((selectedEdge: CanvasEdge): boolean =>
          this.selectedNodeIds.includes(selectedEdge.fromNode) && this.selectedNodeIds.includes(selectedEdge.toNode) &&
          existingEdge.id === selectedEdge.id + '-' + namespace)));
    const result = copyCanvasSelection(this.draftDocument, this.selectedNodeIds, namespace);
    const previousSelection = this.selectedNodeIds.slice();
    const previousPrimary = this.primaryNodeId;
    this.selectedNodeIds = result.nodeIds.slice();
    this.primaryNodeId = this.selectedNodeIds[this.selectedNodeIds.length - 1];
    this.selectedEdgeId = '';
    this.edgeLabelDraft = '';
    const changed = this.commitCandidate(result.document, 'copy');
    if (!changed) {
      this.selectedNodeIds = previousSelection;
      this.primaryNodeId = previousPrimary;
    }
    return changed;
  }

  private deleteSelection(): boolean {
    if (this.selectedNodeIds.length === 0 && this.selectedEdgeId.length === 0) {
      return false;
    }
    const reason: FreeCanvasChangeReason = this.selectedNodeIds.length === 0 ? 'edgeDelete' : 'delete';
    const candidate = deleteCanvasSelection(this.draftDocument, this.selectedNodeIds,
      this.selectedEdgeId.length === 0 ? undefined : this.selectedEdgeId);
    const previousSelection = this.selectedNodeIds.slice();
    const previousPrimary = this.primaryNodeId;
    const previousEdge = this.selectedEdgeId;
    this.clearSelection();
    const changed = this.commitCandidate(candidate, reason);
    if (!changed) {
      this.selectedNodeIds = previousSelection;
      this.primaryNodeId = previousPrimary;
      this.selectedEdgeId = previousEdge;
    }
    return changed;
  }

  private alignSelection(alignment: CanvasAlignment): boolean {
    return this.commitCandidate(alignCanvasNodes(this.draftDocument, this.selectedNodeIds, alignment), 'align');
  }

  private arrangeSelection(arrangement: CanvasArrangement): boolean {
    return this.commitCandidate(arrangeCanvasNodes(this.draftDocument, this.selectedNodeIds, arrangement), 'arrange');
  }

  private distributeSelection(distribution: CanvasDistribution): boolean {
    return this.commitCandidate(distributeCanvasNodes(this.draftDocument, this.selectedNodeIds, distribution),
      'distribute');
  }

  private autoArrange(): boolean {
    const nodeIds = this.selectedNodeIds.length === 0 ?
      this.draftDocument.nodes.map((node: CanvasTextNode): string => node.id) : this.selectedNodeIds;
    return this.commitCandidate(autoArrangeCanvasNodes(this.draftDocument, nodeIds), 'autoArrange');
  }

  private selectedEdge(): CanvasEdge | undefined {
    return this.draftDocument.edges.find((edge: CanvasEdge): boolean => edge.id === this.selectedEdgeId);
  }

  private setSelectedEdgeLabel(label: string): boolean {
    const edge = this.selectedEdge();
    if (edge === undefined) {
      return false;
    }
    return this.commitCandidate(applyCanvasCommand(this.draftDocument, {
      kind: 'updateEdge',
      edgeId: edge.id,
      edge: {
        id: edge.id,
        fromNode: edge.fromNode,
        fromSide: edge.fromSide,
        fromEnd: edge.fromEnd,
        toNode: edge.toNode,
        toSide: edge.toSide,
        toEnd: edge.toEnd,
        label: label.length === 0 ? undefined : label,
        color: edge.color
      }
    }), 'edgeUpdate');
  }

  private setSelectedEdgeDirection(direction: FreeCanvasEdgeDirection): boolean {
    const edge = this.selectedEdge();
    if (edge === undefined) {
      return false;
    }
    let fromEnd: CanvasEdgeEnd = 'none';
    let toEnd: CanvasEdgeEnd = 'arrow';
    if (direction === 'reverse') {
      fromEnd = 'arrow';
      toEnd = 'none';
    } else if (direction === 'none') {
      toEnd = 'none';
    } else if (direction === 'both') {
      fromEnd = 'arrow';
    }
    return this.commitCandidate(applyCanvasCommand(this.draftDocument, {
      kind: 'updateEdge',
      edgeId: edge.id,
      edge: {
        id: edge.id,
        fromNode: edge.fromNode,
        fromSide: edge.fromSide,
        fromEnd,
        toNode: edge.toNode,
        toSide: edge.toSide,
        toEnd,
        label: edge.label,
        color: edge.color
      }
    }), 'edgeUpdate');
  }

  private selectNode(nodeId: string, event: ClickEvent): void {
    this.selectedEdgeId = '';
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
    this.nodeDragStartDocument = cloneCanvasDocument(this.draftDocument);
    this.selectedEdgeId = '';
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
    this.completeDraft('nodeMove', this.nodeDragStartDocument);
    this.nodeDragStartDocument = undefined;
  }

  private cancelNodeDrag(): void {
    if (this.dragStartPositions.length === 0) {
      return;
    }
    if (this.nodeDragStartDocument !== undefined) {
      this.draftDocument = this.nodeDragStartDocument;
    }
    this.dragStartPositions = [];
    this.nodeDragStartDocument = undefined;
    this.refresh();
  }

  private beginResize(node: CanvasTextNode): void {
    this.resizeStartNode = node;
    this.resizeStartDocument = cloneCanvasDocument(this.draftDocument);
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
    this.completeDraft('nodeResize', this.resizeStartDocument);
    this.resizeStartDocument = undefined;
  }

  private cancelResize(): void {
    if (this.resizeStartNode === undefined) {
      return;
    }
    if (this.resizeStartDocument !== undefined) {
      this.draftDocument = this.resizeStartDocument;
    }
    this.resizeStartNode = undefined;
    this.resizeStartDocument = undefined;
    this.refresh();
  }

  private beginBackgroundPan(event: GestureEvent): void {
    this.panStartViewport = this.viewport();
    this.panStartDocument = cloneCanvasDocument(this.draftDocument);
    if (this.interactionMode === 'select') {
      this.selectedEdgeId = '';
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
      this.completeDraft('viewport', this.panStartDocument);
    }
    this.panStartDocument = undefined;
    this.marqueeRect = undefined;
  }

  private cancelBackgroundPan(): void {
    if (this.interactionMode === 'pan') {
      if (this.panStartDocument !== undefined) {
        this.draftDocument = this.panStartDocument;
        this.refresh();
      }
    }
    this.panStartDocument = undefined;
    this.marqueeRect = undefined;
  }

  private beginPinch(): void {
    this.pinchStartViewport = this.viewport();
    this.pinchStartDocument = cloneCanvasDocument(this.draftDocument);
  }

  private updatePinch(event: GestureEvent): void {
    this.updateViewport(zoomCanvasViewportAt(this.pinchStartViewport, {
      x: event.pinchCenterX,
      y: event.pinchCenterY
    }, this.pinchStartViewport.scale * event.scale));
  }

  private endPinch(): void {
    this.completeDraft('viewport', this.pinchStartDocument);
    this.pinchStartDocument = undefined;
  }

  private cancelPinch(): void {
    if (this.pinchStartDocument !== undefined) {
      this.draftDocument = this.pinchStartDocument;
      this.pinchStartDocument = undefined;
      this.refresh();
    }
  }

  private handleAxis(event: AxisEvent): void {
    if (event.action === AxisAction.BEGIN) {
      this.axisChanged = false;
      this.axisStartDocument = cloneCanvasDocument(this.draftDocument);
      return;
    }
    if (event.action === AxisAction.UPDATE) {
      if (this.axisStartDocument === undefined) {
        this.axisStartDocument = cloneCanvasDocument(this.draftDocument);
      }
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
      this.completeDraft('viewport', this.axisStartDocument);
      this.axisStartDocument = undefined;
      return;
    }
    if (event.action === AxisAction.CANCEL) {
      if (this.axisStartDocument !== undefined) {
        this.draftDocument = this.axisStartDocument;
        this.refresh();
      }
      this.axisChanged = false;
      this.axisStartDocument = undefined;
    }
  }

  private handleKey(event: KeyEvent): boolean {
    if (event.type !== KeyType.Down || this.edgeLabelEditing) {
      return false;
    }
    const control = event.getModifierKeyState?.(['Ctrl']) === true;
    const shift = event.getModifierKeyState?.(['Shift']) === true;
    if (control && event.keyCode === KeyCode.KEYCODE_Z) {
      return shift ? this.redo() : this.undo();
    }
    if (control && event.keyCode === KeyCode.KEYCODE_Y) {
      return this.redo();
    }
    if (control && event.keyCode === KeyCode.KEYCODE_C) {
      return this.copySelection();
    }
    if (event.keyCode === KeyCode.KEYCODE_DEL || event.keyCode === KeyCode.KEYCODE_FORWARD_DEL) {
      return this.deleteSelection();
    }
    if (this.selectedNodeIds.length === 0) {
      return false;
    }
    let deltaX = 0;
    let deltaY = 0;
    const distance: number = shift ? 10 : 1;
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
    return this.commitCandidate(moveCanvasNodes(this.draftDocument, positions, { x: deltaX, y: deltaY }),
      'keyboardNudge');
  }

  private findNode(nodeId: string): CanvasTextNode | undefined {
    return this.draftDocument.nodes.find((node: CanvasTextNode): boolean => node.id === nodeId);
  }

  private createEdgeId(): string {
    let id = '';
    do {
      this.edgeSequence++;
      id = 'edge-' + this.edgeSequence;
    } while (this.draftDocument.edges.some((edge: CanvasEdge): boolean => edge.id === id));
    return id;
  }

  private edgeAnchorPoint(node: CanvasTextNode, side: CanvasSide): CanvasPoint {
    return worldToScreen(getCanvasNodeAnchor(node, side, node), this.viewport());
  }

  private connectionHandlePoint(node: CanvasTextNode, side: CanvasSide): CanvasPoint {
    const point = this.edgeAnchorPoint(node, side);
    const offset = 20;
    switch (side) {
      case 'top':
        return { x: point.x, y: point.y - offset };
      case 'right':
        return { x: point.x + offset, y: point.y };
      case 'bottom':
        return { x: point.x, y: point.y + offset };
      case 'left':
        return { x: point.x - offset, y: point.y };
    }
  }

  private beginConnection(node: CanvasTextNode, side: CanvasSide): void {
    this.connectionDraft = {
      fixedPoint: this.edgeAnchorPoint(node, side),
      startMovingPoint: this.connectionHandlePoint(node, side),
      movingPoint: this.connectionHandlePoint(node, side),
      sourceNodeId: node.id,
      sourceSide: side
    };
    this.refresh();
  }

  private updateConnection(event: GestureEvent): void {
    if (this.connectionDraft === undefined) {
      return;
    }
    this.connectionDraft = {
      fixedPoint: this.connectionDraft.fixedPoint,
      startMovingPoint: this.connectionDraft.startMovingPoint,
      movingPoint: {
        x: this.connectionDraft.startMovingPoint.x + event.offsetX,
        y: this.connectionDraft.startMovingPoint.y + event.offsetY
      },
      sourceNodeId: this.connectionDraft.sourceNodeId,
      sourceSide: this.connectionDraft.sourceSide,
      reconnectEdgeId: this.connectionDraft.reconnectEdgeId,
      reconnectEnd: this.connectionDraft.reconnectEnd
    };
    this.refresh();
  }

  private endConnection(): void {
    const draft = this.connectionDraft;
    if (draft === undefined) {
      return;
    }
    const target = findCanvasConnectionTarget(this.draftDocument, this.viewport(), draft.movingPoint,
      draft.reconnectEdgeId === undefined ? draft.sourceNodeId : undefined);
    this.connectionDraft = undefined;
    if (target === undefined) {
      this.refresh();
      return;
    }
    if (draft.reconnectEdgeId !== undefined && draft.reconnectEnd !== undefined) {
      this.finishReconnect(draft.reconnectEdgeId, draft.reconnectEnd, target);
      return;
    }
    const edgeId = this.createEdgeId();
    const edge: CanvasEdge = {
      id: edgeId,
      fromNode: draft.sourceNodeId,
      fromSide: draft.sourceSide,
      fromEnd: 'none',
      toNode: target.nodeId,
      toSide: target.side,
      toEnd: 'arrow'
    };
    this.selectedNodeIds = [];
    this.primaryNodeId = '';
    this.selectedEdgeId = edgeId;
    this.edgeLabelDraft = '';
    this.commitCandidate(applyCanvasCommand(this.draftDocument, { kind: 'addEdge', edge }), 'edgeAdd');
  }

  private cancelConnection(): void {
    this.connectionDraft = undefined;
    this.refresh();
  }

  private beginReconnect(edge: CanvasEdge, end: 'from' | 'to'): void {
    const fromNode = this.findNode(edge.fromNode);
    const toNode = this.findNode(edge.toNode);
    if (fromNode === undefined || toNode === undefined) {
      return;
    }
    const from = worldToScreen(getCanvasNodeAnchor(fromNode, edge.fromSide, toNode), this.viewport());
    const to = worldToScreen(getCanvasNodeAnchor(toNode, edge.toSide, fromNode), this.viewport());
    this.connectionDraft = {
      fixedPoint: end === 'from' ? to : from,
      startMovingPoint: end === 'from' ? from : to,
      movingPoint: end === 'from' ? from : to,
      sourceNodeId: end === 'from' ? edge.fromNode : edge.toNode,
      sourceSide: end === 'from' ? edge.fromSide ?? 'right' : edge.toSide ?? 'left',
      reconnectEdgeId: edge.id,
      reconnectEnd: end
    };
    this.refresh();
  }

  private finishReconnect(edgeId: string, end: 'from' | 'to', target: CanvasConnectionTarget): void {
    const edge = this.draftDocument.edges.find((item: CanvasEdge): boolean => item.id === edgeId);
    if (edge === undefined) {
      this.refresh();
      return;
    }
    const replacement: CanvasEdge = {
      id: edge.id,
      fromNode: end === 'from' ? target.nodeId : edge.fromNode,
      fromSide: end === 'from' ? target.side : edge.fromSide,
      fromEnd: edge.fromEnd,
      toNode: end === 'to' ? target.nodeId : edge.toNode,
      toSide: end === 'to' ? target.side : edge.toSide,
      toEnd: edge.toEnd,
      label: edge.label,
      color: edge.color
    };
    const changed = this.commitCandidate(applyCanvasCommand(this.draftDocument, {
      kind: 'updateEdge',
      edgeId,
      edge: replacement
    }), 'edgeReconnect');
    if (!changed) {
      this.refresh();
    }
  }

  private handleBackgroundClick(event: ClickEvent): void {
    if (this.interactionMode !== 'select') {
      return;
    }
    const edge = findCanvasEdgeAt(this.draftDocument, this.viewport(), { x: event.x, y: event.y });
    if (edge === undefined) {
      this.clearSelection();
      return;
    }
    this.selectedNodeIds = [];
    this.primaryNodeId = '';
    this.selectedEdgeId = edge.id;
    this.edgeLabelDraft = edge.label ?? '';
    this.refresh();
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
      const color = edge.id === this.selectedEdgeId ? SELECTED_EDGE_COLOR : edgeStroke(edge.color);
      this.context.strokeStyle = color;
      this.context.fillStyle = color;
      this.context.lineWidth = edge.id === this.selectedEdgeId ? 3 : 1.5;
      this.context.beginPath();
      this.context.moveTo(from.x, from.y);
      this.context.lineTo(to.x, to.y);
      this.context.stroke();
      if (resolveCanvasEdgeToEnd(edge) === 'arrow') {
        this.drawArrowHead(from, to);
      }
      if (resolveCanvasEdgeFromEnd(edge) === 'arrow') {
        this.drawArrowHead(to, from);
      }
      if (edge.label !== undefined && edge.label.length > 0) {
        this.context.fillText(edge.label, (from.x + to.x) / 2 + 6, (from.y + to.y) / 2 - 6);
      }
    }
    if (this.connectionDraft !== undefined) {
      this.context.strokeStyle = CONNECTION_DRAFT_COLOR;
      this.context.fillStyle = CONNECTION_DRAFT_COLOR;
      this.context.lineWidth = 2;
      this.context.beginPath();
      this.context.moveTo(this.connectionDraft.fixedPoint.x, this.connectionDraft.fixedPoint.y);
      this.context.lineTo(this.connectionDraft.movingPoint.x, this.connectionDraft.movingPoint.y);
      this.context.stroke();
      this.drawArrowHead(this.connectionDraft.fixedPoint, this.connectionDraft.movingPoint);
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
  private ConnectionAnchor(node: CanvasTextNode, side: CanvasSide) {
    Circle()
      .width(ANCHOR_SIZE)
      .height(ANCHOR_SIZE)
      .id('free-canvas-anchor-' + side)
      .fill('#FFFFFFFF')
      .stroke(SELECTED_NODE_BORDER)
      .strokeWidth(2)
      .position({
        x: this.connectionHandlePoint(node, side).x - ANCHOR_HALF,
        y: this.connectionHandlePoint(node, side).y - ANCHOR_HALF
      })
      .gesture(
        PanGesture({ fingers: 1, direction: PanDirection.All, distance: 0 })
          .onActionStart((): void => this.beginConnection(node, side))
          .onActionUpdate((event: GestureEvent): void => this.updateConnection(event))
          .onActionEnd((): void => this.endConnection())
          .onActionCancel((): void => this.cancelConnection())
      )
  }

  @Builder
  private PrimaryConnectionAnchors() {
    if (this.interactionMode === 'select' && this.primaryNodeId.length > 0) {
      if (this.findNode(this.primaryNodeId) !== undefined) {
        this.ConnectionAnchor(this.findNode(this.primaryNodeId)!, 'top')
        this.ConnectionAnchor(this.findNode(this.primaryNodeId)!, 'right')
        this.ConnectionAnchor(this.findNode(this.primaryNodeId)!, 'bottom')
        this.ConnectionAnchor(this.findNode(this.primaryNodeId)!, 'left')
      }
    }
  }

  @Builder
  private EdgeEndpointHandle(edge: CanvasEdge, end: 'from' | 'to') {
    if (this.findNode(edge.fromNode) !== undefined && this.findNode(edge.toNode) !== undefined) {
      Circle()
        .width(ANCHOR_SIZE)
        .height(ANCHOR_SIZE)
        .id('free-canvas-edge-' + end)
        .fill('#FFFFFFFF')
        .stroke(SELECTED_EDGE_COLOR)
        .strokeWidth(2)
        .position({
          x: (end === 'from' ?
            worldToScreen(getCanvasNodeAnchor(this.findNode(edge.fromNode)!, edge.fromSide,
              this.findNode(edge.toNode)!), this.viewport()).x :
            worldToScreen(getCanvasNodeAnchor(this.findNode(edge.toNode)!, edge.toSide,
              this.findNode(edge.fromNode)!), this.viewport()).x) - ANCHOR_HALF,
          y: (end === 'from' ?
            worldToScreen(getCanvasNodeAnchor(this.findNode(edge.fromNode)!, edge.fromSide,
              this.findNode(edge.toNode)!), this.viewport()).y :
            worldToScreen(getCanvasNodeAnchor(this.findNode(edge.toNode)!, edge.toSide,
              this.findNode(edge.fromNode)!), this.viewport()).y) - ANCHOR_HALF
        })
        .gesture(
          PanGesture({ fingers: 1, direction: PanDirection.All, distance: 0 })
            .onActionStart((): void => this.beginReconnect(edge, end))
            .onActionUpdate((event: GestureEvent): void => this.updateConnection(event))
            .onActionEnd((): void => this.endConnection())
            .onActionCancel((): void => this.cancelConnection())
        )
    }
  }

  @Builder
  private SelectedEdgeEndpoints() {
    if (this.selectedEdgeId.length > 0 && this.selectedEdge() !== undefined) {
      this.EdgeEndpointHandle(this.selectedEdge()!, 'from')
      this.EdgeEndpointHandle(this.selectedEdge()!, 'to')
    }
  }

  @Builder
  private SelectedEdgeToolbar() {
    if (this.selectedEdgeId.length > 0) {
      Scroll() {
        Row({ space: 6 }) {
          TextInput({ text: this.edgeLabelDraft, placeholder: 'Label' })
            .id('free-canvas-edge-label')
            .width(140)
            .height(36)
            .onFocus((): void => {
              this.edgeLabelEditing = true;
            })
            .onBlur((): void => {
              this.edgeLabelEditing = false;
            })
            .onChange((value: string): void => {
              this.edgeLabelDraft = value;
            })
          Button('Save')
            .id('free-canvas-edge-label-save')
            .type(ButtonType.Normal)
            .height(36)
            .onClick((): void => {
              this.setSelectedEdgeLabel(this.edgeLabelDraft);
            })
          Button('->')
            .id('free-canvas-edge-forward')
            .type(ButtonType.Normal)
            .width(44)
            .height(36)
            .onClick((): void => {
              this.setSelectedEdgeDirection('forward');
            })
          Button('<-')
            .id('free-canvas-edge-reverse')
            .type(ButtonType.Normal)
            .width(44)
            .height(36)
            .onClick((): void => {
              this.setSelectedEdgeDirection('reverse');
            })
          Button('--')
            .id('free-canvas-edge-none')
            .type(ButtonType.Normal)
            .width(44)
            .height(36)
            .onClick((): void => {
              this.setSelectedEdgeDirection('none');
            })
          Button('<->')
            .id('free-canvas-edge-both')
            .type(ButtonType.Normal)
            .width(52)
            .height(36)
            .onClick((): void => {
              this.setSelectedEdgeDirection('both');
            })
          Button('Delete')
            .id('free-canvas-edge-delete')
            .type(ButtonType.Normal)
            .height(36)
            .fontColor('#FFC01C28')
            .onClick((): void => {
              this.deleteSelection();
            })
        }
        .height(48)
        .padding({ left: 8, right: 8 })
      }
      .width('100%')
      .height(48)
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .backgroundColor('#F7FFFFFF')
      .border({ width: { bottom: 1 }, color: '#FFD7DCE2' })
      .position({ x: 0, y: 0 })
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
      this.PrimaryConnectionAnchors()
      this.SelectedEdgeEndpoints()
      this.Marquee()
      this.SelectedEdgeToolbar()
    }
    .width('100%')
    .height('100%')
    .id('free-canvas')
    .clip(true)
    .backgroundColor('#FFF5F7F9')
    .focusable(true)
    .focusOnTouch(true)
    .onClick((event: ClickEvent): void => this.handleBackgroundClick(event))
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
