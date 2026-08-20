import {
  CanvasTextNode
} from '../model/CanvasModel';
import {
  FREE_CANVAS_CARD_DRAG_THRESHOLD_VP
} from '../gesture/FreeCanvasGestureMachine';

const NODE_CORNER_RADIUS: number = 6;
const DEFAULT_NODE_BACKGROUND: string = '#FFFFFFFF';
const DEFAULT_NODE_BORDER: string = '#FFD7DCE2';
const SELECTED_NODE_BORDER: string = '#FF146C94';

function nodeBackground(color: string | undefined): string {
  switch (color) {
    case '1':
      return '#FFFFE4E6';
    case '2':
      return '#FFFFEDD5';
    case '3':
      return '#FFFEF9C3';
    case '4':
      return '#FFDCFCE7';
    case '5':
      return '#FFE0F2FE';
    case '6':
      return '#FFEDE9FE';
    default:
      return color ?? DEFAULT_NODE_BACKGROUND;
  }
}

@Builder
function DefaultNodeContent(_node: CanvasTextNode): void {
  Text('')
    .width('100%')
    .height('100%')
}

const DEFAULT_CARD_BUILDER: WrappedBuilder<[CanvasTextNode, Object]> = wrapBuilder(DefaultNodeContent);

/**
 * A single immutable node card in the free canvas.
 *
 * Position, size, color, selection and viewport arrive as scalar `@Param` values
 * so ArkUI V2 reliably re-renders the card on every completed edit, move, resize
 * or recolor (interface `@Param` objects are not observed field-by-field). The
 * `node` object is only used to feed the host content builder. Its single-finger
 * gestures are exactly the tablet contract: tap selects, drag past ~6vp selects
 * and moves, double tap edits. While editing, the TextArea owns all touches and
 * the card never pans.
 */
@ComponentV2
export struct FreeCanvasNodeCard {
  @Require @Param node: CanvasTextNode;
  @Param contentText: string = '';
  @Param x: number = 0;
  @Param y: number = 0;
  @Param renderWidth: number = 240;
  @Param renderHeight: number = 160;
  @Param renderColor: string = DEFAULT_NODE_BACKGROUND;
  @Param selected: boolean = false;
  @Param editing: boolean = false;
  @Param editingText: string = '';
  @Param viewportX: number = 0;
  @Param viewportY: number = 0;
  @Param viewportScale: number = 1;
  @Param renderTick: number = 0;
  @Param nodeContentBuilder: WrappedBuilder<[CanvasTextNode, Object]> = DEFAULT_CARD_BUILDER;
  @Param nodeContentContext: Object = new Object();
  @Event onCardSelect: (nodeId: string) => void = (_nodeId: string): void => {
  };
  @Event onCardDoubleTap: (nodeId: string) => void = (_nodeId: string): void => {
  };
  @Event onCardDragStart: (nodeId: string) => void = (_nodeId: string): void => {
  };
  @Event onCardDragUpdate: (nodeId: string, event: GestureEvent) => void =
    (_nodeId: string, _event: GestureEvent): void => {
    };
  @Event onCardDragEnd: (nodeId: string) => void = (_nodeId: string): void => {
  };
  @Event onCardDragCancel: (nodeId: string) => void = (_nodeId: string): void => {
  };
  @Event onCardEditTextChange: (nodeId: string, text: string) => void =
    (_nodeId: string, _text: string): void => {
    };
  @Event onCardEditCommit: (nodeId: string) => void = (_nodeId: string): void => {
  };
  @Event onCardEditCancel: (nodeId: string) => void = (_nodeId: string): void => {
  };

  /** Rebuilds a node object carrying the latest content for the host builder. */
  private contentNode(): CanvasTextNode {
    return {
      id: this.node.id,
      type: 'text',
      text: this.contentText,
      x: this.node.x,
      y: this.node.y,
      width: this.renderWidth,
      height: this.renderHeight,
      color: this.node.color
    };
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.editing) {
        TextArea({ text: this.editingText, placeholder: 'Markdown' })
          .id('free-canvas-node-editor')
          .width('100%')
          .height('100%')
          .padding(12)
          .fontSize(14)
          .backgroundColor(Color.Transparent)
          .onChange((value: string): void => {
            this.onCardEditTextChange(this.node.id, value);
          })
          .onBlur((): void => {
            this.onCardEditCommit(this.node.id);
          })
      } else {
        this.nodeContentBuilder.builder(this.contentNode(), this.nodeContentContext)
      }
    }
    .width(this.renderWidth)
    .height(this.renderHeight)
    .id('free-canvas-node-' + this.node.id)
    .backgroundColor(this.renderColor)
    .border({
      width: this.selected ? 2 : 1,
      color: this.selected ? SELECTED_NODE_BORDER : DEFAULT_NODE_BORDER,
      radius: NODE_CORNER_RADIUS
    })
    .shadow({ radius: 8, color: '#18000000', offsetX: 0, offsetY: 2 })
    .clip(true)
    .position({
      x: this.viewportX + this.x * this.viewportScale,
      y: this.viewportY + this.y * this.viewportScale
    })
    .scale({ x: this.viewportScale, y: this.viewportScale, centerX: 0, centerY: 0 })
    .gesture(
      GestureGroup(
        GestureMode.Exclusive,
        TapGesture({ count: 2 })
          .onAction((): void => {
            this.onCardDoubleTap(this.node.id);
          }),
        TapGesture({ count: 1 })
          .onAction((): void => {
            this.onCardSelect(this.node.id);
          }),
        PanGesture({
          fingers: 1,
          direction: PanDirection.All,
          distance: FREE_CANVAS_CARD_DRAG_THRESHOLD_VP
        })
          .onActionStart((): void => {
            this.onCardDragStart(this.node.id);
          })
          .onActionUpdate((event: GestureEvent): void => {
            this.onCardDragUpdate(this.node.id, event);
          })
          .onActionEnd((): void => {
            this.onCardDragEnd(this.node.id);
          })
          .onActionCancel((): void => {
            this.onCardDragCancel(this.node.id);
          })
      )
    )
  }
}