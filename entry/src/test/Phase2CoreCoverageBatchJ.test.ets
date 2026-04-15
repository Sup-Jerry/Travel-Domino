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

class StrategyDataForJ implements ComposableStrategy {
  density: DensityLevel = DensityLevel.MEDIUM;
  pace: PaceLevel = PaceLevel.BALANCED;
  preference: PreferenceType = PreferenceType.BALANCED;
  energy: EnergyLevel = EnergyLevel.MEDIUM;
}

class UserPreferenceDataForJ implements WeatherUserPreference {
  heatSensitivity: 0 | 1 | 2 = 1;
  rainSensitivity: 0 | 1 | 2 = 1;
  weatherRiskTolerance: 0 | 1 | 2 = 1;
}

class CollabOptionsDataForJ implements WeatherCollabOptions {
  enableMultiDay?: boolean = true;
  enableMultiCity?: boolean = true;
}

class SchedulePolicyDataForJ implements WeatherSchedulePolicy {
  stage: WeatherStageType = 'PLANNING';
  pollIntervalMs: number = 60_000;
  allowLocationTrigger: boolean = true;
  allowManualBypass: boolean = true;
  forceRefreshOnEnter: boolean = false;
}

class PlanStateMachineMockForJ {
  requestSoftReplan(_args: Object): GateResultDataForJ {
    return new GateResultDataForJ();
  }
}

class GateResultDataForJ {
  success: boolean = true;
  reasonCode?: string = 'ok';
  startFromEventId?: number = 1;
}

class HostMockForJ implements ITimelineWeatherHost {
  events: EventEntity[] = [];
  planId: number = 1;
  currentStrategyMode: number = 0;
  weatherFeatureEnabled: boolean = true;
  weatherLoading: boolean = false;
  weatherUserPreference: WeatherUserPreference = new UserPreferenceDataForJ();
  weatherCollabOptions: WeatherCollabOptions = new CollabOptionsDataForJ();
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
  currentWeatherSchedulePolicy: WeatherSchedulePolicy = new SchedulePolicyDataForJ();
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
  planStateMachine: PlanStateMachineMockForJ = new PlanStateMachineMockForJ();

  resolveCurrentWeatherStage(): WeatherStageType { return 'PLANNING'; }
  async getCurrentStrategy(): Promise<ComposableStrategy> { return new StrategyDataForJ(); }
  getCurrentPlanStatus(): PlanStatus { return this.currentPlanStatus; }
  findCurrentActiveEvent(): EventEntity | null { return null; }
  getOrderedScheduleEvents(): EventEntity[] { return this.events; }
  getMinEventDurationLimit(): number { return 20; }
  async skipEvent(_item: EventEntity): Promise<void> { return; }
  recalculateFromEventId(_eventId: number): void { return; }
  recalculateFromIndex(_startIndex: number): void { return; }
  markScheduleChanged(): void { return; }
}

class ServiceBundleForJ {
  host: HostMockForJ = new HostMockForJ();
  service: TimelineWeatherService = new TimelineWeatherService(this.host, new WeatherFacade(), new WeatherRefreshScheduler());
}

function createServiceForJ(host?: HostMockForJ): ServiceBundleForJ {
  const finalHost = host ?? new HostMockForJ();
  const bundle = new ServiceBundleForJ();
  bundle.host = finalHost;
  bundle.service = new TimelineWeatherService(finalHost, new WeatherFacade(), new WeatherRefreshScheduler());
  return bundle;
}

function createSuggestionForJ(id: string): WeatherSuggestion {
  return {
    suggestionId: id,
    level: 'NOTICE',
    triggerType: 'RAIN',
    actionType: 'PREPARE',
    title: `title_${id}`,
    message: `msg_${id}`,
    relatedNodeIds: [],
    createdAt: Date.now(),
    reason: 'r',
    expectedBenefit: 'b',
    canRollback: true,
    cooldownKey: `cool_${id}`,
    expiresAt: Date.now() + 60_000
  };
}

export default function phase2CoreCoverageBatchJTest() {
  describe('phase2CoreCoverageBatchJTest', () => {
    it('normal: timeline_weather_service_score_explanation_should_mark_high_risk_under_70', 0, () => {
      // Arrange
      const bundle = createServiceForJ();
      // Act
      const text = bundle.service.buildWeatherScoreExplanation(68);
      // Assert
      expect(text.indexOf('天气评分：68') >= 0).assertTrue();
      expect(text.indexOf('高风险') >= 0).assertTrue();
    });

    it('boundary: timeline_weather_service_score_explanation_should_clamp_to_100', 0, () => {
      // Arrange
      const bundle = createServiceForJ();
      // Act
      const text = bundle.service.buildWeatherScoreExplanation(130);
      // Assert
      expect(text.indexOf('天气评分：100') >= 0).assertTrue();
      expect(text.indexOf('低风险') >= 0).assertTrue();
    });

    it('invalid: timeline_weather_service_dismiss_should_ignore_empty_suggestion_id', 0, () => {
      // Arrange
      const bundle = createServiceForJ();
      bundle.host.executionWeatherSuggestions = [createSuggestionForJ('s1')];
      bundle.host.executionSuggestionMap.set('s1', bundle.host.executionWeatherSuggestions[0]);
      // Act
      bundle.service.dismissExecutionSuggestion('   ');
      // Assert
      expect(bundle.host.executionWeatherSuggestions.length).assertEqual(1);
      expect(bundle.host.executionSuggestionMap.has('s1')).assertTrue();
    });

    it('conflict: timeline_weather_service_auto_refresh_should_use_latest_event_weather_time', 0, () => {
      // Arrange
      const bundle = createServiceForJ();
      bundle.host.planId = 77;
      bundle.host.weatherLastRefreshAt = Date.now() - 3600_000;
      const event = new EventEntity('evt_j', 1);
      event.status = 1;
      event.weather_fetch_time = Date.now();
      bundle.host.events = [event];
      // Act
      const shouldRefresh = bundle.service.shouldAutoRefreshPlanningWeather(5_000);
      // Assert
      expect(shouldRefresh).assertFalse();
    });

    it('regression: td-20260415-restore-snapshot-should-recover-collab-label', 0, () => {
      // Arrange
      const bundle = createServiceForJ();
      const key = 'PlanningWeatherSnapshot_123';
      AppStorage.setOrCreate(key, JSON.stringify({
        hint: 'h_j',
        score: 88,
        collabSummary: 'c_j',
        strategyHint: 's_j',
        refreshedAt: 1700000000000
      }));
      // Act
      bundle.service.restorePlanningWeatherSnapshot(123);
      // Assert
      expect(bundle.host.weatherPlanningHint).assertEqual('h_j');
      expect(bundle.host.weatherRouteScore).assertEqual(88);
      expect(bundle.host.weatherCollabLabel).assertEqual('多日/多城');
    });

    it('combined: timeline_weather_service_hint_explanation_should_merge_source_hint_and_collab', 0, () => {
      // Arrange
      const bundle = createServiceForJ();
      bundle.host.executionWeatherDisplaySource = 'NEXT_FALLBACK';
      bundle.host.executionWeatherHint = '';
      bundle.host.weatherPlanningHint = 'plan_hint_j';
      bundle.host.executionWeatherCollabSummary = 'exec_collab_j';
      // Act
      const text = bundle.service.buildWeatherHintExplanation();
      // Assert
      expect(text.indexOf('下一节点天气估算') >= 0).assertTrue();
      expect(text.indexOf('plan_hint_j') >= 0).assertTrue();
      expect(text.indexOf('exec_collab_j') >= 0).assertTrue();
    });
  });
}
