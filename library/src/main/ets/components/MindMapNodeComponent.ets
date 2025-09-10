import { MindElixirCore } from '../controller/MindElixirCore';
import { PopupEventsUtils } from '../utils/PopupUtils';
import { Coordinate, DragOrientation, LayoutDirection, NodeObj, NodeOption, NodeStyle } from '../model/NodeObj';
import { MindMenuItem } from './MindMenu';
import { NodeHelper } from '../controller/NodeHelper';
import { UtilsManager } from '../utils/UtilsManager';

const FOLD_BTN_WIDTH: number = 20;
const DRAG_HIGHLIGHT_COLOR: ResourceColor = '#4dc4ff';

@Component
export struct MindMapNodeComponent{
  @Link model: MindElixirCore;
  @Prop @Watch('changeFoldBtnPoint') node: NodeObj; // 绑定节点数据
  @Link selectedNodeId: string; // 当前选中的节点ID
  @Link isDoubleClickAndEditing: boolean; //是否修改（双击）
  @State newTopic: string = this.node.topic;
  @State dragAreaColors: ResourceColor[] = [Color.Transparent, Color.Transparent, Color.Transparent];
  controller: TextInputController = new TextInputController();
  @State nodeStyles: NodeStyle = {};
  @State foldBtnPoint: Coordinate = { x: 0, y: 0 };
  private nodeHelper: NodeHelper = UtilsManager.getNodeHelper(this.model.getInstanceId())!;
  @Link isStartDrop: boolean;
  @Link dragNodeId: string;
  private options: NodeOption | null = null;

  // 获取节点样式
  getStyles(): void {
    const modelStyles = this.model.getMindOptions();
    this.nodeStyles.fontSize = this.node.style?.fontSize || modelStyles.nodeStyle?.fontSize || 16;
    this.nodeStyles.fontFamily = this.node.style?.fontFamily || modelStyles.nodeStyle?.fontFamily || 'HarmonyOS Sans';
    this.nodeStyles.color = this.node.style?.color || modelStyles.nodeStyle?.color || '#000';
    this.nodeStyles.background = this.node.style?.background || modelStyles.nodeStyle?.background || Color.Transparent;
    this.nodeStyles.fontWeight = this.node.style?.fontWeight || modelStyles.nodeStyle?.fontWeight || 'normal';
    this.nodeStyles.border = this.node.style?.border || modelStyles.nodeStyle?.border || { width: 0, radius: 20 };
    this.nodeStyles.width = this.node.style?.width || modelStyles.nodeStyle?.width;
  }

  getFoldBtnPoint(): Coordinate {
    try {
      const layout = this.model.getMindOptions().layout!;

      if (layout === LayoutDirection.LEFT) {
        return {
          x: this.node.x! - FOLD_BTN_WIDTH / 2,
          y: this.node.y! + (this.node.height!) / 2 - FOLD_BTN_WIDTH / 2
        };
      } else if (layout === LayoutDirection.RIGHT) {
        return {
          x: this.node.x! + this.node.width! - FOLD_BTN_WIDTH / 2,
          y: this.node.y! + (this.node.height!) / 2 - FOLD_BTN_WIDTH / 2
        };
      } else if (layout === LayoutDirection.TOP) {
        return {
          x: this.node.x! + (this.node.width!) / 2 - FOLD_BTN_WIDTH / 2,
          y: this.node.y! - FOLD_BTN_WIDTH / 2
        };
      } else if (layout === LayoutDirection.BOTTOM) {
        return {
          x: this.node.x! + (this.node.width!) / 2 - FOLD_BTN_WIDTH / 2,
          y: this.node.y! + (this.node.height!) - FOLD_BTN_WIDTH / 2
        };
      } else {
        return {
          x: this.node.x! + this.node.width! - FOLD_BTN_WIDTH / 2,
          y: this.node.y! + (this.node.height!) / 2 - FOLD_BTN_WIDTH / 2
        };
      }
    } catch (e) {
      console.error('node data error');
      return { x: 0, y: 0 };
    }
  }

