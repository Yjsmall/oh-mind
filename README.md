# ohos_mind_elixir

## Introduction

**ohos_mind_elixir** is an open-source mind mapping framework. In response to the advantages of mind mapping, it has the
following features:

- Node linking
- Node drag-and-drop functionality
- Support the right-click menu of nodes
- Support for practical keyboard shortcuts
- Undo and redo functionality
- Support custom modification of node styles and connection line styles

## How to Install

```shell
ohpm install @ohos/mind-elixir
```

For details about the OpenHarmony ohpm environment configuration,see [OpenHarmony HAR](https://ohpm.openharmony.cn/#/cn/help/downloadandinstall).

## How to Use

MindElixir references and usage

```typescript
import { MindElixir, MindElixirData, MindElixirCore, NodeOption, LayoutDirection } from '@ohos/mind-elixir';
import mindElixirData from '../model/MindElixirData';

@Entry
@ComponentV2
struct Index {
  // Basic configuration
  private mindOption: NodeOption = {
    locale: 'zh',                       // Language setting
    draggable: true,                    // Toggle for drag-and-drop node modification
    editable: true,                     // Toggle for double-click node editing
    toolBar: true,                      // Toggle for toolbar
    allowUndo: true,                    // Toggle for operation history recording
    contextMenu: true,                  // Toggle for context menu
    layout: LayoutDirection.RIGHT,      // Mind map orientation
    collapsible: true,                  // Toggle for expand node
    siblingAlignment: true,             // Toggle for sibling node alignment
    nodeShape: 'line',                  // Mind map style: 'line' for straight, 'curve' for curved
    mindInViewport: true,               // Display mind map within the viewport
    nodeSpacing: {
      horizontal: 30,                   // Horizontal node spacing
      vertical: 50                      // Vertical node spacing
    },
    nodeStyle: {                        // Unified node style settings
      fontSize: 20,                     // Node font size
      fontFamily: 'HarmonyOS Sans',     // Node font family
      color: '#333',                    // Node font color
      background: '#fff',               // Node background color
      fontWeight: 'normal',             // Node font weight (bold or normal)
      border: {                         // Node border style settings
        width: 1,                       // Node border width
        radius: 0,                      // Node border radius
        color: '#000',                  // Node border color
      },
      maxWidth: 200,                    // Set node maximum width
      padding: 5                        // Set node padding
    },
    lineStyle: {                        // Connector style settings
      width: 2,                         // Connector width
      color: '#e64553'                  // Connector color
    }
  };

  // MindElixirCore is an imperative command service, not reactive UI state.
  private model: MindElixirCore = new MindElixirCore(this.mindOption);
  private initializedData: MindElixirData = mindElixirData;

  // Page display
  build() {
    RelativeContainer() {
      MindElixir({ model: this.model, data: this.initializedData })
        .height('100%')
        .width('100%')
    }
      .height('100%')
      .width('100%')
  }
}

```

## Core Function Examples
``` typescript
// Add a child node
this.model.add('parent-node-id', 'New Node Name');

// Add a parent node
this.model.addParent('current-node-id', 'New Parent Node Name');

// Add a sibling node
this.model.addSibling('sibling-node-id', true); // true: add before, false: add after

// Delete a node
this.model.remove('node-id-to-delete');

// Move a node position
this.model.move('node-id', MoveDirection.UP); // Move up

// Update node properties
const updatedNode = {
    id: 'node-id',
    topic: 'Updated Node Name',
    style: {
    color: '#ff0000',
    background: '#f0f0f0'
    }
};
this.model.updateNode(updatedNode);

// Set mind map layout direction
this.model.setMindDirection(LayoutDirection.LEFT); // Set to left layout

// Zoom control
this.model.zoomIn();    // Zoom in
this.model.zoomOut();   // Zoom out
this.model.setScaleVal(1.0); // Set zoom scale

// Undo and redo
this.model.undo(); // Undo
this.model.redo(); // Redo

// Node selection
this.model.selectNode('node-id'); // Select node
this.model.getSelectedNode();     // Get selected node data

// Expand and collapse nodes
this.model.expandedNode('node-id'); // Expand node and its children
this.model.foldNode('node-id');     // Collapse node and its children

// Reset position
this.model.resetPosition(); // Reset mind map to center position
```




## Interface Description

### MindElixirCore Interface

| Interface Name    | Parameters                                               | Return Type            | Description                          |
| ----------------- | -------------------------------------------------------- | :--------------------- | -------------------- |
| refresh           | mindElixirData?: MindElixirData                          | void                   | Refresh mind map data                |
| getData           | None                                                     | MindElixirData \| null | Get node data                        |
| add               | id: string, topic?: string                               | boolean                | Add child node                       |
| addParent         | id: string, topic?: string                               | boolean                | Add parent node                      |
| addSibling        | id: string, isBefore?: boolean                           | boolean                | Add sibling node                     |
| remove            | id: string                                               | boolean                | Delete node                          |
| move              | id: string, direction: MoveDirection                     | boolean                | Move node up/down at same level      |
| updateNode        | updatedNode: NodeObj                                     | boolean                | Update node                          |
| setMindDirection  | direction: LayoutDirection                               | LayoutDirection        | Set mind map layout direction        |
| getMindDirection  | None                                                     | LayoutDirection        | Get mind map layout direction        |
| setScaleVal       | value: number                                            | void                   | Set zoom scale                       |
| getScaleVal       | None                                                     | number                 | Get zoom scale                       |
| zoomIn            | None                                                     | void                   | Zoom in mind map                     |
| zoomOut           | None                                                     | void                   | Zoom out mind map                    |
| undo              | None                                                     | boolean                | Undo to previous state               |
| redo              | None                                                     | boolean                | Redo undone operation                |
| getSelectedNodeId | None                                                     | string                 | Get selected node ID                 |
| getSelectedNode   | None                                                     | NodeObj \| null        | Get selected node data               |
| selectNode        | id: string                                               | boolean                | Set selected node                    |
| expandedNode      | id: string                                               | void                   | Expand node and its children         |
| foldNode          | id: string                                               | void                   | Collapse node and its children       |
| resetPosition     | None                                                     | void                   | Reset mind map position              |
| startLink         | nodeId: string, isLink: boolean, bidirectional?: boolean | void                   | Start creating node link             |
| renderLink        | endNodeId: string                                        | void                   | Render link between nodes            |
| updateLinkLabel   | arrowId: string, newLabel: string                        | void                   | Change link label                    |
| destroy           | None                                                     | void                   | Destroy instance, clean up resources |


### Enum Types
```typescript
enum LayoutDirection {
  LEFT = 0,    // Left layout
  RIGHT = 1    // Right layout
  TOP = 2,     // Top layout
  BOTTOM = 3,  // Bottom layout
}

enum MoveDirection {
  UP,          // Move up
  DOWN         // Move down
}

enum DragOrientation {
  TOP,         // Drag to top of target node
  MIDDLE,      // Drag to middle of target node (as child node)
  BOTTOM       // Drag to bottom of target node
}
```

###  NodeOption Configuration Options

| Parameter Name   | Type            | Default Value                    | Description                   |
|--------------------| ---------------- |----------------------------------|-------------------------------|
| locale           | string          | 'zh'                             | Language setting              |
| draggable        | boolean         | false                            | Node drag-and-drop toggle     |
| editable         | boolean         | false                            | Node editing toggle           |
| toolBar          | boolean         | false                            | Toolbar toggle                |
| allowUndo        | boolean         | false                            | Undo/redo toggle              |
| contextMenu      | boolean         | false                            | Context menu toggle           |
| layout           | LayoutDirection | LayoutDirection.RIGHT            | Mind map layout direction     |
| siblingAlignment | boolean         | false                            | Sibling node alignment toggle |
| nodeShape        | string          | 'line'                           | Node shape (line/curve)       |
| mindInViewport   | boolean         | false                            | Display mind map in viewport  |
| collapsible      | boolean         | false                            | Node expand toggle            |
| nodeSpacing      | Object          | { horizontal: 50, vertical: 30 } | Node spacing configuration    |
| nodeStyle        | Object          | See below                        | Node style configuration      |
| lineStyle        | Object          | { width: 2, color: '#e64553' }   | Connector style configuration |

###  NodeStyle Node Style Configuration

| Parameter Name | Type          | Default Value    | Description      |
|--------------------| ---------------- |--------------------| ---------------- |
| fontSize       | number        | 20               | Font size        |
| fontFamily     | string        | 'HarmonyOS Sans' | Font family      |
| color          | string        | '#333'           | Font color       |
| background     | string        | '#fff'           | Background color |
| fontWeight     | string        | 'normal'         | Font weight      |
| border         | BorderOptions | { width: 2 }     | Border style     |
| maxWidth       | number        | 200              | Maximum width    |
| padding        | number        | 10               | Padding          |

###  NodeObj Node Object Structure

```typescript
interface NodeObj {
    id: string;                  // Node ID
    topic: string;               // Node topic
    children?: NodeObj[];        // Array of child nodes
    expanded?: boolean;          // Whether expanded
    style?: NodeStyle;           // Node style
    tags?: string[];             // Tags
    direction?: LayoutDirection; // Node direction
    // Properties calculated for layout...
    x?: number;                  // X coordinate
    y?: number;                  // Y coordinate
    level?: number;              // Level
    width?: number;              // Width
    height?: number;             // Height
    subtreeWidth?: number;       // Subtree width
    subtreeHeight?: number;      // Subtree height
    richText?: RichTextSpan[];    // RichText
}
```

###  Arrow Structure

```typescript
interface Arrow {
    id: string;                  // Arrow ID
    from: string;                // Source node ID
    to: string;                  // Target node ID
    label?: string;              // Link label
    bidirectional?: boolean;     // Whether bidirectional link
}
```

## Shortcut Keys

| Shortcut Key       | Function                   |
| ------------------ | -------------------------- |
| Ctrl + Z           | Undo                       |
| Ctrl + Y           | Redo                       |
| Alt + Enter        | Insert sibling node        |
| Shift + Enter      | Insert sibling node before |
| Tab                | Insert child node          |
| Ctrl + Enter       | Insert parent node         |
| Delete / Backspace | Delete node                |
| Ctrl + C           | Copy                       |
| Ctrl + V           | Paste                      |
| Ctrl + X           | Cut                        |
| Ctrl + "+"         | Zoom in mind map           |
| Ctrl + "-"         | Zoom out mind map          |
| Ctrl + 0           | Reset mind map             |

## Constraints and Limitations

Verified with HarmonyOS Command Line Tools 6.1.1 (API 24), targeting and remaining compatible with HarmonyOS API 23.

API 24 is used only as the installed compilation toolchain. The application API baseline and all platform API calls are
limited to API 23 or earlier. Its ArkUI components use state management V2 (`@ComponentV2`, `@Param`, `@Event`,
`@Local`, and `@Monitor`).

## Directory Structure

```javascript
    |---- MindElixir
    |     |---- entry                                             # Example code folder
    |     |---- library                                           # MindElixir library folder
    |           |---- src
    |           	 |---- main
    |           		  |---- ets
    |          				   |---- controller                   # Controller layer
    |      					        |---- MindElixirCore.ets      # Core interface class
    |      					        |---- MindLineRender.ets      # Line renderer
    |      					        |---- NodeHelper.ets          # Node helper
    |          				   |---- model                        # Data model
    |      					        |---- NodeObj.ets             # Node object definition
    |          				   |---- utils                        # Utility classes
    |      					        |---- CanvasPositionUtils.ets # Canvas position utility
    |      					        |---- ZoomUtils.ets           # Zoom utility
    |      					        |---- ShortcutManager.ets     # Shortcut key manager
    |      					        |---- UtilsManager.ets        # Utility manager
    |          				   |---- view                         # View layer
    |      					        |---- components              # Components
    |     |---- README_zh.md                                         # Chinese documentation
    |     |---- README.md                                      # English documentation
```

## How to Contribute

If you encounter any issues during use, please submit an [Issue](https://gitee.com/openharmony-tpc-incubate/ohos_mind_elixir/issues) to the component. Of course, [PR](https://gitee.com/openharmony-tpc-incubate/ohos_mind_elixir/pulls) contributions are also very welcome for collaborative development.

## License

This project is based on [Apache License 2.0](https://gitee.com/openharmony-tpc-incubate/ohos_mind_elixir/blob/master/LICENSE). Feel free to enjoy and participate in open source.
