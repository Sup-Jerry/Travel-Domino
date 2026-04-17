import { describe, it, expect } from '@ohos/hypium';
import {
  buildPlanListShareEventItems,
  sortPlanListShareEvents
} from '../main/ets/pages/PlanListPage';
import {
  isPlanSearchCacheFresh,
  resolvePlanSearchResultText
} from '../main/ets/pages/PlanSearchPage';
import {
  resolveMapPickerCenterHint,
  resolveMapPickerSelectionAddress,
  resolveMapPickerStorageKey
} from '../main/ets/pages/MapPickerPage';
import {
  resolveMyPageAvatarSyncPendingHint,
  resolveMyPageAvatarUpdateToast,
  resolveMyPageProfileBootstrapHint
} from '../main/ets/pages/MyPage';
import {
  buildSettingsGeneralAiPoiRangeConfig,
  SettingsGeneralAiPoiInputState
} from '../main/ets/pages/SettingsGeneralPage';
import {
  buildSettingsPreferenceModeUsageItems,
  ModeFrequencyView,
  normalizeSettingsPreferenceCount,
  resolveSettingsPreferenceDensityText,
  resolveSettingsPreferenceDominantModeText,
  resolveSettingsPreferenceEnergyText,
  resolveSettingsPreferencePaceText,
  resolveSettingsPreferencePreferenceText,
  resolveSettingsPreferenceStrategySummary,
  resolveSettingsPreferenceWeatherLevelText
} from '../main/ets/pages/SettingsPreferenceInsightsPage';
import { AiDailyPoiRangeConfig } from '../main/ets/common/utils/PreferenceManager';
import { TravelPlanItem } from '../main/ets/model/interface/IStandardEvent';
import { UserStrategyProfile } from '../main/ets/domain/strategy/UserStrategyProfile';

