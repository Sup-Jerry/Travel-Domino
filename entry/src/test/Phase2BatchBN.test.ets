import { describe, it, expect } from '@ohos/hypium';
import {
  canPlanListRepromptPermission,
  resolvePlanListShareCategory,
  resolvePlanListShareEndTime,
  resolvePlanListShareIcon,
  resolvePlanListShareStartTime
} from '../main/ets/pages/PlanListPage';
import { TravelPlanItem } from '../main/ets/model/interface/IStandardEvent';
import {
  isPlanSearchTrashPlan,
  normalizePlanSearchKeyword,
  resolvePlanSearchCacheKey,
  resolvePlanSearchStateColor,
  resolvePlanSearchStateLabel,
  shouldPlanSearchLoadMore
} from '../main/ets/pages/PlanSearchPage';
import {
  buildMapPickerCoordinateFallbackAddress,
  formatMapPickerDistance,
  isMapPickerAddressResolving,
  isMapPickerCoordinateValid
} from '../main/ets/pages/MapPickerPage';
import {
  normalizeMyPageLightHintKey,
  normalizeMyPageUsername,
  shouldMyPageEmitLightHint
} from '../main/ets/pages/MyPage';
import {
  resolveSettingsGeneralAiPoiInput,
  resolveSettingsGeneralIdleGapTriggerMinutes,
  resolveSettingsGeneralMinEventDuration,
  resolveSettingsGeneralThemeModeText
} from '../main/ets/pages/SettingsGeneralPage';
import {
  clampSettingsPreferenceInt,
  parseSettingsPreferenceModeCount,
  parseSettingsPreferenceModeFrequency,
  resolveSettingsPreferenceConsistencyRateText,
  resolveSettingsPreferenceModeTotalCount,
  resolveSettingsPreferencePercentText,
  resolveSettingsPreferencePercentWidth
} from '../main/ets/pages/SettingsPreferenceInsightsPage';

function buildEvent(overrides?: Partial<TravelPlanItem>): TravelPlanItem {
  const item = {} as TravelPlanItem;
  item.fixedStartTime = '09:30';
  item.computedStartTime = '10:00';
  item.priority = 0;
  item.lockStatus = 0;
  item.type = 'NORMAL';
  if (overrides) {
    if (overrides.fixedStartTime !== undefined) {
      item.fixedStartTime = overrides.fixedStartTime;
    }
    if (overrides.computedStartTime !== undefined) {
      item.computedStartTime = overrides.computedStartTime;
    }
    if (overrides.priority !== undefined) {
      item.priority = overrides.priority;
    }
    if (overrides.lockStatus !== undefined) {
      item.lockStatus = overrides.lockStatus;
    }
    if (overrides.type !== undefined) {
      item.type = overrides.type;
    }
  }
  return item;
}

