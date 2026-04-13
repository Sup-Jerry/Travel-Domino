import { describe, expect, it } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { PlanStatus } from '../main/ets/domain/statemachine/PlanStatus';
import { ComposableStrategy, DensityLevel, EnergyLevel, PaceLevel, PreferenceType } from '../main/ets/domain/strategy/TravelStrategyDimensions';
import { TimelineWeatherService, ITimelineWeatherHost } from '../main/ets/domain/timeline/services/TimelineWeatherService';
import {
  GeoPointInput,
  WeatherCollabOptions,
  WeatherSchedulePolicy,
  WeatherStageType,
  WeatherSuggestion,
  WeatherUserPreference
} from '../main/ets/domain/services/WeatherModels';
import { WeatherFacade } from '../main/ets/domain/services/WeatherFacade';
import { WeatherRefreshScheduler } from '../main/ets/domain/services/WeatherRefreshScheduler';

class StrategyData implements ComposableStrategy {
  density: DensityLevel = DensityLevel.MEDIUM;
  pace: PaceLevel = PaceLevel.BALANCED;
  preference: PreferenceType = PreferenceType.BALANCED;
  energy: EnergyLevel = EnergyLevel.MEDIUM;
}

class UserPreferenceData implements WeatherUserPreference {
  heatSensitivity: 0 | 1 | 2 = 1;
  rainSensitivity: 0 | 1 | 2 = 1;
  weatherRiskTolerance: 0 | 1 | 2 = 1;
}

class CollabOptionsData implements WeatherCollabOptions {
  enableMultiDay?: boolean = true;
  enableMultiCity?: boolean = true;
}

class SchedulePolicyData implements WeatherSchedulePolicy {
  stage: WeatherStageType = 'PLANNING';
  pollIntervalMs: number = 0;
  allowLocationTrigger: boolean = false;
  allowManualBypass: boolean = true;
  forceRefreshOnEnter: boolean = false;
}

class GeoPointData implements GeoPointInput {
  latitude: number = 0;
  longitude: number = 0;
}

class SuggestionData implements WeatherSuggestion {
  suggestionId: string = '';
  level: 'INFO' | 'NOTICE' | 'WARNING' = 'INFO';
  triggerType: 'RAIN' | 'HEAT' | 'COLD' | 'WIND' | 'SEVERE_ALERT' | 'UNKNOWN' = 'UNKNOWN';
  actionType: 'NONE' | 'PREPARE' | 'REORDER' | 'SHORTEN_STAY' | 'REPLACE_NODE' | 'SKIP_NODE' = 'NONE';
  title: string = '';
  message: string = '';
  relatedNodeIds: string[] = [];
  createdAt: number = Date.now();
  reason: string = '';
  expectedBenefit: string = '';
  canRollback: boolean = true;
  cooldownKey: string = '';
  expiresAt: number = Date.now() + 60000;
}

class PreviewData {
  suggestionId: string = '';
  actionType: 'NONE' | 'PREPARE' | 'REORDER' | 'SHORTEN_STAY' | 'REPLACE_NODE' | 'SKIP_NODE' = 'NONE';
  changedOrder: boolean = false;
  changedDurations: boolean = false;
  skippedNodeIds: string[] = [];
  affectedNodeIds: string[] = [];
  reasonCode?: string = '';
  startFromEventId?: number = 0;
  changeSummary: string[] = [];
  summary: string = '';
  riskDelta: number = 0;
}

class GateResultData {
  success: boolean = false;
  reasonCode?: string = '';
  startFromEventId?: number = 0;
}

class PlanStateTransitionRequestData {
  planId: string = '';
  reason: string = '';
  currentNodeId?: string = '';
  preserveCompletedNodes: boolean = true;
  preserveStartedWindow: boolean = true;
  useWeatherConstraint: boolean = true;
}

class PlanStateMachineMock {
  requestSoftReplan(_args: PlanStateTransitionRequestData): GateResultData {
    const result = new GateResultData();
    result.success = true;
    result.reasonCode = 'ok';
    result.startFromEventId = 1;
    return result;
  }
}

class HostMock implements ITimelineWeatherHost {
  events: EventEntity[] = [];
  planId: number = 1;
  currentStrategyMode: number = 0;
  weatherFeatureEnabled: boolean = true;
  weatherLoading: boolean = false;
  weatherUserPreference: WeatherUserPreference = new UserPreferenceData();
  weatherCollabOptions: WeatherCollabOptions = new CollabOptionsData();
  executionWeatherEnabled: boolean = false;
  executionWeatherLoading: boolean = false;
  currentPlanStatus: PlanStatus = PlanStatus.DRAFT;
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
  currentWeatherSchedulePolicy: WeatherSchedulePolicy = new SchedulePolicyData();
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

  planStateMachine: PlanStateMachineMock = new PlanStateMachineMock();

  resolveCurrentWeatherStage(): WeatherStageType {
    return 'PLANNING';
  }