function buildShareSourceEvent(overrides?: Partial<TravelPlanItem>): TravelPlanItem {
  const item = {} as TravelPlanItem;
  item.name = '景点A';
  item.address = '地址A';
  item.duration = 90;
  item.dayOffset = 0;
  item.sortOrder = 0;
  item.fixedStartTime = '09:30';
  item.computedStartTime = '10:00';
  item.priority = 0;
  item.lockStatus = 0;
  item.type = 'NORMAL';
  if (overrides) {
    if (overrides.name !== undefined) {
      item.name = overrides.name;
    }
    if (overrides.address !== undefined) {
      item.address = overrides.address;
    }
    if (overrides.duration !== undefined) {
      item.duration = overrides.duration;
    }
    if (overrides.dayOffset !== undefined) {
      item.dayOffset = overrides.dayOffset;
    }
    if (overrides.sortOrder !== undefined) {
      item.sortOrder = overrides.sortOrder;
    }
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

function buildAiPoiInputState(overrides?: Partial<SettingsGeneralAiPoiInputState>): SettingsGeneralAiPoiInputState {
  const state: SettingsGeneralAiPoiInputState = {
    defaultMinInput: '4',
    defaultMaxInput: '6',
    soldierMinInput: '5',
    soldierMaxInput: '8',
    leisureMinInput: '3',
    leisureMaxInput: '5'
  };
  if (overrides) {
    if (overrides.defaultMinInput !== undefined) {
      state.defaultMinInput = overrides.defaultMinInput;
    }
    if (overrides.defaultMaxInput !== undefined) {
      state.defaultMaxInput = overrides.defaultMaxInput;
    }
    if (overrides.soldierMinInput !== undefined) {
      state.soldierMinInput = overrides.soldierMinInput;
    }
    if (overrides.soldierMaxInput !== undefined) {
      state.soldierMaxInput = overrides.soldierMaxInput;
    }
    if (overrides.leisureMinInput !== undefined) {
      state.leisureMinInput = overrides.leisureMinInput;
    }
    if (overrides.leisureMaxInput !== undefined) {
      state.leisureMaxInput = overrides.leisureMaxInput;
    }
  }
  return state;
}

function buildAiPoiRangeConfig(): AiDailyPoiRangeConfig {
  return {
    defaultMin: 4,
    defaultMax: 6,
    soldierMin: 5,
    soldierMax: 8,
    leisureMin: 3,
    leisureMax: 5
  };
}

function buildStrategyProfile(overrides?: Partial<UserStrategyProfile>): UserStrategyProfile {
  const profile: UserStrategyProfile = {
    avgDensity: 1,
    avgPace: 1,
    avgPreference: 0,
    avgEnergy: 1,
    modeFrequency: '{}',
    sampleCount: 0,
    updatedAt: 0,
    manualOverrideEnabled: false,
    consistencyMatchCount: 0,
    consistencyMismatchCount: 0,
    lastConsistencyCheckAt: 0
  };
  if (overrides) {
    if (overrides.avgDensity !== undefined) {
      profile.avgDensity = overrides.avgDensity;
    }
    if (overrides.avgPace !== undefined) {
      profile.avgPace = overrides.avgPace;
    }
    if (overrides.avgPreference !== undefined) {
      profile.avgPreference = overrides.avgPreference;
    }
    if (overrides.avgEnergy !== undefined) {
      profile.avgEnergy = overrides.avgEnergy;
    }
    if (overrides.modeFrequency !== undefined) {
      profile.modeFrequency = overrides.modeFrequency;
    }
    if (overrides.sampleCount !== undefined) {
      profile.sampleCount = overrides.sampleCount;
    }
    if (overrides.updatedAt !== undefined) {
      profile.updatedAt = overrides.updatedAt;
    }
    if (overrides.manualOverrideEnabled !== undefined) {
      profile.manualOverrideEnabled = overrides.manualOverrideEnabled;
    }
    if (overrides.consistencyMatchCount !== undefined) {
      profile.consistencyMatchCount = overrides.consistencyMatchCount;
    }
    if (overrides.consistencyMismatchCount !== undefined) {
      profile.consistencyMismatchCount = overrides.consistencyMismatchCount;
    }
    if (overrides.lastConsistencyCheckAt !== undefined) {
      profile.lastConsistencyCheckAt = overrides.lastConsistencyCheckAt;
    }
  }
  return profile;
}

export default function phase2BatchBWTest() {
  describe('Phase2BatchBW', () => {
    describe('phase2_batch_bw_plan_list_page_pure_logic', () => {
      it('normal: share_events_should_sort_by_day_offset_then_sort_order', 0, () => {
        // Arrange
        const events = [
          buildShareSourceEvent({ name: 'B', dayOffset: 1, sortOrder: 2 }),
          buildShareSourceEvent({ name: 'A', dayOffset: 0, sortOrder: 5 }),
          buildShareSourceEvent({ name: 'C', dayOffset: 1, sortOrder: 1 })
        ];
        // Act
        const sorted = sortPlanListShareEvents(events);
        // Assert
        expect(sorted[0].name).assertEqual('A');
        expect(sorted[1].name).assertEqual('C');
        expect(sorted[2].name).assertEqual('B');
      });

      it('boundary: share_events_should_apply_name_location_and_duration_fallbacks', 0, () => {
        // Arrange
        const events = [
          buildShareSourceEvent({
            name: '   ',
            address: '',
            duration: 0,
            fixedStartTime: '',
            computedStartTime: '',
            dayOffset: -2
          })
        ];
        // Act
        const items = buildPlanListShareEventItems(events);
        // Assert
        expect(items.length).assertEqual(1);
        expect(items[0].name).assertEqual('未命名地点');
        expect(items[0].location).assertEqual('待补充地点');
        expect(items[0].duration).assertEqual(0.5);
        expect(items[0].dayOffset).assertEqual(0);
        expect(items[0].startTime).assertEqual('--:--');
        expect(items[0].endTime).assertEqual('--:--');
      });
    });

    describe('phase2_batch_bw_plan_search_page_pure_logic', () => {
      it('normal: cache_fresh_should_allow_when_ttl_exactly_met', 0, () => {
        // Arrange
        // Act
        const fresh = isPlanSearchCacheFresh(1000, 4000, 3000);
        // Assert
        expect(fresh).assertTrue();
      });

      it('invalid: cache_fresh_should_reject_invalid_or_reverse_timestamp', 0, () => {
        // Arrange
        // Act
        const invalidNow = isPlanSearchCacheFresh(1000, Number.NaN, 3000);
        const reverseTime = isPlanSearchCacheFresh(5000, 4000, 3000);
        // Assert
        expect(invalidNow).assertFalse();
        expect(reverseTime).assertFalse();
      });

      it('combined: result_text_should_prioritize_searching_and_sanitize_count', 0, () => {
        // Arrange
        // Act
        const searching = resolvePlanSearchResultText(true, true, 99);
        const loadingMore = resolvePlanSearchResultText(false, true, 5.9);
        const normal = resolvePlanSearchResultText(false, false, -1);
        // Assert
        expect(searching).assertEqual('搜索中...');
        expect(loadingMore).assertEqual('结果 5 条（加载更多中）');
        expect(normal).assertEqual('结果 0 条');
      });
    });

    describe('phase2_batch_bw_map_picker_page_pure_logic', () => {
      it('normal: center_hint_should_match_route_source', 0, () => {
        // Arrange
        // Act
        const geocode = resolveMapPickerCenterHint('geocode', '西湖');
        const existing = resolveMapPickerCenterHint('existing', '');
        const current = resolveMapPickerCenterHint('current', '');
        // Assert
        expect(geocode).assertEqual('已按“西湖”定位到附近，可拖动微调');
        expect(existing).assertEqual('已定位到已保存坐标，可拖动微调');
        expect(current).assertEqual('已定位到当前位置，可拖动选点');
      });

      it('boundary: selection_address_should_trim_or_fallback_for_unknown_text', 0, () => {
        // Arrange
        // Act
        const trimmed = resolveMapPickerSelectionAddress('  杭州东站  ', 30.1, 120.2);
        const fallback = resolveMapPickerSelectionAddress('未知坐标点', 1, 2);
        // Assert
        expect(trimmed).assertEqual('杭州东站');
        expect(fallback).assertEqual('已选位置(1.00000, 2.00000)');
      });

      it('combined: storage_key_should_scope_positive_plan_id_only', 0, () => {
        // Arrange
        // Act
        const scoped = resolveMapPickerStorageKey(12.8);
        const globalZero = resolveMapPickerStorageKey(0);
        const globalNegative = resolveMapPickerStorageKey(-1);
        // Assert
        expect(scoped).assertEqual('pickedLocationStr_12');
        expect(globalZero).assertEqual('pickedLocationStr');
        expect(globalNegative).assertEqual('pickedLocationStr');
      });
    });

    describe('phase2_batch_bw_my_page_pure_logic', () => {
      it('normal: bootstrap_hint_should_build_offline_hint_with_guest_fallback', 0, () => {
        // Arrange
        // Act
        const hint = resolveMyPageProfileBootstrapHint('', 'offline');
        // Assert
        expect(hint !== null).assertTrue();
        if (hint) {
          expect(hint.key).assertEqual('profile_offline:guest_local');
          expect(hint.message).assertEqual('当前为离线缓存资料');
        }
      });

      it('boundary: avatar_feedback_should_split_synced_and_pending_states', 0, () => {
        // Arrange
        // Act
        const syncedToast = resolveMyPageAvatarUpdateToast('SYNCED');
        const pendingToast = resolveMyPageAvatarUpdateToast('PENDING');
        const pendingHint = resolveMyPageAvatarSyncPendingHint('user_9');
        // Assert
        expect(syncedToast).assertEqual('头像已更新并同步');
        expect(pendingToast).assertEqual('头像已更新（本地）');
        expect(pendingHint.key).assertEqual('avatar_cloud_sync_pending:user_9');
        expect(pendingHint.message).assertEqual('云端同步失败或延迟，稍后将自动重试');
      });

      it('invalid: bootstrap_hint_should_return_null_for_ready_state', 0, () => {
        // Arrange
        // Act
        const hint = resolveMyPageProfileBootstrapHint('acc_1', 'ready');
        // Assert
        expect(hint === null).assertTrue();
      });
    });

    describe('phase2_batch_bw_settings_general_page_pure_logic', () => {
      it('normal: ai_poi_range_config_should_swap_min_max_and_clamp_each_mode', 0, () => {
        // Arrange
        const current = buildAiPoiRangeConfig();
        const inputs = buildAiPoiInputState({
          defaultMinInput: '10',
          defaultMaxInput: '4',
          soldierMinInput: '20',
          soldierMaxInput: '0',
          leisureMinInput: 'x',
          leisureMaxInput: '2'
        });
        // Act
        const next = buildSettingsGeneralAiPoiRangeConfig(inputs, current);
        // Assert
        expect(next.defaultMin).assertEqual(4);
        expect(next.defaultMax).assertEqual(10);
        expect(next.soldierMin).assertEqual(1);
        expect(next.soldierMax).assertEqual(12);
        expect(next.leisureMin).assertEqual(2);
        expect(next.leisureMax).assertEqual(3);
      });
    });

    describe('phase2_batch_bw_settings_preference_insights_page_pure_logic', () => {
      it('normal: text_resolvers_should_cover_density_pace_preference_energy_and_weather', 0, () => {
        // Arrange
        // Act
        const weather = resolveSettingsPreferenceWeatherLevelText(2);
        const density = resolveSettingsPreferenceDensityText(0);
        const pace = resolveSettingsPreferencePaceText(2);
        const preference = resolveSettingsPreferencePreferenceText(4);
        const energy = resolveSettingsPreferenceEnergyText(1);
        // Assert
        expect(weather).assertEqual('高');
        expect(density).assertEqual('低');
        expect(pace).assertEqual('紧凑');
        expect(preference).assertEqual('夜景');
        expect(energy).assertEqual('中等');
      });

      it('boundary: strategy_summary_should_return_insufficient_copy_before_threshold', 0, () => {
        // Arrange
        const profile = buildStrategyProfile({
          sampleCount: 2,
          manualOverrideEnabled: false
        });
        // Act
        const summary = resolveSettingsPreferenceStrategySummary(profile);
        // Assert
        expect(summary).assertEqual('样本不足，继续使用 AI 后会形成更稳定画像');
      });

      it('conflict: dominant_mode_should_prefer_highest_count_and_fallback_to_none_when_empty', 0, () => {
        // Arrange
        const freq: ModeFrequencyView = {
          modeCustom: 6,
          modeDefault: 2,
          modeSoldier: 5,
          modeLeisure: 4
        };
        // Act
        const dominant = resolveSettingsPreferenceDominantModeText(freq, 17);
        const empty = resolveSettingsPreferenceDominantModeText(freq, 0);
        // Assert
        expect(dominant).assertEqual('自定义');
        expect(empty).assertEqual('暂无');
      });

      it('regression: mode_usage_items_and_safe_count_should_keep_labels_order_and_floor_positive_values', 0, () => {
        // Arrange
        const freq: ModeFrequencyView = {
          modeCustom: 1,
          modeDefault: 2,
          modeSoldier: 3,
          modeLeisure: 4
        };
        // Act
        const items = buildSettingsPreferenceModeUsageItems(freq);
        const count = normalizeSettingsPreferenceCount(3.9);
        const invalidCount = normalizeSettingsPreferenceCount(Number.NaN);
        // Assert
        expect(items.length).assertEqual(4);
        expect(items[0].label).assertEqual('默认');
        expect(items[1].label).assertEqual('特种兵');
        expect(items[2].label).assertEqual('休闲');
        expect(items[3].label).assertEqual('自定义');
        expect(count).assertEqual(3);
        expect(invalidCount).assertEqual(0);
      });

      it('combined: strategy_summary_should_render_full_profile_dimensions_after_threshold', 0, () => {
        // Arrange
        const profile = buildStrategyProfile({
          avgDensity: 2,
          avgPace: 0,
          avgPreference: 3,
          avgEnergy: 2,
          sampleCount: 8,
          manualOverrideEnabled: true
        });
        // Act
        const summary = resolveSettingsPreferenceStrategySummary(profile);
        // Assert
        expect(summary).assertEqual('高密度 · 松弛节奏 · 文化偏好 · 充沛体力');
      });
    });
  });
}