export default function phase2BatchBNTest() {
  describe('Phase2BatchBN', () => {
    describe('phase2_batch_bn_plan_list_page_pure_logic', () => {
      it('normal: reprompt_should_allow_when_never_prompted_before', 0, () => {
        // Arrange
        const now = 1000;
        // Act
        const allowed = canPlanListRepromptPermission(now, 999, false, 600000);
        // Assert
        expect(allowed).assertTrue();
      });

      it('boundary: reprompt_should_block_when_cooldown_not_reached', 0, () => {
        // Arrange
        const now = 1999;
        const lastPromptAt = 1000;
        // Act
        const allowed = canPlanListRepromptPermission(now, lastPromptAt, true, 1000);
        // Assert
        expect(allowed).assertFalse();
      });

      it('invalid: share_start_should_fallback_to_computed_time_when_fixed_empty', 0, () => {
        // Arrange
        const event = buildEvent({ fixedStartTime: '', computedStartTime: '10:15' });
        // Act
        const start = resolvePlanListShareStartTime(event);
        // Assert
        expect(start).assertEqual('10:15');
      });

      it('conflict: share_icon_should_use_anchor_icon_when_locked_or_anchor', 0, () => {
        // Arrange
        const locked = buildEvent({ lockStatus: 1, priority: 0, type: 'NORMAL' });
        const anchor = buildEvent({ lockStatus: 0, priority: 0, type: 'ANCHOR' });
        // Act
        const iconByLock = resolvePlanListShareIcon(locked);
        const iconByType = resolvePlanListShareIcon(anchor);
        // Assert
        expect(iconByLock).assertEqual('⏰');
        expect(iconByType).assertEqual('⏰');
      });

      it('regression: td-20260417-share_end_should_keep_valid_hhmm_after_duration_add', 0, () => {
        // Arrange
        const event = buildEvent({ fixedStartTime: '09:30' });
        // Act
        const end = resolvePlanListShareEndTime(event, 30);
        // Assert
        expect(end).assertEqual('10:00');
      });

      it('combined: share_category_and_default_icon_should_match_flexible_event', 0, () => {
        // Arrange
        const event = buildEvent({ priority: 0, lockStatus: 0, type: 'NORMAL' });
        // Act
        const category = resolvePlanListShareCategory(event);
        const icon = resolvePlanListShareIcon(event);
        // Assert
        expect(category).assertEqual('灵活行程');
        expect(icon).assertEqual('📍');
      });
    });

    describe('phase2_batch_bn_plan_search_page_pure_logic', () => {
      it('normal: keyword_should_trim_and_cache_key_should_lowercase', 0, () => {
        // Arrange
        const raw = '  HaNgZhOu  ';
        // Act
        const keyword = normalizePlanSearchKeyword(raw);
        const cacheKey = resolvePlanSearchCacheKey(raw);
        // Assert
        expect(keyword).assertEqual('HaNgZhOu');
        expect(cacheKey).assertEqual('hangzhou');
      });

      it('boundary: state_should_mark_archived_when_not_trash_and_status_is_2', 0, () => {
        // Arrange
        const status = 2;
        // Act
        const label = resolvePlanSearchStateLabel(status, 0);
        const color = resolvePlanSearchStateColor(status, 0);
        // Assert
        expect(label).assertEqual('归档');
        expect(color).assertEqual('#7A8699');
      });

      it('invalid: trash_plan_should_be_false_for_negative_delete_time', 0, () => {
        // Arrange
        const deleteTime = -1;
        // Act
        const isTrash = isPlanSearchTrashPlan(deleteTime);
        // Assert
        expect(isTrash).assertFalse();
      });

      it('conflict: trash_state_should_override_status_when_delete_time_positive', 0, () => {
        // Arrange
        const status = 1;
        const deleteTime = 123;
        // Act
        const label = resolvePlanSearchStateLabel(status, deleteTime);
        const color = resolvePlanSearchStateColor(status, deleteTime);
        // Assert
        expect(label).assertEqual('回收站');
        expect(color).assertEqual('#D03D3D');
      });

      it('regression: td-20260417-load_more_guard_should_block_when_any_flag_not_ready', 0, () => {
        // Arrange
        // Act
        const blockWhenSearching = shouldPlanSearchLoadMore(true, true, false, true);
        const blockWhenNoMore = shouldPlanSearchLoadMore(true, false, false, false);
        // Assert
        expect(blockWhenSearching).assertFalse();
        expect(blockWhenNoMore).assertFalse();
      });

      it('combined: cache_key_should_use_empty_token_for_blank_keyword', 0, () => {
        // Arrange
        const raw = '   ';
        // Act
        const key = resolvePlanSearchCacheKey(raw);
        const canLoad = shouldPlanSearchLoadMore(true, false, false, true);
        // Assert
        expect(key).assertEqual('__empty__');
        expect(canLoad).assertTrue();
      });
    });

    describe('phase2_batch_bn_map_picker_page_pure_logic', () => {
      it('normal: coordinate_should_reject_zero_zero_even_if_in_range', 0, () => {
        // Arrange
        // Act
        const valid = isMapPickerCoordinateValid(0, 0);
        // Assert
        expect(valid).assertFalse();
      });

      it('boundary: distance_should_floor_meter_value_below_1000', 0, () => {
        // Arrange
        const distance = 999.9;
        // Act
        const text = formatMapPickerDistance(distance);
        // Assert
        expect(text).assertEqual('999m');
      });

      it('invalid: coordinate_should_reject_non_finite_value', 0, () => {
        // Arrange
        const lat = Number.POSITIVE_INFINITY;
        // Act
        const valid = isMapPickerCoordinateValid(lat, 116.4);
        // Assert
        expect(valid).assertFalse();
      });

      it('conflict: resolving_state_should_detect_getting_location_prefix', 0, () => {
        // Arrange
        const address = '正在获取当前位置...';
        // Act
        const resolving = isMapPickerAddressResolving(address);
        // Assert
        expect(resolving).assertTrue();
      });

      it('regression: td-20260417-fallback_address_should_keep_5_digits_for_zero_padding', 0, () => {
        // Arrange
        const lat = 1;
        const lng = 2;
        // Act
        const text = buildMapPickerCoordinateFallbackAddress(lat, lng);
        // Assert
        expect(text).assertEqual('已选位置(1.00000, 2.00000)');
      });

      it('combined: distance_and_resolving_should_support_ready_address_with_km_text', 0, () => {
        // Arrange
        const address = '东京塔';
        // Act
        const resolving = isMapPickerAddressResolving(address);
        const distanceText = formatMapPickerDistance(1500);
        // Assert
        expect(resolving).assertFalse();
        expect(distanceText).assertEqual('1.5km');
      });
    });

    describe('phase2_batch_bn_my_page_pure_logic', () => {
      it('normal: username_should_accept_valid_chinese_and_space', 0, () => {
        // Arrange
        const input = '  张三 01 ';
        // Act
        const username = normalizeMyPageUsername(input);
        // Assert
        expect(username).assertEqual('张三 01');
      });

      it('boundary: username_should_reject_when_over_custom_max_length', 0, () => {
        // Arrange
        const input = 'abcde';
        // Act
        const username = normalizeMyPageUsername(input, 4);
        // Assert
        expect(username).assertEqual('');
      });

      it('invalid: light_hint_should_not_emit_when_next_key_blank', 0, () => {
        // Arrange
        // Act
        const shouldEmit = shouldMyPageEmitLightHint('k', 1000, '   ', 2000, 1000);
        // Assert
        expect(shouldEmit).assertFalse();
      });

      it('conflict: light_hint_should_emit_when_key_changed_within_dedup_window', 0, () => {
        // Arrange
        const lastKey = 'profile_offline:a';
        const nextKey = 'profile_cloud_fail:a';
        // Act
        const shouldEmit = shouldMyPageEmitLightHint(lastKey, 1000, nextKey, 1500, 10000);
        // Assert
        expect(shouldEmit).assertTrue();
      });

      it('regression: td-20260417-light_hint_should_allow_same_key_when_dedup_exactly_elapsed', 0, () => {
        // Arrange
        const key = 'profile_offline:user1';
        // Act
        const shouldEmit = shouldMyPageEmitLightHint(key, 1000, key, 3000, 2000);
        // Assert
        expect(shouldEmit).assertTrue();
      });

      it('combined: light_hint_key_normalization_should_trim_then_participate_in_emit', 0, () => {
        // Arrange
        const rawKey = '  avatar_cloud_sync_pending:user2  ';
        // Act
        const normalized = normalizeMyPageLightHintKey(rawKey);
        const shouldEmit = shouldMyPageEmitLightHint('', 0, normalized, 10, 12000);
        // Assert
        expect(normalized).assertEqual('avatar_cloud_sync_pending:user2');
        expect(shouldEmit).assertTrue();
      });
    });

    describe('phase2_batch_bn_settings_general_page_pure_logic', () => {
      it('normal: theme_text_should_map_light_mode', 0, () => {
        // Arrange
        // Act
        const text = resolveSettingsGeneralThemeModeText('light');
        // Assert
        expect(text).assertEqual('浅色');
      });

      it('boundary: idle_gap_minutes_should_parse_int_prefix_from_decimal_string', 0, () => {
        // Arrange
        const input = '15.9';
        // Act
        const value = resolveSettingsGeneralIdleGapTriggerMinutes(input, 45);
        // Assert
        expect(value).assertEqual(15);
      });

      it('invalid: min_event_duration_should_fallback_to_current_when_input_nan', 0, () => {
        // Arrange
        const input = 'not-a-number';
        // Act
        const value = resolveSettingsGeneralMinEventDuration(input, 60);
        // Assert
        expect(value).assertEqual(60);
      });

      it('conflict: ai_poi_input_should_use_fallback_when_invalid_text', 0, () => {
        // Arrange
        const input = 'abc';
        // Act
        const value = resolveSettingsGeneralAiPoiInput(input, 6);
        // Assert
        expect(value).assertEqual(6);
      });

      it('regression: td-20260417-ai_poi_input_should_keep_numeric_input_in_allowed_range', 0, () => {
        // Arrange
        const input = '8';
        // Act
        const value = resolveSettingsGeneralAiPoiInput(input, 6);
        // Assert
        expect(value).assertEqual(8);
      });

      it('combined: idle_and_duration_should_normalize_in_same_round', 0, () => {
        // Arrange
        // Act
        const idle = resolveSettingsGeneralIdleGapTriggerMinutes('-5', 45);
        const duration = resolveSettingsGeneralMinEventDuration('-1', 30);
        // Assert
        expect(idle).assertEqual(1);
        expect(duration).assertEqual(1);
      });
    });

    describe('phase2_batch_bn_settings_preference_insights_page_pure_logic', () => {
      it('normal: clamp_should_round_and_keep_inside_range', 0, () => {
        // Arrange
        const value = 1.6;
        // Act
        const result = clampSettingsPreferenceInt(value, 0, 2);
        // Assert
        expect(result).assertEqual(2);
      });

      it('boundary: parse_mode_count_should_return_zero_when_value_is_zero', 0, () => {
        // Arrange
        const raw = '{"1":0}';
        // Act
        const value = parseSettingsPreferenceModeCount(raw, '1');
        // Assert
        expect(value).assertEqual(0);
      });

      it('invalid: clamp_should_return_min_when_value_not_finite', 0, () => {
        // Arrange
        const value = Number.NaN;
        // Act
        const result = clampSettingsPreferenceInt(value, 3, 9);
        // Assert
        expect(result).assertEqual(3);
      });

      it('conflict: mode_frequency_should_parse_each_mode_key_independently', 0, () => {
        // Arrange
        const raw = '{"-1":1,"0":2,"1":3,"2":4}';
        // Act
        const freq = parseSettingsPreferenceModeFrequency(raw);
        // Assert
        expect(freq.modeCustom).assertEqual(1);
        expect(freq.modeDefault).assertEqual(2);
        expect(freq.modeSoldier).assertEqual(3);
        expect(freq.modeLeisure).assertEqual(4);
      });

      it('regression: td-20260417-percent_text_and_width_should_keep_one_decimal_rule', 0, () => {
        // Arrange
        // Act
        const text = resolveSettingsPreferencePercentText(1, 3);
        const width = resolveSettingsPreferencePercentWidth(1, 3);
        // Assert
        expect(text).assertEqual('33.3%');
        expect(width).assertEqual('33.3%');
      });

      it('combined: total_count_and_consistency_rate_should_handle_empty_and_non_empty_cases', 0, () => {
        // Arrange
        const freq = parseSettingsPreferenceModeFrequency('{"0":2,"1":1}');
        // Act
        const total = resolveSettingsPreferenceModeTotalCount(freq);
        const emptyRate = resolveSettingsPreferenceConsistencyRateText(0, 0);
        const normalRate = resolveSettingsPreferenceConsistencyRateText(2, 1);
        // Assert
        expect(total).assertEqual(3);
        expect(emptyRate.indexOf('%') >= 0).assertFalse();
        expect(normalRate).assertEqual('66.7%');
      });
    });
  });
}
