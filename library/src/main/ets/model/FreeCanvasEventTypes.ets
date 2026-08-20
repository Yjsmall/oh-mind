import { CanvasDocument, cloneCanvasDocument } from '../model/CanvasModel';

export type FreeCanvasChangeReason =
  'viewport' | 'nodeMove' | 'nodeResize' | 'keyboardNudge' |
  'nodeAdd' | 'nodeEdit' | 'nodeColor' | 'nodeReorder' |
  'edgeAdd' | 'edgeUpdate' | 'edgeDelete' | 'edgeReconnect' |
  'copy' | 'delete' | 'align' | 'arrange' | 'distribute' | 'autoArrange' |
  'undo' | 'redo' | 'retry' | 'flush';

export interface FreeCanvasChangeEvent {
  readonly reason: FreeCanvasChangeReason;
  readonly requestId: string;
  readonly baseRevision: number;
  readonly document: CanvasDocument;
  readonly selectedNodeIds: ReadonlyArray<string>;
  readonly selectedEdgeId?: string;
}

export interface FreeCanvasPendingChange {
  readonly reason: FreeCanvasChangeReason;
  readonly document: CanvasDocument;
  readonly selectedNodeIds: ReadonlyArray<string>;
  readonly selectedEdgeId?: string;
}

export function clonePendingChange(change: FreeCanvasPendingChange): FreeCanvasPendingChange {
  return {
    reason: change.reason,
    document: cloneCanvasDocument(change.document),
    selectedNodeIds: change.selectedNodeIds.slice(),
    selectedEdgeId: change.selectedEdgeId
  };
}