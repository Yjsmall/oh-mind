import {
  CanvasDocument,
  CanvasTextNode,
  FreeCanvas,
  FreeCanvasChangeEvent,
  FreeCanvasController,
  FreeCanvasSaveResult
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
  @Local private multiSelect: boolean = false;
  @Local private revision: number = 0;
  @Local private saveResult: FreeCanvasSaveResult | undefined = undefined;
  @Local private activatedNodeId: string = '';
  @Local private failNextSave: boolean = false;
  @Local private flushCount: number = 0;
  @Local private discardCount: number = 0;
  private readonly canvasController: FreeCanvasController = new FreeCanvasController();

  private setMultiSelect(enabled: boolean): void {
    this.multiSelect = enabled;
    this.canvasController.setMultiSelectEnabled(enabled);
  }

  private acceptChange(event: FreeCanvasChangeEvent): void {
    if (this.failNextSave) {
      this.failNextSave = false;
      this.saveResult = { requestId: event.requestId, status: 'failure', message: 'Simulated failure' };
      return;
    }
    this.document = event.document;
    this.revision++;
    this.saveResult = { requestId: event.requestId, status: 'success', revision: this.revision };
  }

  build() {
    Column() {
      Scroll() {
        Row({ space: 8 }) {
          Button('Multi')
            .id('toolbar-multiselect')
            .type(ButtonType.Normal)
            .backgroundColor(this.multiSelect ? '#FF146C94' : '#FFE5E9ED')
            .fontColor(this.multiSelect ? Color.White : '#FF20252B')
            .onClick((): void => this.setMultiSelect(!this.multiSelect))
          Button('Flush')
            .id('toolbar-flush')
            .type(ButtonType.Normal)
            .onClick((): void => {
              this.canvasController.flushPendingChange();
              this.flushCount++;
            })
          Button('Discard')
            .id('toolbar-discard')
            .type(ButtonType.Normal)
            .onClick((): void => {
              this.canvasController.discardPendingChange();
              this.discardCount++;
            })
          Button('Undo')
            .id('toolbar-undo')
            .type(ButtonType.Normal)
            .onClick((): void => {
              this.canvasController.undo();
            })
          Button('Redo')
            .id('toolbar-redo')
            .type(ButtonType.Normal)
            .onClick((): void => {
              this.canvasController.redo();
            })
          Button('Add')
            .id('toolbar-add')
            .type(ButtonType.Normal)
            .onClick((): void => {
              this.canvasController.addTextNode('');
            })
          Button('Open')
            .id('toolbar-open')
            .type(ButtonType.Normal)
            .onClick((): void => {
              this.canvasController.activateSelectedNode();
            })
          Button('Fail next')
            .id('toolbar-fail-next-save')
            .type(ButtonType.Normal)
            .fontColor(this.failNextSave ? '#FFC01C28' : '#FF20252B')
            .onClick((): void => {
              this.failNextSave = true;
            })
          Button('Copy')
            .id('toolbar-copy')
            .type(ButtonType.Normal)
            .onClick((): void => {
              this.canvasController.copySelection();
            })
          Button('Delete')
            .id('toolbar-delete')
            .type(ButtonType.Normal)
            .onClick((): void => {
              this.canvasController.deleteSelection();
            })
          Button('Align L')
            .id('toolbar-align-left')
            .type(ButtonType.Normal)
            .onClick((): void => {
              this.canvasController.alignSelection('left');
            })
          Button('Row')
            .id('toolbar-row')
            .type(ButtonType.Normal)
            .onClick((): void => {
              this.canvasController.arrangeSelection('row');
            })
          Button('Column')
            .id('toolbar-column')
            .type(ButtonType.Normal)
            .onClick((): void => {
              this.canvasController.arrangeSelection('column');
            })
          Button('Space H')
            .id('toolbar-distribute-horizontal')
            .type(ButtonType.Normal)
            .onClick((): void => {
              this.canvasController.distributeSelection('horizontal');
            })
          Button('Auto')
            .id('toolbar-auto')
            .type(ButtonType.Normal)
            .onClick((): void => {
              this.canvasController.autoArrange();
            })
          Button('Fit')
            .id('toolbar-fit')
            .type(ButtonType.Normal)
            .onClick((): void => this.canvasController.fitContent())
          Button('100%')
            .id('toolbar-reset')
            .type(ButtonType.Normal)
            .onClick((): void => this.canvasController.resetViewport())
        }
        .height(56)
        .padding({ left: 12, right: 12 })
      }
      .id('main-toolbar')
      .width('100%')
      .height(56)
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .backgroundColor(Color.White)

      if (this.activatedNodeId.length > 0) {
        Text('Activated: ' + this.activatedNodeId)
          .id('node-activation-status')
          .width('100%')
          .height(28)
          .padding({ left: 12, right: 12 })
          .fontSize(12)
          .fontColor('#FF5D6670')
      }

      Text(`flush=${this.flushCount} discard=${this.discardCount}`)
        .id('flush-discard-status')
        .width('100%')
        .height(24)
        .padding({ left: 12, right: 12 })
        .fontSize(11)
        .fontColor('#FF9AA3AD')

      FreeCanvas({
        document: this.document,
        controller: this.canvasController,
        nodeContentBuilder: DEMO_NODE_BUILDER,
        committedRevision: this.revision,
        saveResult: this.saveResult,
        onChangeComplete: (event: FreeCanvasChangeEvent): void => this.acceptChange(event),
        onNodeActivate: (nodeId: string): void => {
          this.activatedNodeId = nodeId;
        }
      })
        .layoutWeight(1)
        .width('100%')
    }
    .width('100%')
    .height('100%')
  }
}