import {
  CanvasTextNode,
  CanvasViewport
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
 * The parent passes fresh immutable `CanvasTextNode` objects on every completed
 * edit, move, resize or recolor, so the card re-renders position, size, color
 * and Markdown content immediately. Its single-finger gestures are exactly the
 * tablet contract: tap selects, drag past ~6vp selects and moves, double tap
 * edits. Mouse clicks on a card are routed through the canvas background handler
 * (which understands Ctrl/Shift append), so the card itself does not attach an
 * onClick that would fight its gestures.
 */
@ComponentV2
export struct FreeCanvasNodeCard {
  @Require @Param node: CanvasTextNode;
  @Param viewport: CanvasViewport = { x: 0, y: 0, scale: 1 };
  @Param selected: boolean = false;
  @Param editing: boolean = false;
  @Param editingText: string = '';
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
        this.nodeContentBuilder.builder(this.node, this.nodeContentContext)
      }
    }
    .width(this.node.width)
    .height(this.node.height)
    .id('free-canvas-node-' + this.node.id)
    .backgroundColor(nodeBackground(this.node.color))
    .border({
      width: this.selected ? 2 : 1,
      color: this.selected ? SELECTED_NODE_BORDER : DEFAULT_NODE_BORDER,
      radius: NODE_CORNER_RADIUS
    })
    .shadow({ radius: 8, color: '#18000000', offsetX: 0, offsetY: 2 })
    .clip(true)
    .position({
      x: this.viewport.x + this.node.x * this.viewport.scale,
      y: this.viewport.y + this.node.y * this.viewport.scale
    })
    .scale({ x: this.viewport.scale, y: this.viewport.scale, centerX: 0, centerY: 0 })
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