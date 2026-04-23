import { describe, it, expect } from '@ohos/hypium';
import { ThemeCenter } from '../main/ets/common/utils/ThemeCenter';
import { DomainConstants } from '../main/ets/common/constants/DomainConstants';
import {
  EventItemView,
  formatEventItemCommuteTime,
  formatEventItemTimestamp,
  getEventItemTravelModeIcon,
  resolveEventItemCompanionOpacity,
  resolveEventItemCompanionStateLabel,
  resolveEventItemActualRangeMeta,
  resolveEventItemConflictGapMinutes,
  resolveEventItemForecastRange,
  resolveEventItemPlanRange,
  resolveEventItemStartTimeDisplay,
  resolveEventItemThemeColor
} from '../main/ets/pages/components/views/EventItemView';
import { EventEntity } from '../main/ets/model/entity/EventEntity';

interface EventItemTimeRangeMetaTest {
  text: string;
  isEstimated: boolean;
}

interface EventItemPaletteTest {
  primary: Object;
  danger: Object;
  warning: Object;
  divider: Object;
  cardBg: Object;
  cardBgSoft: Object;
}

interface EventItemViewParamsTest {
  event?: EventEntity;
  index?: number;
  totalCount?: number;
  showTravelIndicator?: boolean;
  isCompanionMode?: boolean;
  companionCurrentEventId?: number;
  showWeather?: boolean;
  onMoveUp?: () => void;
  onMoveDown?: () => void;
  onMainContentClick?: () => void;
  onTimeClick?: () => void;
  onCommuteChange?: (minutes: number) => void;
  onEditClick?: () => void;
  onTravelModeChange?: (mode: number) => void;
  onManualTravelInput?: (minutes: number) => void;
  onConflictAction?: (item: EventEntity, strategy: string, gapMinutes: number) => void;
}

interface EventItemViewPrivateTest {
  event: EventEntity;
  index: number;
  totalCount: number;
  showTravelIndicator: boolean;
  isCompanionMode: boolean;
  companionCurrentEventId: number;
  showWeather: boolean;
  isReasonPopupShow: boolean;
  tempCommuteVal: string;
  isManualInputPopupShow: boolean;
  planningTimeDisplayMode: number;
  companionTimeDisplayMode: number;
  effectiveTheme: string;
  onMoveUp: () => void;
  onMoveDown: () => void;
  onMainContentClick: () => void;
  onTimeClick: () => void;
  onCommuteChange: (minutes: number) => void;
  onEditClick: () => void;
  onTravelModeChange: (mode: number) => void;
  onManualTravelInput: (minutes: number) => void;
  onConflictAction: (item: EventEntity, strategy: string, gapMinutes: number) => void;
  setInitiallyProvidedValue(params: EventItemViewParamsTest): void;
  updateStateVars(params: EventItemViewParamsTest): void;
  getPalette(): EventItemPaletteTest;
  getTravelModeIcon(mode: number): string;
  getDisplayTime(isStart: boolean): string;
  getCurrentDisplayMode(): number;
  switchDisplayMode(): void;
  getThemeColor(name: string): string;
  getStartTimeDisplay(): string;
  getEndTimeDisplay(): string;
  formatCommuteTime(minutes: number): string;
  formatTs(ts: number): string;
  getPlanRange(): string;
  getForecastRange(): string;
  getActualRangeMeta(): EventItemTimeRangeMetaTest;
  getActualMainColor(): Object;
  getCompanionOpacity(): number;
  getCompanionStateLabel(): string;
  getCompanionCardBackground(): Object;
  getCompanionBorderColor(): Object;
  getConflictGapMinutes(): number;
  TransportMenu(): void;
  ReasonPopupBuilder(): void;
  initialRender(): void;
}

