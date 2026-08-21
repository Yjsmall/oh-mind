import { CanvasResizeHandle } from '../geometry/FreeCanvasGeometry';
import { CanvasSide } from '../model/CanvasModel';

const RESIZE_HANDLE_SIZE: number = 12;
const RESIZE_HANDLE_HALF: number = RESIZE_HANDLE_SIZE / 2;
const ANCHOR_SIZE: number = 14;
const ANCHOR_HALF: number = ANCHOR_SIZE / 2;
const ANCHOR_OFFSET: number = 20;
const SELECTED_NODE_BORDER: string = '#FF146C94';

interface HandlePoint {
  x: number;
  y: number;
}

/**
 * Resize handles and connection anchors of the primary selected node.
 *
 * All geometry arrives as screen-space scalar `@Param` values, so ArkUI V2
 * re-renders every dot whenever the selection, node geometry or viewport
 * changes. Rendering these dots through a `@Builder` with value parameters
 * froze them at the first selected node because builder parameters carry no
 * reactive binding.
 */
@ComponentV2
export struct FreeCanvasNodeHandles {
  @Param centerX: number = 0;
  @Param centerY: number = 0;
  @Param halfWidth: number = 0;
  @Param halfHeight: number = 0;
  @Event onResizeStart: (handle: CanvasResizeHandle) => void = (_handle: CanvasResizeHandle): void => {
  };
  @Event onResizeUpdate: (handle: CanvasResizeHandle, event: GestureEvent) => void =
    (_handle: CanvasResizeHandle, _event: GestureEvent): void => {
    };
  @Event onResizeEnd: () => void = (): void => {
  };
  @Event onResizeCancel: () => void = (): void => {
  };
  @Event onAnchorStart: (side: CanvasSide) => void = (_side: CanvasSide): void => {
  };
  @Event onAnchorUpdate: (event: GestureEvent) => void = (_event: GestureEvent): void => {
  };
  @Event onAnchorEnd: () => void = (): void => {
  };
  @Event onAnchorCancel: () => void = (): void => {
  };

  private resizeHandlePoint(handle: CanvasResizeHandle): HandlePoint {
    let x = this.centerX;
    let y = this.centerY;
    if (handle.includes('w')) {
      x = this.centerX - this.halfWidth;
    } else if (handle.includes('e')) {
      x = this.centerX + this.halfWidth;
    }
    if (handle.includes('n')) {
      y = this.centerY - this.halfHeight;
    } else if (handle.includes('s')) {
      y = this.centerY + this.halfHeight;
    }
    return { x, y };
  }

  private anchorPoint(side: CanvasSide): HandlePoint {
    switch (side) {
      case 'top':
        return { x: this.centerX, y: this.centerY - this.halfHeight - ANCHOR_OFFSET };
      case 'right':
        return { x: this.centerX + this.halfWidth + ANCHOR_OFFSET, y: this.centerY };
      case 'bottom':
        return { x: this.centerX, y: this.centerY + this.halfHeight + ANCHOR_OFFSET };
      case 'left':
        return { x: this.centerX - this.halfWidth - ANCHOR_OFFSET, y: this.centerY };
    }
  }

  @Builder
  private ResizeDot(handle: CanvasResizeHandle) {
    Rect()
      .width(RESIZE_HANDLE_SIZE)
      .height(RESIZE_HANDLE_SIZE)
      .id('free-canvas-resize-' + handle)
      .radius(2)
      .fill('#FFFFFFFF')
      .stroke(SELECTED_NODE_BORDER)
      .strokeWidth(2)
      .position({
        x: this.resizeHandlePoint(handle).x - RESIZE_HANDLE_HALF,
        y: this.resizeHandlePoint(handle).y - RESIZE_HANDLE_HALF
      })
      .gesture(
        PanGesture({ fingers: 1, direction: PanDirection.All, distance: 0 })
          .onActionStart((): void => this.onResizeStart(handle))
          .onActionUpdate((event: GestureEvent): void => this.onResizeUpdate(handle, event))
          .onActionEnd((): void => this.onResizeEnd())
          .onActionCancel((): void => this.onResizeCancel())
      )
  }

  @Builder
  private AnchorDot(side: CanvasSide) {
    Circle()
      .width(ANCHOR_SIZE)
      .height(ANCHOR_SIZE)
      .id('free-canvas-anchor-' + side)
      .fill('#FFFFFFFF')
      .stroke(SELECTED_NODE_BORDER)
      .strokeWidth(2)
      .position({
        x: this.anchorPoint(side).x - ANCHOR_HALF,
        y: this.anchorPoint(side).y - ANCHOR_HALF
      })
      .gesture(
        PanGesture({ fingers: 1, direction: PanDirection.All, distance: 0 })
          .onActionStart((): void => this.onAnchorStart(side))
          .onActionUpdate((event: GestureEvent): void => this.onAnchorUpdate(event))
          .onActionEnd((): void => this.onAnchorEnd())
          .onActionCancel((): void => this.onAnchorCancel())
      )
  }

  build() {
    Stack() {
      this.ResizeDot('nw')
      this.ResizeDot('n')
      this.ResizeDot('ne')
      this.ResizeDot('e')
      this.ResizeDot('se')
      this.ResizeDot('s')
      this.ResizeDot('sw')
      this.ResizeDot('w')
      this.AnchorDot('top')
      this.AnchorDot('right')
      this.AnchorDot('bottom')
      this.AnchorDot('left')
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.None)
  }
}
