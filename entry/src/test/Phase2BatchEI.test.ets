import { describe, expect, it } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { IndexTimelineView } from '../main/ets/pages/index/IndexTimelineView';

interface IndexTimelineThemeEI {
  pageBg: string;
  textPrimary: string;
  textSecondary: string;
  textTertiary: string;
  warning: string;
}

interface IndexTimelineGroupEI {
  dayOffset: number;
  actualDateMs: number;
  dateHeader: string;
  events: EventEntity[];
}

interface IndexTimelineParamsEI {
  groupedEvents?: IndexTimelineGroupEI[];
  allEvents?: EventEntity[];
  isArchived?: boolean;
  isCompanionMode?: boolean;
  showWeather?: boolean;
  isPageRefreshing?: boolean;
  gapsCount?: number;
  onIsDayCollapsed?: (dayOffset: number) => boolean;
  onToggleDay?: (dayOffset: number) => void;
}

interface IndexTimelineViewPrivateEI {
  groupedEvents: IndexTimelineGroupEI[];
  allEvents: EventEntity[];
  isArchived: boolean;
  isCompanionMode: boolean;
  showWeather: boolean;
  isPageRefreshing: boolean;
  gapsCount: number;
  theme: IndexTimelineThemeEI;
  onIsDayCollapsed: (dayOffset: number) => boolean;
  onToggleDay: (dayOffset: number) => void;
  onRefresh: () => void;
  onMoveUp: (item: EventEntity) => void;
  onMoveDown: (item: EventEntity) => void;
  onMainContentClick: (item: EventEntity) => void;
  onTimeClick: (item: EventEntity) => void;
  onTravelModeChange: (item: EventEntity, mode: number) => void;
  onManualTravelInput: (item: EventEntity, minutes: number) => void;
  onCommuteChange: (item: EventEntity, minutes: number) => void;
  onConflictAction: (item: EventEntity, strategy: string, gapMinutes: number) => void;
  onMoveToBacklog: (item: EventEntity) => void;
  onDeleteEvent: (item: EventEntity) => void;
  onOpenGapOptimize: () => void;
  setInitiallyProvidedValue(params: IndexTimelineParamsEI): void;
  updateStateVars(params: IndexTimelineParamsEI): void;
  initialRender(): void;
  buildDateHeader(text: string, dayOffset: number, placeCount: number): void;
  swipeStartAction(item: EventEntity): void;
  swipeEndAction(item: EventEntity): void;
}

function buildTimelineEventEI(id: number, name: string = `event_${id}`): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = name;
  event.sort_order = id;
  event.status = 1;
  event.duration = 30;
  event.computed_time = '2026-04-23 09:00';
  return event;
}

function createIndexTimelineViewEI(): IndexTimelineViewPrivateEI {
  return new IndexTimelineView(undefined, {} as LocalStorage) as Object as IndexTimelineViewPrivateEI;
}

export default function phase2BatchEITest() {
  describe('phase2BatchEITest', () => {
    it('normal: index_timeline_private_builders_should_render_expanded_active_group', 0, () => {
      // Arrange
      const page = createIndexTimelineViewEI();
      const first = buildTimelineEventEI(401, 'museum');
      const second = buildTimelineEventEI(402, 'cafe');
      let toggledDay = -1;
      const groupedEvents: IndexTimelineGroupEI[] = [{
          dayOffset: 0,
          actualDateMs: 100,
          dateHeader: 'Day 1',
          events: [first, second]
      }];
      const params: IndexTimelineParamsEI = {
        groupedEvents: groupedEvents,
        allEvents: [first, second],
        isArchived: false,
        isCompanionMode: false,
        showWeather: true,
        isPageRefreshing: false,
        gapsCount: 2,
        onIsDayCollapsed: (_dayOffset: number) => false,
        onToggleDay: (dayOffset: number) => {
          toggledDay = dayOffset;
        }
      };
      page.setInitiallyProvidedValue(params);

      // Act
      let threw = false;
      try {
        page.buildDateHeader('Day 1', 0, 2);
        page.swipeStartAction(first);
        page.swipeEndAction(first);
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
      expect(toggledDay).assertEqual(-1);
    });

    it('boundary: index_timeline_private_builders_should_render_collapsed_archived_group', 0, () => {
      // Arrange
      const page = createIndexTimelineViewEI();
      const item = buildTimelineEventEI(403, 'locked');
      const groupedEvents: IndexTimelineGroupEI[] = [{
          dayOffset: 2,
          actualDateMs: 200,
          dateHeader: 'Day 3',
          events: [item]
      }];
      const params: IndexTimelineParamsEI = {
        groupedEvents: groupedEvents,
        allEvents: [item],
        isArchived: true,
        isCompanionMode: true,
        showWeather: false,
        isPageRefreshing: true,
        gapsCount: 0,
        onIsDayCollapsed: (_dayOffset: number) => true
      };
      page.setInitiallyProvidedValue(params);

      // Act
      let threw = false;
      try {
        page.buildDateHeader('Day 3', 2, 1);
        page.swipeStartAction(item);
        page.swipeEndAction(item);
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
    });

    it('combined: index_timeline_default_callbacks_should_accept_all_action_shapes', 0, () => {
      // Arrange
      const page = createIndexTimelineViewEI();
      const item = buildTimelineEventEI(404, 'combined');

      // Act
      let threw = false;
      try {
        page.onToggleDay(4);
        page.onRefresh();
        page.onMoveUp(item);
        page.onMoveDown(item);
        page.onMainContentClick(item);
        page.onTimeClick(item);
        page.onTravelModeChange(item, 1);
        page.onManualTravelInput(item, 15);
        page.onCommuteChange(item, 20);
        page.onConflictAction(item, 'SMART', 25);
        page.onMoveToBacklog(item);
        page.onDeleteEvent(item);
        page.onOpenGapOptimize();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
    });
  });
}
