import { TimelineViewModel } from '../../viewmodel/TimelineViewModel';
import { CompanionView } from '../components/views/CompanionView';

@Component
export struct IndexCompanionOverlay {
  @Prop vm: TimelineViewModel = new TimelineViewModel();
  @Prop isVisible: boolean = false;
  @Prop overlayZIndex: number = 10;
  @Prop backRequestToken: number = 0;

  build() {
    Stack() {
      if (this.isVisible) {
        CompanionView({
          vm: this.vm,
          isShow: $isVisible,
          backRequestToken: $backRequestToken
        })
          .zIndex(this.overlayZIndex)
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
