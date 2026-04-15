import { describe, expect, it } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { PlanStatus } from '../main/ets/domain/statemachine/PlanStatus';
import { ComposableStrategy, DensityLevel, EnergyLevel, PaceLevel, PreferenceType } from '../main/ets/domain/strategy/TravelStrategyDimensions';
import { PreferenceManager } from '../main/ets/common/utils/PreferenceManager';
import {
  DEFAULT_WEATHER_USER_PREFERENCE,
  GeoPointInput,
  PlanNodeWeatherBinding,
  WeatherCollabOptions,
  WeatherSchedulePolicy,
  WeatherStageType,
  WeatherSuggestion,
  WeatherUserPreference
} from '../main/ets/domain/services/WeatherModels';
import { WeatherFacade } from '../main/ets/domain/services/WeatherFacade';
import { WeatherRefreshScheduler } from '../main/ets/domain/services/WeatherRefreshScheduler';
import { ITimelineWeatherHost, TimelineWeatherService } from '../main/ets/domain/timeline/services/TimelineWeatherService';

class StrategyDataForG implements ComposableStrategy {
  density: DensityLevel = DensityLevel.MEDIUM;
  pace: PaceLevel = PaceLevel.BALANCED;
  preference: PreferenceType = PreferenceType.BALANCED;
  energy: EnergyLevel = EnergyLevel.MEDIUM;
}

class UserPreferenceDataForG implements WeatherUserPreference {
  heatSensitivity: 0 | 1 | 2 = 1;
  rainSensitivity: 0 | 1 | 2 = 1;
  weatherRiskTolerance: 0 | 1 | 2 = 1;
}

class CollabOptionsDataForG implements WeatherCollabOptions {
  enableMultiDay?: boolean = true;
  enableMultiCity?: boolean = true;
}

class SchedulePolicyDataForG implements WeatherSchedulePolicy {
  stage: WeatherStageType = 'PLANNING';
  pollIntervalMs: number = 0;
  allowLocationTrigger: boolean = false;
  allowManualBypass: boolean = true;
  forceRefreshOnEnter: boolean = false;
}

class GateResultDataForG {
  success: boolean = true;
  reasonCode?: string = 'ok';
  startFromEventId?: number = 1;
}

class PlanStateMachineMockForG {
  requestSoftReplan(_args: Object): GateResultDataForG {
    return new GateResultDataForG();
  }
}

class HostMockForG implements ITimelineWeatherHost {
  events: EventEntity[] = [];
  planId: number = 1;
  currentStrategyMode: number = 0;
  weatherFeatureEnabled: boolean = true;
  weatherLoading: boolean = false;
  weatherUserPreference: WeatherUserPreference = new UserPreferenceDataForG();
  weatherCollabOptions: WeatherCollabOptions = new CollabOptionsDataForG();
  executionWeatherEnabled: boolean = false;
  executionWeatherLoading: boolean = false;
  currentPlanStatus: PlanStatus = PlanStatus.READY;
  executionWeatherLastTrigger: string = '';
  executionWeatherErrorCode: string = '';
  executionWeatherScore: number = -1;
  executionWeatherRefreshAt: number = 0;
  executionWeatherCollabSummary: string = '';
  executionWeatherCollabBadge: string = '';
  executionWeatherDisplaySource: 'CURRENT' | 'NEXT_FALLBACK' | 'UNKNOWN' = 'UNKNOWN';
  executionWeatherCurrentText: string = '';
  executionWeatherNextText: string = '';
  executionWeatherSuggestions: WeatherSuggestion[] = [];
  executionSuggestionMap: Map<string, WeatherSuggestion> = new Map<string, WeatherSuggestion>();
  executionWeatherHint: string = '';
  executionWeatherLevel: 'INFO' | 'NOTICE' | 'WARNING' = 'INFO';
  executionWeatherLastLocation: GeoPointInput | null = null;
  executionWeatherLocationTriggerCooldownMs: number = 0;
  executionWeatherLastLocationTriggerAt: number = 0;
  currentWeatherSchedulePolicy: WeatherSchedulePolicy = new SchedulePolicyDataForG();
  executionReplanBusy: boolean = false;
  executionWeatherApplying: boolean = false;
  executionWeatherAppliedSummary: string = '';
  executionWeatherLastEmitAt: number = 0;
  executionWeatherLocationDeltaMeters: number = 0;
  executionSuggestionCooldownMs: number = 0;
  executionSuggestionCooldownMap: Map<string, number> = new Map<string, number>();
  weatherPlanningHint: string = '';
  weatherRouteScore: number = -1;
  weatherCollabSummary: string = '';
  weatherCollabLabel: string = '';
  weatherStrategyHint: string = '';
  weatherLastRefreshAt: number = 0;
  planStateMachine: PlanStateMachineMockForG = new PlanStateMachineMockForG();

