# ohos_mind_elixir

## 简介

**ohos_mind_elixir** 是一个开源的思维导图框架，针对思维导图的优势，拥有以下特性：

- 节点关联
- 节点拖拽功能
- 支持节点右键菜单
- 支持实用快捷键操作
- 撤销与重做
- 支持自定义修改节点样式和连接线样式

## 下载安装

```shell
ohpm install @ohos/mind-elixir
```

OpenHarmony ohpm环境配置等更多内容，请参考[如何安装OpenHarmony ohpm](https://gitcode.com/openharmony-tpc/docs/blob/master/OpenHarmony_har_usage.md)



## 使用说明

MindElixir引用及使用

```typescript
import { MindElixir, MindElixirData, MindElixirCore, NodeOption } from '@ohos/mind-elixir';
import mindElixirData from '../model/MindElixirData2';

@Entry
@Component
struct Index {
  //基础配置
  private mindOption: NodeOption = {
    locale: 'zh',                       // 语言设置
    draggable: true,					// 可拖拽修改节点开关
    editable: true,						// 双击修改节点信息开关
    toolBar: true,						// 工具栏开关
    allowUndo: true,					// 记录操作历史开关
    layout: LayoutDirection.RIGHT,		// 思维导图朝向
    nodeShape: 'line',					// 思维导图样式 line直线、curve曲线
    mindInViewport: true,               // 思维导图显示在可视区域内
    nodeSpacing: {
      horizontal: 30,                   // 节点水平间隔
      vertical: 50                      // 节点垂直间隔
    },
    nodeStyle: {                        // 节点统一样式设置
      fontSize: 20,                         // 节点字体大小
      fontFamily: 'HarmonyOS Sans',         // 节点字体样式
      color: '#333',						// 节点字体颜色
      background: '#fff',                   // 节点背景颜色
      fontWeight: 'normal',                 // 节点字体是否加粗
      border: {                         // 节点边框样式设置
        width: 1,                           // 节点边框宽度
        radius: 0,							// 节点边框圆角大小
        color: '#000',						// 节点边框颜色
      },
      maxWidth: 200,						// 设置节点最大宽度
      padding: 5							// 设置节点边距
    }
  };
   
  @State model: MindElixirCore = new MindElixirCore(this.mindOption);
  private initializedData: MindElixirData = mindElixirData;

   //页面展示
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



## 接口说明

### MindElixirCore 接口

| 接口名                   | 参数                                            | 说明                                                                                              |
|-----------------------| ---------------------------------------------- |:------------------------------------------------------------------------------------------------|
| getData               | 无                                              | 获取节点数据。                                                                                         |
| add                   | id: string, <br/>topic: string = 'new node'    | 添加子节点。<br/>参数id：父节点ID。<br/>参数topic：节点名称。                                                        |
| addParent             | id: string, <br/>topic: string = 'new node'    | 添加父节点。<br/>参数id：节点ID。<br/>参数topic：节点名称。                                                         |
| addSibling            | id: string,<br/>isBefore?: boolean             | 添加兄弟节点。<br/>参数id：节点ID。<br/>isBefore：当前节点前或者后。                                                   |
| remove                | id: string                                     | 删除节点。<br/>参数id：要删除的节点ID。                                                                        |
| move                  | id: string,<br/>direction: MoveDirection       | 同级节点上下移动。<br/>参数id：当前移动节点ID。<br/>参数direction：移动方向（MoveDirection.UP向上移动,MoveDirection.DOWN向下移动）。 |
| updateNode            | updatedNode: NodeObj                           | 更新节点属性。<br/>参数updatedNode：要更新的节点对象信息。                                                           |
| setMindDirection      | direction: number                              | 设置思维导图布局方向。<br/>参数direction 布局方向 (默认为右侧布局，0：左侧布局，1：右侧布局)。                                       |
| getMindDirection      | 无                                              | 获取思维导图布局方向。                                                                                     |
| setScaleVal           | value: number                                  | 设置缩放比例，默认为1。                                                                                    |
| getScaleVal           | 无                                              | 获取缩放比例。                                                                                         |
| zoomIn                | 无                                              | 放大思维导图。                                                                                         |
| zoomOut               | 无                                              | 缩小思维导图。                                                                                         |
| undo                  | 无                                              | 撤销到上一个状态。                                                                                       |
| redo                  | 无                                              | 重做被撤销的操作。                                                                                       |
| getArrowsData         | 无                                              | 获取箭头数据。                                                                                         |
| getSelectedNodeId     | 无                                              | 获取选中节点ID。                                                                                       |
| getSelectedNode       | 无                                              | 获取选中节点数据。                                                                                       |
| selectNode            | nodeId: string                             | 设置选中节点。<br/>参数nodeId：选中节点ID，如果传入‘’，取消选中。                                                        |
| expandedNode          | selectNodeId: string                       | 展开节点。<br/>参数selectNodeId：展开节点ID。                                                                |
| foldNode              | selectNodeId: string                       | 折叠节点。<br/>参数selectNodeId：折叠节点ID。                                                                |
| resetPosition         | 无                                              | 重置思维导图位置。                                                                                       |

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
|     |---- entry  # 示例代码文件夹
|     |---- library  # MindElixir 库文件夹
|           |----src
|           	 |----main
|           		  |----ets
|          				   |----controller
|      					        |----MindElixirCore   #MindElixir对外接口
|     |---- README.MD  # 安装使用方法
|     |---- README_zh.MD  # 安装使用方法   
```

## 贡献代码

使用过程中发现任何问题都可以提 Issue给组件，当然，也非常欢迎发 PR共建 。

## 开源协议

本项目基于 MIT License，请自由地享受和参与开源。