function buildEventItemTestEvent(id: number): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = id === 1 ? '餐厅A' : '酒店B';
  event.type = id === 1 ? 0 : 3;
  event.source = id === 1 ? 1 : 0;
  event.duration = id === 1 ? 90 : 60;
  event.computed_time = id === 1 ? '09:00' : '11:00';
  event.fixed_start_time = id === 1 ? '09:05' : '11:05';
  event.actual_start_time = id === 1 ? 0 : new Date(2026, 3, 19, 11, 5, 0, 0).getTime();
  event.actual_end_time = id === 1 ? 0 : new Date(2026, 3, 19, 12, 5, 0, 0).getTime();
  event.forecast_start_time = id === 1 ? '09:10' : '11:10';
  event.forecast_end_time = id === 1 ? '10:40' : '12:10';
  event.dynamic_start_time = id === 1 ? new Date(2026, 3, 19, 9, 15, 0, 0).getTime() : 0;
  event.dynamic_end_time = id === 1 ? new Date(2026, 3, 19, 10, 45, 0, 0).getTime() : 0;
  event.is_forecast_conflict = id === 1;
  event.completion_status = id === 1 ? EventEntity.STATE_PENDING : EventEntity.STATE_SKIPPED;
  event.gap_minutes = id === 1 ? 20 : 0;
  event.conflict_msg = id === 1 ? '冲突 20 分钟' : '';
  event.lock_status = 0;
  return event;
}

