import { BacklogView } from '../components/views/BacklogView';
import { TravelPlanItem } from '../../model/interface/IStandardEvent';

@Component
export struct IndexBacklogSection {
  @Prop items: TravelPlanItem[] = [];
  @Prop isExpanded: boolean = false;
  @Prop dividerColor: string = '#E7EDF5';

  onToggleExpand: () => void = () => {};
  onMoveToSchedule: (item: TravelPlanItem) => void = () => {};
  onMoveAllToSchedule: () => void = () => {};

  build() {
    Column() {
      BacklogView({
        items: this.items,
        isExpanded: this.isExpanded,
        onToggleExpand: () => this.onToggleExpand(),
        onMoveToSchedule: (item: TravelPlanItem) => this.onMoveToSchedule(item),
        onMoveAllToSchedule: () => this.onMoveAllToSchedule()
      })
        .constraintSize({ maxHeight: '30%' })
        .zIndex(1);

      Divider().color(this.dividerColor);
    }
    .width('100%');
  }
}
