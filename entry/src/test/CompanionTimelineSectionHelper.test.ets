import { describe, it, expect } from '@ohos/hypium';
import { ThemeCenter } from '../main/ets/common/utils/ThemeCenter';
import {
  CompanionTimelineSection,
  getCompanionTimelineFilterSummary,
  getCompanionTimelineVisibleCount,
  isCompanionTimelineFocused,
  shouldShowCompanionTimelineEmptyState
} from '../main/ets/pages/components/views/companion/CompanionTimelineSection';
import { EventEntity } from '../main/ets/model/entity/EventEntity';

interface CompanionTimelineSectionPaletteTest {
  textPrimary: Object;
  textSecondary: Object;
  companionBg: Object;
}

interface CompanionTimelineSectionParamsTest {
  focusedEventId?: number;
  filterLabel?: string;
  focusPosition?: number;
  timelineCount?: number;
  events?: EventEntity[];
}

interface CompanionTimelineSectionPrivateTest {
  focusedEventId: number;
  filterLabel: string;
  focusPosition: number;
  timelineCount: number;
  events: EventEntity[];
  effectiveTheme: string;
  getStateDotColor: (event: EventEntity) => Object;
  getEventStateLabel: (event: EventEntity) => string;
  getStateTagTextColor: (event: EventEntity) => Object;
  getStateTagBackgroundColor: (event: EventEntity) => Object;
  getStateBorderColor: (event: EventEntity) => Object;
  getTimelineSupplement: (event: EventEntity) => string;
  onItemTap: (event: EventEntity, index: number) => void;
  onScrollIndex: (start: number, end: number, center: number) => void;
  onScrollStop: () => void;
  setInitiallyProvidedValue(params: CompanionTimelineSectionParamsTest): void;
  updateStateVars(params: CompanionTimelineSectionParamsTest): void;
  getThemePalette(): CompanionTimelineSectionPaletteTest;
}

function buildTimelineEvent(id: number, name: string): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = name;
  return event;
}

export default function companionTimelineSectionHelperTest() {
  describe('unit_test_case_generator_autofill_CompanionTimelineSectionHelper', () => {
    it('normal: timeline_focus_should_match_same_event_id', 0, () => {
      // Arrange
      const itemId = 100;
      const focusedEventId = 100;

      // Act
      const focused = isCompanionTimelineFocused(itemId, focusedEventId);

      // Assert
      expect(focused).assertTrue();
    });

    it('boundary: visible_count_should_keep_minimum_one_when_timeline_empty', 0, () => {
      // Arrange
      const timelineCount = 0;

      // Act
      const visibleCount = getCompanionTimelineVisibleCount(timelineCount);

      // Assert
      expect(visibleCount).assertEqual(1);
    });

    it('invalid: timeline_empty_state_should_be_false_for_negative_count', 0, () => {
      // Arrange
      const timelineCount = -1;

      // Act
      const isEmpty = shouldShowCompanionTimelineEmptyState(timelineCount);

      // Assert
      expect(isEmpty).assertFalse();
    });

    it('conflict: timeline_focus_should_be_false_when_ids_conflict', 0, () => {
      // Arrange
      const itemId = 101;
      const focusedEventId = 202;

      // Act
      const focused = isCompanionTimelineFocused(itemId, focusedEventId);

      // Assert
      expect(focused).assertFalse();
    });

    it('regression: filter_summary_should_keep_filter_and_position_tokens', 0, () => {
      // Arrange
      const filterLabel = '进行中';
      const focusPosition = 2;
      const timelineCount = 0;

      // Act
      const summary = getCompanionTimelineFilterSummary(filterLabel, focusPosition, timelineCount);

      // Assert
      expect(summary.includes(filterLabel)).assertTrue();
      expect(summary.includes('2/1')).assertTrue();
    });

    it('combined: summary_and_empty_state_should_follow_count_matrix', 0, () => {
      // Arrange
      const emptySummary = getCompanionTimelineFilterSummary('全部', 0, 0);
      const nonEmptySummary = getCompanionTimelineFilterSummary('全部', 3, 8);
      const emptyVisible = shouldShowCompanionTimelineEmptyState(0);
      const nonEmptyVisible = shouldShowCompanionTimelineEmptyState(8);

      // Act
      const result = emptySummary.includes('0/1')
        && nonEmptySummary.includes('3/8')
        && emptyVisible
        && !nonEmptyVisible;

      // Assert
      expect(result).assertTrue();
    });

    it('combined: timeline_section_instance_should_sync_props_and_keep_default_render_helpers_stable', 0, () => {
      // Arrange
      const page = new CompanionTimelineSection(undefined, {} as LocalStorage) as Object as CompanionTimelineSectionPrivateTest;
      const first = buildTimelineEvent(1, 'museum');
      const second = buildTimelineEvent(2, 'station');
      const third = buildTimelineEvent(3, 'airport');

      // Act
      const dotColor = page.getStateDotColor(first);
      const stateLabel = page.getEventStateLabel(first);
      const tagTextColor = page.getStateTagTextColor(first);
      const tagBgColor = page.getStateTagBackgroundColor(first);
      const borderColor = page.getStateBorderColor(first);
      const supplement = page.getTimelineSupplement(first);
      page.onItemTap(first, 0);
      page.onScrollIndex(0, 1, 0);
      page.onScrollStop();
      page.setInitiallyProvidedValue({
        focusedEventId: first.id,
        filterLabel: '全部',
        focusPosition: 1,
        timelineCount: 2,
        events: [first, second]
      });
      page.updateStateVars({
        focusedEventId: third.id,
        filterLabel: '跳过',
        focusPosition: 2,
        timelineCount: 1,
        events: [third]
      });
      page.effectiveTheme = 'dark';
      const palette = page.getThemePalette();

      // Assert
      expect(dotColor).assertEqual('#999');
      expect(stateLabel).assertEqual('--');
      expect(tagTextColor).assertEqual('#666');
      expect(tagBgColor).assertEqual('#F5F5F5');
      expect(borderColor).assertEqual('#DDD');
      expect(supplement).assertEqual('--');
      expect(page.focusedEventId).assertEqual(third.id);
      expect(page.filterLabel).assertEqual('跳过');
      expect(page.focusPosition).assertEqual(2);
      expect(page.timelineCount).assertEqual(1);
      expect(page.events.length).assertEqual(1);
      expect(palette.textPrimary).assertEqual(ThemeCenter.getPalette('dark').textPrimary);
      expect(palette.textSecondary).assertEqual(ThemeCenter.getPalette('dark').textSecondary);
      expect(palette.companionBg).assertEqual(ThemeCenter.getPalette('dark').companionBg);
    });
  });
}
