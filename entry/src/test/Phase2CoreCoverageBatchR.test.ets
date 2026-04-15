import { describe, expect, it } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { PlanStatus } from '../main/ets/domain/statemachine/PlanStatus';
import { ComposableStrategy, DensityLevel, EnergyLevel, PaceLevel, PreferenceType } from '../main/ets/domain/strategy/TravelStrategyDimensions';
import {
  GeoPointInput,
  ReplanChangeSummaryItem,
  SoftReplanApplyResult,
  SoftReplanMode,
  SoftReplanPreview,
  WeatherCollabOptions,
  WeatherSchedulePolicy,
  WeatherStageType,
  WeatherSuggestion,
  WeatherUserPreference
} from '../main/ets/domain/services/WeatherModels';
import { ITimelineWeatherHost, TimelineWeatherService } from '../main/ets/domain/timeline/services/TimelineWeatherService';
import { WeatherFacade } from '../main/ets/domain/services/WeatherFacade';
import { WeatherRefreshScheduler } from '../main/ets/domain/services/WeatherRefreshScheduler';

class StrategyDataForR implements ComposableStrategy {
  density: DensityLevel = DensityLevel.MEDIUM;
  pace: PaceLevel = PaceLevel.BALANCED;
  preference: PreferenceType = PreferenceType.BALANCED;
  energy: EnergyLevel = EnergyLevel.MEDIUM;
}

class UserPreferenceDataForR implements WeatherUserPreference {
  heatSensitivity: 0 | 1 | 2 = 1;
  rainSensitivity: 0 | 1 | 2 = 1;
  weatherRiskTolerance: 0 | 1 | 2 = 1;
}

class CollabOptionsDataForR implements WeatherCollabOptions {
  enableMultiDay?: boolean = true;
  enableMultiCity?: boolean = true;
}

class SchedulePolicyDataForR implements WeatherSchedulePolicy {
  stage: WeatherStageType = 'IN_PROGRESS';
  pollIntervalMs: number = 60_000;
  allowLocationTrigger: boolean = true;
  allowManualBypass: boolean = true;
  forceRefreshOnEnter: boolean = false;
}

class GateResultDataForR {
  success: boolean = true;
  reasonCode?: string = 'ok';
  startFromEventId?: number = 0;
}

class SoftReplanPreviewDataForR implements SoftReplanPreview {
  suggestionId: string = 'x';
  actionType: 'NONE' | 'PREPARE' | 'REORDER' | 'SHORTEN_STAY' | 'REPLACE_NODE' | 'SKIP_NODE' = 'NONE';
  changedOrder: boolean = false;
  changedDurations: boolean = false;
  skippedNodeIds: string[] = [];
  affectedNodeIds: string[] = [];
  reasonCode?: string = 'ok';
  startFromEventId?: number = 0;
  changeSummary: ReplanChangeSummaryItem[] = [];
  summary: string = 'ok';
  riskDelta: number = 0;
}

class SoftReplanApplyResultDataForR implements SoftReplanApplyResult {
  success: boolean = true;
  rolledBack: boolean = false;
  errorCode: '' | 'REPLAN_CONFLICT' | 'REPLAN_IMMUTABLE' | 'REPLAN_NO_CANDIDATE' | 'REPLAN_TIMEOUT' | 'REPLAN_INVALID' | 'REPLAN_BUSY' = '';
  reasonCode?: string = 'ok';
  startFromEventId?: number = 0;
  preview: SoftReplanPreview = new SoftReplanPreviewDataForR();
}

class PlanStateMachineMockForR {
  gateResult: GateResultDataForR = new GateResultDataForR();

  requestSoftReplan(_args: Object): GateResultDataForR {
    return this.gateResult;
  }
}

