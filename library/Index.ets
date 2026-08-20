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

import MindElixir from './src/main/ets/components/MindElixir';
import { MindElixirCore } from './src/main/ets/controller/MindElixirCore';
import {
  CanvasPosition,
  CanvasSize,
  NodeObj,
  NodeOption,
  MindElixirData,
  Arrow,
  LayoutDirection,
  MoveDirection,
  DragOrientation,
  NodeStyle,
  Coordinate,
  NodeSize,
  LayoutResult,
  Bounds,
  ParentNode,
  WindowRect,
  TextSize,
  FlatNodeObj,
  MenuOptionItem
} from './src/main/ets/model/NodeObj';
import {
  CARDNOTE_CANVAS_SCHEMA_VERSION,
  CardNoteCanvasExtension,
  CanvasDocument,
  CanvasEdge,
  CanvasEdgeEnd,
  CanvasNodeType,
  CanvasSide,
  CanvasTextNode,
  CanvasViewport,
  JSON_CANVAS_DEFAULT_FROM_END,
  JSON_CANVAS_DEFAULT_TO_END,
  cloneCanvasDocument,
  resolveCanvasEdgeFromEnd,
  resolveCanvasEdgeToEnd
} from './src/main/ets/model/CanvasModel';
import {
  CanvasValidationError,
  CanvasValidationErrorCode,
  validateCanvasDocument
} from './src/main/ets/model/CanvasValidation';
import {
  CanvasJsonCodecError,
  CanvasJsonCodecErrorCode,
  parseCanvasJson,
  serializeCanvasJson
} from './src/main/ets/codec/CanvasJsonCodec';

export {
  MindElixir,
  MindElixirCore,
  CanvasPosition,
  CanvasSize,
  NodeObj,
  NodeOption,
  MindElixirData,
  Arrow,
  LayoutDirection,
  MoveDirection,
  DragOrientation,
  NodeStyle,
  Coordinate,
  NodeSize,
  LayoutResult,
  Bounds,
  ParentNode,
  WindowRect,
  TextSize,
  FlatNodeObj,
  MenuOptionItem,
  CARDNOTE_CANVAS_SCHEMA_VERSION,
  CardNoteCanvasExtension,
  CanvasDocument,
  CanvasEdge,
  CanvasEdgeEnd,
  CanvasJsonCodecError,
  CanvasJsonCodecErrorCode,
  CanvasNodeType,
  CanvasSide,
  CanvasTextNode,
  CanvasValidationError,
  CanvasValidationErrorCode,
  CanvasViewport,
  JSON_CANVAS_DEFAULT_FROM_END,
  JSON_CANVAS_DEFAULT_TO_END,
  cloneCanvasDocument,
  parseCanvasJson,
  resolveCanvasEdgeFromEnd,
  resolveCanvasEdgeToEnd,
  serializeCanvasJson,
  validateCanvasDocument
};