  resolveCurrentWeatherStage(): WeatherStageType {
    return 'PLANNING';
  }

  async getCurrentStrategy(): Promise<ComposableStrategy> {
    return new StrategyDataForG();
  }

  getCurrentPlanStatus(): PlanStatus {
    return this.currentPlanStatus;
  }

  findCurrentActiveEvent(): EventEntity | null {
    return null;
  }

  getOrderedScheduleEvents(): EventEntity[] {
    return this.events;
  }

  getMinEventDurationLimit(): number {
    return 20;
  }

  async skipEvent(_item: EventEntity): Promise<void> {
    return;
  }

  recalculateFromEventId(_eventId: number): void {
    return;
  }

  recalculateFromIndex(_startIndex: number): void {
    return;
  }

  markScheduleChanged(): void {
    return;
  }
}

class PreferenceStoreMockForG {
  private readonly values: Map<string, Object> = new Map<string, Object>();

  async put(key: string, value: Object): Promise<void> {
    this.values.set(key, value);
  }

  async get(key: string, defaultValue: Object): Promise<Object> {
    const value = this.values.get(key);
    return value === undefined ? defaultValue : value;
  }

  async flush(): Promise<void> {
    return;
  }
}

class BundleForG {
  host: HostMockForG = new HostMockForG();
  service: TimelineWeatherService = new TimelineWeatherService(
    this.host,
    new WeatherFacade(),
    new WeatherRefreshScheduler()
  );
}

function createBundleForG(): BundleForG {
  return new BundleForG();
}

function ensurePreferenceMockForG(): PreferenceManager {
  const manager = PreferenceManager.getInstance();
  Reflect.set(manager, 'pref', new PreferenceStoreMockForG());
  return manager;
}

function clearPreferenceMockForG(): void {
  const manager = PreferenceManager.getInstance();
  Reflect.set(manager, 'pref', null);
}

function createSuggestionForG(id: string): WeatherSuggestion {
  return {
    suggestionId: id,
    level: 'NOTICE',
    triggerType: 'UNKNOWN',
    actionType: 'NONE',
    title: `title_${id}`,
    message: `msg_${id}`,
    relatedNodeIds: [],
    createdAt: Date.now(),
    reason: 'r',
    expectedBenefit: 'b',
    canRollback: false,
    cooldownKey: `cool_${id}`,
    expiresAt: Date.now() + 60_000
  };
}