  changeFoldBtnPoint() {
    this.foldBtnPoint = this.getFoldBtnPoint();
  }

  aboutToAppear(): void {
    this.getStyles();
    this.foldBtnPoint = this.getFoldBtnPoint();
    this.options = this.model.getMindOptions();
  }

  @Builder
  MenuBuilder() {
    Flex({ direction: FlexDirection.Column, justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center }) {
      MindMenuItem({ currentNode: this.node, model: this.model });
    }.width(200);
  }

  // 计算选中状态的边框样式
  private getBorderStyle(): BorderOptions {
    const isSelected = this.selectedNodeId === this.node.id;
    const borderWidth = this.nodeStyles.border?.width !== undefined ? Number(this.nodeStyles.border.width) : 0;
    return {
      width: isSelected ? 3 : (this.node.level! <= 1 ? 2 : borderWidth),
      color: isSelected ? '#1890FF' : this.nodeStyles?.border?.color,
      radius: this.nodeStyles.border?.radius !== undefined ? Number(this.nodeStyles.border.radius) : 20
    };
  }

  // 清除拖拽区域颜色
  private clearDragAreaColors(): void {
    this.dragAreaColors = [Color.Transparent, Color.Transparent, Color.Transparent];
  }

  // 处理拖拽区域事件
  private handleDragAreaEvent(index: number, orientation: DragOrientation): void {
    if (this.dragNodeId === this.node.id) {
      return;
    }

    this.clearDragAreaColors();
    this.model.moveNodeToTargetNode(this.dragNodeId, this.node.id, orientation);
  }

  // 构建文本输入框
  @Builder
  private TextInputBuilder() {
    TextInput({ text: this.node.topic, controller: this.controller })
      .position({ x: this.node.x, y: this.node.y })
      .fontSize(this.nodeStyles.fontSize)
      .fontColor(this.nodeStyles.color)
      .width('auto')
      .height(this.node.height)
      .constraintSize({ maxWidth: this.node.style?.maxWidth ?? this.options?.nodeStyle?.maxWidth })
      .padding(0)
      .borderRadius(0)
      .backgroundColor(this.nodeStyles.background)
      .border({
        width: this.selectedNodeId === this.node.id ? 4 : 0,
        color: '#1890FF'
      })
      .onChange((value) => {
        this.newTopic = value;
      })
      .defaultFocus(this.node.id === this.selectedNodeId)
      .onBlur(() => {
        this.isDoubleClickAndEditing = false;
        this.selectedNodeId = '';
        this.model.selectNode(this.selectedNodeId);

        if (this.newTopic !== this.node.topic) {
          this.node.topic = this.newTopic;
          this.model.updateNode(this.node);
        }
      });
  }

  // 构建拖拽区域
  @Builder
  private DragAreaBuilder(index: number, orientation: DragOrientation) {
    Row()
      .zIndex(20)
      .borderRadius(this.getBorderStyle().radius)
      .position({
        x: this.node.x,
        y: this.node.y! + (orientation === DragOrientation.BOTTOM ? this.node.height! + 5 :
          orientation === DragOrientation.TOP ? -(this.node.height! + 5) : 0)
      })
      .width(this.node.width)
      .height(this.node.height)
      .backgroundColor(this.dragAreaColors[index])
      .visibility(this.isStartDrop ? Visibility.Visible : Visibility.None)
      .onDrop(() => this.handleDragAreaEvent(index, orientation))
      .onDragEnter(() => {
        if (this.dragNodeId !== this.node.id) {
          this.dragAreaColors[index] = DRAG_HIGHLIGHT_COLOR;
        }
      })
      .onDragLeave(() => {
        this.dragAreaColors[index] = Color.Transparent;
      });
  }

