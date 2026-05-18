import { describe, it, expect } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import {
  buildIndexTimelineHeaderText,
  IndexTimelineView,
  resolveIndexTimelineBottomSpacerHeight,
  resolveIndexTimelineVisiblePlaceCount,
  shouldEnableIndexTimelineItem,
  shouldShowIndexTimelineGapHint,
  shouldShowIndexTimelineGroupItems
} from '../main/ets/pages/index/IndexTimelineView';

interface IndexTimelineThemeTest {
  pageBg?: string;
  textPrimary?: string;
  textSecondary?: string;
  textTertiary?: string;
  warning?: string;
}

interface IndexTimelineGroupTest {
  dayOffset: number;
  actualDateMs: number;
  dateHeader: string;
  events: EventEntity[];
}

interface IndexTimelineViewParamsTest {
  groupedEvents?: IndexTimelineGroupTest[];
  allEvents?: EventEntity[];
  isArchived?: boolean;
  isCompanionMode?: boolean;
  showWeather?: boolean;
  isPageRefreshing?: boolean;
  gapsCount?: number;
  theme?: IndexTimelineThemeTest;
  onIsDayCollapsed?: (dayOffset: number) => boolean;
  onToggleDay?: (dayOffset: number) => void;
  onRefresh?: () => void;
  onMoveUp?: (item: EventEntity) => void;
  onMoveDown?: (item: EventEntity) => void;
  onMainContentClick?: (item: EventEntity) => void;
  onTimeClick?: (item: EventEntity) => void;
  onTravelModeChange?: (item: EventEntity, mode: number) => void;
  onManualTravelInput?: (item: EventEntity, minutes: number) => void;
  onCommuteChange?: (item: EventEntity, minutes: number) => void;
  onConflictAction?: (item: EventEntity, strategy: string, gapMinutes: number) => void;
  onMoveToBacklog?: (item: EventEntity) => void;
  onDeleteEvent?: (item: EventEntity) => void;
  onOpenGapOptimize?: () => void;
}

interface IndexTimelineViewPrivateTest {
  groupedEvents: IndexTimelineGroupTest[];
  allEvents: EventEntity[];
  isArchived: boolean;
  isCompanionMode: boolean;
  showWeather: boolean;
  isPageRefreshing: boolean;
  gapsCount: number;
  theme: IndexTimelineThemeTest;
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
  setInitiallyProvidedValue(params: IndexTimelineViewParamsTest): void;
  updateStateVars(params: IndexTimelineViewParamsTest): void;
  initialRender(): void;
}

function buildTimelineEvent(id: number): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = `timeline_event_${id}`;
  event.sort_order = id;
  event.status = 1;
  return event;
}

