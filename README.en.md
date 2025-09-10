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

For details about the OpenHarmony ohpm environment
configuration,see [OpenHarmony HAR](https://gitcode.com/openharmony-tpc/docs/blob/master/OpenHarmony_har_usage.md)

## How to Use

MindElixir references and usage

```typescript
import { MindElixir, MindElixirData, MindElixirCore, NodeOption } from '@ohos/mind-elixir';
import mindElixirData from '../model/MindElixirData2';

@Entry
@Component
struct Index {
  // basic configuration
  private mindOption: NodeOption = {
    locale: 'zh',                       // Setting the language
    draggable: true,					// Whether the node can be dragged
    editable: true,						// Double-click to modify the node information
    toolBar: true,						// Whether to open the tool bar
    allowUndo: true,					// Whether to record operation history
    layout: LayoutDirection.RIGHT,		// Mind map orientation
    nodeShape: 'line',					// Mind map style line, curve
    mindInViewport: true,               // The mind map is displayed in the visual area
    nodeSpacing: {
      horizontal: 30,                   // Setting the horizontal interval of nodes
      vertical: 50                      // Setting the vertical distance between nodes
    },
    nodeStyle: {                        // Setting the unified style of the node
      fontSize: 20,                         // Setting the font size of the node
      fontFamily: 'HarmonyOS Sans',         // Setting the font style of the node
      color: '#333',						// Setting the font color of the node
      background: '#fff',                   // Setting the background color of the node
      fontWeight: 'normal',                 // Setting the font weight of the node
      border: {                         // Setting the border of the node
        width: 1,                           // Setting the border width of the node
        radius: 0,							// Setting the border radius of the node
        color: '#000',						// Setting the border color of the node
      },
      maxWidth: 200,						// Setting the maximum width of the node
      padding: 5							// Setting the node padding
    }
  };
   
  @State model: MindElixirCore = new MindElixirCore(this.mindOption);
  private initializedData: MindElixirData = mindElixirData;

   // Web Presentation
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

## Available APIs

### MindElixirCore APIs

| API               | **Parameter**                               | **Description**                                                                                                                                                  |
|-------------------|---------------------------------------------|:-----------------------------------------------------------------------------------------------------------------------------------------------------------------|
| getData           | N/A                                         | Obtain the original node data.                                                                                                                                   |
| add               | id: string, <br/>topic: string = 'new node' | Add child node.<br/>**id**：father node ID.<br/>**topic**：node topic.                                                                                             |
| addParent         | id: string, <br/>topic: string = 'new node' | Add parent node.<br/>**id**：node ID.<br/>**topic**：node name.                                                                                                    |
| addSibling        | id: string,<br/>isBefore?: boolean          | Add sibling nodes.<br/>**id**：node ID.<br/>**isBefore**：Before or after the current node.                                                                        |
| remove            | id: string                                  | Delete Node.<br/>**id**：The node ID to be deleted.                                                                                                               |
| move              | id: string, <br/>direction: MoveDirection   | Nodes at the same level move up and down.<br/>**id**：Current mobile node ID.<br/>**direction**：moving direction（MoveDirection.UP  ,MoveDirection.DOWN）.          |
| updateNode        | updatedNode: NodeObj                        | Update node attributes.<br/>**updatedNode**：Information of the node object to be updated.                                                                        |
| setMindDirection  | direction: number                           | Set the layout direction of the mind map.<br/>**direction**: layout direction (The default layout is on the right side，0：left side layout，1：right  side layout). |
| getMindDirection  | N/A                                         | Obtain the layout direction of the mind map.                                                                                                                     |
| setScaleVal       | value: number                               | Set the zoom ratio，default is 1.                                                                                                                                 |
| getScaleVal       | N/A                                         | Get the zoom ratio.                                                                                                                                              |
| getCanvasSize     | N/A                                         | Get the canvas size.                                                                                                                                             |
| undo              | N/A                                         | Undo to the previous state.                                                                                                                                      |
| redo              | N/A                                         | Redo the revoked operation.                                                                                                                                      |
| getArrowsData     | N/A                                         | Obtain arrow data.                                                                                                                                               |
| getSelectedNodeId | N/A                                         | Obtain the ID of the selected node.                                                                                                                              |
| getSelectedNode   | N/A                                         | Obtain the data of the selected node.                                                                                                                            |
| selectNode        | nodeId: string \| null                      | Set the selected node.<br/>**nodeId**：Selected Node ID，If passed in null，cancel selected.                                                                        |
| expandedNode      | selectNodeId: string                        | Expand node.<br/>**selectNodeId**：Expand node ID.                                                                                                                |
| foldNode          | selectNodeId: string                        | Fold node.<br/>**selectNodeId**：fold node ID.                                                                                                                    |
| resetPosition     | N/A                                         | Reset the canvas position to the origin.                                                                                                                         |

## Shortcut Key

| shortcut key       | function                        |
|--------------------|---------------------------------|
| Ctrl + Z           | revocation                      |
| Ctrl + Y           | redo                            |
| Alt + Enter        | Insert sibling nodes            |
| Shift + Enter      | Insert the sibling node forward |
| Tab                | Insert a child node             |
| Ctrl + Enter       | Insert the parent node          |
| Delete / Backspace | Delete Node                     |
| Ctrl + C           | copy                            |
| Ctrl + V           | paste                           |
| Ctrl + X           | cut                             |
| Ctrl + "+"         | Enlarge the mind map            |
| Ctrl + "-"         | Shrink the mind map             |
| Ctrl + 0           | Reset the mind map              |

## Constraints

This project has been verified in the following versions：
DevEco Studio 5.1.0 Release(5.1.0.849), SDK: API17(5.0.5)。

## Directory Structure

```javascript
|----MindElixir
|     |---- entry  # Example code folder
|     |---- library  # MindElixir library
|           |----src
|           	 |----main
|           		  |----ets
|          				   |----controller
|      					        |----MindElixirCore   # MindElixir external APIs
|     |---- README.MD  # Readme
|     |---- README_zh.MD  # Readme  
```

## How to Contribute

If you find any problem when using the project, submit an Issue or a PR .

## License

This project is licensed under MIT License.

