import { describe, expect, it } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { PlanStatus } from '../main/ets/domain/statemachine/PlanStatus';
import { ComposableStrategy, DensityLevel, EnergyLevel, PaceLevel, PreferenceType } from '../main/ets/domain/strategy/TravelStrategyDimensions';
import {
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

class StrategyDataForS implements ComposableStrategy {
  density: DensityLevel = DensityLevel.MEDIUM;
  pace: PaceLevel = PaceLevel.BALANCED;
  preference: PreferenceType = PreferenceType.BALANCED;
  energy: EnergyLevel = EnergyLevel.MEDIUM;
}

class UserPreferenceDataForS implements WeatherUserPreference {
  heatSensitivity: 0 | 1 | 2 = 1;
  rainSensitivity: 0 | 1 | 2 = 1;
  weatherRiskTolerance: 0 | 1 | 2 = 1;
}

class CollabOptionsDataForS implements WeatherCollabOptions {
  enableMultiDay?: boolean = true;
  enableMultiCity?: boolean = true;
}

class SchedulePolicyDataForS implements WeatherSchedulePolicy {
  stage: WeatherStageType = 'IN_PROGRESS';
  pollIntervalMs: number = 60_000;
  allowLocationTrigger: boolean = true;
  allowManualBypass: boolean = true;
  forceRefreshOnEnter: boolean = false;
}

class GateResultDataForS {
  success: boolean = true;
  reasonCode?: string = 'ok';
  startFromEventId?: number = 0;
}

class PlanStateMachineMockForS {
  gateResult: GateResultDataForS = new GateResultDataForS();

  requestSoftReplan(_args: Object): GateResultDataForS {
    return this.gateResult;
  }
}

class HostMockForS implements ITimelineWeatherHost {
  events: EventEntity[] = [];
  planId: number = 1;
  currentStrategyMode: number = 0;
  weatherFeatureEnabled: boolean = true;
  weatherLoading: boolean = false;
  weatherUserPreference: WeatherUserPreference = new UserPreferenceDataForS();
  weatherCollabOptions: WeatherCollabOptions = new CollabOptionsDataForS();
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
  currentWeatherSchedulePolicy: WeatherSchedulePolicy = new SchedulePolicyDataForS();
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
  planStateMachine: PlanStateMachineMockForS = new PlanStateMachineMockForS();

  resolveCurrentWeatherStage(): WeatherStageType { return 'IN_PROGRESS'; }
  async getCurrentStrategy(): Promise<ComposableStrategy> { return new StrategyDataForS(); }
  getCurrentPlanStatus(): PlanStatus { return this.currentPlanStatus; }
  findCurrentActiveEvent(): EventEntity | null { return null; }
  getOrderedScheduleEvents(): EventEntity[] { return this.events; }
  getMinEventDurationLimit(): number { return 20; }
  async skipEvent(_item: EventEntity): Promise<void> { return; }
  recalculateFromEventId(_eventId: number): void { return; }
  recalculateFromIndex(_startIndex: number): void { return; }
  markScheduleChanged(): void { return; }
}

class ServiceBundleForS {
  host: HostMockForS = new HostMockForS();
  service: TimelineWeatherService = new TimelineWeatherService(this.host, new WeatherFacade(), new WeatherRefreshScheduler());
}

function createBundleForS(): ServiceBundleForS {
  return new ServiceBundleForS();
}

export default function phase2CoreCoverageBatchSTest() {
  describe('phase2CoreCoverageBatchSTest', () => {
    it('normal: timeline_weather_refresh_planning_should_clear_runtime_when_feature_disabled', 0, async () => {
      // Arrange
      const bundle = createBundleForS();
      bundle.host.weatherFeatureEnabled = false;
      bundle.host.weatherPlanningHint = 'old_hint_s';
      bundle.host.executionWeatherHint = 'old_exec_hint_s';
      bundle.host.executionWeatherDisplaySource = 'CURRENT';
      // Act
      await bundle.service.refreshPlanningWeather(false);
      // Assert
      expect(bundle.host.weatherPlanningHint).assertEqual('');
      expect(bundle.host.executionWeatherHint).assertEqual('');
      expect(bundle.host.executionWeatherDisplaySource).assertEqual('UNKNOWN');
    });

    it('boundary: timeline_weather_refresh_execution_should_return_when_scheduler_disabled_and_non_manual', 0, async () => {
      // Arrange
      const bundle = createBundleForS();
      bundle.host.executionWeatherEnabled = false;
      // Act
      await bundle.service.refreshExecutionWeather(false, 'TIMER', 'IN_PROGRESS');
      // Assert
      expect(bundle.host.executionWeatherLastTrigger).assertEqual('');
      expect(bundle.host.executionWeatherLoading).assertFalse();
    });

    it('invalid: timeline_weather_resolve_coordinates_should_fallback_to_base_when_name_empty', 0, async () => {
      // Arrange
      const bundle = createBundleForS();
      // Act
      const point = await bundle.service.resolveCoordinatesForPlaceName('   ', undefined, undefined, 'add', 0, 0);
      // Assert
      expect(point.latitude).assertEqual(0);
      expect(point.longitude).assertEqual(0);
    });

    it('conflict: timeline_weather_refresh_execution_should_return_when_not_execution_stage_and_non_manual', 0, async () => {
      // Arrange
      const bundle = createBundleForS();
      bundle.host.currentPlanStatus = PlanStatus.CONFIRMED;
      // Act
      await bundle.service.refreshExecutionWeather(false, 'TIMER', 'CONFIRMED');
      // Assert
      expect(bundle.host.executionWeatherLastTrigger).assertEqual('');
      expect(bundle.host.executionWeatherLoading).assertFalse();
    });

    it('regression: td-20260415-timeline-weather-restore-snapshot-should-ignore-empty-raw', 0, () => {
      // Arrange
      const bundle = createBundleForS();
      bundle.host.weatherPlanningHint = 'keep_hint_s';
      bundle.host.weatherRouteScore = 77;
      AppStorage.setOrCreate('PlanningWeatherSnapshot_808', '');
      // Act
      bundle.service.restorePlanningWeatherSnapshot(808);
      // Assert
      expect(bundle.host.weatherPlanningHint).assertEqual('keep_hint_s');
      expect(bundle.host.weatherRouteScore).assertEqual(77);
    });

    it('combined: timeline_weather_refresh_execution_should_return_when_loading_true', 0, async () => {
      // Arrange
      const bundle = createBundleForS();
      bundle.host.executionWeatherLoading = true;
      // Act
      await bundle.service.refreshExecutionWeather(false, 'MANUAL', 'IN_PROGRESS');
      // Assert
      expect(bundle.host.executionWeatherLastTrigger).assertEqual('');
      expect(bundle.host.executionWeatherLoading).assertTrue();
    });
  });
}