export default function eventItemViewHelperTest() {
  describe('unit_test_case_generator_autofill_EventItemViewHelper', () => {
    it('normal: event_item_travel_mode_icon_should_map_drive_to_car', 0, () => {
      // Arrange
      const mode = 2;
      // Act
      const icon = getEventItemTravelModeIcon(mode);
      // Assert
      expect(icon).assertEqual('🚗');
    });

    it('boundary: event_item_commute_time_should_format_exact_hour', 0, () => {
      // Arrange
      const minutes = 120;
      // Act
      const text = formatEventItemCommuteTime(minutes);
      // Assert
      expect(text).assertEqual('2h');
    });

    it('invalid: event_item_travel_mode_icon_should_fallback_for_unknown_mode', 0, () => {
      // Arrange
      const mode = 999;
      // Act
      const icon = getEventItemTravelModeIcon(mode);
      // Assert
      expect(icon).assertEqual('🚗');
    });

    it('conflict: event_item_conflict_gap_should_parse_from_message_when_gap_missing', 0, () => {
      // Arrange
      const gapMinutes = 0;
      const conflictMsg = '与下一项冲突 25 分钟';
      // Act
      const resolved = resolveEventItemConflictGapMinutes(gapMinutes, conflictMsg);
      // Assert
      expect(resolved).assertEqual(25);
    });

    it('regression: td-20260412-event-item-walk-override-icon-should-stay-walk', 0, () => {
      // Arrange
      const mode = 4;
      // Act
      const icon = getEventItemTravelModeIcon(mode);
      // Assert
      expect(icon).assertEqual('🚶');
    });

    it('combined: event_item_gap_and_commute_text_should_match_expected', 0, () => {
      // Arrange
      const gapMinutes = 10;
      const conflictMsg = '冲突 30 分钟';
      const commuteMinutes = 95;
      // Act
      const resolvedGap = resolveEventItemConflictGapMinutes(gapMinutes, conflictMsg);
      const commuteText = formatEventItemCommuteTime(commuteMinutes);
      // Assert
      expect(resolvedGap).assertEqual(10);
      expect(commuteText).assertEqual('1h 35m');
    });
  });

  describe('unit_test_case_generator_autofill_EventItemViewHelperBranches', () => {
    it('normal: event_item_plan_range_should_join_start_and_end_by_duration', 0, () => {
      // Arrange
      const computedTime = '09:00';
      const fixedStartTime = '';
      const duration = 90;
      // Act
      const range = resolveEventItemPlanRange(computedTime, fixedStartTime, duration);
      // Assert
      expect(range).assertEqual('09:00-10:30');
    });

    it('normal: event_item_forecast_range_should_prefer_dynamic_range_when_both_bounds_present', 0, () => {
      // Arrange
      const dynamicStart = new Date(2026, 3, 19, 8, 10, 0, 0).getTime();
      const dynamicEnd = new Date(2026, 3, 19, 9, 40, 0, 0).getTime();
      const planRange = '08:00-09:30';

      // Act
      const range = resolveEventItemForecastRange(dynamicStart, dynamicEnd, planRange);

      // Assert
      expect(range).assertEqual('08:10-09:40');
    });

    it('boundary: event_item_forecast_range_should_fallback_to_plan_when_one_dynamic_bound_missing', 0, () => {
      // Arrange
      const dynamicStart = new Date(2026, 3, 19, 8, 10, 0, 0).getTime();
      const dynamicEnd = 0;
      const planRange = '08:00-09:30';

      // Act
      const range = resolveEventItemForecastRange(dynamicStart, dynamicEnd, planRange);

      // Assert
      expect(range).assertEqual(planRange);
    });

    it('combined: event_item_actual_range_meta_should_cover_actual_estimated_dynamic_and_plan_fallbacks', 0, () => {
      // Arrange
      const actualStart = new Date(2026, 3, 19, 10, 0, 0, 0).getTime();
      const actualEnd = new Date(2026, 3, 19, 11, 0, 0, 0).getTime();
      const dynamicStart = new Date(2026, 3, 19, 10, 15, 0, 0).getTime();
      const dynamicEnd = new Date(2026, 3, 19, 11, 15, 0, 0).getTime();
      const planRange = '10:00-11:00';

      // Act
      const exact = resolveEventItemActualRangeMeta(actualStart, actualEnd, 0, 0, 60, planRange);
      const estimatedFromActualStart = resolveEventItemActualRangeMeta(actualStart, 0, 0, 0, 45, planRange);
      const estimatedFromDynamic = resolveEventItemActualRangeMeta(0, 0, dynamicStart, dynamicEnd, 60, planRange);
      const fallback = resolveEventItemActualRangeMeta(0, 0, 0, 0, 60, planRange);

      // Assert
      expect(exact.text).assertEqual('10:00-11:00');
      expect(exact.isEstimated).assertFalse();
      expect(estimatedFromActualStart.text).assertEqual('10:00-10:45');
      expect(estimatedFromActualStart.isEstimated).assertTrue();
      expect(estimatedFromDynamic.text).assertEqual('10:15-11:15');
      expect(estimatedFromDynamic.isEstimated).assertTrue();
      expect(fallback.text).assertEqual(planRange);
      expect(fallback.isEstimated).assertTrue();
    });

    it('boundary: event_item_start_display_should_fallback_to_placeholder_when_both_times_empty', 0, () => {
      // Arrange
      const computedTime = '';
      const fixedStartTime = '';
      // Act
      const display = resolveEventItemStartTimeDisplay(computedTime, fixedStartTime);
      // Assert
      expect(display).assertEqual('--:--');
    });

    it('invalid: event_item_timestamp_should_return_placeholder_for_non_positive_timestamp', 0, () => {
      // Arrange
      const ts = 0;
      // Act
      const text = formatEventItemTimestamp(ts);
      // Assert
      expect(text).assertEqual('--:--');
    });

    it('conflict: event_item_theme_color_should_prioritize_event_type_over_name_keyword', 0, () => {
      // Arrange
      const eventType = 3;
      const eventSource = 0;
      const name = '吃饭地铁站';
      const effectiveTheme = 'light';
      const defaultPrimary = '#123456';
      // Act
      const color = resolveEventItemThemeColor(eventType, eventSource, name, effectiveTheme, defaultPrimary);
      // Assert
      expect(color).assertEqual('#9E9E9E');
    });

    it('regression: td-20260418-event_item_companion_state_label_should_keep_ready_for_current_pending_event', 0, () => {
      // Arrange
      const completionStatus = EventEntity.STATE_PENDING;
      const actualStartTime = 0;
      const eventId = 200;
      const companionCurrentEventId = 200;
      // Act
      const label = resolveEventItemCompanionStateLabel(completionStatus, actualStartTime, eventId, companionCurrentEventId);
      // Assert
      expect(label).assertEqual('READY');
    });

    it('combined: event_item_companion_opacity_and_state_should_match_completed_event_expectation', 0, () => {
      // Arrange
      const isCompanionMode = true;
      const eventId = 9;
      const companionCurrentEventId = 8;
      const completionStatus = EventEntity.STATE_COMPLETED;
      const actualStartTime = 1;
      // Act
      const opacity = resolveEventItemCompanionOpacity(
        isCompanionMode,
        eventId,
        companionCurrentEventId,
        completionStatus,
        actualStartTime
      );
      const label = resolveEventItemCompanionStateLabel(
        completionStatus,
        actualStartTime,
        eventId,
        companionCurrentEventId
      );
      // Assert
      expect(opacity).assertEqual(0.45);
      expect(label).assertEqual('COMPLETED');
    });

    it('combined: event_item_view_instance_should_cover_private_time_palette_and_companion_state_helpers', 0, () => {
      // Arrange
      const page = new EventItemView(undefined, {} as LocalStorage) as Object as EventItemViewPrivateTest;
      const initialEvent = buildEventItemTestEvent(1);
      const nextEvent = buildEventItemTestEvent(2);
      let callCount = 0;
      let lastMinutes = -1;
      let lastMode = -1;
      const initParams: EventItemViewParamsTest = {
        event: initialEvent,
        index: 0,
        totalCount: 3,
        showTravelIndicator: true,
        isCompanionMode: true,
        companionCurrentEventId: 1,
        showWeather: false,
        onMoveUp: () => { callCount += 1; },
        onMoveDown: () => { callCount += 1; },
        onMainContentClick: () => { callCount += 1; },
        onTimeClick: () => { callCount += 1; },
        onCommuteChange: (minutes: number) => {
          lastMinutes = minutes;
          callCount += 1;
        },
        onEditClick: () => { callCount += 1; },
        onTravelModeChange: (mode: number) => {
          lastMode = mode;
          callCount += 1;
        },
        onManualTravelInput: (minutes: number) => {
          lastMinutes = minutes;
          callCount += 1;
        },
        onConflictAction: (_item: EventEntity, _strategy: string, gapMinutes: number) => {
          lastMinutes = gapMinutes;
          callCount += 1;
        }
      };
      const nextParams: EventItemViewParamsTest = {
        event: nextEvent,
        index: 1,
        totalCount: 5,
        showTravelIndicator: false,
        isCompanionMode: true,
        companionCurrentEventId: 99,
        showWeather: true
      };

      // Act
      page.onMoveUp();
      page.onMoveDown();
      page.onMainContentClick();
      page.onTimeClick();
      page.onCommuteChange(5);
      page.onEditClick();
      page.onTravelModeChange(2);
      page.onManualTravelInput(10);
      page.onConflictAction(initialEvent, 'smart', 15);
      page.isReasonPopupShow = true;
      page.tempCommuteVal = '18';
      page.isManualInputPopupShow = true;
      page.effectiveTheme = 'dark';
      const darkPalette = page.getPalette();
      const defaultMode = page.getCurrentDisplayMode();
      page.setInitiallyProvidedValue(initParams);
      page.updateStateVars(initParams);
      const startPlan = page.getDisplayTime(true);
      page.switchDisplayMode();
      const displayMode = page.getCurrentDisplayMode();
      const startActual = page.getDisplayTime(true);
      const endActual = page.getDisplayTime(false);
      const walkIcon = page.getTravelModeIcon(4);
      const themeColor = page.getThemeColor('餐厅A');
      const startText = page.getStartTimeDisplay();
      const endText = page.getEndTimeDisplay();
      const commuteText = page.formatCommuteTime(95);
      const formattedTs = page.formatTs(initialEvent.dynamic_start_time);
      const planRange = page.getPlanRange();
      const forecastRange = page.getForecastRange();
      const actualMeta = page.getActualRangeMeta();
      const actualMainColor = page.getActualMainColor();
      const companionOpacity = page.getCompanionOpacity();
      const companionLabel = page.getCompanionStateLabel();
      const companionBg = page.getCompanionCardBackground();
      const companionBorder = page.getCompanionBorderColor();
      const gapMinutes = page.getConflictGapMinutes();
      page.onMoveUp();
      page.onMoveDown();
      page.onMainContentClick();
      page.onTimeClick();
      page.onCommuteChange(22);
      page.onEditClick();
      page.onTravelModeChange(3);
      page.onManualTravelInput(26);
      page.onConflictAction(initialEvent, 'delay', gapMinutes);
      page.updateStateVars(nextParams);
      const nextActualMeta = page.getActualRangeMeta();
      const nextOpacity = page.getCompanionOpacity();
      const nextLabel = page.getCompanionStateLabel();
      const nextBg = page.getCompanionCardBackground();
      const nextBorder = page.getCompanionBorderColor();

      // Assert
      expect(defaultMode).assertEqual(0);
      expect(darkPalette.primary).assertEqual(ThemeCenter.getPalette('dark').primary);
      expect(page.isReasonPopupShow).assertTrue();
      expect(page.tempCommuteVal).assertEqual('18');
      expect(page.isManualInputPopupShow).assertTrue();
      expect(startPlan).assertEqual('09:00');
      expect(displayMode).assertEqual(1);
      expect(startActual).assertEqual('未记录');
      expect(endActual).assertEqual('10:40');
      expect(walkIcon).assertEqual('🚶');
      expect(themeColor).assertEqual('#57C6B7');
      expect(startText).assertEqual('09:00');
      expect(endText).assertEqual('10:30');
      expect(commuteText).assertEqual('1h 35m');
      expect(formattedTs).assertEqual('09:15');
      expect(planRange).assertEqual('09:00-10:30');
      expect(forecastRange).assertEqual('09:15-10:45');
      expect(actualMeta.text).assertEqual('09:15-10:45');
      expect(actualMeta.isEstimated).assertTrue();
      expect(actualMainColor).assertEqual(ThemeCenter.getPalette('dark').danger);
      expect(companionOpacity).assertEqual(1);
      expect(companionLabel).assertEqual('READY');
      expect(companionBg).assertEqual(ThemeCenter.getPalette('dark').cardBgSoft);
      expect(companionBorder).assertEqual(ThemeCenter.getPalette('dark').primary);
      expect(gapMinutes).assertEqual(20);
      expect(callCount).assertEqual(9);
      expect(lastMode).assertEqual(3);
      expect(lastMinutes).assertEqual(20);
      expect(page.event.id).assertEqual(2);
      expect(page.index).assertEqual(1);
      expect(page.totalCount).assertEqual(5);
      expect(page.showTravelIndicator).assertFalse();
      expect(page.isCompanionMode).assertTrue();
      expect(page.companionCurrentEventId).assertEqual(99);
      expect(page.showWeather).assertTrue();
      expect(nextActualMeta.text).assertEqual('11:05-12:05');
      expect(nextActualMeta.isEstimated).assertFalse();
      expect(nextOpacity).assertEqual(0.3);
      expect(nextLabel).assertEqual('SKIPPED');
      expect(nextBg).assertEqual(ThemeCenter.getPalette('dark').cardBg);
      expect(nextBorder).assertEqual(ThemeCenter.getPalette('dark').warning);
    });

    it('normal: event_item_view_initial_render_should_support_plan_weather_and_ai_reason_branch', 0, () => {
      // Arrange
      const page = new EventItemView(undefined, {} as LocalStorage) as Object as EventItemViewPrivateTest;
      const event = buildEventItemTestEvent(1);
      event.pre_travel_min = 18;
      event.ai_reasoning = 'recommended';
      event.weather_text = 'sunny';
      event.weather_temperature = 26;
      event.note = 'window seat';
      event.transit_warning = true;
      page.setInitiallyProvidedValue({
        event: event,
        index: 0,
        totalCount: 2,
        showTravelIndicator: true,
        isCompanionMode: false,
        companionCurrentEventId: -1,
        showWeather: true
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

    it('boundary: event_item_view_initial_render_should_support_companion_loading_branch', 0, () => {
      // Arrange
      const page = new EventItemView(undefined, {} as LocalStorage) as Object as EventItemViewPrivateTest;
      const event = buildEventItemTestEvent(2);
      event.pre_travel_min = DomainConstants.COMMUTE_LOADING;
      event.weather_text = '';
      event.weather_temperature = 0;
      page.setInitiallyProvidedValue({
        event: event,
        index: 1,
        totalCount: 3,
        showTravelIndicator: true,
        isCompanionMode: true,
        companionCurrentEventId: 99,
        showWeather: false
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

    it('conflict: event_item_view_initial_render_should_support_walk_too_far_and_conflict_branch', 0, () => {
      // Arrange
      const page = new EventItemView(undefined, {} as LocalStorage) as Object as EventItemViewPrivateTest;
      const event = buildEventItemTestEvent(1);
      event.pre_travel_min = DomainConstants.COMMUTE_WALK_TOO_FAR;
      event.is_conflict = true;
      event.conflict_msg = 'conflict 20 min';
      page.setInitiallyProvidedValue({
        event: event,
        index: 0,
        totalCount: 2,
        showTravelIndicator: true,
        isCompanionMode: false,
        companionCurrentEventId: -1,
        showWeather: false
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

    it('invalid: event_item_view_initial_render_should_support_no_transit_branch', 0, () => {
      // Arrange
      const page = new EventItemView(undefined, {} as LocalStorage) as Object as EventItemViewPrivateTest;
      const event = buildEventItemTestEvent(2);
      event.pre_travel_min = DomainConstants.COMMUTE_NO_TRANSIT;
      event.travel_mode = 3;
      event.note = '';
      page.setInitiallyProvidedValue({
        event: event,
        index: 2,
        totalCount: 4,
        showTravelIndicator: true,
        isCompanionMode: false,
        companionCurrentEventId: -1,
        showWeather: true
      });
      page.effectiveTheme = 'dark';

      // Act
      let threw = false;
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
      expect(page.getTravelModeIcon(event.travel_mode)).assertEqual('🚇');
    });

    it('combined: event_item_view_initial_render_should_support_fallback_commute_and_manual_popup_branch', 0, () => {
      // Arrange
      const page = new EventItemView(undefined, {} as LocalStorage) as Object as EventItemViewPrivateTest;
      const event = buildEventItemTestEvent(1);
      event.pre_travel_min = DomainConstants.COMMUTE_FALLBACK_UNKNOWN;
      event.travel_mode = 2;
      event.transit_warning = false;
      event.ai_reasoning = '';
      event.weather_text = '';
      event.weather_temperature = 0;
      page.setInitiallyProvidedValue({
        event: event,
        index: 1,
        totalCount: 2,
        showTravelIndicator: true,
        isCompanionMode: true,
        companionCurrentEventId: 99,
        showWeather: true
      });
      page.companionTimeDisplayMode = 1;
      page.isManualInputPopupShow = true;
      page.tempCommuteVal = '33';

      // Act
      let threw = false;
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
      expect(page.formatCommuteTime(event.pre_travel_min)).assertEqual('16h 39m');
      expect(page.isManualInputPopupShow).assertTrue();
    });

    it('boundary: event_item_start_display_should_prefer_computed_time_over_fixed_time', 0, () => {
      // Arrange
      const computedTime = '10:20';
      const fixedStartTime = '09:30';
      // Act
      const display = resolveEventItemStartTimeDisplay(computedTime, fixedStartTime);
      // Assert
      expect(display).assertEqual('10:20');
    });

    it('combined: event_item_actual_range_meta_should_estimate_end_from_actual_start_and_duration', 0, () => {
      // Arrange
      const actualStart = new Date(2026, 3, 23, 8, 15).getTime();
      const duration = 75;
      const planRange = '08:00-09:00';
      // Act
      const meta = resolveEventItemActualRangeMeta(actualStart, 0, 0, 0, duration, planRange);
      // Assert
      expect(meta.isEstimated).assertTrue();
      expect(meta.text.indexOf('08:15') >= 0).assertTrue();
      expect(meta.text.indexOf('09:30') >= 0).assertTrue();
    });

    it('boundary: event_item_companion_future_pending_event_should_use_dimmed_default_state', 0, () => {
      // Arrange
      const eventId = 10;
      const currentEventId = 20;
      // Act
      const opacity = resolveEventItemCompanionOpacity(true, eventId, currentEventId, EventEntity.STATE_PENDING, 0);
      const label = resolveEventItemCompanionStateLabel(EventEntity.STATE_PENDING, 0, eventId, currentEventId);
      // Assert
      expect(opacity).assertEqual(0.55);
      expect(label).assertEqual('FUTURE');
    });

    it('conflict: event_item_theme_color_should_use_keyword_palette_for_food_and_hotel_names', 0, () => {
      // Arrange
      const defaultPrimary = '#123456';
      // Act
      const foodLight = resolveEventItemThemeColor(0, 0, '晚餐', 'light', defaultPrimary);
      const foodDark = resolveEventItemThemeColor(0, 0, '晚餐', 'dark', defaultPrimary);
      const hotelLight = resolveEventItemThemeColor(0, 0, '酒店入住', 'light', defaultPrimary);
      const hotelDark = resolveEventItemThemeColor(0, 0, '酒店入住', 'dark', defaultPrimary);
      // Assert
      expect(foodLight).assertEqual('#FF9800');
      expect(foodDark).assertEqual('#FFB85C');
      expect(hotelLight).assertEqual('#7B1FA2');
      expect(hotelDark).assertEqual('#B889E0');
    });

    it('combined: event_item_builders_should_render_transport_menu_and_reason_popup', 0, () => {
      // Arrange
      const page = new EventItemView(undefined, {} as LocalStorage) as Object as EventItemViewPrivateTest;
      const event = buildEventItemTestEvent(1);
      let threw = false;
      event.pre_travel_min = 18;
      event.travel_mode = 2;
      event.ai_reasoning = 'route reason';
      page.setInitiallyProvidedValue({
        event: event,
        index: 0,
        totalCount: 1,
        showTravelIndicator: true,
        isCompanionMode: false,
        companionCurrentEventId: -1,
        showWeather: false
      });
      page.effectiveTheme = 'light';

      // Act
      try {
        page.TransportMenu();
        page.ReasonPopupBuilder();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
    });
  });
}
