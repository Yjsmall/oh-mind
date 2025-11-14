# ohos_mind_elixir

## 简介

**ohos_mind_elixir** 是一个开源的思维导图框架，针对思维导图的优势，拥有以下特性：

- 节点关联
- 节点拖拽功能
- 支持节点右键菜单
- 支持实用快捷键操作
- 撤销与重做
- 支持自定义修改节点样式和连接线样式
- 支持功能动态化配置

## 下载安装

```shell
ohpm install @ohos/mind-elixir
```

OpenHarmony ohpm环境配置等更多内容，请参考[如何安装OpenHarmony ohpm](https://ohpm.openharmony.cn/#/cn/help/downloadandinstall)。



## 使用说明

MindElixir引用及使用

```typescript
import { MindElixir, MindElixirData, MindElixirCore, NodeOption, LayoutDirection } from '@ohos/mind-elixir';
import mindElixirData from '../model/MindElixirData2';

@Entry
@Component
struct Index {
  // 基础配置
  private mindOption: NodeOption = {
    locale: 'zh',                       // 语言设置
    draggable: true,                    // 可拖拽修改节点开关
    editable: true,                     // 双击修改节点信息开关
    toolBar: true,                      // 工具栏开关
    allowUndo: true,                    // 记录操作历史开关
    contextMenu: true,                  // 上下文菜单开关
    layout: LayoutDirection.RIGHT,      // 思维导图朝向
    collapsible: true,                  // 节点可展开开关
    siblingAlignment: true,             // 兄弟节点对齐开关
    nodeShape: 'line',                  // 思维导图样式 line直线、curve曲线
    mindInViewport: true,               // 思维导图显示在可视区域内
    nodeSpacing: {
      horizontal: 30,                   // 节点水平间隔
      vertical: 50                      // 节点垂直间隔
    },
    nodeStyle: {                        // 节点统一样式设置
      fontSize: 20,                     // 节点字体大小
      fontFamily: 'HarmonyOS Sans',     // 节点字体样式
      color: '#333',                    // 节点字体颜色
      background: '#fff',               // 节点背景颜色
      fontWeight: 'normal',             // 节点字体是否加粗
      border: {                         // 节点边框样式设置
        width: 1,                       // 节点边框宽度
        radius: 0,                      // 节点边框圆角大小
        color: '#000',                  // 节点边框颜色
      },
      maxWidth: 200,                    // 设置节点最大宽度
      padding: 5                        // 设置节点边距
    },
    lineStyle: {                        // 连接线样式设置
      width: 2,                         // 连接线宽度
      color: '#e64553'                  // 连接线颜色
    }
  };

  @State model: MindElixirCore = new MindElixirCore(this.mindOption);
  private initializedData: MindElixirData = mindElixirData;

  // 页面展示
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

## 核心功能示例
``` typescript
// 添加子节点
this.model.add('parent-node-id', '新节点名称');

// 添加父节点
this.model.addParent('current-node-id', '新父节点名称');

// 添加兄弟节点
this.model.addSibling('sibling-node-id', true); // true表示在前面添加，false表示在后面添加

// 删除节点
this.model.remove('node-id-to-delete');

// 移动节点位置
this.model.move('node-id', MoveDirection.UP); // 向上移动

// 更新节点属性
const updatedNode = {
    id: 'node-id',
    topic: '更新后的节点名称',
    style: {
    color: '#ff0000',
    background: '#f0f0f0'
    }
};
this.model.updateNode(updatedNode);

// 设置思维导图布局方向
this.model.setMindDirection(LayoutDirection.LEFT); // 设置为左侧布局

// 缩放控制
this.model.zoomIn();    // 放大
this.model.zoomOut();   // 缩小
this.model.setScaleVal(1.0); // 设置缩放比例

// 撤销重做
this.model.undo(); // 撤销
this.model.redo(); // 重做

// 节点选择
this.model.selectNode('node-id'); // 选择节点
this.model.getSelectedNode();     // 获取选中节点

// 展开折叠节点
this.model.expandedNode('node-id'); // 展开节点及其子节点
this.model.foldNode('node-id');     // 折叠节点及其子节点

// 重置位置
this.model.resetPosition(); // 重置思维导图到中心位置
```




## 接口说明

### MindElixirCore 接口

| 接口名            | 参数                                                     | 返回值                 | 说明                 |
| ----------------- | -------------------------------------------------------- | :--------------------- | -------------------- |
| refresh           | mindElixirData?: MindElixirData                          | void                   | 刷新思维导图数据     |
| getData           | 无                                                       | MindElixirData \| null | 获取节点数据         |
| add               | id: string, topic?: string                               | boolean                | 添加子节点           |
| addParent         | id: string, topic?: string                               | boolean                | 添加父节点           |
| addSibling        | id: string, isBefore?: boolean                           | boolean                | 添加兄弟节点         |
| remove            | id: string                                               | boolean                | 删除节点             |
| move              | id: string, direction: MoveDirection                     | boolean                | 同级节点上下移动     |
| updateNode        | updatedNode: NodeObj                                     | boolean                | 更新节点             |
| setMindDirection  | direction: LayoutDirection                               | LayoutDirection        | 设置思维导图布局方向 |
| getMindDirection  | 无                                                       | LayoutDirection        | 获取思维导图布局方向 |
| setScaleVal       | value: number                                            | void                   | 设置缩放比例         |
| getScaleVal       | 无                                                       | number                 | 获取缩放比例         |
| zoomIn            | 无                                                       | void                   | 放大思维导图         |
| zoomOut           | 无                                                       | void                   | 缩小思维导图         |
| undo              | 无                                                       | boolean                | 撤销到上一个状态     |
| redo              | 无                                                       | boolean                | 重做被撤销的操作     |
| getSelectedNodeId | 无                                                       | string                 | 获取选中节点ID       |
| getSelectedNode   | 无                                                       | NodeObj \| null        | 获取选中节点数据     |
| selectNode        | id: string                                               | boolean                | 设置选中节点         |
| expandedNode      | id: string                                               | void                   | 展开节点及其子节点   |
| foldNode          | id: string                                               | void                   | 折叠节点及其子节点   |
| resetPosition     | 无                                                       | void                   | 重置思维导图位置     |
| startLink         | nodeId: string, isLink: boolean, bidirectional?: boolean | void                   | 开始创建节点链接     |
| renderLink        | endNodeId: string                                        | void                   | 渲染节点间的链接     |
| updateLinkLabel   | arrowId: string, newLabel: string                        | void                   | 更改链接标签         |
| destroy           | 无                                                       | void                   | 销毁实例，清理资源   |


### 枚举类型
```typescript
enum LayoutDirection {
  LEFT = 0,    // 左侧布局
  RIGHT = 1    // 右侧布局
  TOP = 2,     // 上方布局
  BOTTOM = 3,  // 下方布局
}

enum MoveDirection {
  UP,          // 向上移动
  DOWN         // 向下移动
}

enum DragOrientation {
  TOP,         // 拖拽到目标节点上方
  MIDDLE,      // 拖拽到目标节点中间（作为子节点）
  BOTTOM       // 拖拽到目标节点下方
}
```

### NodeOption配置选项
| 参数名               | 类型                | 默认值                              | 说明               |
|-------------------|-------------------|----------------------------------|------------------|
| locale            | string            | 'zh'                             | 语言设置             |
| draggable         | boolean           | false                            | 节点拖拽开关           |
| editable          | boolean           | false                            | 节点编辑开关           |
| toolBar           | boolean           | false                            | 工具栏开关            |
| allowUndo         | boolean           | false                            | 撤销重做开关           |
| contextMenu       | boolean           | false                            | 上下文菜单开关          |
| layout            | LayoutDirection   | LayoutDirection.RIGHT            | 思维导图布局方向         |
| siblingAlignment  | boolean           | false                            | 兄弟节点对齐开关         |
| nodeShape         | string            | 'line'                           | 节点形状（line/curve） |
| mindInViewport    | boolean           | false                            | 思维导图显示在可视区域内     |
| collapsible       | boolean           | false                            | 思维导图节点是否可展开      |
| nodeSpacing       | Object            | { horizontal: 50, vertical: 30 } | 节点间距配置           |
| nodeStyle         | Object            | 详见下文                             | 节点样式配置           |
| lineStyle         | Object            | { width: 2, color: '#e64553' }   | 连接线样式配置          |

### NodeStyle节点样式配置
| 参数名     | 类型   | 默认值           | 说明     |
|--------------------| ---------------- |--------------------| ---------------- |
| fontSize   | number | 20               | 字体大小 |
| fontFamily | string | 'HarmonyOS Sans' | 字体 |
| color      | string | '#333'           | 字体颜色 |
| background | string | '#fff'           | 背景颜色 |
| fontWeight | string | 'normal'         | 字体粗细 |
| border     | BorderOptions | { width: 2 }     | 边框样式 |
| maxWidth   | number | 200              | 最大宽度 |
| padding    | number | 10               | 内边距   |

### NodeObj 节点对象结构
```typescript
interface NodeObj {
    id: string;                  // 节点ID
    topic: string;               // 节点主题
    children?: NodeObj[];        // 子节点数组
    expanded?: boolean;          // 是否展开
    style?: NodeStyle;           // 节点样式
    tags?: string[];             // 标签
    direction?: LayoutDirection; // 节点方向
    // 布局计算相关属性计算得来...
    x?: number;                  // X坐标
    y?: number;                  // Y坐标
    level?: number;              // 层级
    width?: number;              // 宽度
    height?: number;             // 高度
    subtreeWidth?: number;       // 子树宽度
    subtreeHeight?: number;      // 子树高度
    richText?: RichTextSpan[];    // 富文本
}
```

### Arrow 箭头/链接结构
```typescript
interface Arrow {
    id: string;                  // 箭头ID
    from: string;                // 起始节点ID
    to: string;                  // 目标节点ID
    label?: string;              // 链接标签
    bidirectional?: boolean;     // 是否双向链接
}
```

## 快捷键  

| 快捷键                | 功能             |
|--------------------| ---------------- |
| Ctrl + Z           | 撤销             |
| Ctrl + Y           | 重做             |
| Alt + Enter        | 插入兄弟节点     |
| Shift + Enter      | 向前插入兄弟节点 |
| Tab                | 插入子节点       |
| Ctrl + Enter       | 插入父节点       |
| Delete / Backspace | 删除节点         |
| Ctrl + C           | 复制             |
| Ctrl + V           | 粘贴             |
| Ctrl + X           | 剪切             |
| Ctrl + "+"         | 放大思维导图     |
| Ctrl + "-"         | 缩小思维导图     |
| Ctrl + 0           | 重置思维导图     |

## 约束与限制

在下述版本验证通过：
DevEco Studio 5.1.0 Release(5.1.0.849), SDK: API17(5.0.5)。

## 目录结构

```javascript
    |---- MindElixir
    |     |---- entry                                             # 示例代码文件夹
    |     |---- library                                           # MindElixir 库文件夹
    |           |---- src
    |           	 |---- main
    |           		  |---- ets
    |          				   |---- controller                   # 控制器层
    |      					        |---- MindElixirCore.ets      # 核心接口类
    |      					        |---- MindLineRender.ets      # 线条渲染器
    |      					        |---- NodeHelper.ets          # 节点助手
    |          				   |---- model                        # 数据模型
    |      					        |---- NodeObj.ets             # 节点对象定义
    |          				   |---- utils                        # 工具类
    |      					        |---- CanvasPositionUtils.ets # 画布位置工具
    |      					        |---- ZoomUtils.ets           # 缩放工具
    |      					        |---- ShortcutManager.ets     # 快捷键管理
    |      					        |---- UtilsManager.ets        # 工具管理器
    |          				   |---- view                         # 视图层
    |      					        |---- components              # 组件
    |     |---- README_zh.md                                        # 中文文档
    |     |---- README.md                                      # 英文文档
```

## 贡献代码

使用过程中发现任何问题都可以提 [Issue](https://gitee.com/openharmony-tpc-incubate/ohos_mind_elixir/issues) 给我们，当然，我们也非常欢迎你给我们发 [PR](https://gitee.com/openharmony-tpc-incubate/ohos_mind_elixir/pulls) 。

## 开源协议

本项目基于 [Apache License 2.0](https://gitee.com/openharmony-tpc-incubate/ohos_mind_elixir/blob/master/LICENSE) ，请自由地享受和参与开源。

