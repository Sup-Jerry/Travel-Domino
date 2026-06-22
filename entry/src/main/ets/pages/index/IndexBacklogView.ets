import { EventEntity } from '../../model/entity/EventEntity';
import { TravelPlanItem } from '../../model/interface/IStandardEvent';
import { IndexBacklogSection } from './IndexBacklogSection';

type IndexBacklogViewVoidAction = () => void;
type IndexBacklogViewMoveAction = (item: TravelPlanItem) => void;

export function shouldIncludeIndexBacklogEvent(status: number): boolean {
  return status !== 1;
}

export function resolveIndexBacklogItems(events: EventEntity[]): TravelPlanItem[] {
  return events
    .filter((event: EventEntity) => shouldIncludeIndexBacklogEvent(event.status))
    .map((event: EventEntity) => event.toInterface());
}

@Component
export struct IndexBacklogView {
  @Prop events: EventEntity[] = [];
  @Prop isExpanded: boolean = false;
  @Prop dividerColor: string = '#E7EDF5';

  onToggleExpand: IndexBacklogViewVoidAction = () => {};
  onMoveToSchedule: IndexBacklogViewMoveAction = () => {};
  onMoveAllToSchedule: IndexBacklogViewVoidAction = () => {};

  private resolveBacklogItems(): TravelPlanItem[] {
    return resolveIndexBacklogItems(this.events);
  }

  build() {
    IndexBacklogSection({
      items: this.resolveBacklogItems(),
      isExpanded: this.isExpanded,
      dividerColor: this.dividerColor,
      onToggleExpand: this.onToggleExpand,
      onMoveToSchedule: this.onMoveToSchedule,
      onMoveAllToSchedule: this.onMoveAllToSchedule
    });
  }
}
