/**
 * Pure ArkUI-free gesture arbitration and selection semantics for the free canvas.
 *
 * The FreeCanvas component feeds pointer, long-press and pinch events into this
 * machine and applies the returned decisions. Keeping the arbitration and
 * selection logic free of ArkUI types makes tablet gesture behavior unit-testable
 * without a running UI host.
 */

export type FreeCanvasGestureSource = 'touch' | 'mouse' | 'trackpad';

export type FreeCanvasGesturePhase =
  | 'idle'
  | 'panning'
  | 'marqueeArmed'
  | 'marqueeActive'
  | 'pinching'
  | 'nodeWait'
  | 'nodeDragging'
  | 'editing'
  | 'cancelled';

/** Quick single-finger drag on empty space moves the viewport. */
export const FREE_CANVAS_PAN_THRESHOLD_VP: number = 5;
/** Holding still this long arms marquee selection on empty space. */
export const FREE_CANVAS_MARQUEE_LONG_PRESS_MS: number = 400;
/** Slight finger jitter tolerated before the long press is confirmed. */
export const FREE_CANVAS_MARQUEE_JITTER_VP: number = 8;
/** A card drag only selects and moves after exceeding this distance. */
export const FREE_CANVAS_CARD_DRAG_THRESHOLD_VP: number = 6;

export type FreeCanvasEmptyDecision = 'none' | 'pan' | 'marquee';
export type FreeCanvasNodeDecision = 'none' | 'select' | 'move' | 'edit';

function distanceBetween(ax: number, ay: number, bx: number, by: number): number {
  return Math.hypot(ax - bx, ay - by);
}

export interface FreeCanvasGestureTrace {
  readonly source: FreeCanvasGestureSource;
  readonly fingers: number;
  readonly phase: FreeCanvasGesturePhase;
}

export class FreeCanvasGestureMachine {
  private phase: FreeCanvasGesturePhase = 'idle';
  private source: FreeCanvasGestureSource = 'touch';
  private fingers: number = 0;
  private originX: number = 0;
  private originY: number = 0;
  private lastX: number = 0;
  private lastY: number = 0;
  private longPressArmed: boolean = false;
  private pinchHeld: boolean = false;

  getPhase(): FreeCanvasGesturePhase {
    return this.phase;
  }

  getSource(): FreeCanvasGestureSource {
    return this.source;
  }

  getFingers(): number {
    return this.fingers;
  }

  trace(): FreeCanvasGestureTrace {
    return { source: this.source, fingers: this.fingers, phase: this.phase };
  }

  /** First finger (or mouse button) down on empty canvas space. */
  beginEmpty(source: FreeCanvasGestureSource, fingers: number, x: number, y: number): FreeCanvasGesturePhase {
    this.resetInternal();
    this.source = source;
    this.fingers = fingers;
    this.originX = x;
    this.originY = y;
    this.lastX = x;
    this.lastY = y;
    this.phase = 'idle';
    return this.phase;
  }

  /**
   * Empty-space movement. Before the long press fires a quick move past the pan
   * threshold becomes a viewport pan; after the long press the same move becomes
   * a marquee drag.
   */
  moveEmpty(x: number, y: number): FreeCanvasEmptyDecision {
    if (this.phase === 'pinching') {
      return 'none';
    }
    this.lastX = x;
    this.lastY = y;
    if (this.longPressArmed) {
      this.phase = 'marqueeActive';
      return 'marquee';
    }
    if (this.phase === 'panning') {
      return 'pan';
    }
    if (this.phase === 'marqueeActive') {
      return 'marquee';
    }
    const distance = distanceBetween(this.originX, this.originY, x, y);
    if (distance > FREE_CANVAS_PAN_THRESHOLD_VP) {
      this.phase = 'panning';
      return 'pan';
    }
    return 'none';
  }

  /** Fired by LongPressGesture after the configured hold duration. */
  confirmLongPress(): FreeCanvasGesturePhase {
    if (this.phase === 'pinching' || this.phase === 'panning') {
      return this.phase;
    }
    this.longPressArmed = true;
    this.phase = 'marqueeArmed';
    return this.phase;
  }

  /** A two-finger pinch takes priority over every single-finger gesture. */
  beginPinch(fingers: number): FreeCanvasGesturePhase {
    this.pinchHeld = true;
    this.fingers = fingers;
    this.phase = 'pinching';
    return this.phase;
  }

