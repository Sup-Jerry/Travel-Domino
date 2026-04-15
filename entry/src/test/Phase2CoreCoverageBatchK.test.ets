import { describe, expect, it } from '@ohos/hypium';
import { PreferenceManager } from '../main/ets/common/utils/PreferenceManager';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { PlanStatus } from '../main/ets/domain/statemachine/PlanStatus';
import { ComposableStrategy, DensityLevel, EnergyLevel, PaceLevel, PreferenceType } from '../main/ets/domain/strategy/TravelStrategyDimensions';
import {
  DEFAULT_WEATHER_USER_PREFERENCE,
  GeoPointInput,
  WeatherCollabOptions,
  WeatherSchedulePolicy,
  WeatherStageType,
  WeatherSuggestion,
  WeatherUserPreference
} from '../main/ets/domain/services/WeatherModels';
import { ITimelineWeatherHost, TimelineWeatherService } from '../main/ets/domain/timeline/services/TimelineWeatherService';
import { WeatherFacade } from '../main/ets/domain/services/WeatherFacade';
import { WeatherRefreshScheduler } from '../main/ets/domain/services/WeatherRefreshScheduler';

class StrategyDataForK implements ComposableStrategy {
  density: DensityLevel = DensityLevel.MEDIUM;
  pace: PaceLevel = PaceLevel.BALANCED;
  preference: PreferenceType = PreferenceType.BALANCED;
  energy: EnergyLevel = EnergyLevel.MEDIUM;
}

class UserPreferenceDataForK implements WeatherUserPreference {
  heatSensitivity: 0 | 1 | 2 = 1;
  rainSensitivity: 0 | 1 | 2 = 1;
  weatherRiskTolerance: 0 | 1 | 2 = 1;
}

class CollabOptionsDataForK implements WeatherCollabOptions {
  enableMultiDay?: boolean = true;
  enableMultiCity?: boolean = true;
}

class SchedulePolicyDataForK implements WeatherSchedulePolicy {
  stage: WeatherStageType = 'PLANNING';
  pollIntervalMs: number = 60_000;
  allowLocationTrigger: boolean = true;
  allowManualBypass: boolean = true;
  forceRefreshOnEnter: boolean = false;
}

class GateResultDataForK {
  success: boolean = true;
  reasonCode?: string = 'ok';
  startFromEventId?: number = 1;
}

class PlanStateMachineMockForK {
  requestSoftReplan(_args: Object): GateResultDataForK {
    return new GateResultDataForK();
  }
}

class HostMockForK implements ITimelineWeatherHost {
  events: EventEntity[] = [];
  planId: number = 1;
  currentStrategyMode: number = 0;
  weatherFeatureEnabled: boolean = true;
  weatherLoading: boolean = false;
  weatherUserPreference: WeatherUserPreference = new UserPreferenceDataForK();
  weatherCollabOptions: WeatherCollabOptions = new CollabOptionsDataForK();
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
  currentWeatherSchedulePolicy: WeatherSchedulePolicy = new SchedulePolicyDataForK();
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
  planStateMachine: PlanStateMachineMockForK = new PlanStateMachineMockForK();

  resolveCurrentWeatherStage(): WeatherStageType { return 'PLANNING'; }
  async getCurrentStrategy(): Promise<ComposableStrategy> { return new StrategyDataForK(); }
  getCurrentPlanStatus(): PlanStatus { return this.currentPlanStatus; }
  findCurrentActiveEvent(): EventEntity | null { return null; }
  getOrderedScheduleEvents(): EventEntity[] { return this.events; }
  getMinEventDurationLimit(): number { return 20; }
  async skipEvent(_item: EventEntity): Promise<void> { return; }
  recalculateFromEventId(_eventId: number): void { return; }
  recalculateFromIndex(_startIndex: number): void { return; }
  markScheduleChanged(): void { return; }
}

class WeatherFacadeMockForK {
  policy: WeatherSchedulePolicy = new SchedulePolicyDataForK();
  resolveSchedulePolicy(stage: WeatherStageType): WeatherSchedulePolicy {
    this.policy.stage = stage;
    return this.policy;
  }
}

class WeatherSchedulerMockForK {
  startCalls: number = 0;
  stopCalls: number = 0;
  lastInterval: number = 0;
  lastCallback: (() => void) | null = null;

