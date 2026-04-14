import { describe, expect, it } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { PlanStatus } from '../main/ets/domain/statemachine/PlanStatus';
import { ComposableStrategy, DensityLevel, EnergyLevel, PaceLevel, PreferenceType } from '../main/ets/domain/strategy/TravelStrategyDimensions';
import { TimelineWeatherService, ITimelineWeatherHost } from '../main/ets/domain/timeline/services/TimelineWeatherService';
import {
  GeoPointInput,
  PlanNodeWeatherBinding,
  ReplanChangeSummaryItem,
  SoftReplanPreview,
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

class GateResultData {
  success: boolean = true;
  reasonCode?: string = 'ok';
  startFromEventId?: number = 1;
}

class PlanStateMachineMock {
  requestSoftReplan(_args: Object): GateResultData {
    return new GateResultData();
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

  recalculateFromIndexCalls: number[] = [];

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
    return this.events.filter((item: EventEntity) => item.status === 1);
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

  recalculateFromIndex(startIndex: number): void {
    this.recalculateFromIndexCalls.push(startIndex);
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

class ReplanNodeSnapshotData {
  id: number = 0;
  sortOrder: number = 0;
  duration: number = 0;
  startTs: number = 0;
  endTs: number = 0;
}

function createBundle(): ServiceBundle {
  return new ServiceBundle();
}

function createEvent(id: number, status: number = 1): EventEntity {
  const item = new EventEntity(`e_${id}`, 1);
  item.id = id;
  item.status = status;
  item.sort_order = id * 100;
  item.duration = 60;
  item.completion_status = EventEntity.STATE_PENDING;
  item.dynamic_start_time = id * 1_000;
  item.dynamic_end_time = id * 1_000 + 3_600_000;
  return item;
}

function createSuggestion(
  id: string,
  level: 'INFO' | 'NOTICE' | 'WARNING',
  actionType: 'NONE' | 'PREPARE' | 'REORDER' | 'SHORTEN_STAY' | 'REPLACE_NODE' | 'SKIP_NODE',
  createdAt: number,
  expiresAt: number
): WeatherSuggestion {
  return {
    suggestionId: id,
    level: level,
    triggerType: 'UNKNOWN',
    actionType: actionType,
    title: `title_${id}`,
    message: `msg_${id}`,
    relatedNodeIds: ['1', '2'],
    createdAt: createdAt,
    reason: 'r',
    expectedBenefit: 'b',
    canRollback: true,
    cooldownKey: `cool_${id}`,
    expiresAt: expiresAt,
    actionPayload: {
      targetNodeIds: ['1', '2'],
      suggestedStayMinutes: 35
    }
  };
}

function createPreview(reasonCode: string): SoftReplanPreview {
  return {
    suggestionId: 's1',
    actionType: 'REORDER',
    changedOrder: true,
    changedDurations: false,
    skippedNodeIds: [],
    affectedNodeIds: ['1', '2'],
    reasonCode: reasonCode,
    startFromEventId: 1,
    changeSummary: [],
    summary: '',
    riskDelta: -10
  };
}

function createReplanNodeSnapshotData(
  id: number,
  sortOrder: number,
  duration: number,
  startTs: number,
  endTs: number
): ReplanNodeSnapshotData {
  const item = new ReplanNodeSnapshotData();
  item.id = id;
  item.sortOrder = sortOrder;
  item.duration = duration;
  item.startTs = startTs;
  item.endTs = endTs;
  return item;
}

export default function phase2CoreCoverageBatchETest() {
  describe('phase2CoreCoverageBatchETest', () => {
    it('normal: timeline_weather_service_build_soft_preview_should_map_action_flags_and_reason', 0, () => {
      // Arrange
      const bundle = createBundle();
      const shorten = createSuggestion('s_shorten', 'NOTICE', 'SHORTEN_STAY', Date.now(), Date.now() + 60_000);
      // Act
      const preview = bundle.service.buildSoftReplanPreview(shorten, undefined, 9);
      // Assert
      expect(preview.changedDurations).assertTrue();
      expect(preview.changedOrder).assertFalse();
      expect(preview.reasonCode).assertEqual('duration_adjusted');
      expect(preview.summary.indexOf('35') >= 0).assertTrue();
    });

    it('boundary: timeline_weather_service_filter_active_suggestions_should_remove_expired_and_sort_by_level_then_time', 0, () => {
      // Arrange
      const bundle = createBundle();
      const now = Date.now();
      bundle.host.executionSuggestionCooldownMs = 120_000;
      bundle.host.executionSuggestionCooldownMap.set('cool_skip', now - 1_000);
      const expired = createSuggestion('expired', 'WARNING', 'NONE', now - 50_000, now - 1);
      const cooldown = createSuggestion('skip', 'WARNING', 'NONE', now - 40_000, now + 20_000);
      cooldown.cooldownKey = 'cool_skip';
      const warning = createSuggestion('warn', 'WARNING', 'NONE', now - 30_000, now + 20_000);
      const notice = createSuggestion('notice', 'NOTICE', 'NONE', now - 20_000, now + 20_000);
      const info = createSuggestion('info', 'INFO', 'NONE', now - 10_000, now + 20_000);
      // Act
      const filtered = bundle.service.filterActiveExecutionSuggestions([expired, cooldown, notice, info, warning]);
      // Assert
      expect(filtered.length).assertEqual(3);
      expect(filtered[0].suggestionId).assertEqual('warn');
      expect(filtered[1].suggestionId).assertEqual('notice');
      expect(filtered[2].suggestionId).assertEqual('info');
    });

    it('invalid: timeline_weather_service_apply_execution_suggestion_should_respect_emit_interval_when_not_manual', 0, () => {
      // Arrange
      const bundle = createBundle();
      const now = Date.now();
      bundle.host.executionWeatherLastEmitAt = now;
      const suggestion = createSuggestion('i1', 'INFO', 'NONE', now, now + 60_000);
      // Act
      bundle.service.applyExecutionSuggestion(suggestion, 'TIMER');
      // Assert
      expect(bundle.host.executionSuggestionMap.has('i1')).assertTrue();
      expect(bundle.host.executionWeatherHint).assertEqual('msg_i1');
      expect(bundle.host.executionWeatherLevel).assertEqual('INFO');
      expect(bundle.host.executionSuggestionCooldownMap.has('cool_i1')).assertFalse();
    });

    it('conflict: timeline_weather_service_build_structured_summary_and_text_should_cover_immutable_noop_and_counts', 0, () => {
      // Arrange
      const bundle = createBundle();
      const before = new Map<number, ReplanNodeSnapshotData>();
      const after = new Map<number, ReplanNodeSnapshotData>();
      before.set(1, createReplanNodeSnapshotData(1, 100, 60, 1_000, 2_000));
      after.set(1, createReplanNodeSnapshotData(1, 300, 40, 61_000, 62_000));

      // Act
      const structured = bundle.service.buildStructuredReplanSummary(before, after, ['1']);
      const immutableText = bundle.service.composeReplanSummaryText(createPreview('immutable_blocked'), structured);
      const changedText = bundle.service.composeReplanSummaryText(createPreview('ok'), structured);
      const noop = bundle.service.buildStructuredReplanSummary(before, before, ['1']);

      // Assert
      expect(structured.length).assertEqual(3);
      expect(immutableText.indexOf('未执行重排') >= 0).assertTrue();
      expect(changedText.indexOf('顺序变更 1 项') >= 0).assertTrue();
      expect(noop.length).assertEqual(1);
      expect(noop[0].type).assertEqual('NO_OP');
    });

    it('regression: td-20260414-phase2-weather-snapshot_restore_should_recover_state_and_recalculate', 0, () => {
      // Arrange
      const bundle = createBundle();
      const e1 = createEvent(1);
      e1.duration = 90;
      bundle.host.events = [e1, createEvent(2)];
      const snapshot = bundle.service.cloneEventSnapshot();
      bundle.host.events[0].duration = 10;
      // Act
      bundle.service.restoreEventSnapshot(snapshot);
      // Assert
      expect(bundle.host.events[0].duration).assertEqual(90);
      expect(bundle.host.recalculateFromIndexCalls.length).assertEqual(1);
      expect(bundle.host.recalculateFromIndexCalls[0]).assertEqual(0);
    });

    it('combined: timeline_weather_service_patch_execution_weather_should_only_update_pending_bound_events', 0, () => {
      // Arrange
      const bundle = createBundle();
      const pendingBound = createEvent(1);
      const completedBound = createEvent(2);
      completedBound.completion_status = EventEntity.STATE_COMPLETED;
      const pendingNoBinding = createEvent(3);
      bundle.host.events = [pendingBound, completedBound, pendingNoBinding];

      const binding = new Map<number, PlanNodeWeatherBinding>();
      binding.set(1, {
        nodeId: '1',
        eventId: 1,
        suitabilityScore: 88,
        riskTags: [],
        weather: {
          locationKey: 'loc_1',
          sourceType: 'PLAN_LOCATION',
          weatherTime: Date.now(),
          fetchTime: 123456,
          conditionCode: 'RAIN',
          conditionText: '小雨',
          temperatureCelsius: 20
        }
      });
      // Act
      bundle.service.patchExecutionWeatherToEvents(binding, false);
      // Assert
      expect(bundle.host.events[0].weather_condition).assertEqual('RAIN');
      expect(bundle.host.events[0].weather_text).assertEqual('小雨');
      expect(bundle.host.events[0].weather_temperature).assertEqual(20);
      expect(bundle.host.events[0].weather_fetch_time).assertEqual(123456);
      expect(bundle.host.events[1].weather_condition).assertEqual('');
      expect(bundle.host.events[2].weather_condition).assertEqual('');
    });
  });
}
