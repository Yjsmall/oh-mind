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

export {
  CARDNOTE_CANVAS_SCHEMA_VERSION,
  JSON_CANVAS_DEFAULT_FROM_END,
  JSON_CANVAS_DEFAULT_TO_END,
  cloneCanvasDocument,
  cloneCanvasEdge,
  cloneCanvasTextNode,
  cloneCanvasViewport,
  resolveCanvasEdgeFromEnd,
  resolveCanvasEdgeToEnd
} from './src/main/ets/model/CanvasModel';
export type {
  CardNoteCanvasExtension,
  CanvasDocument,
  CanvasEdge,
  CanvasEdgeEnd,
  CanvasNodeType,
  CanvasSide,
  CanvasTextNode,
  CanvasViewport
} from './src/main/ets/model/CanvasModel';
export {
  CanvasValidationError,
  validateCanvasDocument
} from './src/main/ets/model/CanvasValidation';
export type { CanvasValidationErrorCode } from './src/main/ets/model/CanvasValidation';
export {
  CanvasJsonCodecError,
  parseCanvasJson,
  serializeCanvasJson
} from './src/main/ets/codec/CanvasJsonCodec';
export type { CanvasJsonCodecErrorCode } from './src/main/ets/codec/CanvasJsonCodec';
export {
  CanvasCommandError,
  applyCanvasCommand,
  applyCanvasTransaction
} from './src/main/ets/commands/CanvasCommand';
export type {
  AddCanvasEdgeCommand,
  AddCanvasNodeCommand,
  CanvasCommand,
  CanvasCommandErrorCode,
  ClearCanvasViewportCommand,
  RemoveCanvasEdgeCommand,
  RemoveCanvasNodeCommand,
  ReorderCanvasNodeCommand,
  SetCanvasViewportCommand,
  UpdateCanvasEdgeCommand,
  UpdateCanvasNodeCommand
} from './src/main/ets/commands/CanvasCommand';
export {
  CanvasController,
  CanvasControllerError
} from './src/main/ets/controller/CanvasController';
export type {
  CanvasControllerErrorCode,
  CanvasControllerOptions
} from './src/main/ets/controller/CanvasController';
export {
  FREE_CANVAS_FIT_PADDING,
  FREE_CANVAS_MAX_SCALE,
  FREE_CANVAS_MIN_NODE_HEIGHT,
  FREE_CANVAS_MIN_NODE_WIDTH,
  FREE_CANVAS_MIN_SCALE,
  clampCanvasScale,
  fitCanvasViewport,
  getCanvasContentBounds,
  getCanvasNodeAnchor,
  moveCanvasNodes,
  nodeIntersectsCanvasRect,
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
} from './src/main/ets/geometry/FreeCanvasGeometry';
export type {
  CanvasNodePosition,
  CanvasPoint,
  CanvasRect,
  CanvasResizeHandle,
  CanvasSize
} from './src/main/ets/geometry/FreeCanvasGeometry';
export {
  CanvasEditingError,
  alignCanvasNodes,
  arrangeCanvasNodes,
  autoArrangeCanvasNodes,
  copyCanvasSelection,
  deleteCanvasSelection,
  distanceToCanvasSegment,
  distributeCanvasNodes,
  findCanvasConnectionTarget,
  findCanvasEdgeAt,
  nearestCanvasNodeSide
} from './src/main/ets/geometry/CanvasEditingGeometry';
export {
  addCanvasTextNode,
  reorderCanvasNode,
  setCanvasNodesColor,
  updateCanvasNodeText
} from './src/main/ets/editing/CanvasNodeEditing';
export type { CanvasNodeLayerAction } from './src/main/ets/editing/CanvasNodeEditing';
export { FreeCanvasSaveSession } from './src/main/ets/controller/FreeCanvasSaveSession';
export type {
  FreeCanvasSaveRequest,
  FreeCanvasSaveResult,
  FreeCanvasSaveResultDisposition,
  FreeCanvasSaveStatus
} from './src/main/ets/controller/FreeCanvasSaveSession';
export type {
  CanvasAlignment,
  CanvasArrangement,
  CanvasConnectionTarget,
  CanvasCopyResult,
  CanvasDistribution,
  CanvasEditingErrorCode
} from './src/main/ets/geometry/CanvasEditingGeometry';
export { FreeCanvasController } from './src/main/ets/controller/FreeCanvasController';
export type {
  FreeCanvasControllerBinding,
  FreeCanvasEdgeDirection,
  FreeCanvasInteractionMode
} from './src/main/ets/controller/FreeCanvasController';
export { FreeCanvas } from './src/main/ets/components/FreeCanvas';
export type {
  FreeCanvasChangeEvent,
  FreeCanvasChangeReason
} from './src/main/ets/components/FreeCanvas';
