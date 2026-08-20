import { describe, expect, it } from '@ohos/hypium';
import { CanvasDocument, FreeCanvasSaveSession } from '@ohos/mind-elixir';

function saveDocument(text: string): CanvasDocument {
  return {
    nodes: [{ id: 'a', type: 'text', text, x: 0, y: 0, width: 200, height: 100 }],
    edges: []
  };
}

export default function freeCanvasSaveSessionTest() {
  describe('freeCanvasSaveSessionTest', () => {
    it('issuesMonotonicRequestsFromConfirmedRevision', 0, () => {
      const session = new FreeCanvasSaveSession(4, 'test-session');
      const first = session.createRequest(saveDocument('one'));
      const second = session.createRequest(saveDocument('two'));
      expect(first.requestId).assertEqual('test-session-save-1');
      expect(second.requestId).assertEqual('test-session-save-2');
      expect(first.baseRevision).assertEqual(4);
      expect(second.baseRevision).assertEqual(4);
      expect(session.getStatus()).assertEqual('pending');
    });

    it('keepsRequestIdsUniqueAcrossCanvasSessions', 0, () => {
      const firstSession = new FreeCanvasSaveSession();
      const secondSession = new FreeCanvasSaveSession();

      const first = firstSession.createRequest(saveDocument('one'));
      const second = secondSession.createRequest(saveDocument('two'));

      expect(first.requestId === second.requestId).assertFalse();
    });

    it('advancesOnlyAfterSuccessfulHostResults', 0, () => {
      const session = new FreeCanvasSaveSession();
      const first = session.createRequest(saveDocument('one'));
      const second = session.createRequest(saveDocument('two'));
      expect(session.applyResult({ requestId: first.requestId, status: 'success', revision: 1 }))
        .assertEqual('applied');
      expect(session.getConfirmedRevision()).assertEqual(1);
      expect(session.getStatus()).assertEqual('pending');
      expect(session.applyResult({ requestId: second.requestId, status: 'success', revision: 2 }))
        .assertEqual('applied');
      expect(session.getConfirmedRevision()).assertEqual(2);
      expect(session.getStatus()).assertEqual('saved');
    });

    it('retainsFailedDraftAndRetriesFromLastConfirmedRevision', 0, () => {
      const session = new FreeCanvasSaveSession(7);
      const request = session.createRequest(saveDocument('draft'));
      expect(session.applyResult({ requestId: request.requestId, status: 'failure', message: 'disk full' }))
        .assertEqual('applied');
      expect(session.getConfirmedRevision()).assertEqual(7);
      expect(session.getStatus()).assertEqual('failed');
      expect(session.hasUnsavedChanges()).assertEqual(true);
      const retry = session.createRequest(request.document);
      expect(retry.baseRevision).assertEqual(7);
      expect(retry.document.nodes[0].text).assertEqual('draft');
    });

    it('ignoresDuplicateAndOutOfOrderResults', 0, () => {
      const session = new FreeCanvasSaveSession();
      const older = session.createRequest(saveDocument('older'));
      const newer = session.createRequest(saveDocument('newer'));
      expect(session.applyResult({ requestId: newer.requestId, status: 'success', revision: 2 }))
        .assertEqual('applied');
      expect(session.applyResult({ requestId: older.requestId, status: 'success', revision: 1 }))
        .assertEqual('stale');
      expect(session.applyResult({ requestId: newer.requestId, status: 'success', revision: 2 }))
        .assertEqual('duplicate');
      expect(session.getConfirmedRevision()).assertEqual(2);
      expect(session.getStatus()).assertEqual('saved');
    });

    it('turnsMalformedSuccessIntoRetryableFailure', 0, () => {
      const session = new FreeCanvasSaveSession(3);
      const request = session.createRequest(saveDocument('draft'));
      expect(session.applyResult({ requestId: request.requestId, status: 'success' })).assertEqual('invalid');
      expect(session.getConfirmedRevision()).assertEqual(3);
      expect(session.getStatus()).assertEqual('failed');
    });
  });
}
