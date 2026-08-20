# oh-mind Canvas Core

`@ohos/mind-elixir` 提供 CardNote 使用的 JSON Canvas 核心和 ArkUI V2 自由画布组件。2.0 是不兼容重构，旧树状 `MindElixir`、`MindElixirCore` 和 `NodeObj` API 已删除。

`FreeCanvas` 在 Canvas 层绘制连线，并在上层定位原生 ArkUI 节点内容。当前支持单选、多选、框选、节点拖拽、八向缩放、画布平移、双指和滚轮缩放、适应内容、视口复位与方向键微调。手势草稿留在组件内部，每个完整操作只向宿主发出一次候选快照。

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

### ArkUI 组件

```typescript
@ComponentV2
struct MindMapView {
  @Require @Param document: CanvasDocument;
  private readonly canvasController = new FreeCanvasController();

  build() {
    FreeCanvas({
      document: this.document,
      controller: this.canvasController,
      onChangeComplete: (event: FreeCanvasChangeEvent): void => {
        // 把 event.document 提交到宿主持久化边界。
      }
    })
  }
}
```

控制器提供 `fitContent`、`resetViewport`、`setInteractionMode('select' | 'pan')` 和 `clearSelection`。宿主可通过 `nodeContentBuilder` 传入 `WrappedBuilder<[CanvasTextNode, Object]>`，使用原生 ArkUI 展示 Markdown/LaTeX；不传时使用纯文本回退。组件不访问持久化、PDF 状态、ArkWeb 或原生解析模块。

## 校验

校验器会拒绝非法文档、未知字段、重复 ID、悬空边、非整数节点坐标、非正尺寸、非法锚点或端点、不支持的节点类型，以及非法 CardNote 视口扩展。`parseCanvasJson` 会把缺省的顶层 `nodes` 或 `edges` 归一化为空数组。

## 构建

使用 HarmonyOS SDK `6.1.1(24)`，compatible 和 target SDK 为 `6.1.0(23)`。`DEVECO_SDK_HOME` 必须指向 SDK 根目录。

```powershell
ohpm install
hvigorw.bat --no-daemon --mode module -p module=entry@default -p coverage=false test
hvigorw.bat --no-daemon --mode module -p module=library@default assembleHar
hvigorw.bat --no-daemon --mode module -p module=entry@default assembleHap
hvigorw.bat --no-daemon --mode module -p module=entry@ohosTest assembleHap
```
