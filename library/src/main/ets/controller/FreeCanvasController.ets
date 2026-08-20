import {
  CanvasAlignment,
  CanvasArrangement,
  CanvasDistribution
} from '../geometry/CanvasEditingGeometry';

export type FreeCanvasInteractionMode = 'select' | 'pan';
export type FreeCanvasEdgeDirection = 'forward' | 'reverse' | 'none' | 'both';

export interface FreeCanvasControllerBinding {
  readonly fitContent: () => void;
  readonly resetViewport: () => void;
  readonly setInteractionMode: (mode: FreeCanvasInteractionMode) => void;
  readonly clearSelection: () => void;
  readonly canUndo: () => boolean;
  readonly canRedo: () => boolean;
  readonly undo: () => boolean;
  readonly redo: () => boolean;
  readonly copySelection: () => boolean;
  readonly deleteSelection: () => boolean;
  readonly alignSelection: (alignment: CanvasAlignment) => boolean;
  readonly arrangeSelection: (arrangement: CanvasArrangement) => boolean;
  readonly distributeSelection: (distribution: CanvasDistribution) => boolean;
  readonly autoArrange: () => boolean;
  readonly setSelectedEdgeLabel: (label: string) => boolean;
  readonly setSelectedEdgeDirection: (direction: FreeCanvasEdgeDirection) => boolean;
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

  canUndo(): boolean {
    return this.binding?.canUndo() ?? false;
  }

  canRedo(): boolean {
    return this.binding?.canRedo() ?? false;
  }

  undo(): boolean {
    return this.binding?.undo() ?? false;
  }

  redo(): boolean {
    return this.binding?.redo() ?? false;
  }

  copySelection(): boolean {
    return this.binding?.copySelection() ?? false;
  }

  deleteSelection(): boolean {
    return this.binding?.deleteSelection() ?? false;
  }

  alignSelection(alignment: CanvasAlignment): boolean {
    return this.binding?.alignSelection(alignment) ?? false;
  }

  arrangeSelection(arrangement: CanvasArrangement): boolean {
    return this.binding?.arrangeSelection(arrangement) ?? false;
  }

  distributeSelection(distribution: CanvasDistribution): boolean {
    return this.binding?.distributeSelection(distribution) ?? false;
  }

  autoArrange(): boolean {
    return this.binding?.autoArrange() ?? false;
  }

  setSelectedEdgeLabel(label: string): boolean {
    return this.binding?.setSelectedEdgeLabel(label) ?? false;
  }

  setSelectedEdgeDirection(direction: FreeCanvasEdgeDirection): boolean {
    return this.binding?.setSelectedEdgeDirection(direction) ?? false;
  }
}
