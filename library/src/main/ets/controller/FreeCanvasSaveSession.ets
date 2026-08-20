import { CanvasDocument, cloneCanvasDocument } from '../model/CanvasModel';

export type FreeCanvasSaveStatus = 'saved' | 'pending' | 'failed';

export interface FreeCanvasSaveRequest {
  readonly requestId: string;
  readonly baseRevision: number;
  readonly document: CanvasDocument;
}

export interface FreeCanvasSaveResult {
  readonly requestId: string;
  readonly status: 'success' | 'failure';
  readonly revision?: number;
  readonly message?: string;
}

export type FreeCanvasSaveResultDisposition = 'applied' | 'duplicate' | 'stale' | 'invalid';

interface PendingSaveRequest {
  readonly requestId: string;
  readonly sequence: number;
}

function validRevision(revision: number): boolean {
  return Number.isInteger(revision) && revision >= 0;
}

export class FreeCanvasSaveSession {
  private confirmedRevision: number;
  private sequence: number = 0;
  private pending: PendingSaveRequest[] = [];
  private completedRequestIds: string[] = [];
  private latestSuccessfulSequence: number = 0;
  private failed: boolean = false;

  constructor(confirmedRevision: number = 0) {
    this.confirmedRevision = validRevision(confirmedRevision) ? confirmedRevision : 0;
  }

  createRequest(document: CanvasDocument): FreeCanvasSaveRequest {
    this.sequence++;
    const requestId = 'canvas-save-' + this.sequence;
    this.pending.push({ requestId, sequence: this.sequence });
    this.failed = false;
    return {
      requestId,
      baseRevision: this.confirmedRevision,
      document: cloneCanvasDocument(document)
    };
  }

  applyResult(result: FreeCanvasSaveResult): FreeCanvasSaveResultDisposition {
    if (this.completedRequestIds.includes(result.requestId)) {
      return 'duplicate';
    }
    const requestIndex = this.pending.findIndex((request: PendingSaveRequest): boolean =>
      request.requestId === result.requestId);
    if (requestIndex < 0) {
      return 'stale';
    }
    const request = this.pending[requestIndex];
    if (result.status === 'success' && (result.revision === undefined || !validRevision(result.revision))) {
      this.pending.splice(requestIndex, 1);
      this.completedRequestIds.push(result.requestId);
      this.failed = true;
      return 'invalid';
    }
    this.completedRequestIds.push(result.requestId);
    if (this.completedRequestIds.length > 512) {
      this.completedRequestIds.shift();
    }
    if (result.status === 'failure') {
      this.pending.splice(requestIndex, 1);
      if (request.sequence >= this.latestSuccessfulSequence) {
        this.failed = true;
      }
      return 'applied';
    }
    if (result.revision! <= this.confirmedRevision) {
      this.pending.splice(requestIndex, 1);
      return 'stale';
    }
    this.confirmedRevision = result.revision!;
    this.latestSuccessfulSequence = Math.max(this.latestSuccessfulSequence, request.sequence);
    this.pending = this.pending.filter((pending: PendingSaveRequest): boolean => pending.sequence > request.sequence);
    this.failed = false;
    return 'applied';
  }

  syncConfirmedRevision(revision: number): void {
    if (validRevision(revision) && revision > this.confirmedRevision) {
      this.confirmedRevision = revision;
    }
  }

  getConfirmedRevision(): number {
    return this.confirmedRevision;
  }

  getStatus(): FreeCanvasSaveStatus {
    if (this.pending.length > 0) {
      return 'pending';
    }
    return this.failed ? 'failed' : 'saved';
  }

  hasUnsavedChanges(): boolean {
    return this.getStatus() !== 'saved';
  }
}