class HostMockForR implements ITimelineWeatherHost {
  events: EventEntity[] = [];
  planId: number = 1;
  currentStrategyMode: number = 0;
  weatherFeatureEnabled: boolean = true;
  weatherLoading: boolean = false;
  weatherUserPreference: WeatherUserPreference = new UserPreferenceDataForR();
  weatherCollabOptions: WeatherCollabOptions = new CollabOptionsDataForR();
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
  currentWeatherSchedulePolicy: WeatherSchedulePolicy = new SchedulePolicyDataForR();
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
  planStateMachine: PlanStateMachineMockForR = new PlanStateMachineMockForR();

  recalculateFromEventIdCalls: number[] = [];
  recalculateFromIndexCalls: number[] = [];

  resolveCurrentWeatherStage(): WeatherStageType { return 'IN_PROGRESS'; }
  async getCurrentStrategy(): Promise<ComposableStrategy> { return new StrategyDataForR(); }
  getCurrentPlanStatus(): PlanStatus { return this.currentPlanStatus; }
  findCurrentActiveEvent(): EventEntity | null { return null; }
  getOrderedScheduleEvents(): EventEntity[] { return this.events; }
  getMinEventDurationLimit(): number { return 20; }
  async skipEvent(_item: EventEntity): Promise<void> { return; }
  recalculateFromEventId(eventId: number): void { this.recalculateFromEventIdCalls.push(eventId); }
  recalculateFromIndex(startIndex: number): void { this.recalculateFromIndexCalls.push(startIndex); }
  markScheduleChanged(): void { return; }
}

class DateNowHookForR {
  private readonly originDateNow: Object;
  private readonly values: number[];
  private cursor: number = 0;

  constructor(values: number[]) {
    this.originDateNow = Reflect.get(Date, 'now') as Object;
    this.values = values;
  }

  enable(): void {
    Reflect.set(Date, 'now', (): number => {
      if (this.cursor >= this.values.length) {
        return this.values[this.values.length - 1];
      }
      const value = this.values[this.cursor];
      this.cursor += 1;
      return value;
    });
  }

  restore(): void {
    Reflect.set(Date, 'now', this.originDateNow);
  }
}

class ServiceBundleForR {
  host: HostMockForR = new HostMockForR();
  service: TimelineWeatherService = new TimelineWeatherService(this.host, new WeatherFacade(), new WeatherRefreshScheduler());
}

function createBundleForR(): ServiceBundleForR {
  return new ServiceBundleForR();
}

function createEventForR(id: number): EventEntity {
  const item = new EventEntity(`evt_r_${id}`, 1);
  item.id = id;
  item.status = 1;
  item.sort_order = id * 100;
  item.duration = 60;
  item.completion_status = EventEntity.STATE_PENDING;
  item.lock_status = 0;
  item.fixed_start_time = '';
  return item;
}

function createSuggestionForR(id: string, actionType: 'NONE' | 'PREPARE' = 'NONE'): WeatherSuggestion {
  return {
    suggestionId: id,
    level: 'NOTICE',
    triggerType: 'RAIN',
    actionType: actionType,
    title: `title_${id}`,
    message: `msg_${id}`,
    relatedNodeIds: [],
    createdAt: Date.now(),
    reason: 'reason_r',
    expectedBenefit: 'benefit_r',
    canRollback: true,
    cooldownKey: `cool_${id}`,
    expiresAt: Date.now() + 60_000,
    actionPayload: {}
  };
}

