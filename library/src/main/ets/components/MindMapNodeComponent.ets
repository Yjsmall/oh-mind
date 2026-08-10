import { MindElixirCore } from '../controller/MindElixirCore';
import { PopupEventsUtils } from '../utils/PopupUtils';
import {
  Coordinate,
  DragOrientation,
  LayoutDirection,
  NodeObj,
  NodeOption,
  NodeStyle,
  RichTextSpan
} from '../model/NodeObj';
import { MindMenuItem } from './MindMenu';
import { NodeHelper } from '../controller/NodeHelper';
import { UtilsManager } from '../utils/UtilsManager';
import { RichTextParser } from '../utils/RichTextParser';
import { isColorWhite } from '../utils/Tools';

const DRAG_HIGHLIGHT_COLOR: ResourceColor = '#4dc4ff';


@Extend(Span)
function spanStyle(span: RichTextSpan, nodeStyles: NodeStyle) {
  .fontColor(span.style?.color || nodeStyles.color)
  .fontSize(span.style?.fontSize || nodeStyles.fontSize)
  .fontFamily(span.style?.fontFamily || nodeStyles.fontFamily)
  .fontWeight(span.style?.fontWeight || nodeStyles.fontWeight)
  .backgroundColor(span.style?.background || Color.Transparent);
}

@ComponentV2
export struct MindMapNodeComponent {
  @Require @Param model: MindElixirCore;
  @Require @Param node: NodeObj;
  @Param selectedNodeId: string = '';
  @Param isDoubleClickAndEditing: boolean = false;
  @Param isStartDrop: boolean = false;
  @Param dragNodeId: string = '';
  @Param renderVersion: number = 0;
  @Event onNodeSelectionChange: (nodeId: string) => void = () => {
  };
  @Event onNodeEditingChange: (isEditing: boolean) => void = () => {
  };
  @Event onDragStateChange: (isDragging: boolean, dragNodeId: string) => void = () => {
  };
  @Local newTopic: string = '';
  @Local dragAreaColors: ResourceColor[] = [Color.Transparent, Color.Transparent, Color.Transparent];
  controller: TextInputController = new TextInputController();
  @Local nodeStyles: NodeStyle = {};
  @Local linkStyles: NodeStyle = {};
  @Local foldBtnPoint: Coordinate = { x: 0, y: 0 };
  private nodeHelper: NodeHelper = UtilsManager.getNodeHelper(this.model.getInstanceId())!;
  private options: NodeOption | null = null;
  private textSpans: RichTextSpan[] = [];

  // Use replacement values so style refreshes are visible to V2 state management.
  private createNodeStyles(): NodeStyle {
    const modelStyles = this.model.getMindOptions();
    return {
      fontSize: this.node.style?.fontSize || modelStyles.nodeStyle?.fontSize || 16,
      fontFamily: this.node.style?.fontFamily || modelStyles.nodeStyle?.fontFamily || 'HarmonyOS Sans',
      color: this.node.style?.color || modelStyles.nodeStyle?.color || '#000',
      background: this.node.style?.background || modelStyles.nodeStyle?.background || Color.Transparent,
      fontWeight: this.node.style?.fontWeight || modelStyles.nodeStyle?.fontWeight || 'normal',
      border: this.node.style?.border || modelStyles.nodeStyle?.border || { width: 0, radius: 20 },
      width: this.node.style?.width || modelStyles.nodeStyle?.width
    };
  }

  getFoldBtnWidth(): number {
    return Math.min(25, (this.node.height!) / 1.5);
  }

  getFoldBtnPoint(): Coordinate {
    try {
      const foldBtnWidth: number = this.getFoldBtnWidth();
      const layout = this.model.getMindOptions().layout!;
      if (layout === LayoutDirection.LEFT) {
        return {
          x: this.node.x! - foldBtnWidth / 2,
          y: this.node.y! + (this.node.height!) / 2 - foldBtnWidth / 2
        };
      } else if (layout === LayoutDirection.RIGHT) {
        return {
          x: this.node.x! + this.node.width! - foldBtnWidth / 2,
          y: this.node.y! + (this.node.height!) / 2 - foldBtnWidth / 2
        };
      } else if (layout === LayoutDirection.TOP) {
        return {
          x: this.node.x! + (this.node.width!) / 2 - foldBtnWidth / 2,
          y: this.node.y! - foldBtnWidth / 2
        };
      } else if (layout === LayoutDirection.BOTTOM) {
        return {
          x: this.node.x! + (this.node.width!) / 2 - foldBtnWidth / 2,
          y: this.node.y! + (this.node.height!) - foldBtnWidth / 2
        };
      } else {
        return {
          x: this.node.x! + this.node.width! - foldBtnWidth / 2,
          y: this.node.y! + (this.node.height!) / 2 - foldBtnWidth / 2
        };
      }
    } catch (e) {
      console.error('node data error');
      return { x: 0, y: 0 };
    }
  }

  aboutToAppear(): void {
    this.options = this.model.getMindOptions();
    this.refreshNodeRenderingState();
  }

  @Monitor('renderVersion')
  onMapRenderVersionChanged(): void {
    this.refreshNodeRenderingState();
  }

