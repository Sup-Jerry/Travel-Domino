import { describe, expect, it } from '@ohos/hypium';
import { PreferenceManager } from '../main/ets/common/utils/PreferenceManager';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { AmapService, GeoCoordinate } from '../main/ets/infrastructure/services/AmapService';
import { PlanStatus } from '../main/ets/domain/statemachine/PlanStatus';
import { ComposableStrategy, DensityLevel, EnergyLevel, PaceLevel, PreferenceType } from '../main/ets/domain/strategy/TravelStrategyDimensions';
import { GeoPointInput, WeatherCollabOptions, WeatherSchedulePolicy, WeatherStageType, WeatherSuggestion, WeatherUserPreference } from '../main/ets/domain/services/WeatherModels';
import { ITimelineWeatherHost, TimelineWeatherService } from '../main/ets/domain/timeline/services/TimelineWeatherService';
import { WeatherFacade } from '../main/ets/domain/services/WeatherFacade';
import { WeatherRefreshScheduler } from '../main/ets/domain/services/WeatherRefreshScheduler';

class StrategyDataForQ implements ComposableStrategy {
  density: DensityLevel = DensityLevel.MEDIUM;
  pace: PaceLevel = PaceLevel.BALANCED;
  preference: PreferenceType = PreferenceType.BALANCED;
  energy: EnergyLevel = EnergyLevel.MEDIUM;
}

class UserPreferenceDataForQ implements WeatherUserPreference {
  heatSensitivity: 0 | 1 | 2 = 1;
  rainSensitivity: 0 | 1 | 2 = 1;
  weatherRiskTolerance: 0 | 1 | 2 = 1;
}

class CollabOptionsDataForQ implements WeatherCollabOptions {
  enableMultiDay?: boolean = true;
  enableMultiCity?: boolean = true;
}

class SchedulePolicyDataForQ implements WeatherSchedulePolicy {
  stage: WeatherStageType = 'IN_PROGRESS';
  pollIntervalMs: number = 60_000;
  allowLocationTrigger: boolean = true;
  allowManualBypass: boolean = true;
  forceRefreshOnEnter: boolean = false;
}

class GateResultDataForQ {
  success: boolean = true;
  reasonCode?: string = 'ok';
  startFromEventId?: number = 1;
}

class PlanStateMachineMockForQ {
  requestSoftReplan(_args: Object): GateResultDataForQ {
    return new GateResultDataForQ();
  }
}

class HostMockForQ implements ITimelineWeatherHost {
  events: EventEntity[] = [];
  planId: number = 1;
  currentStrategyMode: number = 0;
  weatherFeatureEnabled: boolean = true;
  weatherLoading: boolean = false;
  weatherUserPreference: WeatherUserPreference = new UserPreferenceDataForQ();
  weatherCollabOptions: WeatherCollabOptions = new CollabOptionsDataForQ();
  executionWeatherEnabled: boolean = true;
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
  currentWeatherSchedulePolicy: WeatherSchedulePolicy = new SchedulePolicyDataForQ();
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
  planStateMachine: PlanStateMachineMockForQ = new PlanStateMachineMockForQ();

  resolveCurrentWeatherStage(): WeatherStageType { return 'IN_PROGRESS'; }
  async getCurrentStrategy(): Promise<ComposableStrategy> { return new StrategyDataForQ(); }
  getCurrentPlanStatus(): PlanStatus { return this.currentPlanStatus; }
  findCurrentActiveEvent(): EventEntity | null { return null; }
  getOrderedScheduleEvents(): EventEntity[] { return this.events; }
  getMinEventDurationLimit(): number { return 20; }
  async skipEvent(_item: EventEntity): Promise<void> { return; }
  recalculateFromEventId(_eventId: number): void { return; }
  recalculateFromIndex(_startIndex: number): void { return; }
  markScheduleChanged(): void { return; }
}

class WeatherFacadeMockForQ {
  policy: WeatherSchedulePolicy = new SchedulePolicyDataForQ();
  resolveSchedulePolicy(_stage: WeatherStageType): WeatherSchedulePolicy {
    return this.policy;
  }
}

