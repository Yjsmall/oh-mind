export type FreeCanvasInteractionMode = 'select' | 'pan';

export interface FreeCanvasControllerBinding {
  readonly fitContent: () => void;
  readonly resetViewport: () => void;
  readonly setInteractionMode: (mode: FreeCanvasInteractionMode) => void;
  readonly clearSelection: () => void;
}

export class FreeCanvasController {
  private binding: FreeCanvasControllerBinding | undefined = undefined;

  bind(binding: FreeCanvasControllerBinding): void {
    this.binding = binding;
  }

  unbind(binding: FreeCanvasControllerBinding): void {
    if (this.binding === binding) {
      this.binding = undefined;
    }
  }

  fitContent(): void {
    this.binding?.fitContent();
  }

  resetViewport(): void {
    this.binding?.resetViewport();
  }

  setInteractionMode(mode: FreeCanvasInteractionMode): void {
    this.binding?.setInteractionMode(mode);
  }

  clearSelection(): void {
    this.binding?.clearSelection();
  }
}
