import { describe, expect, it } from '@ohos/hypium';
import {
  CanvasDocument,
  CanvasTextNode,
  FreeCanvasChangeDebouncer,
  FREE_CANVAS_CARD_DRAG_THRESHOLD_VP,
  FREE_CANVAS_MARQUEE_LONG_PRESS_MS,
  FREE_CANVAS_PAN_THRESHOLD_VP,
  FreeCanvasGestureMachine,
  primaryNodeForSelection,
  selectNodesForMarquee,
  selectNodesForTap
} from '@ohos/mind-elixir';

function document(text: string): CanvasDocument {
  return {
    nodes: [{ id: 'a', type: 'text', text, x: 0, y: 0, width: 200, height: 100 }],
    edges: []
  };
}

function advanceAndFlush(debouncer: FreeCanvasChangeDebouncer): void {
  debouncer.flush();
}

class TimerCapture {
  callback?: () => void = undefined;
}

export default function freeCanvasGestureStateMachineTest() {
  describe('freeCanvasGestureMachineTest', () => {
    it('turnsQuickEmptyDragIntoPanAndSlowHoldIntoMarquee', 0, () => {
      const machine = new FreeCanvasGestureMachine();
      machine.beginEmpty('touch', 1, 10, 10);
      const quick = machine.moveEmpty(30, 10);
      expect(quick).assertEqual('pan');
      expect(machine.getPhase()).assertEqual('panning');
      expect(machine.endEmpty()).assertEqual('pan');

      machine.beginEmpty('touch', 1, 100, 100);
      machine.confirmLongPress();
      expect(machine.getPhase()).assertEqual('marqueeArmed');
      const slow = machine.moveEmpty(120, 100);
      expect(slow).assertEqual('marquee');
      expect(machine.getPhase()).assertEqual('marqueeActive');
      expect(machine.endEmpty()).assertEqual('marquee');
    });

    it('keepsSmallJitterInsideLongPressToleranceBeforePanThreshold', 0, () => {
      const machine = new FreeCanvasGestureMachine();
      machine.beginEmpty('touch', 1, 50, 50);
      expect(machine.moveEmpty(53, 52)).assertEqual('none');
      machine.confirmLongPress();
      expect(machine.getPhase()).assertEqual('marqueeArmed');
      machine.cancel();
      expect(machine.getPhase()).assertEqual('cancelled');
    });

    it('pinchTakesPriorityOverSingleFingerGestures', 0, () => {
      const machine = new FreeCanvasGestureMachine();
      machine.beginEmpty('touch', 1, 0, 0);
      machine.beginPinch(2);
      expect(machine.getPhase()).assertEqual('pinching');
      expect(machine.moveEmpty(20, 20)).assertEqual('none');
      machine.endPinch();
      expect(machine.getPhase()).assertEqual('idle');
    });

    it('nodeDragRequiresCardThresholdAndTapSelectsBelowIt', 0, () => {
      const machine = new FreeCanvasGestureMachine();
      machine.beginEmpty('touch', 1, 0, 0);
      machine.beginNode();
      expect(machine.getPhase()).assertEqual('nodeWait');
      expect(machine.moveNode(1, 1)).assertEqual('none');
      expect(machine.endNode(2)).assertEqual('select');
      expect(machine.endNode(0, true)).assertEqual('edit');
      machine.beginNode();
      expect(machine.moveNode(FREE_CANVAS_CARD_DRAG_THRESHOLD_VP + 2, 0)).assertEqual('move');
      expect(machine.endNode(FREE_CANVAS_CARD_DRAG_THRESHOLD_VP + 2)).assertEqual('move');
    });
  });

  describe('freeCanvasSelectionSemanticsTest', () => {
    it('marqueeReplacesWithoutMultiSelectAndAppendsWithIt', 0, () => {
      const replace = selectNodesForMarquee(['a', 'b'], ['c', 'd'], false);
      expect(replace.join(',')).assertEqual('c,d');
      const append = selectNodesForMarquee(['a', 'b'], ['b', 'c'], true);
      expect(append.join(',')).assertEqual('a,b,c');
    });

    it('tapTogglesWithMultiSelectAndSelectsOtherwise', 0, () => {
      expect(selectNodesForTap(['a', 'b'], 'b', false, false).join(',')).assertEqual('b');
      const toggle = selectNodesForTap(['a', 'b'], 'b', true, false);
      expect(toggle.join(',')).assertEqual('a');
      const append = selectNodesForTap(['a'], 'b', true, false);
      expect(append.join(',')).assertEqual('a,b');
    });

    it('keepsPrimaryOrPicksLastSelection', 0, () => {
      expect(primaryNodeForSelection(['a', 'b'], 'a')).assertEqual('a');
      expect(primaryNodeForSelection(['x', 'y'], 'a')).assertEqual('y');
      expect(primaryNodeForSelection([], 'a')).assertEqual('');
    });
  });

  describe('freeCanvasChangeDebouncerTest', () => {
    it('mergesRapidOperationsIntoOneLatestCandidateAfterIdle', 0, () => {
      const emitted: CanvasDocument[] = [];
      const debouncer = new FreeCanvasChangeDebouncer(100, {
        onChange: (change) => {
          emitted.push(change.document);
        }
      });
      debouncer.schedule({ reason: 'nodeMove', document: document('one'), selectedNodeIds: [] });
      debouncer.schedule({ reason: 'nodeEdit', document: document('two'), selectedNodeIds: [] });
      debouncer.schedule({ reason: 'nodeColor', document: document('three'), selectedNodeIds: [] });
      expect(debouncer.hasPending()).assertEqual(true);
      expect(debouncer.flush()).assertEqual(true);
      expect(emitted.length).assertEqual(1);
      expect(emitted[0].nodes[0].text).assertEqual('three');
      expect(debouncer.hasPending()).assertEqual(false);
    });

    it('discardsPendingChangeWithoutEmitting', 0, () => {
      let emitted = 0;
      const debouncer = new FreeCanvasChangeDebouncer(100, {
        onChange: () => {
          emitted++;
        }
      });
      debouncer.schedule({ reason: 'nodeMove', document: document('draft'), selectedNodeIds: [] });
      debouncer.discard();
      expect(debouncer.hasPending()).assertEqual(false);
      expect(debouncer.flush()).assertEqual(false);
      expect(emitted).assertEqual(0);
    });

    it('idleTimerPublishesTheLatestCandidateOnlyOnce', 0, () => {
      let emitted = 0;
      let latest = '';
      let scheduledMs = 0;
      const holder = new TimerCapture();
      const debouncer = new FreeCanvasChangeDebouncer(200, {
        startTimer: (cb, ms) => {
          scheduledMs = ms;
          holder.callback = cb;
          return 1;
        },
        clearTimer: () => {
          holder.callback = undefined;
        },
        onChange: (change) => {
          emitted++;
          latest = change.document.nodes[0].text;
        }
      });
      debouncer.schedule({ reason: 'nodeMove', document: document('first'), selectedNodeIds: [] });
      debouncer.schedule({ reason: 'nodeColor', document: document('second'), selectedNodeIds: [] });
      expect(scheduledMs).assertEqual(200);
      if (holder.callback !== undefined) {
        holder.callback();
      }
      expect(emitted).assertEqual(1);
      expect(latest).assertEqual('second');
      if (holder.callback !== undefined) {
        holder.callback();
      }
      expect(emitted).assertEqual(1);
    });
  });
}