class WeatherSchedulerMockForQ {
  startCalls: number = 0;
  stopCalls: number = 0;

  start(_intervalMs: number, _callback: () => void): void {
    this.startCalls += 1;
  }

  stop(): void {
    this.stopCalls += 1;
  }
}

class PreferenceManagerMockForQ {
  featureEnabled: boolean = true;
  currentPreference: WeatherUserPreference = new UserPreferenceDataForQ();
  setFeatureCalls: number = 0;
  setPreferenceCalls: number = 0;

  async getWeatherUserPreference(): Promise<WeatherUserPreference> {
    return this.currentPreference;
  }

  async setWeatherUserPreference(preference: WeatherUserPreference): Promise<void> {
    this.setPreferenceCalls += 1;
    this.currentPreference = preference;
    return;
  }

  async isWeatherFeatureEnabled(): Promise<boolean> {
    return this.featureEnabled;
  }

  async setWeatherFeatureEnabled(enabled: boolean): Promise<void> {
    this.setFeatureCalls += 1;
    this.featureEnabled = enabled;
    return;
  }
}

class StaticHooksForQ {
  private readonly originPreferenceGetInstance: Object;
  private readonly originAmapGeocode: Object;

  constructor() {
    this.originPreferenceGetInstance = Reflect.get(PreferenceManager, 'getInstance') as Object;
    this.originAmapGeocode = Reflect.get(AmapService, 'getGeocode') as Object;
  }

  setPreferenceGetInstance(fn: () => PreferenceManagerMockForQ): void {
    Reflect.set(PreferenceManager, 'getInstance', fn);
  }

  setAmapGeocode(fn: (name: string) => Promise<GeoCoordinate | null>): void {
    Reflect.set(AmapService, 'getGeocode', fn);
  }

  restore(): void {
    Reflect.set(PreferenceManager, 'getInstance', this.originPreferenceGetInstance);
    Reflect.set(AmapService, 'getGeocode', this.originAmapGeocode);
  }
}

class ServiceBundleForQ {
  host: HostMockForQ = new HostMockForQ();
  service: TimelineWeatherService = new TimelineWeatherService(this.host, new WeatherFacade(), new WeatherRefreshScheduler());
  facade: WeatherFacadeMockForQ = new WeatherFacadeMockForQ();
  scheduler: WeatherSchedulerMockForQ = new WeatherSchedulerMockForQ();
  preference: PreferenceManagerMockForQ = new PreferenceManagerMockForQ();
}

function createBundleForQ(): ServiceBundleForQ {
  const bundle = new ServiceBundleForQ();
  Reflect.set(bundle.service as Object, 'weatherFacade', bundle.facade);
  Reflect.set(bundle.service as Object, 'weatherScheduler', bundle.scheduler);
  return bundle;
}

