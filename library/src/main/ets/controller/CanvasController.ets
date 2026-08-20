import { CanvasCommand, applyCanvasTransaction } from '../commands/CanvasCommand';
import { CanvasDocument, cloneCanvasDocument } from '../model/CanvasModel';
import { validateCanvasDocument } from '../model/CanvasValidation';
import { serializeCanvasJson } from '../codec/CanvasJsonCodec';

const DEFAULT_HISTORY_LIMIT: number = 100;

export interface CanvasControllerOptions {
  readonly historyLimit?: number;
}

export type CanvasControllerErrorCode = 'INVALID_HISTORY_LIMIT';

export class CanvasControllerError extends Error {
  readonly code: CanvasControllerErrorCode;

  constructor(code: CanvasControllerErrorCode, message: string) {
    super(message);
    this.code = code;
  }
}

function createEmptyCanvasDocument(): CanvasDocument {
  return {
    nodes: [],
    edges: []
  };
}

export class CanvasController {
  private document: CanvasDocument;
  private undoHistory: CanvasDocument[] = [];
  private redoHistory: CanvasDocument[] = [];
  private readonly historyLimit: number;

  constructor(initialDocument: CanvasDocument = createEmptyCanvasDocument(), options: CanvasControllerOptions = {}) {
    const historyLimit = options.historyLimit ?? DEFAULT_HISTORY_LIMIT;
    if (!Number.isInteger(historyLimit) || historyLimit <= 0) {
      throw new CanvasControllerError('INVALID_HISTORY_LIMIT', 'Canvas historyLimit must be a positive integer');
    }
    validateCanvasDocument(initialDocument);
    this.document = cloneCanvasDocument(initialDocument);
    this.historyLimit = historyLimit;
  }

  getSnapshot(): CanvasDocument {
    return cloneCanvasDocument(this.document);
  }

  replaceSnapshot(document: CanvasDocument): CanvasDocument {
    validateCanvasDocument(document);
    this.document = cloneCanvasDocument(document);
    this.clearHistory();
    return this.getSnapshot();
  }

  commitSnapshot(document: CanvasDocument): CanvasDocument {
    validateCanvasDocument(document);
    const candidate = cloneCanvasDocument(document);
    if (serializeCanvasJson(this.document) === serializeCanvasJson(candidate)) {
      return this.getSnapshot();
    }
    this.pushBounded(this.undoHistory, this.document);
    this.redoHistory = [];
    this.document = candidate;
    return this.getSnapshot();
  }

  execute(command: CanvasCommand): CanvasDocument {
    return this.executeTransaction([command]);
  }

  executeTransaction(commands: CanvasCommand[]): CanvasDocument {
    const before = cloneCanvasDocument(this.document);
    const candidate = applyCanvasTransaction(before, commands);
    if (serializeCanvasJson(before) === serializeCanvasJson(candidate)) {
      return this.getSnapshot();
    }

    this.pushBounded(this.undoHistory, before);
    this.redoHistory = [];
    this.document = candidate;
    return this.getSnapshot();
  }

  canUndo(): boolean {
    return this.undoHistory.length > 0;
  }

  canRedo(): boolean {
    return this.redoHistory.length > 0;
  }

  undo(): boolean {
    const previous = this.undoHistory.pop();
    if (previous === undefined) {
      return false;
    }
    this.pushBounded(this.redoHistory, this.document);
    this.document = previous;
    return true;
  }

  redo(): boolean {
    const next = this.redoHistory.pop();
    if (next === undefined) {
      return false;
    }
    this.pushBounded(this.undoHistory, this.document);
    this.document = next;
    return true;
  }

  clearHistory(): void {
    this.undoHistory = [];
    this.redoHistory = [];
  }

  private pushBounded(history: CanvasDocument[], document: CanvasDocument): void {
    history.push(cloneCanvasDocument(document));
    if (history.length > this.historyLimit) {
      history.shift();
    }
  }
}