export default function indexTimelineViewHelperTest() {
  describe('unit_test_case_generator_autofill_IndexTimelineViewHelper', () => {
    it('normal: visible_place_count_should_keep_positive_value', 0, () => {
      // Arrange
      const placeCount = 5;

      // Act
      const actual = resolveIndexTimelineVisiblePlaceCount(placeCount);

      // Assert
      expect(actual).assertEqual(5);
    });

    it('boundary: visible_place_count_should_clamp_negative_to_zero', 0, () => {
      // Arrange
      const placeCount = -2;

      // Act
      const actual = resolveIndexTimelineVisiblePlaceCount(placeCount);

      // Assert
      expect(actual).assertEqual(0);
    });

    it('invalid: group_items_should_hide_when_day_is_collapsed', 0, () => {
      // Arrange
      const isCollapsed = true;

      // Act
      const showItems = shouldShowIndexTimelineGroupItems(isCollapsed);

      // Assert
      expect(showItems).assertFalse();
    });

    it('conflict: gap_hint_should_require_not_archived_and_positive_gap_count', 0, () => {
      // Arrange
      const archived = true;
      const gapsCount = 2;

      // Act
      const archivedResult = shouldShowIndexTimelineGapHint(archived, gapsCount);
      const activeResult = shouldShowIndexTimelineGapHint(false, gapsCount);

      // Assert
      expect(archivedResult).assertFalse();
      expect(activeResult).assertTrue();
    });

    it('regression: spacer_height_should_match_companion_mode_switch', 0, () => {
      // Arrange
      const immersive = true;
      const normal = false;

      // Act
      const immersiveHeight = resolveIndexTimelineBottomSpacerHeight(immersive);
      const normalHeight = resolveIndexTimelineBottomSpacerHeight(normal);

      // Assert
      expect(immersiveHeight).assertEqual(24);
      expect(normalHeight).assertEqual(100);
    });

    it('combined: timeline_helper_matrix_should_keep_header_enable_and_hint_consistent', 0, () => {
      // Arrange
      const headerText = 'Day 1';

      // Act
      const header = buildIndexTimelineHeaderText(headerText, -1);
      const enabled = shouldEnableIndexTimelineItem(false);
      const collapsed = shouldShowIndexTimelineGroupItems(false);
      const gapHint = shouldShowIndexTimelineGapHint(false, 1);

      // Assert
      expect(header).assertEqual('Day 1 共0个地点');
      expect(enabled).assertTrue();
      expect(collapsed).assertTrue();
      expect(gapHint).assertTrue();
    });

    it('combined: timeline_view_instance_should_cover_default_callbacks_and_prop_sync', 0, () => {
      // Arrange
      const page = new IndexTimelineView(undefined, {} as LocalStorage) as Object as IndexTimelineViewPrivateTest;
      const event = buildTimelineEvent(1);
      const grouped: IndexTimelineGroupTest[] = [{
        dayOffset: 0,
        actualDateMs: 1,
        dateHeader: 'Day 1',
        events: [event]
      }];
      const initTheme: IndexTimelineThemeTest = {
        pageBg: '#111111',
        textPrimary: '#222222',
        textSecondary: '#333333',
        textTertiary: '#444444',
        warning: '#555555'
      };
      const nextGrouped: IndexTimelineGroupTest[] = [{
        dayOffset: 1,
        actualDateMs: 2,
        dateHeader: 'Day 2',
        events: [buildTimelineEvent(2)]
      }];
      const nextTheme: IndexTimelineThemeTest = {
        pageBg: '#AAAAAA',
        textPrimary: '#BBBBBB',
        textSecondary: '#CCCCCC',
        textTertiary: '#DDDDDD',
        warning: '#EEEEEE'
      };
      let callCount = 0;
      let lastMode = -1;
      let lastMinutes = -1;
      const initParams: IndexTimelineViewParamsTest = {
        groupedEvents: grouped,
        allEvents: [event],
        isArchived: true,
        isCompanionMode: true,
        showWeather: true,
        isPageRefreshing: true,
        gapsCount: 4,
        theme: initTheme,
        onIsDayCollapsed: (dayOffset: number) => dayOffset === 0,
        onToggleDay: (_dayOffset: number) => { callCount += 1; },
        onRefresh: () => { callCount += 1; },
        onMoveUp: (_item: EventEntity) => { callCount += 1; },
        onMoveDown: (_item: EventEntity) => { callCount += 1; },
        onMainContentClick: (_item: EventEntity) => { callCount += 1; },
        onTimeClick: (_item: EventEntity) => { callCount += 1; },
        onTravelModeChange: (_item: EventEntity, mode: number) => {
          lastMode = mode;
          callCount += 1;
        },
        onManualTravelInput: (_item: EventEntity, minutes: number) => {
          lastMinutes = minutes;
          callCount += 1;
        },
        onCommuteChange: (_item: EventEntity, minutes: number) => {
          lastMinutes = minutes;
          callCount += 1;
        },
        onConflictAction: (_item: EventEntity, _strategy: string, gapMinutes: number) => {
          lastMinutes = gapMinutes;
          callCount += 1;
        },
        onMoveToBacklog: (_item: EventEntity) => { callCount += 1; },
        onDeleteEvent: (_item: EventEntity) => { callCount += 1; },
        onOpenGapOptimize: () => { callCount += 1; }
      };
      const nextEvent = nextGrouped[0].events[0];
      const nextParams: IndexTimelineViewParamsTest = {
        groupedEvents: nextGrouped,
        allEvents: [nextEvent],
        isArchived: false,
        isCompanionMode: false,
        showWeather: false,
        isPageRefreshing: false,
        gapsCount: 0,
        theme: nextTheme
      };

      // Act
      const defaultCollapsed = page.onIsDayCollapsed(9);
      page.onToggleDay(9);
      page.onRefresh();
      page.onMoveUp(event);
      page.onMoveDown(event);
      page.onMainContentClick(event);
      page.onTimeClick(event);
      page.onTravelModeChange(event, 1);
      page.onManualTravelInput(event, 2);
      page.onCommuteChange(event, 3);
      page.onConflictAction(event, 'smart', 4);
      page.onMoveToBacklog(event);
      page.onDeleteEvent(event);
      page.onOpenGapOptimize();
      page.setInitiallyProvidedValue(initParams);
      const collapsedAfterInit = page.onIsDayCollapsed(0);
      page.onToggleDay(0);
      page.onRefresh();
      page.onMoveUp(event);
      page.onMoveDown(event);
      page.onMainContentClick(event);
      page.onTimeClick(event);
      page.onTravelModeChange(event, 8);
      page.onManualTravelInput(event, 16);
      page.onCommuteChange(event, 24);
      page.onConflictAction(event, 'delay', 32);
      page.onMoveToBacklog(event);
      page.onDeleteEvent(event);
      page.onOpenGapOptimize();
      page.updateStateVars(nextParams);
      const collapsedAfterUpdate = page.onIsDayCollapsed(0);

      // Assert
      expect(defaultCollapsed).assertFalse();
      expect(collapsedAfterInit).assertTrue();
      expect(collapsedAfterUpdate).assertTrue();
      expect(callCount).assertEqual(13);
      expect(lastMode).assertEqual(8);
      expect(lastMinutes).assertEqual(32);
      expect(page.groupedEvents.length).assertEqual(1);
      expect(page.groupedEvents[0].dayOffset).assertEqual(1);
      expect(page.allEvents[0].id).assertEqual(2);
      expect(page.isArchived).assertFalse();
      expect(page.isCompanionMode).assertFalse();
      expect(page.showWeather).assertFalse();
      expect(page.isPageRefreshing).assertFalse();
      expect(page.gapsCount).assertEqual(0);
      expect(page.theme.pageBg).assertEqual('#AAAAAA');
      expect(page.theme.textPrimary).assertEqual('#BBBBBB');
    });

    it('normal: timeline_view_initial_render_should_support_group_items_and_gap_hint_branch', 0, () => {
      // Arrange
      const page = new IndexTimelineView(undefined, {} as LocalStorage) as Object as IndexTimelineViewPrivateTest;
      const first = buildTimelineEvent(11);
      const second = buildTimelineEvent(12);
      page.setInitiallyProvidedValue({
        groupedEvents: [{
          dayOffset: 0,
          actualDateMs: 10,
          dateHeader: 'Day 1',
          events: [first, second]
        }],
        allEvents: [first, second],
        isArchived: false,
        isCompanionMode: false,
        showWeather: true,
        isPageRefreshing: false,
        gapsCount: 2,
        onIsDayCollapsed: (_dayOffset: number) => false
      });

      // Act
      let threw = false;
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
    });

    it('boundary: timeline_view_initial_render_should_support_collapsed_archived_branch', 0, () => {
      // Arrange
      const page = new IndexTimelineView(undefined, {} as LocalStorage) as Object as IndexTimelineViewPrivateTest;
      const event = buildTimelineEvent(21);
      page.setInitiallyProvidedValue({
        groupedEvents: [{
          dayOffset: 2,
          actualDateMs: 20,
          dateHeader: 'Day 2',
          events: [event]
        }],
        allEvents: [event],
        isArchived: true,
        isCompanionMode: true,
        showWeather: false,
        isPageRefreshing: true,
        gapsCount: 0,
        onIsDayCollapsed: (_dayOffset: number) => true
      });

      // Act
      let threw = false;
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
    });

    it('regression: timeline_view_initial_render_should_support_visible_group_without_gap_hint_in_companion_mode', 0, () => {
      // Arrange
      const page = new IndexTimelineView(undefined, {} as LocalStorage) as Object as IndexTimelineViewPrivateTest;
      const event = buildTimelineEvent(31);
      page.setInitiallyProvidedValue({
        groupedEvents: [{
          dayOffset: 3,
          actualDateMs: 30,
          dateHeader: 'Day 3',
          events: [event]
        }],
        allEvents: [event],
        isArchived: false,
        isCompanionMode: true,
        showWeather: false,
        isPageRefreshing: true,
        gapsCount: 0,
        onIsDayCollapsed: (_dayOffset: number) => false
      });
      let threw = false;

      // Act
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
      expect(resolveIndexTimelineBottomSpacerHeight(true)).assertEqual(24);
      expect(shouldShowIndexTimelineGapHint(false, 0)).assertFalse();
      expect(shouldEnableIndexTimelineItem(page.isArchived)).assertTrue();
    });

    it('combined: timeline_view_should_cover_hidden_group_and_header_matrix_with_negative_places', 0, () => {
      // Arrange
      const page = new IndexTimelineView(undefined, {} as LocalStorage) as Object as IndexTimelineViewPrivateTest;
      const event = buildTimelineEvent(41);
      page.setInitiallyProvidedValue({
        groupedEvents: [{
          dayOffset: 4,
          actualDateMs: 40,
          dateHeader: 'Day 4',
          events: [event]
        }],
        allEvents: [event],
        isArchived: false,
        isCompanionMode: false,
        showWeather: true,
        isPageRefreshing: false,
        gapsCount: 3,
        onIsDayCollapsed: (_dayOffset: number) => true
      });
      let threw = false;

      // Act
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }
      const header = buildIndexTimelineHeaderText('Day 4', -5);
      const hiddenItems = shouldShowIndexTimelineGroupItems(true);
      const archivedDisabled = shouldEnableIndexTimelineItem(true);

      // Assert
      expect(threw).assertFalse();
      expect(header.indexOf('Day 4') >= 0).assertTrue();
      expect(hiddenItems).assertFalse();
      expect(archivedDisabled).assertFalse();
      expect(shouldShowIndexTimelineGapHint(false, 3)).assertTrue();
    });

    it('boundary: timeline_header_text_should_keep_zero_place_count_visible', 0, () => {
      // Arrange
      const text = 'Day 5';

      // Act
      const header = buildIndexTimelineHeaderText(text, 0);

      // Assert
      expect(header.indexOf('Day 5') >= 0).assertTrue();
      expect(header.indexOf('0') >= 0).assertTrue();
    });

    it('combined: timeline_view_initial_render_should_support_mixed_collapsed_groups_and_gap_hint_matrix', 0, () => {
      // Arrange
      const page = new IndexTimelineView(undefined, {} as LocalStorage) as Object as IndexTimelineViewPrivateTest;
      const first = buildTimelineEvent(51);
      const second = buildTimelineEvent(52);
      page.setInitiallyProvidedValue({
        groupedEvents: [{
          dayOffset: 5,
          actualDateMs: 50,
          dateHeader: 'Day 5',
          events: [first]
        }, {
          dayOffset: 6,
          actualDateMs: 60,
          dateHeader: 'Day 6',
          events: [second]
        }],
        allEvents: [first, second],
        isArchived: false,
        isCompanionMode: true,
        showWeather: true,
        isPageRefreshing: false,
        gapsCount: 2,
        onIsDayCollapsed: (dayOffset: number) => dayOffset === 5
      });
      let threw = false;

      // Act
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }
      const firstHidden = shouldShowIndexTimelineGroupItems(page.onIsDayCollapsed(5));
      const secondVisible = shouldShowIndexTimelineGroupItems(page.onIsDayCollapsed(6));
      const gapHint = shouldShowIndexTimelineGapHint(false, 2);
      const spacerHeight = resolveIndexTimelineBottomSpacerHeight(true);

      // Assert
      expect(threw).assertFalse();
      expect(firstHidden).assertFalse();
      expect(secondVisible).assertTrue();
      expect(gapHint).assertTrue();
      expect(spacerHeight).assertEqual(24);
    });

    it('boundary: timeline_header_text_should_clamp_negative_place_count_to_zero_text', 0, () => {
      // Arrange
      const text = 'Day 6';

      // Act
      const header = buildIndexTimelineHeaderText(text, -9);

      // Assert
      expect(header.indexOf('Day 6') >= 0).assertTrue();
      expect(header.indexOf('0') >= 0).assertTrue();
    });

    it('combined: timeline_view_initial_render_should_support_archived_companion_mode_without_gap_hint', 0, () => {
      // Arrange
      const page = new IndexTimelineView(undefined, {} as LocalStorage) as Object as IndexTimelineViewPrivateTest;
      const first = buildTimelineEvent(61);
      const second = buildTimelineEvent(62);
      page.setInitiallyProvidedValue({
        groupedEvents: [{
          dayOffset: 7,
          actualDateMs: 70,
          dateHeader: 'Day 7',
          events: [first, second]
        }],
        allEvents: [first, second],
        isArchived: true,
        isCompanionMode: true,
        showWeather: false,
        isPageRefreshing: false,
        gapsCount: 4,
        onIsDayCollapsed: (_dayOffset: number) => false
      });
      let threw = false;

      // Act
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }
      const itemsVisible = shouldShowIndexTimelineGroupItems(page.onIsDayCollapsed(7));
      const itemEnabled = shouldEnableIndexTimelineItem(true);
      const gapHint = shouldShowIndexTimelineGapHint(true, 4);
      const spacerHeight = resolveIndexTimelineBottomSpacerHeight(true);

      // Assert
      expect(threw).assertFalse();
      expect(itemsVisible).assertTrue();
      expect(itemEnabled).assertFalse();
      expect(gapHint).assertFalse();
      expect(spacerHeight).assertEqual(24);
    });
  });
}

