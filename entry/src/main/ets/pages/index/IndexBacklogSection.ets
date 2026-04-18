import { BacklogView } from '../components/views/BacklogView';
import { TravelPlanItem } from '../../model/interface/IStandardEvent';

export function resolveIndexBacklogSectionMaxHeight(): string {
  return '30%';
}

export function getDefaultIndexBacklogSectionDividerColor(): string {
  return '#E7EDF5';
}

@Component
export struct IndexBacklogSection {
  @Prop items: TravelPlanItem[] = [];
  @Prop isExpanded: boolean = false;
  @Prop dividerColor: string = getDefaultIndexBacklogSectionDividerColor();

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
        .constraintSize({ maxHeight: resolveIndexBacklogSectionMaxHeight() })
        .zIndex(1);

      Divider().color(this.dividerColor);
    }
    .width('100%');
  }
}
