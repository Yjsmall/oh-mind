import { KeyCode } from '@kit.InputKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
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
  resolveCanvasNodeAnchorSide,
  resolveCanvasViewport,
  screenToWorld,
  selectNodesInCanvasRect,
  setDocumentCanvasViewport,
  worldToScreen,
  zoomCanvasViewportBetweenPoints,
  zoomCanvasViewportByWheel
} from '../geometry/FreeCanvasGeometry';
import {
  CanvasAlignmentGuide,
  FREE_CANVAS_ALIGNMENT_THRESHOLD_VP,
  resolveCanvasAlignmentGuides
} from '../geometry/CanvasAlignmentGeometry';
import {
  CanvasBezierCurve,
  createCanvasBezierCurve,
  getCanvasBezierPointAt,
  getCanvasEdgeScreenCurve
} from '../geometry/CanvasEdgeGeometry';
import {
  CanvasAlignment,
  CanvasArrangement,
  CanvasConnectionTarget,
  CanvasCopyResult,
  CanvasDistribution,
  CanvasEditingError,
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
  FreeCanvasEdgeDirection
} from '../controller/FreeCanvasController';
import {
  CanvasNodeLayerAction,
  addCanvasTextNode,
  reorderCanvasNode,
  setCanvasNodesColor,
  updateCanvasNodeText
} from '../editing/CanvasNodeEditing';
import {
  FreeCanvasSaveResult,
  FreeCanvasSaveSession,
  FreeCanvasSaveStatus
} from '../controller/FreeCanvasSaveSession';
import {
  FreeCanvasChangeDebouncer,
  FREE_CANVAS_IDLE_SAVE_MS
} from '../controller/FreeCanvasChangeDebouncer';
import {
  FreeCanvasChangeEvent,
  FreeCanvasChangeReason,
  FreeCanvasPendingChange
} from '../model/FreeCanvasEventTypes';
import {
  FreeCanvasGestureMachine,
  FREE_CANVAS_MARQUEE_LONG_PRESS_MS,
  FREE_CANVAS_PAN_THRESHOLD_VP,
  selectNodesForMarquee,
  selectNodesForTap,
  primaryNodeForSelection
} from '../gesture/FreeCanvasGestureMachine';
import { FreeCanvasNodeCard } from './FreeCanvasNodeCard';
import { FreeCanvasNodeHandles } from './FreeCanvasNodeHandles';

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
const TOOLBAR_HEIGHT: number = 48;
const TOOLBAR_EDGE_WIDTH: number = 430;
const TOOLBAR_MULTI_WIDTH: number = 360;
const EDGE_TOUCH_TOLERANCE: number = 24;
const DEFAULT_NEW_NODE_WIDTH: number = 240;
const DEFAULT_NEW_NODE_HEIGHT: number = 160;
const EMPTY_DOCUMENT: CanvasDocument = { nodes: [], edges: [] };
const LOG_DOMAIN: number = 0x0000;
const GESTURE_LOG_TAG: string = 'FreeCanvasGesture';
const STATE_LOG_TAG: string = 'FreeCanvasState';

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

function customEdgeColorDraft(color: string | undefined): string {
  return color !== undefined && /^#[0-9A-Fa-f]{6}$/.test(color) ? color.toUpperCase() : '';
}

function isValidCustomEdgeColor(color: string): boolean {
  return /^#[0-9A-Fa-f]{6}$/.test(color.trim());
}

interface CanvasConnectionDraft {
  readonly fixedPoint: CanvasPoint;
  readonly fixedSide: CanvasSide;
  readonly startMovingPoint: CanvasPoint;
  readonly movingPoint: CanvasPoint;
  readonly sourceNodeId: string;
  readonly sourceSide: CanvasSide;
  readonly reconnectEdgeId?: string;
  readonly reconnectEnd?: 'from' | 'to';
}

/** Reads the primary finger without dereferencing a possibly empty fingerList. */
function gestureFirstFinger(event: GestureEvent): FingerInfo | undefined {
  const infos = event.fingerInfos;
  if (infos !== undefined && infos.length > 0) {
    return infos[0];
  }
  const list = event.fingerList;
  if (list !== undefined && list.length > 0) {
    return list[0];
  }
  return undefined;
}

function validFingerCount(event: GestureEvent): number {
  const infos = event.fingerInfos;
  if (infos !== undefined && infos.length > 0) {
    return infos.length;
  }
  const list = event.fingerList;
  if (list !== undefined) {
    return list.length;
  }
  return 0;
}

@ComponentV2
export struct FreeCanvas {
  @Require @Param document: CanvasDocument = EMPTY_DOCUMENT;
  @Param controller: FreeCanvasController = new FreeCanvasController();
  @Param nodeContentBuilder: WrappedBuilder<[CanvasTextNode, Object]> = DEFAULT_NODE_BUILDER;
  @Param nodeContentContext: Object = new DefaultFreeCanvasNodeContext();
  @Param committedRevision: number = 0;
  @Param saveResult: FreeCanvasSaveResult | undefined = undefined;
  @Event onChangeComplete: (event: FreeCanvasChangeEvent) => void = (): void => {
  };
  @Event onNodeActivate: (nodeId: string) => void = (): void => {
  };

  @Local private draftDocument: CanvasDocument = EMPTY_DOCUMENT;
  @Local private selectedNodeIds: string[] = [];
  @Local private primaryNodeId: string = '';
  @Local private selectedEdgeId: string = '';
  @Local private edgeLabelDraft: string = '';
  @Local private edgeColorDraft: string = '';
  @Local private edgeLabelEditing: boolean = false;
  @Local private hoveredEdgeId: string = '';
  @Local private editingNodeId: string = '';
  @Local private nodeTextDraft: string = '';
  @Local private saveStatus: FreeCanvasSaveStatus = 'saved';
  @Local private multiSelectEnabled: boolean = false;
  @Local private marqueeRect: CanvasRect | undefined = undefined;
  @Local private connectionDraft: CanvasConnectionDraft | undefined = undefined;
  @Local private renderRevision: number = 0;
  @Local private containerWidth: number = 0;
  @Local private containerHeight: number = 0;
  @Local private containerGlobalX: number = 0;
  @Local private containerGlobalY: number = 0;
  @Local private colorPopupVisible: boolean = false;
  @Local private alignPopupVisible: boolean = false;
  @Local private morePopupVisible: boolean = false;
  @Local private alignmentGuides: ReadonlyArray<CanvasAlignmentGuide> = [];
  // Measured window-space rects of the floating layers; hit testing uses these
  // instead of width constants so localized or scaled content stays clickable.
  @Local private edgeToolbarBounds: CanvasRect | undefined = undefined;
  @Local private nodeToolbarBounds: CanvasRect | undefined = undefined;
  @Local private colorPopupBounds: CanvasRect | undefined = undefined;
  @Local private alignPopupBounds: CanvasRect | undefined = undefined;
  @Local private morePopupBounds: CanvasRect | undefined = undefined;

  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private inputSnapshotJson: string = '';
  private panStartViewport: CanvasViewport = { x: 0, y: 0, scale: 1 };
  private pinchStartViewport: CanvasViewport = { x: 0, y: 0, scale: 1 };
  private pinchStartCenter: CanvasPoint = { x: 0, y: 0 };
  private marqueeStart: CanvasPoint = { x: 0, y: 0 };
  private selectionBeforeMarquee: string[] = [];
  private marqueeActive: boolean = false;
  private dragStartPositions: CanvasNodePosition[] = [];
  private resizeStartNode: CanvasTextNode | undefined = undefined;
  private nodeDragStartDocument: CanvasDocument | undefined = undefined;
  private resizeStartDocument: CanvasDocument | undefined = undefined;
  private panStartDocument: CanvasDocument | undefined = undefined;
  private pinchStartDocument: CanvasDocument | undefined = undefined;
  private axisStartDocument: CanvasDocument | undefined = undefined;
  private historyController: CanvasController = new CanvasController();
  private saveSession: FreeCanvasSaveSession = new FreeCanvasSaveSession();
  private changeDebouncer: FreeCanvasChangeDebouncer = new FreeCanvasChangeDebouncer(FREE_CANVAS_IDLE_SAVE_MS, {
    startTimer: (callback: () => void, ms: number): number => setTimeout(callback, ms),
    clearTimer: (handle: number): void => clearTimeout(handle),
    onChange: (change: FreeCanvasPendingChange): void => {
      this.publishPendingChange(change);
    }
  });
  private copySequence: number = 0;
  private copySelectionFailed: boolean = false;
  private edgeSequence: number = 0;
  private nodeSequence: number = 0;
  private axisChanged: boolean = false;
  private pinchActive: boolean = false;
  private suppressNextBackgroundClick: boolean = false;
  private mousePressed: boolean = false;
  private mouseButton: MouseButton = MouseButton.Left;
  private mouseClientX: number = 0;
  private mouseClientY: number = 0;
  private readonly gestureMachine: FreeCanvasGestureMachine = new FreeCanvasGestureMachine();
  private readonly controllerBinding: FreeCanvasControllerBinding = {
    fitContent: (): void => this.fitContent(),
    resetViewport: (): void => this.resetViewport(),
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
    addTextNode: (text: string): boolean => this.addTextNode(text),
    editSelectedNode: (): boolean => this.editSelectedNode(),
    commitNodeEdit: (): boolean => this.commitNodeEdit(),
    cancelNodeEdit: (): boolean => this.cancelNodeEdit(),
    setSelectedNodesColor: (color?: string): boolean => this.setSelectedNodesColor(color),
    reorderSelectedNode: (action: CanvasNodeLayerAction): boolean => this.reorderSelectedNode(action),
    activateSelectedNode: (): boolean => this.activateSelectedNode(),
    retrySave: (): boolean => this.retrySave(),
    flushPendingChange: (): boolean => this.flushPendingChange(),
    discardPendingChange: (): void => this.discardPendingChange(),
    currentDraft: (): CanvasDocument => this.draftDocument,
    setMultiSelectEnabled: (enabled: boolean): void => this.setMultiSelectEnabled(enabled),
    setSelectedEdgeLabel: (label: string): boolean => this.setSelectedEdgeLabel(label),
    setSelectedEdgeDirection: (direction: FreeCanvasEdgeDirection): boolean =>
      this.setSelectedEdgeDirection(direction),
    setSelectedEdgeColor: (color?: string): boolean => this.setSelectedEdgeColor(color)
  };