  // 构建折叠指示器
  @Builder
  private FoldIndicatorBuilder() {
    if (this.node.children?.length && !this.node.expanded) {
      Text(this.nodeHelper.getAllChildrenNumber(this.node) + '')
        .position({ x: this.foldBtnPoint.x, y: this.foldBtnPoint.y })
        .fontSize(12)
        .width(FOLD_BTN_WIDTH)
        .height(FOLD_BTN_WIDTH)
        .textAlign(TextAlign.Center)
        .border({ width: 3, color: Color.Orange })
        .borderRadius(10)
        .opacity(0.9)
        .backgroundColor('#fff');
    }
  }

  build() {
    Stack() {
      Column() {
        if (this.isDoubleClickAndEditing && this.node.id === this.selectedNodeId && this.options?.editable) {
          this.TextInputBuilder();
        } else {
          // 拖拽区域
          if (!this.node.isCantDrag) {
            if (this.node.level !== 0) {
              this.DragAreaBuilder(0, DragOrientation.TOP);
            }
            this.DragAreaBuilder(1, DragOrientation.MIDDLE);
            if (this.node.level !== 0) {
              this.DragAreaBuilder(2, DragOrientation.BOTTOM);
            }
          }

          // 节点标签
          Row() {
            Text(this.node.topic)
              .fontColor(!this.node.isCantDrag ? this.nodeStyles.color : '#ccc')
              .fontSize(this.nodeStyles.fontSize)
              .fontFamily(this.nodeStyles.fontFamily)
              .fontWeight(this.nodeStyles.fontWeight)
              .textAlign(TextAlign.Start);

            if (this.node.tags && this.node.tags.length > 0) {
              Image($r('app.media.more'))
                .width(18)
                .fillColor('#000')
                .margin({ left: 2, right: 2 })
                .onClick(() => {
                  this.selectedNodeId = this.node.id;
                  this.model.selectNode(this.selectedNodeId);
                  PopupEventsUtils.getInstance().open();
                });
            }
          }
          .padding(this.node.tags && this.node.tags.length > 0 ? { left: 3, right: 3 } : { left: 3 })
          .justifyContent(Number(this.node.tags?.length) > 0 ? FlexAlign.SpaceBetween : FlexAlign.Center)
          .position({ x: this.node.x, y: this.node.y })
          .width(this.node.width)
          .backgroundColor(this.nodeStyles.background)
          .height(this.node.height)
          .border({
            width: this.getBorderStyle().width,
            color: this.getBorderStyle().color,
            radius: this.getBorderStyle().radius
          })
          .bindContextMenu((this.options?.contextMenu && !this.isStartDrop) ? this.MenuBuilder : null,
            ResponseType.LongPress, {
              enableArrow: false,
              placement: Placement.Top,
              onAppear: () => {
                this.selectedNodeId = this.node.id;
                this.model.selectNode(this.selectedNodeId);
              }
            })
          .draggable(this.options?.draggable)
          .onDragStart(() => {
            this.isStartDrop = true;
            this.dragNodeId = this.node.id;
            this.model.setDragStatusForSubtree(this.node.id, false);
          })

          .onDragEnd(() => {
            this.isStartDrop = false;
            this.model.setDragStatusForSubtree(this.node.id, true);
            this.dragNodeId = '';
          })
          .gesture(
            GestureGroup(GestureMode.Exclusive,
              TapGesture({ count: 2 }).onAction(() => {
                this.selectedNodeId = this.node.id;
                this.model.selectNode(this.node.id);
                this.isDoubleClickAndEditing = true;
                this.controller.setTextSelection(0, this.node.topic.length, { menuPolicy: MenuPolicy.SHOW });
              }),
              TapGesture({ count: 1 }).onAction(() => {
                if (this.model.hasLinkedNode()) {
                  this.model.renderLink(this.node.id);
                  this.model.startLink('', false);
                } else {
                  if (this.node.children?.length) {
                    if (this.node.expanded) {
                      this.model.foldNode(this.node.id);
                    } else {
                      this.model.expandedNode(this.node.id);
                    }
                  }
                }
                this.isDoubleClickAndEditing = false;
                this.selectedNodeId = this.node.id;
                this.model.selectNode(this.node.id);
              })
            ));
          this.FoldIndicatorBuilder();
        }
      };
    };
  }
}