  start(intervalMs: number, callback: () => void): void {
    this.startCalls += 1;
    this.lastInterval = intervalMs;
    this.lastCallback = callback;
  }

  stop(): void {
    this.stopCalls += 1;
  }
}

class PreferenceManagerMockForK {
  throwOnRead: boolean = false;
  featureEnabled: boolean = true;
  currentPreference: WeatherUserPreference = new UserPreferenceDataForK();
  setWeatherFeatureEnabledCalls: number = 0;
  setWeatherPreferenceCalls: number = 0;

  async getWeatherUserPreference(): Promise<WeatherUserPreference> {
    if (this.throwOnRead) {
      throw new Error('pref_read_fail_k');
    }
    return this.currentPreference;
  }

  async setWeatherUserPreference(preference: WeatherUserPreference): Promise<void> {
    this.setWeatherPreferenceCalls += 1;
    this.currentPreference = preference;
  }

  async isWeatherFeatureEnabled(): Promise<boolean> {
    if (this.throwOnRead) {
      throw new Error('pref_read_fail_k');
    }
    return this.featureEnabled;
  }

  async setWeatherFeatureEnabled(enabled: boolean): Promise<void> {
    this.setWeatherFeatureEnabledCalls += 1;
    this.featureEnabled = enabled;
  }
}

class StaticHooksForK {
  private readonly originPreferenceGetInstance: Object;

  constructor() {
    this.originPreferenceGetInstance = Reflect.get(PreferenceManager, 'getInstance') as Object;
  }

  setPreferenceGetInstance(fn: () => PreferenceManagerMockForK): void {
    Reflect.set(PreferenceManager, 'getInstance', fn);
  }

  restore(): void {
    Reflect.set(PreferenceManager, 'getInstance', this.originPreferenceGetInstance);
  }
}

class ServiceBundleForK {
  host: HostMockForK = new HostMockForK();
  service: TimelineWeatherService = new TimelineWeatherService(this.host, new WeatherFacade(), new WeatherRefreshScheduler());
  facade: WeatherFacadeMockForK = new WeatherFacadeMockForK();
  scheduler: WeatherSchedulerMockForK = new WeatherSchedulerMockForK();
}

function createBundleForK(): ServiceBundleForK {
  const bundle = new ServiceBundleForK();
  Reflect.set(bundle.service as Object, 'weatherFacade', bundle.facade);
  Reflect.set(bundle.service as Object, 'weatherScheduler', bundle.scheduler);
  return bundle;
}

