import { EventEntity } from '../../model/entity/EventEntity';
import { TravelPlanItem } from '../../model/interface/IStandardEvent';
import { IndexBacklogSection } from './IndexBacklogSection';

@Component
export struct IndexBacklogView {
  @Prop events: EventEntity[] = [];
  @Prop isExpanded: boolean = false;
  @Prop dividerColor: string = '#E7EDF5';

  onToggleExpand: () => void = () => {};
  onMoveToSchedule: (item: TravelPlanItem) => void = () => {};
  onMoveAllToSchedule: () => void = () => {};

  private resolveBacklogItems(): TravelPlanItem[] {
    return this.events
      .filter((event: EventEntity) => event.status !== 1)
      .map((event: EventEntity) => event.toInterface());
  }

  build() {
    IndexBacklogSection({
      items: this.resolveBacklogItems(),
      isExpanded: this.isExpanded,
      dividerColor: this.dividerColor,
      onToggleExpand: () => this.onToggleExpand(),
      onMoveToSchedule: (item: TravelPlanItem) => this.onMoveToSchedule(item),
      onMoveAllToSchedule: () => this.onMoveAllToSchedule()
    });
  }
}
