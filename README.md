# oh-mind Canvas Core

`@ohos/mind-elixir` provides the JSON Canvas core and ArkUI V2 free-canvas component used by CardNote. Version 2 is an incompatible redesign: the former tree-shaped `MindElixir`, `MindElixirCore`, and `NodeObj` APIs have been removed.

`FreeCanvas` renders edges in a Canvas layer and positions native ArkUI node content above it. It supports text-node creation and editing, colors and z-order, selection, multi-selection, marquee selection, node dragging, eight resize handles, canvas panning, pinch and wheel zoom, fit-to-content, viewport reset, and arrow-key nudging. Four-side anchors create edges; selected edges support labels, four direction modes, deletion, and endpoint reconnection. Copy, delete, undo, redo, alignment, row/column arrangement, equal distribution, and explicit deterministic auto-arrange are available through the controller. Gesture and text-edit drafts remain inside the component; the host receives one save request when an operation completes.

## Data Contract

The persisted snapshot is the JSON Canvas 1.0 text-node and edge subset:

```json
{
  "nodes": [
    {
      "id": "note-a",
      "type": "text",
      "text": "# Note A",
      "x": 0,
      "y": 0,
      "width": 240,
      "height": 160
    }
  ],
  "edges": [],
  "cardnote": {
    "schemaVersion": 1,
    "viewport": { "x": 0, "y": 0, "scale": 1 }
  }
}
```

Node array order is the bottom-to-top z-order. `file`, `link`, and `group` nodes are rejected explicitly. Selection, edit state, gesture drafts, undo history, and PDF highlight references are not persisted in the snapshot.

## Usage

```typescript
import {
  CanvasCommand,
  CanvasController,
  CanvasDocument,
  parseCanvasJson,
  serializeCanvasJson
} from '@ohos/mind-elixir';

const initial: CanvasDocument = parseCanvasJson('{"nodes":[],"edges":[]}');
const controller = new CanvasController(initial, { historyLimit: 100 });
const commands: CanvasCommand[] = [
  {
    kind: 'addNode',
    node: {
      id: 'note-a',
      type: 'text',
      text: '# Note A',
      x: 0,
      y: 0,
      width: 240,
      height: 160
    }
  },
  { kind: 'setViewport', viewport: { x: 0, y: 0, scale: 1 } }
];

controller.executeTransaction(commands);
const snapshot: CanvasDocument = controller.getSnapshot();
const json: string = serializeCanvasJson(snapshot);
```

`executeTransaction` is atomic and creates at most one undo item. A failed command leaves the current snapshot and history unchanged. Inputs and returned snapshots are deep-cloned at the API boundary.

Supported commands are `addNode`, `updateNode`, `removeNode`, `reorderNode`, `addEdge`, `updateEdge`, `removeEdge`, `setViewport`, and `clearViewport`. Removing a node also removes its connected edges.

### ArkUI component

```typescript
@ComponentV2
struct MindMapView {
  @Require @Param document: CanvasDocument;
  @Require @Param revision: number;
  @Require @Param saveResult: FreeCanvasSaveResult | undefined;
  private readonly canvasController = new FreeCanvasController();

  build() {
    FreeCanvas({
      document: this.document,
      controller: this.canvasController,
      committedRevision: this.revision,
      saveResult: this.saveResult,
      onChangeComplete: (event: FreeCanvasChangeEvent): void => {
        // Persist event.document using event.requestId and event.baseRevision.
      },
      onNodeActivate: (nodeId: string): void => {
        // Resolve references and navigate in the host.
      }
    })
  }
}
```

Each completion event contains a process-unique, session-prefixed monotonic `requestId`, the last confirmed `baseRevision`, and an immutable candidate document. Feed the matching `FreeCanvasSaveResult` back through `saveResult`; only a successful result advances the confirmed revision. Failure retains a visible retryable draft, while duplicate and out-of-order results cannot regress the session. The host remains responsible for serial persistence and authoritative committed snapshots.

The controller exposes viewport and selection commands plus `addTextNode`, `editSelectedNode`, `commitNodeEdit`, `cancelNodeEdit`, `setSelectedNodesColor`, `reorderSelectedNode`, `activateSelectedNode`, `retrySave`, undo/redo, copy/delete, layout, and edge editing. Node activation emits only the node ID and never changes the snapshot. Pass a `WrappedBuilder<[CanvasTextNode, Object]>` through `nodeContentBuilder` to render native Markdown/LaTeX content; without one, the component uses a plain-text fallback. The component does not access persistence, PDF state, ArkWeb, or native parsing modules.

Undo history is bounded and session-only. A completed drag, resize, viewport gesture, edge operation, copy/delete, or layout command creates at most one history item. Ordinary snapshot loading never invokes auto-arrange; only an explicit `autoArrange` command changes the layout.

## Validation

The validator rejects malformed documents, unknown fields, duplicate IDs, dangling edges, non-integer node coordinates, non-positive sizes, invalid sides or endpoints, unsupported node types, and invalid CardNote viewport extensions. Missing top-level `nodes` or `edges` are normalized to empty arrays by `parseCanvasJson`.

## Build

Use HarmonyOS SDK `6.1.1(24)` with compatible and target SDK `6.1.0(23)`. `DEVECO_SDK_HOME` must point to the SDK root.

```powershell
ohpm install
hvigorw.bat --no-daemon --mode module -p module=entry@default -p coverage=false test
hvigorw.bat --no-daemon --mode module -p module=library@default assembleHar
hvigorw.bat --no-daemon --mode module -p module=entry@default assembleHap
hvigorw.bat --no-daemon --mode module -p module=entry@ohosTest assembleHap
```