  private refreshNodeRenderingState(): void {
    this.newTopic = this.node.topic;
    this.nodeStyles = this.createNodeStyles();
    this.linkStyles = this.createNodeStyles();
    this.foldBtnPoint = this.getFoldBtnPoint();
    this.textSpans = RichTextParser.parse(this.node);
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

  private updateDragAreaColor(index: number, color: ResourceColor): void {
    this.dragAreaColors = [
      index === 0 ? color : this.dragAreaColors[0],
      index === 1 ? color : this.dragAreaColors[1],
      index === 2 ? color : this.dragAreaColors[2]
    ];
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
  private TextAreaBuilder() {
    TextArea({ text: this.node.topic, controller: this.controller })
      .position({ x: this.node.x, y: this.node.y })
      .fontSize(this.nodeStyles.fontSize)
      .fontColor(this.nodeStyles.color)
      .width(this.node.width)
      .height('auto')
      .constraintSize({ maxWidth: this.node.style?.maxWidth ?? this.options?.nodeStyle?.maxWidth })
      .padding(this.node.style?.padding ?? this.options?.nodeStyle?.padding)
      .borderRadius(this.getBorderStyle().radius)
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
        this.onNodeEditingChange(false);
        this.onNodeSelectionChange('');

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
          this.updateDragAreaColor(index, DRAG_HIGHLIGHT_COLOR);
        }
      })
      .onDragLeave(() => {
        this.updateDragAreaColor(index, Color.Transparent);
      });
  }

  // 构建折叠指示器
  @Builder
  private FoldIndicatorBuilder() {
    if (this.node.children?.length && this.options?.collapsible &&
      (!this.node.expanded || this.selectedNodeId === this.node.id)) {
      Text(!this.node.expanded ? this.nodeHelper.getAllChildrenNumber(this.node) + '' : '-')
        .position({ x: this.foldBtnPoint.x, y: this.foldBtnPoint.y })
        .fontSize(14)
        .width(this.getFoldBtnWidth())
        .height(this.getFoldBtnWidth())
        .lineHeight(this.getFoldBtnWidth() - 2)
        .textAlign(TextAlign.Center)
        .border({ width: 1, color: this.nodeStyles.color })
        .borderRadius('50%')
        .fontColor(isColorWhite(this.nodeStyles.color) ? '#000' : this.nodeStyles.color)
        .backgroundColor('#fff')
        .onClick(() => {
          if (this.node.expanded) {
            this.model.foldNode(this.node.id);
          } else {
            this.model.expandedNode(this.node.id);
          }
        });
    }
  }

  // 构建富文本渲染器
  @Builder
  private RichTextBuilder() {
    Text() {
      ForEach(this.textSpans, (span: RichTextSpan) => {
        if (span.isLink) {
          Span(span.text)
            .spanStyle(span, this.linkStyles)
            .onClick(() => {
              if(span.originText && this.node.onLinkClick) {
                this.node.onLinkClick(span.originText || '');
              } else if (span.onClick) {
                span.onClick();
              }
            });
        } else {
          Span(span.text)
            .spanStyle(span, this.nodeStyles);
        }
      });
    }
    .fontColor(this.nodeStyles.color)
    .fontSize(this.nodeStyles.fontSize)
    .fontFamily(this.nodeStyles.fontFamily)
    .fontWeight(this.nodeStyles.fontWeight)
    .textAlign(TextAlign.Start);
  }

  build() {
    Stack() {
      Column() {
        if (this.isDoubleClickAndEditing && this.node.id === this.selectedNodeId && this.options?.editable) {
          this.TextAreaBuilder
          ();
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
            this.RichTextBuilder();
            if (this.node.tags && this.node.tags.length > 0) {
              Image($r('app.media.more'))
                .width(18)
                .fillColor('#000')
                .margin({ left: 2, right: 2 })
                .onClick(() => {
                  this.onNodeSelectionChange(this.node.id);
                  PopupEventsUtils.getInstance().open();
                });
            }
          }
          .padding(this.node.tags && this.node.tags.length > 0 ? { left: 3, right: 3 } : { left: 3 })
          .justifyContent(FlexAlign.Center)
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
              backgroundColor: Color.White,
              backgroundBlurStyle: BlurStyle.NONE,
              onAppear: () => {
                this.onNodeSelectionChange(this.node.id);
              }
            })
          .draggable(this.options?.draggable)
          .onDragStart(() => {
            this.onDragStateChange(true, this.node.id);
            this.model.setDragStatusForSubtree(this.node.id, false);
          })

          .onDragEnd(() => {
            this.model.setDragStatusForSubtree(this.node.id, true);
            this.onDragStateChange(false, '');
          })
          .gesture(
            GestureGroup(GestureMode.Exclusive,
              TapGesture({ count: 2 }).onAction(() => {
                this.onNodeSelectionChange(this.node.id);
                this.onNodeEditingChange(true);
                this.controller.setTextSelection(0, this.node.topic.length, { menuPolicy: MenuPolicy.SHOW });
              }),
              TapGesture({ count: 1 }).onAction(() => {
                if (this.model.hasLinkedNode()) {
                  this.model.renderLink(this.node.id);
                  this.model.startLink('', false);
                }
                this.onNodeEditingChange(false);
                this.onNodeSelectionChange(this.node.id);
              })
            ));

          this.FoldIndicatorBuilder();
        }
      };
    };
  }
}