export default function phase2CoreCoverageBatchQTest() {
  describe('phase2CoreCoverageBatchQTest', () => {
    it('normal: timeline_weather_reload_preference_should_clear_runtime_when_feature_disabled', 0, async () => {
      // Arrange
      const bundle = createBundleForQ();
      const hooks = new StaticHooksForQ();
      bundle.preference.featureEnabled = false;
      bundle.preference.currentPreference = { heatSensitivity: 2, rainSensitivity: 0, weatherRiskTolerance: 2 };
      bundle.host.weatherPlanningHint = 'planning_q';
      bundle.host.executionWeatherHint = 'execution_q';
      hooks.setPreferenceGetInstance((): PreferenceManagerMockForQ => bundle.preference);
      // Act
      await bundle.service.reloadWeatherUserPreference();
      // Assert
      expect(bundle.host.weatherFeatureEnabled).assertFalse();
      expect(bundle.host.weatherUserPreference.heatSensitivity).assertEqual(2);
      expect(bundle.host.weatherPlanningHint).assertEqual('');
      expect(bundle.host.executionWeatherHint).assertEqual('');
      hooks.restore();
    });

    it('boundary: timeline_weather_auto_refresh_should_return_true_when_plan_id_is_non_positive', 0, () => {
      // Arrange
      const bundle = createBundleForQ();
      bundle.host.planId = 0;
      bundle.host.weatherLastRefreshAt = Date.now();
      // Act
      const result = bundle.service.shouldAutoRefreshPlanningWeather(24 * 60 * 60 * 1000);
      // Assert
      expect(result).assertTrue();
    });

    it('invalid: timeline_weather_restore_snapshot_should_ignore_invalid_json_payload', 0, () => {
      // Arrange
      const bundle = createBundleForQ();
      bundle.host.weatherPlanningHint = 'keep_q';
      AppStorage.setOrCreate('PlanningWeatherSnapshot_501', '{bad_json_q');
      // Act
      bundle.service.restorePlanningWeatherSnapshot(501);
      // Assert
      expect(bundle.host.weatherPlanningHint).assertEqual('keep_q');
      expect(bundle.host.weatherRouteScore).assertEqual(-1);
    });

    it('conflict: timeline_weather_resolve_coordinates_should_use_base_value_without_geocode_when_base_is_valid', 0, async () => {
      // Arrange
      const bundle = createBundleForQ();
      const hooks = new StaticHooksForQ();
      let geocodeCalls = 0;
      hooks.setAmapGeocode(async (_name: string): Promise<GeoCoordinate | null> => {
        geocodeCalls += 1;
        return new GeoCoordinate(31.1, 121.1);
      });
      // Act
      const point = await bundle.service.resolveCoordinatesForPlaceName('bund_q', 31.23, 121.47, 'add', 0, 0);
      // Assert
      expect(point.latitude).assertEqual(31.23);
      expect(point.longitude).assertEqual(121.47);
      expect(geocodeCalls).assertEqual(0);
      hooks.restore();
    });

    it('regression: td-20260415-set_feature_enabled_with_zero_interval_should_not_start_scheduler', 0, async () => {
      // Arrange
      const bundle = createBundleForQ();
      const hooks = new StaticHooksForQ();
      hooks.setPreferenceGetInstance((): PreferenceManagerMockForQ => bundle.preference);
      bundle.host.weatherFeatureEnabled = false;
      bundle.host.planId = 66;
      bundle.facade.policy.pollIntervalMs = 0;
      let planningRefreshCalls = 0;
      Reflect.set(bundle.service as Object, 'refreshPlanningWeather', async (_force: boolean = false): Promise<void> => {
        planningRefreshCalls += 1;
        return;
      });
      // Act
      await bundle.service.setWeatherFeatureEnabled(true);
      // Assert
      expect(bundle.host.weatherFeatureEnabled).assertTrue();
      expect(planningRefreshCalls > 0).assertTrue();
      expect(bundle.scheduler.startCalls).assertEqual(0);
      hooks.restore();
    });

    it('combined: timeline_weather_resolve_coordinates_geocode_miss_and_update_preference_enabled_should_keep_runtime', 0, async () => {
      // Arrange
      const bundle = createBundleForQ();
      const hooks = new StaticHooksForQ();
      hooks.setPreferenceGetInstance((): PreferenceManagerMockForQ => bundle.preference);
      let geocodeCalls = 0;
      hooks.setAmapGeocode(async (_name: string): Promise<GeoCoordinate | null> => {
        geocodeCalls += 1;
        return null;
      });
      bundle.host.weatherPlanningHint = 'keep_runtime_q';
      bundle.preference.featureEnabled = true;
      // Act
      const point = await bundle.service.resolveCoordinatesForPlaceName('unknown_q', undefined, undefined, 'update', 0, 0);
      await bundle.service.updateWeatherUserPreference({ heatSensitivity: 0, rainSensitivity: 2, weatherRiskTolerance: 1 });
      // Assert
      expect(point.latitude).assertEqual(0);
      expect(point.longitude).assertEqual(0);
      expect(geocodeCalls).assertEqual(1);
      expect(bundle.preference.setPreferenceCalls).assertEqual(1);
      expect(bundle.host.weatherFeatureEnabled).assertTrue();
      expect(bundle.host.weatherPlanningHint).assertEqual('keep_runtime_q');
      hooks.restore();
    });
  });
}


