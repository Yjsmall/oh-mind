# oh-mind Canvas Core

`@ohos/mind-elixir` currently provides the pure ArkTS core for CardNote's native free canvas. Version 2 is an incompatible redesign: the former tree-shaped `MindElixir`, `MindElixirCore`, and `NodeObj` APIs have been removed.

The current HAR contains no ArkUI canvas component. `FreeCanvas` and native gestures belong to the next implementation phase.

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

## Validation

The validator rejects malformed documents, unknown fields, duplicate IDs, dangling edges, non-integer node coordinates, non-positive sizes, invalid sides or endpoints, unsupported node types, and invalid CardNote viewport extensions. Missing top-level `nodes` or `edges` are normalized to empty arrays by `parseCanvasJson`.

## Build

Use HarmonyOS SDK `6.1.1(24)` with compatible and target SDK `6.1.0(23)`. `DEVECO_SDK_HOME` must point to the SDK root.

```powershell
ohpm install
hvigorw.bat --no-daemon --mode module -p module=entry@default -p coverage=false test
hvigorw.bat --no-daemon --mode module -p module=library@default assembleHar
```
