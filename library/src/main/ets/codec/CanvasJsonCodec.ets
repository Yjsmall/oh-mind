import { CanvasDocument, cloneCanvasDocument } from '../model/CanvasModel';
import { CanvasValidationError, validateCanvasDocument } from '../model/CanvasValidation';

export type CanvasJsonCodecErrorCode = 'INVALID_JSON';

export class CanvasJsonCodecError extends Error {
  readonly code: CanvasJsonCodecErrorCode;

  constructor(message: string) {
    super(message);
    this.code = 'INVALID_JSON';
  }
}

export function parseCanvasJson(json: string): CanvasDocument {
  let parsed: CanvasDocument;
  try {
    parsed = JSON.parse(json) as CanvasDocument;
  } catch (_error) {
    throw new CanvasJsonCodecError('Invalid Canvas JSON: malformed JSON text');
  }

  validateCanvasDocument(parsed);
  return cloneCanvasDocument({
    nodes: parsed.nodes === undefined ? [] : parsed.nodes,
    edges: parsed.edges === undefined ? [] : parsed.edges,
    cardnote: parsed.cardnote
  });
}

export function serializeCanvasJson(document: CanvasDocument): string {
  validateCanvasDocument(document);
  return JSON.stringify(cloneCanvasDocument(document));
}

export { CanvasValidationError };