  /**
   * First finger down on a node card. The origin lives in the same delta space
   * the caller feeds to `moveNode` (0,0 = gesture start), so the drag threshold
   * is measured against the gesture's own offset instead of a stale previous
   * gesture's origin.
   */
  beginNode(x: number = 0, y: number = 0): FreeCanvasGesturePhase {
    if (this.pinchHeld) {
      return this.phase;
    }
    this.fingers = 1;
    this.originX = x;
    this.originY = y;
    this.lastX = x;
    this.lastY = y;
    this.phase = 'nodeWait';
    return this.phase;
  }

  /**
   * Node movement. Only after the drag threshold does the gesture become a
   * move; anything below stays a pending tap that resolves on release. Resize
   * handles pass a zero threshold because they respond from the first pixel.
   */
  moveNode(x: number, y: number, threshold: number = FREE_CANVAS_CARD_DRAG_THRESHOLD_VP):
    FreeCanvasNodeDecision {
    if (this.pinchHeld || this.phase === 'editing') {
      return 'none';
    }
    if (this.phase === 'nodeDragging') {
      return 'move';
    }
    const distance = distanceBetween(this.originX, this.originY, x, y);
    if (distance > threshold) {
      this.phase = 'nodeDragging';
      return 'move';
    }
    return 'none';
  }

  /** Release after a node gesture; below the drag threshold it is a tap. */
  endNode(startDistance: number, doubleTap: boolean = false): FreeCanvasNodeDecision {
    if (this.phase === 'editing') {
      return 'none';
    }
    if (this.phase === 'nodeDragging' || startDistance > FREE_CANVAS_CARD_DRAG_THRESHOLD_VP) {
      this.settle();
      return 'move';
    }
    this.settle();
    return doubleTap ? 'edit' : 'select';
  }

  /** Enter node editing; the editor owns all touches while active. */
  beginEditing(): FreeCanvasGesturePhase {
    this.phase = 'editing';
    return this.phase;
  }

  /** End an empty-space gesture: pan, marquee or a plain tap. */
  endEmpty(): FreeCanvasEmptyDecision {
    const decision = this.phase === 'marqueeActive' ? 'marquee' :
      (this.phase === 'panning' ? 'pan' : 'none');
    this.settle();
    return decision;
  }

  /** Cancel any gesture; the canvas restores the pre-gesture draft. */
  cancel(): FreeCanvasGesturePhase {
    this.settle();
    this.phase = 'cancelled';
    return this.phase;
  }

  /** End a two-finger pinch. */
  endPinch(): FreeCanvasGesturePhase {
    this.settle();
    return this.phase;
  }

  private settle(): void {
    this.pinchHeld = false;
    this.longPressArmed = false;
    this.phase = 'idle';
  }

  private resetInternal(): void {
    this.phase = 'idle';
    this.fingers = 0;
    this.longPressArmed = false;
    this.pinchHeld = false;
  }
}

/** Replaces the current node selection unless multi-select appends to it. */
export function selectNodesForMarquee(previous: ReadonlyArray<string>,
  marquee: ReadonlyArray<string>, multiSelect: boolean): string[] {
  if (!multiSelect) {
    return marquee.slice();
  }
  const merged = previous.slice();
  for (let index = 0; index < marquee.length; index++) {
    if (!merged.includes(marquee[index])) {
      merged.push(marquee[index]);
    }
  }
  return merged;
}

/** With multi-select enabled a tap toggles; otherwise it single-selects. */
export function selectNodesForTap(previous: ReadonlyArray<string>, nodeId: string,
  multiSelect: boolean, toggleModifier: boolean): string[] {
  if (!multiSelect && !toggleModifier) {
    return [nodeId];
  }
  if (previous.includes(nodeId)) {
    return previous.filter((id: string): boolean => id !== nodeId);
  }
  const merged = previous.slice();
  merged.push(nodeId);
  return merged;
}

export function primaryNodeForSelection(selection: ReadonlyArray<string>,
  previousPrimary: string): string {
  if (selection.includes(previousPrimary)) {
    return previousPrimary;
  }
  return selection.length === 0 ? '' : selection[selection.length - 1];
}