export default function phase2CoreCoverageBatchGTest() {
  describe('phase2CoreCoverageBatchGTest', () => {
    it('normal: timeline_weather_service_dismiss_execution_suggestion_should_remove_target_from_list_and_map', 0, () => {
      // Arrange
      const bundle = createBundleForG();
      const s1 = createSuggestionForG('s1');
      const s2 = createSuggestionForG('s2');
      bundle.host.executionWeatherSuggestions = [s1, s2];
      bundle.host.executionSuggestionMap.set('s1', s1);
      bundle.host.executionSuggestionMap.set('s2', s2);
      // Act
      bundle.service.dismissExecutionSuggestion('s1');
      // Assert
      expect(bundle.host.executionWeatherSuggestions.length).assertEqual(1);
      expect(bundle.host.executionWeatherSuggestions[0].suggestionId).assertEqual('s2');
      expect(bundle.host.executionSuggestionMap.has('s1')).assertFalse();
      expect(bundle.host.executionSuggestionMap.has('s2')).assertTrue();
    });

    it('boundary: timeline_weather_service_explanations_should_cover_invalid_score_and_planning_hint_fallback', 0, () => {
      // Arrange
      const bundle = createBundleForG();
      bundle.host.weatherPlanningHint = '';
      bundle.host.weatherCollabSummary = '';
      // Act
      const invalidScoreText = bundle.service.buildWeatherScoreExplanation(-1);
      const planningHint = bundle.service.buildPlanningWeatherHintExplanation();
      // Assert
      expect(invalidScoreText.indexOf('暂无可用天气评分') >= 0).assertTrue();
      expect(planningHint.indexOf('当前暂无额外天气提示') >= 0).assertTrue();
    });

    it('invalid: timeline_weather_service_resolve_coordinates_should_use_base_when_name_empty_or_base_valid', 0, async () => {
      // Arrange
      const bundle = createBundleForG();
      // Act
      const fromValidBase = await bundle.service.resolveCoordinatesForPlaceName('任意', 31.2, 121.4, 'add', 0, 0);
      const fromEmptyName = await bundle.service.resolveCoordinatesForPlaceName('   ', undefined, undefined, 'update', 30.1, 120.2);
      // Assert
      expect(fromValidBase.latitude).assertEqual(31.2);
      expect(fromValidBase.longitude).assertEqual(121.4);
      expect(fromEmptyName.latitude).assertEqual(30.1);
      expect(fromEmptyName.longitude).assertEqual(120.2);
    });

    it('conflict: timeline_weather_service_restore_snapshot_should_apply_valid_json_and_ignore_invalid_json', 0, () => {
      // Arrange
      const bundle = createBundleForG();
      const key = 'PlanningWeatherSnapshot_99';
      const payload = '{"hint":"h1","score":88,"collabSummary":"c1","strategyHint":"s1","refreshedAt":1700000000000}';
      AppStorage.setOrCreate(key, payload);
      // Act
      bundle.service.restorePlanningWeatherSnapshot(99);
      const afterValidHint = bundle.host.weatherPlanningHint;
      AppStorage.setOrCreate(key, '{bad-json');
      bundle.service.restorePlanningWeatherSnapshot(99);
      // Assert
      expect(afterValidHint).assertEqual('h1');
      expect(bundle.host.weatherPlanningHint).assertEqual('h1');
      expect(bundle.host.weatherRouteScore).assertEqual(88);
      expect(bundle.host.weatherCollabLabel).assertEqual('多日/多城');
    });

    it('regression: td-20260415-timeline-weather-reload-preference_should_fallback_defaults_when_storage_unavailable', 0, async () => {
      // Arrange
      const bundle = createBundleForG();
      clearPreferenceMockForG();
      bundle.host.weatherFeatureEnabled = false;
      // Act
      await bundle.service.reloadWeatherUserPreference();
      // Assert
      expect(bundle.host.weatherFeatureEnabled).assertTrue();
      expect(bundle.host.weatherUserPreference.heatSensitivity).assertEqual(DEFAULT_WEATHER_USER_PREFERENCE.heatSensitivity);
      expect(bundle.host.weatherUserPreference.rainSensitivity).assertEqual(DEFAULT_WEATHER_USER_PREFERENCE.rainSensitivity);
      expect(bundle.host.weatherUserPreference.weatherRiskTolerance).assertEqual(DEFAULT_WEATHER_USER_PREFERENCE.weatherRiskTolerance);
    });

    it('combined: timeline_weather_service_set_and_update_preference_should_clear_runtime_when_feature_disabled', 0, async () => {
      // Arrange
      const bundle = createBundleForG();
      ensurePreferenceMockForG();
      bundle.host.weatherPlanningHint = 'old_hint';
      bundle.host.weatherRouteScore = 90;
      bundle.host.executionWeatherHint = 'old_exec_hint';
      const nextPreference: WeatherUserPreference = { heatSensitivity: 2, rainSensitivity: 0, weatherRiskTolerance: 1 };
      // Act
      await bundle.service.setWeatherFeatureEnabled(false);
      await bundle.service.updateWeatherUserPreference(nextPreference);
      const readback = bundle.service.getWeatherUserPreference();
      // Assert
      expect(bundle.host.weatherFeatureEnabled).assertFalse();
      expect(bundle.host.weatherPlanningHint).assertEqual('');
      expect(bundle.host.weatherRouteScore).assertEqual(-1);
      expect(bundle.host.executionWeatherHint).assertEqual('');
      expect(readback.heatSensitivity).assertEqual(2);
      expect(readback.rainSensitivity).assertEqual(0);
      expect(readback.weatherRiskTolerance).assertEqual(1);
    });
  });
}
