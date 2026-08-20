# oh-mind Canvas Core

`@ohos/mind-elixir` 当前提供 CardNote 原生自由画布的纯 ArkTS 核心。2.0 是不兼容重构，旧树状 `MindElixir`、`MindElixirCore` 和 `NodeObj` API 已删除。

当前 HAR 不包含 ArkUI 画布组件。`FreeCanvas` 和原生手势属于下一实施阶段。

## 数据契约

持久化快照采用 JSON Canvas 1.0 的文本节点与连线子集：

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

节点数组顺序表达从底到顶的层级。`file`、`link` 和 `group` 节点会收到明确的不支持错误。选择、编辑状态、手势草稿、撤销历史和 PDF 高亮引用不写入快照。

## 使用方式

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

`executeTransaction` 保证原子性，并且最多产生一个撤销项。任一命令失败时，当前快照和历史都保持不变。API 边界会深拷贝输入和返回快照。

支持的命令包括 `addNode`、`updateNode`、`removeNode`、`reorderNode`、`addEdge`、`updateEdge`、`removeEdge`、`setViewport` 和 `clearViewport`。删除节点时会同时删除与其相连的边。

## 校验

校验器会拒绝非法文档、未知字段、重复 ID、悬空边、非整数节点坐标、非正尺寸、非法锚点或端点、不支持的节点类型，以及非法 CardNote 视口扩展。`parseCanvasJson` 会把缺省的顶层 `nodes` 或 `edges` 归一化为空数组。

## 构建

使用 HarmonyOS SDK `6.1.1(24)`，compatible 和 target SDK 为 `6.1.0(23)`。`DEVECO_SDK_HOME` 必须指向 SDK 根目录。

```powershell
ohpm install
hvigorw.bat --no-daemon --mode module -p module=entry@default -p coverage=false test
hvigorw.bat --no-daemon --mode module -p module=library@default assembleHar
```
