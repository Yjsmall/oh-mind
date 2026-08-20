import {
  CanvasDocument,
  CanvasTextNode,
  FreeCanvas,
  FreeCanvasChangeEvent,
  FreeCanvasController,
  FreeCanvasInteractionMode
} from '@ohos/mind-elixir';

const DEMO_DOCUMENT: CanvasDocument = {
  nodes: [
    { id: 'source', type: 'text', text: '# Source note\n\nDrag or resize this card.', x: 40, y: 80,
      width: 240, height: 150, color: '5' },
    { id: 'idea', type: 'text', text: '# Independent idea\n\nCanvas positions persist exactly.', x: 380, y: 40,
      width: 250, height: 160, color: '4' },
    { id: 'result', type: 'text', text: '# Result\n\nUse the toolbar to select or pan.', x: 380, y: 290,
      width: 250, height: 150, color: '3' }
  ],
  edges: [
    { id: 'source-idea', fromNode: 'source', fromSide: 'right', toNode: 'idea', toSide: 'left',
      label: 'supports' },
    { id: 'idea-result', fromNode: 'idea', fromSide: 'bottom', toNode: 'result', toSide: 'top' }
  ],
  cardnote: { schemaVersion: 1, viewport: { x: 40, y: 40, scale: 1 } }
};

@Builder
function DemoNode(node: CanvasTextNode, _context: Object) {
  Text(node.text)
    .width('100%')
    .height('100%')
    .padding(14)
    .fontSize(14)
    .fontColor('#FF20252B')
    .maxLines(8)
    .textOverflow({ overflow: TextOverflow.Ellipsis })
}

const DEMO_NODE_BUILDER: WrappedBuilder<[CanvasTextNode, Object]> = wrapBuilder(DemoNode);

@Entry
@ComponentV2
struct Index {
  @Local private document: CanvasDocument = DEMO_DOCUMENT;
  @Local private mode: FreeCanvasInteractionMode = 'select';
  private readonly canvasController: FreeCanvasController = new FreeCanvasController();

  private setMode(mode: FreeCanvasInteractionMode): void {
    this.mode = mode;
    this.canvasController.setInteractionMode(mode);
  }

  private acceptChange(event: FreeCanvasChangeEvent): void {
    this.document = event.document;
  }

  build() {
    Column() {
      Row({ space: 8 }) {
        Button('Select')
          .id('toolbar-select')
          .type(ButtonType.Normal)
          .backgroundColor(this.mode === 'select' ? '#FF146C94' : '#FFE5E9ED')
          .fontColor(this.mode === 'select' ? Color.White : '#FF20252B')
          .onClick((): void => this.setMode('select'))
        Button('Pan')
          .id('toolbar-pan')
          .type(ButtonType.Normal)
          .backgroundColor(this.mode === 'pan' ? '#FF146C94' : '#FFE5E9ED')
          .fontColor(this.mode === 'pan' ? Color.White : '#FF20252B')
          .onClick((): void => this.setMode('pan'))
        Blank()
        Button('Fit')
          .id('toolbar-fit')
          .type(ButtonType.Normal)
          .onClick((): void => this.canvasController.fitContent())
        Button('100%')
          .id('toolbar-reset')
          .type(ButtonType.Normal)
          .onClick((): void => this.canvasController.resetViewport())
      }
      .width('100%')
      .height(56)
      .padding({ left: 12, right: 12 })
      .backgroundColor(Color.White)

      FreeCanvas({
        document: this.document,
        controller: this.canvasController,
        nodeContentBuilder: DEMO_NODE_BUILDER,
        onChangeComplete: (event: FreeCanvasChangeEvent): void => this.acceptChange(event)
      })
        .layoutWeight(1)
        .width('100%')
    }
    .width('100%')
    .height('100%')
  }
}
