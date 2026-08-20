import {
  FreeCanvasPendingChange,
  clonePendingChange
} from '../model/FreeCanvasEventTypes';

export const FREE_CANVAS_IDLE_SAVE_MS: number = 800;

export interface FreeCanvasChangeDebouncerOptions {
  readonly startTimer?: (callback: () => void, ms: number) => number;
  readonly clearTimer?: (handle: number) => void;
  readonly onChange: (change: FreeCanvasPendingChange) => void;
}

/**
 * Debounces completed free-canvas operations into a single latest candidate.
 *
 * Every completed operation overwrites the pending candidate and resets the idle
 * timer. Only the latest full snapshot is published after the idle window, on an
 * explicit flush, or never if discarded. Pure ArkTS so host unit tests can
 * exercise merged saves without a running UI host.
 */
export class FreeCanvasChangeDebouncer {
  private pending: FreeCanvasPendingChange | undefined = undefined;
  private timerHandle: number = 0;
  private readonly idleMs: number;
  private readonly startTimer: (callback: () => void, ms: number) => number;
  private readonly clearTimer: (handle: number) => void;
  private readonly onChange: (change: FreeCanvasPendingChange) => void;

  constructor(idleMs: number = FREE_CANVAS_IDLE_SAVE_MS, options: FreeCanvasChangeDebouncerOptions) {
    this.idleMs = idleMs > 0 ? idleMs : FREE_CANVAS_IDLE_SAVE_MS;
    this.startTimer = options.startTimer ?? ((callback, ms): number => setTimeout(callback, ms));
    this.clearTimer = options.clearTimer ?? ((handle): void => clearTimeout(handle));
    this.onChange = options.onChange;
  }

  hasPending(): boolean {
    return this.pending !== undefined;
  }

  pendingChange(): FreeCanvasPendingChange | undefined {
    if (this.pending === undefined) {
      return undefined;
    }
    return clonePendingChange(this.pending);
  }

  /** Records a completed operation, replacing any older candidate, and resets the idle timer. */
  schedule(change: FreeCanvasPendingChange): void {
    this.pending = clonePendingChange(change);
    this.clearTimer(this.timerHandle);
    const handle = this.startTimer((): void => {
      const ready = this.pending;
      if (ready === undefined) {
        return;
      }
      this.pending = undefined;
      this.onChange(ready);
    }, this.idleMs);
    this.timerHandle = handle;
  }

  /** Publishes the latest candidate immediately; returns whether a change was emitted. */
  flush(): boolean {
    const ready = this.pending;
    if (ready === undefined) {
      return false;
    }
    this.clearTimer(this.timerHandle);
    this.pending = undefined;
    this.onChange(ready);
    return true;
  }

  /** Drops any pending candidate (used when the current document is deleted). */
  discard(): void {
    this.clearTimer(this.timerHandle);
    this.pending = undefined;
  }
}