export default function phase2CoreCoverageBatchRTest() {
  describe('phase2CoreCoverageBatchRTest', () => {
    it('normal: timeline_weather_planning_hint_explanation_should_use_planning_hint_and_collab', 0, () => {
      // Arrange
      const bundle = createBundleForR();
      bundle.host.weatherPlanningHint = '计划天气提示_r';
      bundle.host.weatherCollabSummary = '跨城趋势平稳_r';
      // Act
      const text = bundle.service.buildPlanningWeatherHintExplanation();
      // Assert
      expect(text.indexOf('计划节点天气') >= 0).assertTrue();
      expect(text.indexOf('计划天气提示_r') >= 0).assertTrue();
      expect(text.indexOf('跨城趋势平稳_r') >= 0).assertTrue();
    });

    it('boundary: timeline_weather_get_display_source_should_return_unknown_by_default', 0, () => {
      // Arrange
      const bundle = createBundleForR();
      // Act
      const source = bundle.service.getExecutionWeatherDisplaySource();
      // Assert
      expect(source).assertEqual('UNKNOWN');
    });

    it('invalid: timeline_weather_dismiss_should_ignore_unknown_suggestion_id', 0, () => {
      // Arrange
      const bundle = createBundleForR();
      const suggestion = createSuggestionForR('s_invalid_r');
      bundle.host.executionWeatherSuggestions = [suggestion];
      bundle.host.executionSuggestionMap.set(suggestion.suggestionId, suggestion);
      // Act
      bundle.service.dismissExecutionSuggestion('not_exists_r');
      // Assert
      expect(bundle.host.executionWeatherSuggestions.length).assertEqual(1);
      expect(bundle.host.executionSuggestionMap.has('s_invalid_r')).assertTrue();
    });

    it('conflict: timeline_weather_request_soft_replan_should_timeout_and_rollback_when_apply_takes_too_long', 0, async () => {
      // Arrange
      const bundle = createBundleForR();
      const event = createEventForR(1);
      bundle.host.events = [event];
      bundle.host.planId = 7;
      bundle.host.currentPlanStatus = PlanStatus.READY;
      bundle.host.planStateMachine.gateResult = {
        success: true,
        reasonCode: 'ok',
        startFromEventId: 0
      };
      const suggestion = createSuggestionForR('s_timeout_r', 'NONE');
      bundle.host.executionWeatherSuggestions = [suggestion];
      bundle.host.executionSuggestionMap.set(suggestion.suggestionId, suggestion);
      const dateHook = new DateNowHookForR([1000, 20050]);
      dateHook.enable();
      // Act
      const result = await bundle.service.requestSoftReplan(7, 's_timeout_r', 'APPLY');
      // Assert
      expect(result.success).assertFalse();
      expect(result.errorCode).assertEqual('REPLAN_TIMEOUT');
      expect(result.reasonCode).assertEqual('timeout');
      expect(result.rolledBack).assertTrue();
      expect(bundle.host.recalculateFromIndexCalls.length >= 2).assertTrue();
      dateHook.restore();
    });

    it('regression: td-20260415-timeline-weather-apply-wrapper-should-forward-to-request_soft_replan', 0, async () => {
      // Arrange
      const bundle = createBundleForR();
      let callCount = 0;
      Reflect.set(bundle.service as Object, 'requestSoftReplan',
        async (_planId: number, _suggestionId: string, _mode: SoftReplanMode): Promise<SoftReplanApplyResult> => {
          callCount += 1;
          return new SoftReplanApplyResultDataForR();
        });
      // Act
      const result = await bundle.service.applyWeatherSuggestion('s_wrapper_r');
      // Assert
      expect(result.success).assertTrue();
      expect(callCount).assertEqual(1);
    });

    it('combined: timeline_weather_hint_explanation_should_fallback_to_planning_hint_when_execution_hint_empty', 0, () => {
      // Arrange
      const bundle = createBundleForR();
      bundle.host.executionWeatherDisplaySource = 'NEXT_FALLBACK';
      bundle.host.executionWeatherHint = '';
      bundle.host.weatherPlanningHint = 'planning_fallback_r';
      bundle.host.executionWeatherCollabSummary = 'exec_collab_r';
      // Act
      const text = bundle.service.buildWeatherHintExplanation();
      // Assert
      expect(text.indexOf('下一节点天气估算') >= 0).assertTrue();
      expect(text.indexOf('planning_fallback_r') >= 0).assertTrue();
      expect(text.indexOf('exec_collab_r') >= 0).assertTrue();
    });
  });
}