export default function phase2CoreCoverageBatchKTest() {
  describe('phase2CoreCoverageBatchKTest', () => {
    it('normal: timeline_weather_service_set_feature_disabled_should_stop_scheduler_and_clear_runtime', 0, async () => {
      // Arrange
      const bundle = createBundleForK();
      const hooks = new StaticHooksForK();
      const prefMock = new PreferenceManagerMockForK();
      hooks.setPreferenceGetInstance((): PreferenceManagerMockForK => prefMock);
      bundle.host.weatherPlanningHint = 'hint_k';
      bundle.host.weatherCollabSummary = 'summary_k';
      bundle.host.executionWeatherHint = 'exec_hint_k';
      bundle.host.executionWeatherEnabled = true;
      // Act
      await bundle.service.setWeatherFeatureEnabled(false);
      // Assert
      expect(prefMock.setWeatherFeatureEnabledCalls).assertEqual(1);
      expect(bundle.host.weatherFeatureEnabled).assertFalse();
      expect(bundle.host.executionWeatherEnabled).assertFalse();
      expect(bundle.host.weatherPlanningHint).assertEqual('');
      expect(bundle.scheduler.stopCalls > 0).assertTrue();
      hooks.restore();
    });

    it('boundary: timeline_weather_service_start_scheduler_should_trigger_planning_refresh_on_confirmed_force_enter', 0, () => {
      // Arrange
      const bundle = createBundleForK();
      let planningRefreshCalls = 0;
      bundle.host.currentPlanStatus = PlanStatus.CONFIRMED;
      bundle.host.weatherFeatureEnabled = true;
      bundle.host.planId = 88;
      bundle.facade.policy.stage = 'CONFIRMED';
      bundle.facade.policy.pollIntervalMs = 15_000;
      bundle.facade.policy.forceRefreshOnEnter = true;
      Reflect.set(bundle.service as Object, 'refreshPlanningWeather', async (_force: boolean = false): Promise<void> => {
        planningRefreshCalls += 1;
        return;
      });
      // Act
      bundle.service.startExecutionWeatherScheduler(88, 'CONFIRMED');
      // Assert
      expect(bundle.scheduler.startCalls).assertEqual(1);
      expect(bundle.scheduler.lastInterval).assertEqual(15_000);
      expect(planningRefreshCalls > 0).assertTrue();
    });

    it('invalid: timeline_weather_service_resolve_coordinate_should_keep_base_when_name_empty', 0, async () => {
      // Arrange
      const bundle = createBundleForK();
      // Act
      const point = await bundle.service.resolveCoordinatesForPlaceName('   ', undefined, undefined, 'add', 31.2, 121.5);
      // Assert
      expect(point.latitude).assertEqual(31.2);
      expect(point.longitude).assertEqual(121.5);
    });

    it('conflict: timeline_weather_service_reload_preference_should_fallback_to_default_when_manager_throws', 0, async () => {
      // Arrange
      const bundle = createBundleForK();
      const hooks = new StaticHooksForK();
      const prefMock = new PreferenceManagerMockForK();
      prefMock.throwOnRead = true;
      bundle.host.weatherFeatureEnabled = false;
      bundle.host.weatherUserPreference.heatSensitivity = 2;
      hooks.setPreferenceGetInstance((): PreferenceManagerMockForK => prefMock);
      // Act
      await bundle.service.reloadWeatherUserPreference();
      // Assert
      expect(bundle.host.weatherFeatureEnabled).assertTrue();
      expect(bundle.host.weatherUserPreference.heatSensitivity).assertEqual(DEFAULT_WEATHER_USER_PREFERENCE.heatSensitivity);
      hooks.restore();
    });

    it('regression: td-20260415-update-preference-when-feature-off-should-clear-runtime', 0, async () => {
      // Arrange
      const bundle = createBundleForK();
      const hooks = new StaticHooksForK();
      const prefMock = new PreferenceManagerMockForK();
      prefMock.featureEnabled = false;
      bundle.host.weatherPlanningHint = 'planning_keep_k';
      bundle.host.executionWeatherHint = 'execution_keep_k';
      hooks.setPreferenceGetInstance((): PreferenceManagerMockForK => prefMock);
      // Act
      await bundle.service.updateWeatherUserPreference(new UserPreferenceDataForK());
      // Assert
      expect(prefMock.setWeatherPreferenceCalls).assertEqual(1);
      expect(bundle.host.weatherFeatureEnabled).assertFalse();
      expect(bundle.host.weatherPlanningHint).assertEqual('');
      expect(bundle.host.executionWeatherHint).assertEqual('');
      hooks.restore();
    });

    it('combined: timeline_weather_service_set_feature_enabled_should_start_scheduler_with_policy_interval', 0, async () => {
      // Arrange
      const bundle = createBundleForK();
      const hooks = new StaticHooksForK();
      const prefMock = new PreferenceManagerMockForK();
      let planningRefreshCalls = 0;
      bundle.host.weatherFeatureEnabled = false;
      bundle.host.currentPlanStatus = PlanStatus.READY;
      bundle.facade.policy.stage = 'IN_PROGRESS';
      bundle.facade.policy.pollIntervalMs = 20_000;
      hooks.setPreferenceGetInstance((): PreferenceManagerMockForK => prefMock);
      Reflect.set(bundle.service as Object, 'refreshPlanningWeather', async (_force: boolean = false): Promise<void> => {
        planningRefreshCalls += 1;
        return;
      });
      // Act
      await bundle.service.setWeatherFeatureEnabled(true);
      // Assert
      expect(bundle.host.weatherFeatureEnabled).assertTrue();
      expect(bundle.scheduler.startCalls).assertEqual(1);
      expect(bundle.scheduler.lastInterval).assertEqual(20_000);
      expect(planningRefreshCalls > 0).assertTrue();
      hooks.restore();
    });
  });
}
