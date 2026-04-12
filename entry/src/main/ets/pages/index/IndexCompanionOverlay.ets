import { TimelineViewModel } from '../../viewmodel/TimelineViewModel';
import { CompanionView } from '../components/views/CompanionView';

export function shouldShowIndexCompanionOverlay(isVisible: boolean): boolean {
  return isVisible;
}

export function resolveIndexCompanionOverlayZIndex(overlayZIndex: number): number {
  return overlayZIndex;
}

@Component
export struct IndexCompanionOverlay {
  @Prop vm: TimelineViewModel = new TimelineViewModel();
  @Prop isVisible: boolean = false;
  @Prop overlayZIndex: number = 10;

  build() {
    Stack() {
      if (shouldShowIndexCompanionOverlay(this.isVisible)) {
        CompanionView({
          vm: this.vm,
          isShow: $isVisible
        })
          .zIndex(resolveIndexCompanionOverlayZIndex(this.overlayZIndex))
          .transition({
            type: TransitionType.All,
            opacity: 0,
            translate: { y: 12 },
            scale: { x: 0.985, y: 0.985 }
          })
      }
    }
  }
}