  aboutToAppear(): void {
    this.saveSession.syncConfirmedRevision(this.committedRevision);
    this.saveStatus = this.saveSession.getStatus();
    this.acceptInputDocument();
    this.controller.bind(this.controllerBinding);
  }

  aboutToDisappear(): void {
    this.flushPendingChange();
    this.controller.unbind(this.controllerBinding);
  }

  @Monitor('document')
  private onDocumentChanged(): void {
    // An echo of the last published document (the host confirming a save) must
    // not discard a newer pending autosave candidate.
    if (serializeCanvasJson(this.document) === this.inputSnapshotJson) {
      return;
    }
    this.discardPendingChange();
    this.acceptInputDocument();
  }

  @Monitor('committedRevision')
  private onCommittedRevisionChanged(): void {
    this.saveSession.syncConfirmedRevision(this.committedRevision);
    this.saveStatus = this.saveSession.getStatus();
  }

  @Monitor('saveResult')
  private onSaveResultChanged(): void {
    if (this.saveResult === undefined) {
      return;
    }
    this.saveSession.applyResult(this.saveResult);
    this.saveStatus = this.saveSession.getStatus();
    hilog.info(LOG_DOMAIN, STATE_LOG_TAG,
      'save result: status=%{public}s requestId=%{public}s revision=%{public}d',
      this.saveStatus, this.saveResult.requestId, this.saveResult.revision ?? -1);
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
    this.saveSession = new FreeCanvasSaveSession(this.committedRevision);
    this.saveStatus = this.saveSession.getStatus();
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
      this.edgeColorDraft = '';
    } else {
      this.edgeLabelDraft = this.selectedEdge()?.label ?? '';
      this.edgeColorDraft = customEdgeColorDraft(this.selectedEdge()?.color);
    }
    this.multiSelectEnabled = false;
    this.closePopups();
    this.marqueeRect = undefined;
    this.refresh();
    hilog.info(LOG_DOMAIN, STATE_LOG_TAG,
      'document accepted: nodes=%{public}d edges=%{public}d revision=%{public}d',
      this.draftDocument.nodes.length, this.draftDocument.edges.length, this.committedRevision);
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
    this.scheduleChange('viewport', setDocumentCanvasViewport(this.draftDocument, viewport));
  }

  private resetViewport(): void {
    this.scheduleChange('viewport', setDocumentCanvasViewport(this.draftDocument, { x: 0, y: 0, scale: 1 }));
  }

  private setMultiSelectEnabled(enabled: boolean): void {
    if (this.multiSelectEnabled === enabled) {
      return;
    }
    this.multiSelectEnabled = enabled;
    hilog.info(LOG_DOMAIN, STATE_LOG_TAG, 'multi-select enabled=%{public}s', String(enabled));
  }

  private closePopups(): void {
    this.colorPopupVisible = false;
    this.alignPopupVisible = false;
    this.morePopupVisible = false;
  }

  private clearSelection(): void {
    this.selectedNodeIds = [];
    this.primaryNodeId = '';
    this.selectedEdgeId = '';
    this.edgeLabelDraft = '';
    this.edgeColorDraft = '';
    this.edgeLabelEditing = false;
    this.multiSelectEnabled = false;
    this.closePopups();
    this.cancelNodeEdit();
  }

  private publishPendingChange(change: FreeCanvasPendingChange): void {
    this.inputSnapshotJson = serializeCanvasJson(change.document);
    const request = this.saveSession.createRequest(change.document);
    this.saveStatus = this.saveSession.getStatus();
    hilog.info(LOG_DOMAIN, STATE_LOG_TAG,
      'change published: reason=%{public}s requestId=%{public}s baseRevision=%{public}d nodes=%{public}d edges=%{public}d',
      change.reason, request.requestId, request.baseRevision,
      change.document.nodes.length, change.document.edges.length);
    this.onChangeComplete({
      reason: change.reason,
      requestId: request.requestId,
      baseRevision: request.baseRevision,
      document: request.document,
      selectedNodeIds: this.selectedNodeIds.slice(),
      selectedEdgeId: this.selectedEdgeId.length === 0 ? undefined : this.selectedEdgeId
    });
  }

  private scheduleChange(reason: FreeCanvasChangeReason, candidate?: CanvasDocument): void {
    const document = candidate === undefined ? this.draftDocument : candidate;
    if (serializeCanvasJson(document) !== serializeCanvasJson(this.draftDocument)) {
      this.draftDocument = document;
      this.refresh();
    }
    this.changeDebouncer.schedule({
      reason,
      document,
      selectedNodeIds: this.selectedNodeIds.slice(),
      selectedEdgeId: this.selectedEdgeId.length === 0 ? undefined : this.selectedEdgeId
    });
  }

  private flushPendingChange(): boolean {
    return this.changeDebouncer.flush();
  }

  private discardPendingChange(): void {
    this.changeDebouncer.discard();
  }

  private retrySave(): boolean {
    if (!this.saveSession.hasUnsavedChanges()) {
      return false;
    }
    this.changeDebouncer.discard();
    this.publishPendingChange({
      reason: 'retry',
      document: this.draftDocument,
      selectedNodeIds: this.selectedNodeIds.slice(),
      selectedEdgeId: this.selectedEdgeId.length === 0 ? undefined : this.selectedEdgeId
    });
    return true;
  }

  private completeDraft(reason: FreeCanvasChangeReason, before: CanvasDocument | undefined): boolean {
    if (before === undefined || serializeCanvasJson(before) === serializeCanvasJson(this.draftDocument)) {
      return false;
    }
    this.historyController.commitSnapshot(this.draftDocument);
    this.scheduleChange(reason);
    return true;
  }

  private commitCandidate(candidate: CanvasDocument, reason: FreeCanvasChangeReason): boolean {
    const before = cloneCanvasDocument(this.draftDocument);
    if (serializeCanvasJson(before) === serializeCanvasJson(candidate)) {
      return false;
    }
    this.draftDocument = this.historyController.commitSnapshot(candidate);
    this.refresh();
    this.scheduleChange(reason);
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
      this.edgeColorDraft = '';
    } else {
      this.edgeLabelDraft = this.selectedEdge()?.label ?? '';
      this.edgeColorDraft = customEdgeColorDraft(this.selectedEdge()?.color);
    }
  }

  private undo(): boolean {
    if (!this.historyController.undo()) {
      return false;
    }
    this.draftDocument = this.historyController.getSnapshot();
    this.filterSelection();
    this.refresh();
    this.scheduleChange('undo');
    return true;
  }

  private redo(): boolean {
    if (!this.historyController.redo()) {
      return false;
    }
    this.draftDocument = this.historyController.getSnapshot();
    this.filterSelection();
    this.refresh();
    this.scheduleChange('redo');
    return true;
  }

  private copySelection(): boolean {
    if (this.selectedNodeIds.length === 0) {
      return false;
    }
    let result: CanvasCopyResult | undefined = undefined;
    while (result === undefined) {
      this.copySequence++;
      try {
        result = copyCanvasSelection(this.draftDocument, this.selectedNodeIds, 'copy-' + this.copySequence);
      } catch (error) {
        const editingError = error as CanvasEditingError;
        if (!(editingError instanceof CanvasEditingError) || editingError.code !== 'IDENTIFIER_CONFLICT') {
          this.copySelectionFailed = true;
          return false;
        }
      }
    }
    this.copySelectionFailed = false;
    const previousSelection = this.selectedNodeIds.slice();
    const previousPrimary = this.primaryNodeId;
    this.selectedNodeIds = result.nodeIds.slice();
    this.primaryNodeId = this.selectedNodeIds[this.selectedNodeIds.length - 1];
    this.selectedEdgeId = '';
    this.edgeLabelDraft = '';
    this.edgeColorDraft = '';
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
    const previousMultiSelect = this.multiSelectEnabled;
    this.clearSelection();
    const changed = this.commitCandidate(candidate, reason);
    if (!changed) {
      this.selectedNodeIds = previousSelection;
      this.primaryNodeId = previousPrimary;
      this.selectedEdgeId = previousEdge;
      this.multiSelectEnabled = previousMultiSelect;
    }
    return changed;
  }

  private alignSelection(alignment: CanvasAlignment): boolean {
    this.closePopups();
    return this.commitCandidate(alignCanvasNodes(this.draftDocument, this.selectedNodeIds, alignment), 'align');
  }

  private arrangeSelection(arrangement: CanvasArrangement): boolean {
    this.closePopups();
    return this.commitCandidate(arrangeCanvasNodes(this.draftDocument, this.selectedNodeIds, arrangement), 'arrange');
  }

  private distributeSelection(distribution: CanvasDistribution): boolean {
    this.closePopups();
    return this.commitCandidate(distributeCanvasNodes(this.draftDocument, this.selectedNodeIds, distribution),
      'distribute');
  }

  private autoArrange(): boolean {
    this.closePopups();
    const nodeIds = this.selectedNodeIds.length === 0 ?
      this.draftDocument.nodes.map((node: CanvasTextNode): string => node.id) : this.selectedNodeIds;
    return this.commitCandidate(autoArrangeCanvasNodes(this.draftDocument, nodeIds), 'autoArrange');
  }

  private createNodeId(): string {
    let id = '';
    do {
      this.nodeSequence++;
      id = 'node-' + this.nodeSequence;
    } while (this.draftDocument.nodes.some((node: CanvasTextNode): boolean => node.id === id));
    return id;
  }

  private addTextNode(text: string): boolean {
    const id = this.createNodeId();
    const center = screenToWorld({ x: this.containerWidth / 2, y: this.containerHeight / 2 }, this.viewport());
    const candidate = addCanvasTextNode(this.draftDocument, id, {
      x: center.x - DEFAULT_NEW_NODE_WIDTH / 2,
      y: center.y - DEFAULT_NEW_NODE_HEIGHT / 2
    }, text, DEFAULT_NEW_NODE_WIDTH, DEFAULT_NEW_NODE_HEIGHT);
    this.selectedNodeIds = [id];
    this.primaryNodeId = id;
    this.selectedEdgeId = '';
    this.multiSelectEnabled = false;
    this.closePopups();
    const changed = this.commitCandidate(candidate, 'nodeAdd');
    if (changed) {
      this.beginNodeEdit(id);
    }
    return changed;
  }

  private beginNodeEdit(nodeId: string): boolean {
    const node = this.findNode(nodeId);
    if (node === undefined) {
      return false;
    }
    this.selectedNodeIds = [nodeId];
    this.primaryNodeId = nodeId;
    this.selectedEdgeId = '';
    this.multiSelectEnabled = false;
    this.closePopups();
    this.editingNodeId = nodeId;
    this.nodeTextDraft = node.text;
    this.gestureMachine.beginEditing();
    hilog.info(LOG_DOMAIN, STATE_LOG_TAG, 'node edit begin: nodeId=%{public}s', nodeId);
    return true;
  }

  private editSelectedNode(): boolean {
    return this.primaryNodeId.length > 0 && this.beginNodeEdit(this.primaryNodeId);
  }

  private commitNodeEdit(): boolean {
    if (this.editingNodeId.length === 0) {
      return false;
    }
    const nodeId = this.editingNodeId;
    const text = this.nodeTextDraft;
    this.editingNodeId = '';
    this.nodeTextDraft = '';
    hilog.info(LOG_DOMAIN, STATE_LOG_TAG, 'node edit commit: nodeId=%{public}s', nodeId);
    return this.commitCandidate(updateCanvasNodeText(this.draftDocument, nodeId, text), 'nodeEdit');
  }

  private cancelNodeEdit(): boolean {
    if (this.editingNodeId.length === 0) {
      return false;
    }
    this.editingNodeId = '';
    this.nodeTextDraft = '';
    hilog.info(LOG_DOMAIN, STATE_LOG_TAG, 'node edit cancelled');
    return true;
  }

  private setSelectedNodesColor(color?: string): boolean {
    this.closePopups();
    return this.commitCandidate(setCanvasNodesColor(this.draftDocument, this.selectedNodeIds, color), 'nodeColor');
  }

  private reorderSelectedNode(action: CanvasNodeLayerAction): boolean {
    if (this.primaryNodeId.length === 0) {
      return false;
    }
    return this.commitCandidate(reorderCanvasNode(this.draftDocument, this.primaryNodeId, action), 'nodeReorder');
  }

  private activateSelectedNode(): boolean {
    if (this.primaryNodeId.length === 0 || this.findNode(this.primaryNodeId) === undefined) {
      return false;
    }
    this.onNodeActivate(this.primaryNodeId);
    return true;
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

  private setSelectedEdgeColor(color?: string): boolean {
    const edge = this.selectedEdge();
    if (edge === undefined) {
      return false;
    }
    const changed = this.commitCandidate(applyCanvasCommand(this.draftDocument, {
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
        label: edge.label,
        color
      }
    }), 'edgeUpdate');
    if (changed) {
      this.edgeColorDraft = customEdgeColorDraft(color);
    }
    return changed;
  }

  private applyCustomEdgeColor(): boolean {
    const value = this.edgeColorDraft.trim();
    return isValidCustomEdgeColor(value) && this.setSelectedEdgeColor(value.toUpperCase());
  }

  private selectNode(nodeId: string, toggleModifier: boolean): void {
    if (this.editingNodeId.length > 0) {
      this.commitNodeEdit();
    }
    this.selectedEdgeId = '';
    this.edgeLabelDraft = '';
    this.edgeColorDraft = '';
    this.closePopups();
    this.applyNodeTapSelection(nodeId, toggleModifier);
    // A card's tap bubbles to the canvas background; keep the background
    // handler from turning this into an empty-canvas deselect.
    this.suppressNextBackgroundClick = true;
    hilog.info(LOG_DOMAIN, GESTURE_LOG_TAG,
      'node tap: nodeId=%{public}s multiSelect=%{public}s selected=%{public}d',
      nodeId, String(this.multiSelectEnabled), this.selectedNodeIds.length);
  }

  private selectNodeWithEvent(nodeId: string, event: ClickEvent): void {
    if (this.editingNodeId.length > 0) {
      this.commitNodeEdit();
    }
    const toggleModifier = event.getModifierKeyState?.(['Ctrl']) === true ||
      event.getModifierKeyState?.(['Shift']) === true;
    this.selectedEdgeId = '';
    this.edgeLabelDraft = '';
    this.edgeColorDraft = '';
    this.closePopups();
    this.applyNodeTapSelection(nodeId, toggleModifier);
    this.suppressNextBackgroundClick = true;
    hilog.info(LOG_DOMAIN, GESTURE_LOG_TAG,
      'node tap: nodeId=%{public}s multiSelect=%{public}s selected=%{public}d',
      nodeId, String(this.multiSelectEnabled), this.selectedNodeIds.length);
  }

  private applyNodeTapSelection(nodeId: string, toggleModifier: boolean): void {
    const next = selectNodesForTap(this.selectedNodeIds, nodeId, this.multiSelectEnabled, toggleModifier);
    this.selectedNodeIds = next;
    this.primaryNodeId = primaryNodeForSelection(next, nodeId);
    this.renderRevision++;
  }

  private beginNodeGesture(nodeId: string): void {
    if (this.pinchActive) {
      return;
    }
    if (this.editingNodeId.length > 0) {
      this.commitNodeEdit();
    }
    this.nodeDragStartDocument = cloneCanvasDocument(this.draftDocument);
    this.selectedEdgeId = '';
    this.edgeLabelDraft = '';
    this.edgeColorDraft = '';
    this.closePopups();
    this.gestureMachine.beginNode();
    if (!this.selectedNodeIds.includes(nodeId)) {
      const next = selectNodesForTap(this.selectedNodeIds, nodeId, this.multiSelectEnabled, false);
      this.selectedNodeIds = next;
      this.primaryNodeId = primaryNodeForSelection(next, nodeId);
    }
    this.renderRevision++;
    this.dragStartPositions = this.draftDocument.nodes
      .filter((node: CanvasTextNode): boolean => this.selectedNodeIds.includes(node.id))
      .map((node: CanvasTextNode): CanvasNodePosition => ({ id: node.id, x: node.x, y: node.y }));
    hilog.info(LOG_DOMAIN, GESTURE_LOG_TAG,
      'node drag start: nodeId=%{public}s moving=%{public}d phase=%{public}s',
      nodeId, this.dragStartPositions.length, this.gestureMachine.getPhase());
  }

  private updateNodeDrag(event: GestureEvent): void {
    if (this.pinchActive || this.dragStartPositions.length === 0) {
      return;
    }
    const scale = this.viewport().scale;
    const rawDelta: CanvasPoint = {
      x: event.offsetX / scale,
      y: event.offsetY / scale
    };
    this.gestureMachine.moveNode(rawDelta.x, rawDelta.y);
    const alignment = resolveCanvasAlignmentGuides(
      this.dragStartPositions,
      rawDelta,
      this.draftDocument.nodes,
      FREE_CANVAS_ALIGNMENT_THRESHOLD_VP
    );
    this.alignmentGuides = alignment.guides;
    this.draftDocument = moveCanvasNodes(this.draftDocument, this.dragStartPositions, alignment.delta);
    this.refresh();
  }

  private endNodeDrag(): void {
    this.alignmentGuides = [];
    if (this.dragStartPositions.length === 0) {
      return;
    }
    this.dragStartPositions = [];
    this.gestureMachine.endNode(0);
    this.completeDraft('nodeMove', this.nodeDragStartDocument);
    this.nodeDragStartDocument = undefined;
    hilog.info(LOG_DOMAIN, GESTURE_LOG_TAG, 'node drag end');
  }

  private cancelNodeDrag(): void {
    this.alignmentGuides = [];
    if (this.dragStartPositions.length === 0) {
      return;
    }
    if (this.nodeDragStartDocument !== undefined) {
      this.draftDocument = this.nodeDragStartDocument;
    }
    this.dragStartPositions = [];
    this.nodeDragStartDocument = undefined;
    this.gestureMachine.cancel();
    this.refresh();
    hilog.info(LOG_DOMAIN, GESTURE_LOG_TAG, 'node drag cancelled');
  }

  private beginResize(node: CanvasTextNode): void {
    if (this.pinchActive) {
      return;
    }
    this.resizeStartNode = node;
    this.resizeStartDocument = cloneCanvasDocument(this.draftDocument);
    this.gestureMachine.beginNode();
  }

  private updateResize(handle: CanvasResizeHandle, event: GestureEvent): void {
    if (this.resizeStartNode === undefined || this.pinchActive) {
      return;
    }
    const scale = this.viewport().scale;
    const delta: CanvasPoint = {
      x: event.offsetX / scale,
      y: event.offsetY / scale
    };
    if (this.gestureMachine.moveNode(delta.x, delta.y, 0) !== 'move') {
      return;
    }
    const resized = resizeCanvasNode(this.resizeStartNode, handle, {
      x: delta.x,
      y: delta.y
    });
    this.draftDocument = replaceCanvasNode(this.draftDocument, resized);
    this.refresh();
  }

  private endResize(): void {
    if (this.resizeStartNode === undefined) {
      return;
    }
    this.resizeStartNode = undefined;
    this.gestureMachine.endNode(0);
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
    this.gestureMachine.cancel();
    this.refresh();
  }

  private beginBackgroundPan(): void {
    if (this.pinchActive) {
      return;
    }
    if (this.editingNodeId.length > 0) {
      this.commitNodeEdit();
    }
    this.panStartViewport = this.viewport();
    this.panStartDocument = cloneCanvasDocument(this.draftDocument);
    this.gestureMachine.beginEmpty('touch', 1, 0, 0);
    hilog.info(LOG_DOMAIN, GESTURE_LOG_TAG,
      'background pan start: source=%{public}s phase=%{public}s',
      this.gestureMachine.getSource(), this.gestureMachine.getPhase());
  }

  private updateBackgroundPan(event: GestureEvent): void {
    if (this.pinchActive || this.panStartDocument === undefined) {
      return;
    }
    this.gestureMachine.moveEmpty(event.offsetX, event.offsetY);
    if (this.gestureMachine.getPhase() !== 'panning') {
      return;
    }
    this.updateViewport(panCanvasViewport(this.panStartViewport, event.offsetX, event.offsetY));
  }

  private endBackgroundPan(): void {
    this.gestureMachine.endEmpty();
    this.completeDraft('viewport', this.panStartDocument);
    this.panStartDocument = undefined;
    hilog.info(LOG_DOMAIN, GESTURE_LOG_TAG,
      'background pan end: phase=%{public}s', this.gestureMachine.getPhase());
  }

  private cancelBackgroundPan(): void {
    this.gestureMachine.cancel();
    if (this.panStartDocument !== undefined) {
      this.draftDocument = this.panStartDocument;
      this.refresh();
    }
    this.panStartDocument = undefined;
    hilog.info(LOG_DOMAIN, GESTURE_LOG_TAG,
      'background pan cancelled: phase=%{public}s', this.gestureMachine.getPhase());
  }

  private beginMarquee(event: GestureEvent): void {
    if (this.pinchActive) {
      return;
    }
    const firstFinger = gestureFirstFinger(event);
    if (firstFinger === undefined) {
      hilog.warn(LOG_DOMAIN, GESTURE_LOG_TAG,
        'marquee start ignored: fingers=%{public}d', validFingerCount(event));
      return;
    }
    this.armMarquee(firstFinger.localX, firstFinger.localY);
  }

  private beginMarqueeAt(x: number, y: number): void {
    if (this.pinchActive) {
      return;
    }
    this.armMarquee(x, y);
    hilog.info(LOG_DOMAIN, GESTURE_LOG_TAG,
      'mouse marquee armed: multiSelect=%{public}s', String(this.multiSelectEnabled));
  }

  private armMarquee(x: number, y: number): void {
    if (this.editingNodeId.length > 0) {
      this.commitNodeEdit();
    }
    this.gestureMachine.confirmLongPress();
    this.selectedEdgeId = '';
    this.edgeLabelDraft = '';
    this.edgeColorDraft = '';
    this.closePopups();
    this.panStartViewport = this.viewport();
    this.selectionBeforeMarquee = this.selectedNodeIds.slice();
    this.marqueeStart = screenToWorld({ x, y }, this.panStartViewport);
    this.marqueeRect = { x: this.marqueeStart.x, y: this.marqueeStart.y, width: 0, height: 0 };
    this.marqueeActive = true;
    this.gestureMachine.moveEmpty(x, y);
    hilog.info(LOG_DOMAIN, GESTURE_LOG_TAG,
      'marquee armed: multiSelect=%{public}s selectedBefore=%{public}d',
      String(this.multiSelectEnabled), this.selectionBeforeMarquee.length);
  }

  private continueMarquee(): void {
    if (this.marqueeRect === undefined) {
      this.gestureMachine.confirmLongPress();
      if (this.marqueeStart.x === 0 && this.marqueeStart.y === 0) {
        return;
      }
      this.marqueeRect = { x: this.marqueeStart.x, y: this.marqueeStart.y, width: 0, height: 0 };
    }
    this.gestureMachine.confirmLongPress();
  }

  private updateMarquee(event: GestureEvent): void {
    if (this.pinchActive || this.marqueeRect === undefined) {
      return;
    }
    const firstFinger = gestureFirstFinger(event);
    if (firstFinger === undefined) {
      hilog.warn(LOG_DOMAIN, GESTURE_LOG_TAG,
        'marquee update ignored: fingers=%{public}d', validFingerCount(event));
      return;
    }
    this.applyMarqueeAt(firstFinger.localX, firstFinger.localY);
  }

  private updateMarqueeAt(x: number, y: number): void {
    if (this.pinchActive || this.marqueeRect === undefined) {
      return;
    }
    this.applyMarqueeAt(x, y);
  }

  private applyMarqueeAt(x: number, y: number): void {
    this.gestureMachine.moveEmpty(x, y);
    const current = screenToWorld({ x, y }, this.panStartViewport);
    this.marqueeRect = normalizeCanvasRect(this.marqueeStart, current);
    const hits = selectNodesInCanvasRect(this.draftDocument.nodes, this.marqueeRect);
    this.selectedNodeIds = selectNodesForMarquee(this.selectionBeforeMarquee, hits, this.multiSelectEnabled);
    this.primaryNodeId = primaryNodeForSelection(this.selectedNodeIds, this.primaryNodeId);
  }

  private endMarquee(): void {
    if (this.marqueeRect === undefined) {
      return;
    }
    this.gestureMachine.endEmpty();
    this.marqueeRect = undefined;
    this.marqueeActive = false;
    const selectionChanged = !this.sameIdSet(this.selectionBeforeMarquee, this.selectedNodeIds);
    this.selectionBeforeMarquee = [];
    if (selectionChanged && this.selectedNodeIds.length > 0) {
      // The sweep decided this selection: the last swept node becomes primary so
      // resize handles follow the current interaction instead of an earlier one.
      this.primaryNodeId = this.selectedNodeIds[this.selectedNodeIds.length - 1];
    }
    hilog.info(LOG_DOMAIN, GESTURE_LOG_TAG,
      'marquee end: selected=%{public}d multiSelect=%{public}s',
      this.selectedNodeIds.length, String(this.multiSelectEnabled));
  }

  private sameIdSet(left: ReadonlyArray<string>, right: ReadonlyArray<string>): boolean {
    if (left.length !== right.length) {
      return false;
    }
    return left.every((id: string): boolean => right.includes(id));
  }

  private cancelMarquee(): void {
    this.gestureMachine.cancel();
    this.marqueeRect = undefined;
    if (this.marqueeActive) {
      this.marqueeActive = false;
      this.selectedNodeIds = this.selectionBeforeMarquee;
      this.primaryNodeId = primaryNodeForSelection(this.selectedNodeIds, this.primaryNodeId);
    }
    this.selectionBeforeMarquee = [];
    hilog.info(LOG_DOMAIN, GESTURE_LOG_TAG,
      'marquee cancelled: selected=%{public}d', this.selectedNodeIds.length);
  }

  private beginPinch(event: GestureEvent): void {
    this.cancelConnection();
    if (this.panStartDocument !== undefined) {
      this.draftDocument = this.panStartDocument;
      this.refresh();
      this.panStartDocument = undefined;
    }
    if (this.marqueeRect !== undefined) {
      this.marqueeRect = undefined;
      if (this.marqueeActive) {
        this.marqueeActive = false;
        this.selectedNodeIds = this.selectionBeforeMarquee;
        this.primaryNodeId = primaryNodeForSelection(this.selectedNodeIds, this.primaryNodeId);
      }
      this.selectionBeforeMarquee = [];
    }
    this.cancelNodeDrag();
    this.cancelResize();
    this.gestureMachine.beginPinch(validFingerCount(event));
    this.pinchActive = true;
    this.pinchStartViewport = this.viewport();
    this.pinchStartCenter = { x: event.pinchCenterX, y: event.pinchCenterY };
    this.pinchStartDocument = cloneCanvasDocument(this.draftDocument);
    hilog.info(LOG_DOMAIN, GESTURE_LOG_TAG,
      'pinch start: fingers=%{public}d scale=%{public}f', validFingerCount(event), this.viewport().scale);
  }

  private updatePinch(event: GestureEvent): void {
    if (!this.pinchActive) {
      return;
    }
    const scale = Number((this.pinchStartViewport.scale * event.scale).toFixed(2));
    this.updateViewport(zoomCanvasViewportBetweenPoints(this.pinchStartViewport, this.pinchStartCenter, {
      x: event.pinchCenterX,
      y: event.pinchCenterY
    }, scale));
  }

  private endPinch(): void {
    if (!this.pinchActive) {
      return;
    }
    this.pinchActive = false;
    this.gestureMachine.endPinch();
    hilog.info(LOG_DOMAIN, GESTURE_LOG_TAG,
      'pinch end: scale=%{public}f', this.viewport().scale);
    this.completeDraft('viewport', this.pinchStartDocument);
    this.pinchStartDocument = undefined;
    this.gestureMachine.cancel();
  }

  private cancelPinch(): void {
    if (!this.pinchActive) {
      return;
    }
    this.pinchActive = false;
    this.gestureMachine.cancel();
    hilog.info(LOG_DOMAIN, GESTURE_LOG_TAG, 'pinch cancelled');
    if (this.pinchStartDocument !== undefined) {
      this.draftDocument = this.pinchStartDocument;
      this.refresh();
    }
    this.pinchStartDocument = undefined;
    this.gestureMachine.cancel();
  }

  private handleMouse(event: MouseEvent): void {
    const button = event.button;
    const action = event.action;
    const clientX = event.displayX - this.containerGlobalX;
    const clientY = event.displayY - this.containerGlobalY;
    if (action === MouseAction.Press) {
      this.mousePressed = true;
      this.mouseButton = button;
      this.mouseClientX = clientX;
      this.mouseClientY = clientY;
      if (this.hitTestNode(clientX, clientY) !== undefined) {
        return;
      }
      if (button === MouseButton.Left) {
        this.beginMarqueeAt(clientX, clientY);
      } else {
        this.beginMousePan(clientX, clientY);
      }
      return;
    }
    if (action === MouseAction.Move) {
      if (!this.mousePressed) {
        const edge = findCanvasEdgeAt(this.draftDocument, this.viewport(), { x: clientX, y: clientY },
          EDGE_TOUCH_TOLERANCE);
        const nextHoveredEdgeId = edge?.id ?? '';
        if (nextHoveredEdgeId !== this.hoveredEdgeId) {
          this.hoveredEdgeId = nextHoveredEdgeId;
          this.refresh();
        }
        return;
      }
      if (this.mouseButton === MouseButton.Left) {
        this.updateMarqueeAt(clientX, clientY);
      } else {
        this.updateMousePan(clientX, clientY);
      }
      return;
    }
    if (action === MouseAction.Release) {
      this.mousePressed = false;
      if (this.mouseButton === MouseButton.Left) {
        this.endMarquee();
      } else {
        this.endMousePan();
      }
    }
  }

  /** Converts a measured area into a window-space rect for hit testing. */
  private trackToolbarBounds(area: Area): CanvasRect {
    return {
      x: Number(area.globalPosition.x),
      y: Number(area.globalPosition.y),
      width: Number(area.width),
      height: Number(area.height)
    };
  }

  private pointInsideToolbar(x: number, y: number): boolean {
    if (this.selectedEdgeId.length > 0 &&
      this.insideTrackedBounds(x, y, this.edgeToolbarBounds)) {
      return true;
    }
    if (this.selectedNodeIds.length > 0 && this.selectedEdgeId.length === 0 &&
      this.insideTrackedBounds(x, y, this.nodeToolbarBounds)) {
      return true;
    }
    return (this.colorPopupVisible && this.insideTrackedBounds(x, y, this.colorPopupBounds)) ||
      (this.alignPopupVisible && this.insideTrackedBounds(x, y, this.alignPopupBounds)) ||
      (this.morePopupVisible && this.insideTrackedBounds(x, y, this.morePopupBounds));
  }

  private insideTrackedBounds(x: number, y: number, bounds: CanvasRect | undefined): boolean {
    if (bounds === undefined) {
      return false;
    }
    const left = bounds.x - this.containerGlobalX;
    const top = bounds.y - this.containerGlobalY;
    return x >= left && x <= left + bounds.width && y >= top && y <= top + bounds.height;
  }

  private hitTestNode(x: number, y: number): CanvasTextNode | undefined {
    for (let index = this.draftDocument.nodes.length - 1; index >= 0; index--) {
      const node = this.draftDocument.nodes[index];
      const rect = this.nodeScreenRect(node);
      if (x >= rect.x && x <= rect.x + rect.width && y >= rect.y && y <= rect.y + rect.height) {
        return node;
      }
    }
    return undefined;
  }

  private beginMousePan(x: number, y: number): void {
    this.panStartViewport = this.viewport();
    this.panStartDocument = cloneCanvasDocument(this.draftDocument);
    this.gestureMachine.beginEmpty('mouse', 1, x, y);
    hilog.info(LOG_DOMAIN, GESTURE_LOG_TAG, 'mouse pan start');
  }

  private updateMousePan(x: number, y: number): void {
    if (this.panStartDocument === undefined) {
      return;
    }
    this.gestureMachine.moveEmpty(x, y);
    this.updateViewport(panCanvasViewport(this.panStartViewport, x - this.mouseClientX, y - this.mouseClientY));
    this.mouseClientX = x;
    this.mouseClientY = y;
  }

  private endMousePan(): void {
    this.gestureMachine.endEmpty();
    this.completeDraft('viewport', this.panStartDocument);
    this.panStartDocument = undefined;
  }

  private handleCanvasTouch(event: TouchEvent): void {
    if (event.type !== TouchType.Up || this.editingNodeId.length === 0) {
      return;
    }
    const touch = event.changedTouches.length > 0 ? event.changedTouches[0] : undefined;
    if (touch === undefined) {
      return;
    }
    const x = touch.x;
    const y = touch.y;
    if (this.pointInsideToolbar(x, y)) {
      return;
    }
    if (this.hitTestNode(x, y) !== undefined) {
      return;
    }
    this.commitNodeEdit();
  }

  private handleBackgroundClick(event: ClickEvent): void {
    if (this.suppressNextBackgroundClick) {
      this.suppressNextBackgroundClick = false;
      return;
    }
    // Tapping outside the card leaves editing and auto-saves the draft, so a
    // separate save button is never required.
    if (this.editingNodeId.length > 0) {
      this.commitNodeEdit();
    }
    // Clicks on floating toolbars bubble to the canvas; never let them clear the
    // selection they operate on.
    if (this.pointInsideToolbar(event.x, event.y)) {
      return;
    }
    // Mouse clicks on a card reach here (cards consume gestures but not the
    // parent click); route them into selection with Ctrl/Shift modifiers.
    const hitNode = this.hitTestNode(event.x, event.y);
    if (hitNode !== undefined) {
      this.selectNodeWithEvent(hitNode.id, event);
      return;
    }
    const edge = findCanvasEdgeAt(this.draftDocument, this.viewport(), { x: event.x, y: event.y },
      EDGE_TOUCH_TOLERANCE);
    if (edge === undefined) {
      const hadSelection = this.selectedNodeIds.length > 0 || this.selectedEdgeId.length > 0;
      this.clearSelection();
      if (hadSelection) {
        hilog.info(LOG_DOMAIN, GESTURE_LOG_TAG,
          'background tap cleared selection and multi-select');
      }
      return;
    }
    this.selectedNodeIds = [];
    this.primaryNodeId = '';
    this.selectedEdgeId = edge.id;
    this.edgeLabelDraft = edge.label ?? '';
    this.edgeColorDraft = customEdgeColorDraft(edge.color);
    this.multiSelectEnabled = false;
    this.closePopups();
    this.refresh();
  }

  private clearEdgeHover(): void {
    if (this.hoveredEdgeId.length > 0) {
      this.hoveredEdgeId = '';
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
      this.updateViewport(zoomCanvasViewportByWheel(viewport, { x: event.x, y: event.y }, vertical));
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
    if (event.type !== KeyType.Down || this.edgeLabelEditing || this.editingNodeId.length > 0) {
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

  /**
   * Returns the freshest node object for a card id. `Repeat` reuses item
   * references across updates, so the card builder reads directly from the
   * latest immutable `draftDocument` instead of trusting the item it was given.
   */
  private latestNode(reference: CanvasTextNode): CanvasTextNode {
    const latest = this.draftDocument.nodes.find((node: CanvasTextNode): boolean => node.id === reference.id);
    return latest === undefined ? reference : latest;
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
      fixedSide: side,
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
      fixedSide: this.connectionDraft.fixedSide,
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
      fromSide: draft.reconnectEnd === 'from' ? target.side : draft.sourceSide,
      fromEnd: 'none',
      toNode: target.nodeId,
      toSide: target.side,
      toEnd: 'arrow'
    };
    this.selectedNodeIds = [];
    this.primaryNodeId = '';
    this.selectedEdgeId = edgeId;
    this.edgeLabelDraft = '';
    this.edgeColorDraft = '';
    this.multiSelectEnabled = false;
    this.closePopups();
    this.commitCandidate(applyCanvasCommand(this.draftDocument, { kind: 'addEdge', edge }), 'edgeAdd');
  }

  private cancelConnection(): void {
    this.connectionDraft = undefined;
    this.gestureMachine.cancel();
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
    const fromSide = resolveCanvasNodeAnchorSide(fromNode, edge.fromSide, toNode);
    const toSide = resolveCanvasNodeAnchorSide(toNode, edge.toSide, fromNode);
    this.connectionDraft = {
      fixedPoint: end === 'from' ? to : from,
      fixedSide: end === 'from' ? toSide : fromSide,
      startMovingPoint: end === 'from' ? from : to,
      movingPoint: end === 'from' ? from : to,
      sourceNodeId: end === 'from' ? edge.fromNode : edge.toNode,
      sourceSide: end === 'from' ? fromSide : toSide,
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

  private primaryNode(): CanvasTextNode | undefined {
    return this.findNode(this.primaryNodeId);
  }

  private primaryHandleCenter(): CanvasPoint {
    const node = this.primaryNode();
    const rect = node === undefined ? undefined : this.nodeScreenRect(node);
    if (rect === undefined) {
      return { x: 0, y: 0 };
    }
    return { x: rect.x + rect.width / 2, y: rect.y + rect.height / 2 };
  }

  private primaryHandleHalfSize(): CanvasPoint {
    const node = this.primaryNode();
    const rect = node === undefined ? undefined : this.nodeScreenRect(node);
    if (rect === undefined) {
      return { x: 0, y: 0 };
    }
    return { x: rect.width / 2, y: rect.height / 2 };
  }

  private inferDraftEndSide(start: CanvasPoint, end: CanvasPoint): CanvasSide {
    const deltaX = end.x - start.x;
    const deltaY = end.y - start.y;
    if (Math.abs(deltaX) >= Math.abs(deltaY)) {
      return deltaX >= 0 ? 'left' : 'right';
    }
    return deltaY >= 0 ? 'top' : 'bottom';
  }

  private connectionDraftCurve(draft: CanvasConnectionDraft): CanvasBezierCurve {
    if (draft.reconnectEnd === 'from') {
      return createCanvasBezierCurve(draft.movingPoint, draft.sourceSide,
        draft.fixedPoint, draft.fixedSide, this.viewport().scale);
    }
    const movingSide = draft.reconnectEnd === 'to' ? draft.sourceSide :
      this.inferDraftEndSide(draft.fixedPoint, draft.movingPoint);
    return createCanvasBezierCurve(draft.fixedPoint, draft.fixedSide,
      draft.movingPoint, movingSide, this.viewport().scale);
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
      const curve = getCanvasEdgeScreenCurve(fromNode, edge.fromSide, toNode, edge.toSide, viewport);
      const color = edge.id === this.selectedEdgeId ? SELECTED_EDGE_COLOR : edgeStroke(edge.color);
      this.context.strokeStyle = color;
      this.context.fillStyle = color;
      this.context.lineWidth = edge.id === this.selectedEdgeId ? 3 :
        (edge.id === this.hoveredEdgeId ? 2.5 : 1.5);
      this.context.beginPath();
      this.context.moveTo(curve.start.x, curve.start.y);
      this.context.bezierCurveTo(curve.startControl.x, curve.startControl.y,
        curve.endControl.x, curve.endControl.y, curve.end.x, curve.end.y);
      this.context.stroke();
      if (resolveCanvasEdgeToEnd(edge) === 'arrow') {
        this.drawArrowHead(curve.endControl, curve.end);
      }
      if (resolveCanvasEdgeFromEnd(edge) === 'arrow') {
        this.drawArrowHead(curve.startControl, curve.start);
      }
      if (edge.label !== undefined && edge.label.length > 0) {
        const midpoint = getCanvasBezierPointAt(curve, 0.5);
        this.context.fillText(edge.label, midpoint.x + 6, midpoint.y - 6);
      }
    }
    if (this.connectionDraft !== undefined) {
      const curve = this.connectionDraftCurve(this.connectionDraft);
      this.context.strokeStyle = CONNECTION_DRAFT_COLOR;
      this.context.fillStyle = CONNECTION_DRAFT_COLOR;
      this.context.lineWidth = 2;
      this.context.beginPath();
      this.context.moveTo(curve.start.x, curve.start.y);
      this.context.bezierCurveTo(curve.startControl.x, curve.startControl.y,
        curve.endControl.x, curve.endControl.y, curve.end.x, curve.end.y);
      this.context.stroke();
      this.drawArrowHead(curve.endControl, curve.end);
    }
    if (this.alignmentGuides.length > 0) {
      this.context.strokeStyle = CONNECTION_DRAFT_COLOR;
      this.context.lineWidth = 1.5;
      const viewport = this.viewport();
      this.alignmentGuides.forEach((guide: CanvasAlignmentGuide): void => {
        const screenPosition = worldToScreen({ x: guide.position, y: guide.position }, viewport);
        this.context.beginPath();
        if (guide.axis === 'x') {
          this.context.moveTo(screenPosition.x, 0);
          this.context.lineTo(screenPosition.x, this.containerHeight);
        } else {
          this.context.moveTo(0, screenPosition.y);
          this.context.lineTo(this.containerWidth, screenPosition.y);
        }
        this.context.stroke();
      });
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

  private selectedNodeBounds(): CanvasRect | undefined {
    const selected = this.draftDocument.nodes.filter((node: CanvasTextNode): boolean =>
      this.selectedNodeIds.includes(node.id));
    if (selected.length === 0) {
      return undefined;
    }
    let left = Number.POSITIVE_INFINITY;
    let top = Number.POSITIVE_INFINITY;
    let right = Number.NEGATIVE_INFINITY;
    let bottom = Number.NEGATIVE_INFINITY;
    for (let index = 0; index < selected.length; index++) {
      const rect = this.nodeScreenRect(selected[index]);
      left = Math.min(left, rect.x);
      top = Math.min(top, rect.y);
      right = Math.max(right, rect.x + rect.width);
      bottom = Math.max(bottom, rect.y + rect.height);
    }
    return { x: left, y: top, width: right - left, height: bottom - top };
  }

  private selectedEdgeMidpoint(): CanvasPoint | undefined {
    if (this.selectedEdgeId.length === 0) {
      return undefined;
    }
    const edge = this.selectedEdge();
    if (edge === undefined) {
      return undefined;
    }
    const fromNode = this.findNode(edge.fromNode);
    const toNode = this.findNode(edge.toNode);
    if (fromNode === undefined || toNode === undefined) {
      return undefined;
    }
    const curve = getCanvasEdgeScreenCurve(fromNode, edge.fromSide, toNode, edge.toSide, this.viewport());
    return getCanvasBezierPointAt(curve, 0.5);
  }

  private toolbarPosition(width: number): CanvasPoint {
    const margin = 8;
    const clampX = (value: number): number => Math.max(margin, Math.min(this.containerWidth - width - margin, value));
    if (this.selectedEdgeId.length > 0) {
      const midpoint = this.selectedEdgeMidpoint();
      if (midpoint !== undefined) {
        const below = midpoint.y + 12;
        const y = below + TOOLBAR_HEIGHT <= this.containerHeight - margin ?
          below : Math.max(margin, midpoint.y - TOOLBAR_HEIGHT - 12);
        return { x: clampX(midpoint.x - width / 2), y: Math.max(margin, y) };
      }
    }
    const bounds = this.selectedNodeBounds();
    if (bounds !== undefined) {
      const centerX = bounds.x + bounds.width / 2;
      const below = bounds.y + bounds.height + 10;
      const y = below + TOOLBAR_HEIGHT <= this.containerHeight - margin ?
        below : Math.max(margin, bounds.y - TOOLBAR_HEIGHT - 10);
      return { x: clampX(centerX - width / 2), y: Math.max(margin, y) };
    }
    return {
      x: clampX(this.containerWidth / 2 - width / 2),
      y: Math.max(margin, this.containerHeight - TOOLBAR_HEIGHT - margin)
    };
  }

  @Builder
  private PrimaryNodeHandles() {
    if (this.editingNodeId.length === 0 && this.primaryNodeId.length > 0) {
      FreeCanvasNodeHandles({
        centerX: this.primaryHandleCenter().x,
        centerY: this.primaryHandleCenter().y,
        halfWidth: this.primaryHandleHalfSize().x,
        halfHeight: this.primaryHandleHalfSize().y,
        onResizeStart: (_handle: CanvasResizeHandle): void => {
          const node = this.primaryNode();
          if (node !== undefined) {
            this.beginResize(node);
          }
        },
        onResizeUpdate: (handle: CanvasResizeHandle, event: GestureEvent): void => {
          this.updateResize(handle, event);
        },
        onResizeEnd: (): void => {
          this.endResize();
        },
        onResizeCancel: (): void => {
          this.cancelResize();
        },
        onAnchorStart: (side: CanvasSide): void => {
          const node = this.primaryNode();
          if (node !== undefined) {
            this.beginConnection(node, side);
          }
        },
        onAnchorUpdate: (event: GestureEvent): void => {
          this.updateConnection(event);
        },
        onAnchorEnd: (): void => {
          this.endConnection();
        },
        onAnchorCancel: (): void => {
          this.cancelConnection();
        }
      })
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
  private EdgeColorButton(color: string | undefined, background: string, idSuffix: string) {
    Button() {
      Circle()
        .width(20)
        .height(20)
        .fill(background)
        .stroke('#FF9AA3AD')
        .strokeWidth(1)
    }
    .id('free-canvas-edge-color-' + idSuffix)
    .type(ButtonType.Normal)
    .width(36)
    .height(36)
    .backgroundColor(Color.Transparent)
    .onClick((): void => {
      this.setSelectedEdgeColor(color);
    })
  }

  @Builder
  private FloatingEdgeToolbar() {
    if (this.selectedEdgeId.length > 0) {
      Column() {
        Row({ space: 4 }) {
          TextInput({ text: this.edgeLabelDraft, placeholder: 'Label' })
            .id('free-canvas-edge-label')
            .width(104)
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
          Button('保存')
            .id('free-canvas-edge-label-save')
            .type(ButtonType.Normal)
            .height(36)
            .padding({ left: 5, right: 5 })
            .fontSize(12)
            .onClick((): void => {
              this.setSelectedEdgeLabel(this.edgeLabelDraft);
            })
          Button('→')
            .id('free-canvas-edge-forward')
            .type(ButtonType.Normal)
            .height(36)
            .padding({ left: 4, right: 4 })
            .fontSize(12)
            .onClick((): void => {
              this.setSelectedEdgeDirection('forward');
            })
          Button('←')
            .id('free-canvas-edge-reverse')
            .type(ButtonType.Normal)
            .height(36)
            .padding({ left: 4, right: 4 })
            .fontSize(12)
            .onClick((): void => {
              this.setSelectedEdgeDirection('reverse');
            })
          Button('—')
            .id('free-canvas-edge-none')
            .type(ButtonType.Normal)
            .height(36)
            .padding({ left: 4, right: 4 })
            .fontSize(12)
            .onClick((): void => {
              this.setSelectedEdgeDirection('none');
            })
          Button('⇄')
            .id('free-canvas-edge-both')
            .type(ButtonType.Normal)
            .height(36)
            .padding({ left: 4, right: 4 })
            .fontSize(12)
            .onClick((): void => {
              this.setSelectedEdgeDirection('both');
            })
          this.EdgeColorButton(undefined, EDGE_COLOR, 'default')
          this.EdgeColorButton('1', edgeStroke('1'), '1')
          this.EdgeColorButton('2', edgeStroke('2'), '2')
          this.EdgeColorButton('3', edgeStroke('3'), '3')
          this.EdgeColorButton('4', edgeStroke('4'), '4')
          this.EdgeColorButton('5', edgeStroke('5'), '5')
          this.EdgeColorButton('6', edgeStroke('6'), '6')
          TextInput({ text: this.edgeColorDraft, placeholder: '#RRGGBB' })
            .id('free-canvas-edge-color-custom')
            .width(84)
            .height(36)
            .maxLength(7)
            .onFocus((): void => {
              this.edgeLabelEditing = true;
            })
            .onBlur((): void => {
              this.edgeLabelEditing = false;
            })
            .onChange((value: string): void => {
              this.edgeColorDraft = value;
            })
          Button('应用')
            .id('free-canvas-edge-color-apply')
            .type(ButtonType.Normal)
            .height(36)
            .padding({ left: 5, right: 5 })
            .fontSize(12)
            .enabled(isValidCustomEdgeColor(this.edgeColorDraft))
            .onClick((): void => {
              this.applyCustomEdgeColor();
            })
          Button('删除')
            .id('free-canvas-edge-delete')
            .type(ButtonType.Normal)
            .height(36)
            .padding({ left: 5, right: 5 })
            .fontSize(12)
            .fontColor('#FFC01C28')
            .onClick((): void => {
              this.deleteSelection();
            })
        }
        .height(TOOLBAR_HEIGHT)
        .padding({ left: 6, right: 6 })
      }
      .id('free-canvas-edge-toolbar')
      .position(this.toolbarPosition(TOOLBAR_EDGE_WIDTH))
      .backgroundColor('#F7FFFFFF')
      .border({ width: 1, color: '#FFD7DCE2', radius: 6 })
      .shadow({ radius: 8, color: '#33000000', offsetX: 0, offsetY: 2 })
      .onAreaChange((_oldArea: Area, newArea: Area): void => {
        this.edgeToolbarBounds = this.trackToolbarBounds(newArea);
      })
    }
  }

  @Builder
  private NodeColorButton(color: string | undefined, background: string, idSuffix: string) {
    Button() {
      Circle()
        .width(20)
        .height(20)
        .fill(background)
        .stroke('#FF9AA3AD')
        .strokeWidth(1)
    }
    .id('free-canvas-node-color-' + idSuffix)
    .type(ButtonType.Normal)
    .width(36)
    .height(36)
    .backgroundColor(Color.Transparent)
    .onClick((): void => {
      this.setSelectedNodesColor(color);
    })
  }

  @Builder
  private ColorPopup() {
    if (this.colorPopupVisible) {
      Column({ space: 6 }) {
        this.NodeColorButton(undefined, DEFAULT_NODE_BACKGROUND, 'default')
        this.NodeColorButton('1', '#FFFFE4E6', '1')
        this.NodeColorButton('2', '#FFFFEDD5', '2')
        this.NodeColorButton('3', '#FFFEF9C3', '3')
        this.NodeColorButton('4', '#FFDCFCE7', '4')
        this.NodeColorButton('5', '#FFE0F2FE', '5')
        this.NodeColorButton('6', '#FFEDE9FE', '6')
      }
      .id('free-canvas-color-popup')
      .padding(6)
      .backgroundColor('#FDFFFFFF')
      .border({ width: 1, color: '#FFD7DCE2', radius: 6 })
      .shadow({ radius: 8, color: '#33000000', offsetX: 0, offsetY: 2 })
      .position({
        x: this.toolbarPosition(240).x,
        y: Math.max(8, this.toolbarPosition(240).y - 6 - 7 * 42)
      })
      .onAreaChange((_oldArea: Area, newArea: Area): void => {
        this.colorPopupBounds = this.trackToolbarBounds(newArea);
      })
    }
  }

  @Builder
  private AlignPopup() {
    if (this.alignPopupVisible) {
      Column({ space: 4 }) {
        Button('左对齐')
          .id('free-canvas-align-left')
          .type(ButtonType.Normal)
          .height(28)
          .fontSize(12)
          .onClick((): void => {
            this.alignSelection('left');
          })
        Button('水平居中')
          .id('free-canvas-align-hcenter')
          .type(ButtonType.Normal)
          .height(28)
          .fontSize(12)
          .onClick((): void => {
            this.alignSelection('horizontalCenter');
          })
        Button('右对齐')
          .id('free-canvas-align-right')
          .type(ButtonType.Normal)
          .height(28)
          .fontSize(12)
          .onClick((): void => {
            this.alignSelection('right');
          })
        Button('顶对齐')
          .id('free-canvas-align-top')
          .type(ButtonType.Normal)
          .height(28)
          .fontSize(12)
          .onClick((): void => {
            this.alignSelection('top');
          })
        Button('垂直居中')
          .id('free-canvas-align-vcenter')
          .type(ButtonType.Normal)
          .height(28)
          .fontSize(12)
          .onClick((): void => {
            this.alignSelection('verticalCenter');
          })
        Button('底对齐')
          .id('free-canvas-align-bottom')
          .type(ButtonType.Normal)
          .height(28)
          .fontSize(12)
          .onClick((): void => {
            this.alignSelection('bottom');
          })
        Button('排列成行')
          .id('free-canvas-arrange-row')
          .type(ButtonType.Normal)
          .height(28)
          .fontSize(12)
          .onClick((): void => {
            this.arrangeSelection('row');
          })
        Button('排列成列')
          .id('free-canvas-arrange-column')
          .type(ButtonType.Normal)
          .height(28)
          .fontSize(12)
          .onClick((): void => {
            this.arrangeSelection('column');
          })
        Button('水平均分')
          .id('free-canvas-distribute-horizontal')
          .type(ButtonType.Normal)
          .height(28)
          .fontSize(12)
          .onClick((): void => {
            this.distributeSelection('horizontal');
          })
        Button('垂直均分')
          .id('free-canvas-distribute-vertical')
          .type(ButtonType.Normal)
          .height(28)
          .fontSize(12)
          .onClick((): void => {
            this.distributeSelection('vertical');
          })
      }
      .id('free-canvas-align-popup')
      .padding(6)
      .backgroundColor('#FDFFFFFF')
      .border({ width: 1, color: '#FFD7DCE2', radius: 6 })
      .shadow({ radius: 8, color: '#33000000', offsetX: 0, offsetY: 2 })
      .position({
        x: this.toolbarPosition(160).x,
        y: Math.max(8, this.toolbarPosition(160).y - 6 - 10 * 32)
      })
      .onAreaChange((_oldArea: Area, newArea: Area): void => {
        this.alignPopupBounds = this.trackToolbarBounds(newArea);
      })
    }
  }

  @Builder
  private MorePopup() {
    if (this.morePopupVisible) {
      Column({ space: 4 }) {
        Button('后移一层')
          .id('free-canvas-node-backward')
          .type(ButtonType.Normal)
          .height(28)
          .fontSize(12)
          .onClick((): void => {
            this.reorderSelectedNode('backward');
          })
        Button('前移一层')
          .id('free-canvas-node-forward')
          .type(ButtonType.Normal)
          .height(28)
          .fontSize(12)
          .onClick((): void => {
            this.reorderSelectedNode('forward');
          })
        Button('置底')
          .id('free-canvas-node-bottom')
          .type(ButtonType.Normal)
          .height(28)
          .fontSize(12)
          .onClick((): void => {
            this.reorderSelectedNode('bottom');
          })
        Button('置顶')
          .id('free-canvas-node-top')
          .type(ButtonType.Normal)
          .height(28)
          .fontSize(12)
          .onClick((): void => {
            this.reorderSelectedNode('top');
          })
      }
      .id('free-canvas-more-popup')
      .padding(6)
      .backgroundColor('#FDFFFFFF')
      .border({ width: 1, color: '#FFD7DCE2', radius: 6 })
      .shadow({ radius: 8, color: '#33000000', offsetX: 0, offsetY: 2 })
      .position({
        x: this.toolbarPosition(120).x,
        y: Math.max(8, this.toolbarPosition(120).y - 6 - 4 * 32)
      })
      .onAreaChange((_oldArea: Area, newArea: Area): void => {
        this.morePopupBounds = this.trackToolbarBounds(newArea);
      })
    }
  }

  @Builder
  private ToolbarButton(label: string, id: string, action: () => void) {
    Button(label)
      .id(id)
      .type(ButtonType.Normal)
      .height(36)
      .padding({ left: 8, right: 8 })
      .fontSize(13)
      .onClick(action)
  }

  @Builder
  private FloatingNodeToolbar() {
    if (this.selectedEdgeId.length === 0 && this.selectedNodeIds.length > 0) {
      Column({ space: 0 }) {
        Row({ space: 4 }) {
          if (this.editingNodeId.length > 0) {
            this.ToolbarButton('取消', 'free-canvas-node-edit-cancel', (): void => {
              this.cancelNodeEdit();
            })
          } else {
            this.ToolbarButton('编辑', 'free-canvas-node-edit', (): void => {
              this.editSelectedNode();
            })
            this.ToolbarButton('颜色', 'free-canvas-node-color', (): void => {
              this.colorPopupVisible = !this.colorPopupVisible;
              this.alignPopupVisible = false;
              this.morePopupVisible = false;
            })
            this.ToolbarButton(this.multiSelectEnabled ? '多选开' : '多选', 'free-canvas-multiselect', (): void => {
              this.setMultiSelectEnabled(!this.multiSelectEnabled);
            })
            this.ToolbarButton('引用', 'free-canvas-node-activate', (): void => {
              this.activateSelectedNode();
            })
            this.ToolbarButton('复制', 'free-canvas-copy', (): void => {
              this.copySelection();
            })
            this.ToolbarButton('删除', 'free-canvas-delete', (): void => {
              this.deleteSelection();
            })
            this.ToolbarButton('更多', 'free-canvas-node-more', (): void => {
              this.morePopupVisible = !this.morePopupVisible;
              this.colorPopupVisible = false;
              this.alignPopupVisible = false;
            })
            if (this.selectedNodeIds.length > 1) {
              this.ToolbarButton('布局', 'free-canvas-align', (): void => {
                this.alignPopupVisible = !this.alignPopupVisible;
                this.colorPopupVisible = false;
                this.morePopupVisible = false;
              })
              this.ToolbarButton('自动整理', 'free-canvas-auto', (): void => {
                this.autoArrange();
              })
            }
          }
        }
        .height(TOOLBAR_HEIGHT)
        .padding({ left: 6, right: 6 })
      }
      .id('free-canvas-node-toolbar')
      .position(this.toolbarPosition(TOOLBAR_MULTI_WIDTH))
      .backgroundColor('#F7FFFFFF')
      .border({ width: 1, color: '#FFD7DCE2', radius: 6 })
      .shadow({ radius: 8, color: '#33000000', offsetX: 0, offsetY: 2 })
      .onAreaChange((_oldArea: Area, newArea: Area): void => {
        this.nodeToolbarBounds = this.trackToolbarBounds(newArea);
      })
    }
  }

  @Builder
  private SaveStatusBadge() {
    if (this.saveStatus === 'pending' || this.changeDebouncer.hasPending()) {
      Text('保存中...')
        .id('free-canvas-save-pending')
        .fontSize(12)
        .fontColor('#FF5D6670')
        .padding({ left: 10, right: 10, top: 6, bottom: 6 })
        .backgroundColor('#EEFFFFFF')
        .borderRadius(4)
        .position({ x: Math.max(8, this.containerWidth - 88), y: Math.max(8, this.containerHeight - 40) })
    } else if (this.saveStatus === 'failed') {
      Button('重试')
        .id('free-canvas-save-retry')
        .type(ButtonType.Normal)
        .height(32)
        .fontSize(12)
        .fontColor('#FFC01C28')
        .backgroundColor('#EEFFFFFF')
        .position({ x: Math.max(8, this.containerWidth - 88), y: Math.max(8, this.containerHeight - 40) })
        .onClick((): void => {
          this.retrySave();
        })
    }
  }

  @Builder
  private Marquee() {
    if (this.marqueeRect !== undefined) {
      Rect()
        .width(Math.max(1, this.marqueeRect.width * this.viewport().scale))
        .height(Math.max(1, this.marqueeRect.height * this.viewport().scale))
        .fill(MARQUEE_FILL)
        .stroke(MARQUEE_BORDER)
        .strokeWidth(1)
        .position(worldToScreen({ x: this.marqueeRect.x, y: this.marqueeRect.y }, this.viewport()))
    }
  }

  @Builder
  private NodeCard(node: CanvasTextNode) {
    FreeCanvasNodeCard({
      node: this.latestNode(node),
      contentText: this.latestNode(node).text,
      x: this.latestNode(node).x,
      y: this.latestNode(node).y,
      renderWidth: this.latestNode(node).width,
      renderHeight: this.latestNode(node).height,
      renderColor: nodeBackground(this.latestNode(node).color),
      selected: this.selectedNodeIds.includes(this.latestNode(node).id),
      editing: this.editingNodeId === this.latestNode(node).id,
      editingText: this.nodeTextDraft,
      viewportX: this.viewport().x,
      viewportY: this.viewport().y,
      viewportScale: this.viewport().scale,
      nodeContentBuilder: this.nodeContentBuilder,
      nodeContentContext: this.nodeContentContext,
      onCardSelect: (nodeId: string): void => this.selectNode(nodeId, false),
      onCardDoubleTap: (nodeId: string): void => {
        this.beginNodeEdit(nodeId);
      },
      onCardDragStart: (nodeId: string): void => this.beginNodeGesture(nodeId),
      onCardDragUpdate: (_nodeId: string, event: GestureEvent): void => this.updateNodeDrag(event),
      onCardDragEnd: (_nodeId: string): void => this.endNodeDrag(),
      onCardDragCancel: (_nodeId: string): void => this.cancelNodeDrag(),
      onCardEditTextChange: (_nodeId: string, text: string): void => {
        this.nodeTextDraft = text;
      },
      onCardEditCommit: (_nodeId: string): void => {
        this.commitNodeEdit();
      },
      onCardEditCancel: (_nodeId: string): void => {
        this.cancelNodeEdit();
      }
    })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Canvas(this.context)
        .width('100%')
        .height('100%')
        .hitTestBehavior(HitTestMode.None)
        .onReady((): void => this.drawEdges())

      Repeat<CanvasTextNode>(this.draftDocument.nodes)
        .key((node: CanvasTextNode): string => node.id)
        .each((item: RepeatItem<CanvasTextNode>): void => {
          this.NodeCard(item.item)
        })

      this.PrimaryNodeHandles()
      this.SelectedEdgeEndpoints()
      this.Marquee()
      this.ColorPopup()
      this.AlignPopup()
      this.MorePopup()
      this.FloatingNodeToolbar()
      this.FloatingEdgeToolbar()
      this.SaveStatusBadge()
    }
    .width('100%')
    .height('100%')
    .id('free-canvas')
    .clip(true)
    .backgroundColor('#FFF5F7F9')
    .focusable(true)
    .focusOnTouch(true)
    .onTouch((event: TouchEvent): void => this.handleCanvasTouch(event))
    .onClick((event: ClickEvent): void => this.handleBackgroundClick(event))
    .onMouse((event: MouseEvent): void => this.handleMouse(event))
    .onHover((isHover: boolean): void => {
      if (!isHover) {
        this.clearEdgeHover();
      }
    })
    .onKeyEvent((event: KeyEvent): boolean => this.handleKey(event))
    .onAxisEvent((event?: AxisEvent): void => {
      if (event !== undefined) {
        this.handleAxis(event);
      }
    })
    .onAreaChange((_oldArea: Area, newArea: Area): void => {
      this.containerWidth = Number(newArea.width);
      this.containerHeight = Number(newArea.height);
      this.containerGlobalX = Number(newArea.globalPosition.x);
      this.containerGlobalY = Number(newArea.globalPosition.y);
      this.refresh();
    })
    .gesture(
      GestureGroup(
        GestureMode.Parallel,
        GestureGroup(
          GestureMode.Exclusive,
          GestureGroup(
            GestureMode.Sequence,
            LongPressGesture({ repeat: false, duration: FREE_CANVAS_MARQUEE_LONG_PRESS_MS, fingers: 1 })
              .allowedTypes([SourceTool.Finger, SourceTool.Pen])
              .onAction((event: GestureEvent): void => {
                this.beginMarquee(event);
              }),
            PanGesture({ fingers: 1, direction: PanDirection.All, distance: 1 })
              .allowedTypes([SourceTool.Finger, SourceTool.Pen])
              .onActionStart((): void => {
                this.continueMarquee();
              })
              .onActionUpdate((event: GestureEvent): void => {
                this.updateMarquee(event);
              })
              .onActionEnd((): void => {
                this.endMarquee();
              })
              .onActionCancel((): void => {
                this.cancelMarquee();
              })
          ).onCancel((): void => {
            this.cancelMarquee();
          }),
          PanGesture({ fingers: 1, direction: PanDirection.All, distance: FREE_CANVAS_PAN_THRESHOLD_VP })
            .allowedTypes([SourceTool.Finger, SourceTool.Pen])
            .onActionStart((): void => {
              this.beginBackgroundPan();
            })
            .onActionUpdate((event: GestureEvent): void => {
              this.updateBackgroundPan(event);
            })
            .onActionEnd((): void => {
              this.endBackgroundPan();
            })
            .onActionCancel((): void => {
              this.cancelBackgroundPan();
            })
        ),
        PinchGesture({ fingers: 2, distance: 2 })
          .allowedTypes([SourceTool.Finger, SourceTool.Pen])
          .onActionStart((event: GestureEvent): void => this.beginPinch(event))
          .onActionUpdate((event: GestureEvent): void => this.updatePinch(event))
          .onActionEnd((): void => this.endPinch())
          .onActionCancel((): void => this.cancelPinch())
      )
    )
  }
}