  async getCurrentStrategy(): Promise<ComposableStrategy> {
    return new StrategyData();
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
    return 15;
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

class ServiceBundle {
  host: HostMock = new HostMock();
  service: TimelineWeatherService = new TimelineWeatherService(
    this.host,
    new WeatherFacade(),
    new WeatherRefreshScheduler()
  );
}

function createBundle(): ServiceBundle {
  return new ServiceBundle();
}

function createSuggestion(id: string): SuggestionData {
  const item = new SuggestionData();
  item.suggestionId = id;
  item.title = `suggestion_${id}`;
  item.cooldownKey = `cool_${id}`;
  return item;
}

function createScheduleEvent(fetchTs: number): EventEntity {
  const event = new EventEntity('spot', 1);
  event.status = 1;
  event.latitude = 31.2;
  event.longitude = 121.4;
  event.weather_fetch_time = fetchTs;
  return event;
}

export default function phase2CoreCoverageBatchBTest() {
  describe('phase2CoreCoverageBatchBTest', () => {
    it('normal: timeline_weather_service_score_explanation_should_return_expected_levels', 0, () => {
      // Arrange
      const bundle = createBundle();
      // Act
      const lowRisk = bundle.service.buildWeatherScoreExplanation(92);
      const mediumRisk = bundle.service.buildWeatherScoreExplanation(80);
      const highRisk = bundle.service.buildWeatherScoreExplanation(60);
      // Assert
      expect(lowRisk.indexOf('低风险') >= 0).assertTrue();
      expect(mediumRisk.indexOf('中风险') >= 0).assertTrue();
      expect(highRisk.indexOf('高风险') >= 0).assertTrue();
    });

    it('boundary: timeline_weather_service_should_auto_refresh_based_on_plan_and_age', 0, () => {
      // Arrange
      const bundle = createBundle();
      // Act
      bundle.host.planId = 0;
      const refreshWhenNoPlan = bundle.service.shouldAutoRefreshPlanningWeather();

      bundle.host.planId = 1;
      bundle.host.weatherLastRefreshAt = Date.now() - 1000;
      bundle.host.events = [createScheduleEvent(Date.now() - 1000)];
      const refreshWhenFresh = bundle.service.shouldAutoRefreshPlanningWeather(5000);

      bundle.host.weatherLastRefreshAt = Date.now() - 10000;
      bundle.host.events = [createScheduleEvent(Date.now() - 10000)];
      const refreshWhenStale = bundle.service.shouldAutoRefreshPlanningWeather(5000);
      // Assert
      expect(refreshWhenNoPlan).assertTrue();
      expect(refreshWhenFresh).assertFalse();
      expect(refreshWhenStale).assertTrue();
    });

    it('invalid: timeline_weather_service_coordinate_validation_should_handle_invalid_and_missing_values', 0, () => {
      // Arrange
      const bundle = createBundle();
      // Act
      const invalidRange = bundle.service.isValidCoordinate(91, 120);
      const missingByZero = bundle.service.isCoordinateMissingForWeather(0, 120);
      const validPair = bundle.service.isCoordinateMissingForWeather(30, 120);
      // Assert
      expect(invalidRange).assertFalse();
      expect(missingByZero).assertTrue();
      expect(validPair).assertFalse();
    });

    it('conflict: timeline_weather_service_execution_stage_should_follow_status_priority', 0, () => {
      // Arrange
      const bundle = createBundle();
      bundle.host.currentPlanStatus = PlanStatus.DRAFT;
      bundle.host.events = [];
      // Act
      const whenDraft = bundle.service.isExecutionWeatherStage();
      bundle.host.currentPlanStatus = PlanStatus.READY;
      const whenReady = bundle.service.isExecutionWeatherStage();
      // Assert
      expect(whenDraft).assertFalse();
      expect(whenReady).assertTrue();
    });

    it('regression: td-20260413-phase2-timeline-weather-hint-explanation_should_use_fallback_and_source_text', 0, () => {
      // Arrange
      const bundle = createBundle();
      bundle.host.executionWeatherDisplaySource = 'NEXT_FALLBACK';
      bundle.host.executionWeatherHint = '';
      bundle.host.weatherPlanningHint = '计划天气提示A';
      bundle.host.weatherCollabSummary = '';
      bundle.host.executionWeatherCollabSummary = '执行协同摘要B';
      // Act
      const executionExplanation = bundle.service.buildWeatherHintExplanation();
      const planningExplanation = bundle.service.buildPlanningWeatherHintExplanation();
      // Assert
      expect(executionExplanation.indexOf('下一节点天气估算') >= 0).assertTrue();
      expect(executionExplanation.indexOf('计划天气提示A') >= 0).assertTrue();
      expect(executionExplanation.indexOf('执行协同摘要B') >= 0).assertTrue();
      expect(planningExplanation.indexOf('计划节点天气') >= 0).assertTrue();
    });

    it('combined: timeline_weather_service_should_dismiss_suggestion_and_keep_runtime_state_queries_consistent', 0, () => {
      // Arrange
      const bundle = createBundle();
      const s1 = createSuggestion('s1');
      const s2 = createSuggestion('s2');
      bundle.host.executionWeatherSuggestions = [s1, s2];
      bundle.host.executionSuggestionMap.set('s1', s1);
      bundle.host.executionSuggestionMap.set('s2', s2);
      bundle.host.executionWeatherDisplaySource = 'CURRENT';
      // Act
      bundle.service.dismissExecutionSuggestion('s1');
      const pref = bundle.service.getWeatherUserPreference();
      const enabled = bundle.service.isWeatherFeatureEnabled();
      const source = bundle.service.getExecutionWeatherDisplaySource();
      // Assert
      expect(bundle.host.executionWeatherSuggestions.length).assertEqual(1);
      expect(bundle.host.executionSuggestionMap.has('s1')).assertFalse();
      expect(bundle.host.executionSuggestionMap.has('s2')).assertTrue();
      expect(pref.heatSensitivity).assertEqual(1);
      expect(enabled).assertTrue();
      expect(source).assertEqual('CURRENT');
    });
  });
}
