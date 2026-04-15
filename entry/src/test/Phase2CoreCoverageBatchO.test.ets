import { describe, expect, it } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { EventRepositoryImpl } from '../main/ets/infrastructure/persistence/EventRepositoryImpl';
import { PlanStatus } from '../main/ets/domain/statemachine/PlanStatus';
import { ComposableStrategy, DensityLevel, EnergyLevel, PaceLevel, PreferenceType } from '../main/ets/domain/strategy/TravelStrategyDimensions';
import {
  GeoPointInput,
  SoftReplanPreview,
  WeatherCollabOptions,
  WeatherSchedulePolicy,
  WeatherStageType,
  WeatherSuggestion,
  WeatherSuggestionActionType,
  WeatherUserPreference
} from '../main/ets/domain/services/WeatherModels';
import { ITimelineWeatherHost, TimelineWeatherService } from '../main/ets/domain/timeline/services/TimelineWeatherService';
import { WeatherFacade } from '../main/ets/domain/services/WeatherFacade';
import { WeatherRefreshScheduler } from '../main/ets/domain/services/WeatherRefreshScheduler';
import { AmapService, GeoCoordinate } from '../main/ets/infrastructure/services/AmapService';

class StrategyDataForO implements ComposableStrategy {
  density: DensityLevel = DensityLevel.MEDIUM;
  pace: PaceLevel = PaceLevel.BALANCED;
  preference: PreferenceType = PreferenceType.BALANCED;
  energy: EnergyLevel = EnergyLevel.MEDIUM;
}

class UserPreferenceDataForO implements WeatherUserPreference {
  heatSensitivity: 0 | 1 | 2 = 1;
  rainSensitivity: 0 | 1 | 2 = 1;
  weatherRiskTolerance: 0 | 1 | 2 = 1;
}

class CollabOptionsDataForO implements WeatherCollabOptions {
  enableMultiDay?: boolean = true;
  enableMultiCity?: boolean = true;
}

class SchedulePolicyDataForO implements WeatherSchedulePolicy {
  stage: WeatherStageType = 'PLANNING';
  pollIntervalMs: number = 60_000;
  allowLocationTrigger: boolean = true;
  allowManualBypass: boolean = true;
  forceRefreshOnEnter: boolean = false;
}

class PlanStateMachineMockForO {
  requestSoftReplan(_args: Object): GateResultDataForO {
    return new GateResultDataForO();
  }
}

class GateResultDataForO {
  success: boolean = true;
  reasonCode?: string = 'ok';
  startFromEventId?: number = 1;
}

class HostMockForO implements ITimelineWeatherHost {
  events: EventEntity[] = [];
  planId: number = 1;
  currentStrategyMode: number = 0;
  weatherFeatureEnabled: boolean = true;
  weatherLoading: boolean = false;
  weatherUserPreference: WeatherUserPreference = new UserPreferenceDataForO();
  weatherCollabOptions: WeatherCollabOptions = new CollabOptionsDataForO();
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
  currentWeatherSchedulePolicy: WeatherSchedulePolicy = new SchedulePolicyDataForO();
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
  planStateMachine: PlanStateMachineMockForO = new PlanStateMachineMockForO();

  skipCalls: number = 0;
  recalculateFromEventIdCalls: number[] = [];
  recalculateFromIndexCalls: number[] = [];
  minEventDurationLimit: number = 20;

  resolveCurrentWeatherStage(): WeatherStageType { return 'PLANNING'; }
  async getCurrentStrategy(): Promise<ComposableStrategy> { return new StrategyDataForO(); }
  getCurrentPlanStatus(): PlanStatus { return this.currentPlanStatus; }
  findCurrentActiveEvent(): EventEntity | null { return null; }
  getOrderedScheduleEvents(): EventEntity[] { return this.events.filter((item: EventEntity) => item.status === 1); }
  getMinEventDurationLimit(): number { return this.minEventDurationLimit; }
  async skipEvent(_item: EventEntity): Promise<void> { this.skipCalls += 1; }
  recalculateFromEventId(eventId: number): void { this.recalculateFromEventIdCalls.push(eventId); }
  recalculateFromIndex(startIndex: number): void { this.recalculateFromIndexCalls.push(startIndex); }
  markScheduleChanged(): void { return; }
}

class ServiceBundleForO {
  host: HostMockForO = new HostMockForO();
  service: TimelineWeatherService = new TimelineWeatherService(this.host, new WeatherFacade(), new WeatherRefreshScheduler());
}

class StaticHooksForO {
  private readonly originUpdateTimelineConsistency: Object;
  private readonly originUpdateSingleField: Object;
  private readonly originGeocode: Object;

  constructor() {
    this.originUpdateTimelineConsistency = Reflect.get(EventRepositoryImpl, 'updateTimelineConsistency') as Object;
    this.originUpdateSingleField = Reflect.get(EventRepositoryImpl, 'updateSingleField') as Object;
    this.originGeocode = Reflect.get(AmapService, 'getGeocode') as Object;
  }

  setUpdateTimelineConsistency(fn: (events: Object[], planIdHint?: number) => Promise<void>): void {
    Reflect.set(EventRepositoryImpl, 'updateTimelineConsistency', fn);
  }

  setUpdateSingleField(fn: (id: number, column: string, value: Object, planIdHint?: number) => Promise<void>): void {
    Reflect.set(EventRepositoryImpl, 'updateSingleField', fn);
  }

  setGeocode(fn: (address: string) => Promise<GeoCoordinate | null>): void {
    Reflect.set(AmapService, 'getGeocode', fn);
  }

  restore(): void {
    Reflect.set(EventRepositoryImpl, 'updateTimelineConsistency', this.originUpdateTimelineConsistency);
    Reflect.set(EventRepositoryImpl, 'updateSingleField', this.originUpdateSingleField);
    Reflect.set(AmapService, 'getGeocode', this.originGeocode);
  }
}

function createBundleForO(): ServiceBundleForO {
  return new ServiceBundleForO();
}

function createEventForO(id: number, status: number = 1, duration: number = 90): EventEntity {
  const item = new EventEntity(`evt_o_${id}`, status);
  item.id = id;
  item.status = status;
  item.sort_order = id * 100;
  item.duration = duration;
  item.completion_status = EventEntity.STATE_PENDING;
  item.lock_status = 0;
  item.fixed_start_time = '';
  return item;
}

function createSuggestionForO(actionType: WeatherSuggestionActionType): WeatherSuggestion {
  return {
    suggestionId: `sugg_${actionType}_o`,
    level: 'NOTICE',
    triggerType: 'RAIN',
    actionType: actionType,
    title: 'title_o',
    message: 'message_o',
    relatedNodeIds: [],
    createdAt: Date.now(),
    reason: 'reason_o',
    expectedBenefit: 'benefit_o',
    canRollback: true,
    cooldownKey: `cd_${actionType}_o`,
    expiresAt: Date.now() + 60_000,
    actionPayload: {}
  };
}

function createPreviewForO(ids: string[]): SoftReplanPreview {
  return {
    suggestionId: 'preview_o',
    actionType: 'REORDER',
    changedOrder: true,
    changedDurations: false,
    skippedNodeIds: [],
    affectedNodeIds: ids,
    reasonCode: 'ok',
    startFromEventId: 0,
    changeSummary: [],
    summary: 'summary_o',
    riskDelta: -10
  };
}

export default function phase2CoreCoverageBatchOTest() {
  describe('phase2CoreCoverageBatchOTest', () => {
    it('normal: timeline_weather_build_preview_should_cover_skip_replace_and_reason_fallback_paths', 0, () => {
      // Arrange
      const bundle = createBundleForO();
      const skipSuggestion = createSuggestionForO('SKIP_NODE');
      skipSuggestion.relatedNodeIds = ['11', '12'];
      skipSuggestion.level = 'WARNING';
      const replaceSuggestion = createSuggestionForO('REPLACE_NODE');
      replaceSuggestion.relatedNodeIds = ['21'];
      // Act
      const skipPreview = bundle.service.buildSoftReplanPreview(skipSuggestion, undefined, 11);
      const replacePreview = bundle.service.buildSoftReplanPreview(replaceSuggestion, 'manual_reason_o', 21);
      // Assert
      expect(skipPreview.reasonCode).assertEqual('node_skipped');
      expect(skipPreview.skippedNodeIds.length).assertEqual(1);
      expect(skipPreview.riskDelta).assertEqual(-20);
      expect(replacePreview.reasonCode).assertEqual('manual_reason_o');
      expect(replacePreview.summary.indexOf('替代建议') >= 0).assertTrue();
    });

    it('boundary: timeline_weather_start_event_resolution_should_return_zero_for_empty_or_invalid_ids', 0, () => {
      // Arrange
      const bundle = createBundleForO();
      // Act
      const emptyId = bundle.service.resolveSoftReplanStartEventId(createPreviewForO([]));
      const invalidId = bundle.service.resolveSoftReplanStartEventId(createPreviewForO(['a', '-1']));
      // Assert
      expect(emptyId).assertEqual(0);
      expect(invalidId).assertEqual(0);
    });

    it('invalid: timeline_weather_contains_immutable_node_should_be_false_for_all_pending_unlocked_targets', 0, () => {
      // Arrange
      const bundle = createBundleForO();
      bundle.host.events = [createEventForO(1), createEventForO(2)];
      // Act
      const blocked = bundle.service.containsImmutableNode([1, 2]);
      // Assert
      expect(blocked).assertFalse();
    });

    it('conflict: timeline_weather_apply_action_should_return_false_when_target_contains_immutable_node', 0, async () => {
      // Arrange
      const bundle = createBundleForO();
      const target = createEventForO(101);
      target.completion_status = EventEntity.STATE_COMPLETED;
      bundle.host.events = [target];
      const suggestion = createSuggestionForO('SHORTEN_STAY');
      suggestion.actionPayload = {
        targetNodeIds: ['101'],
        suggestedStayMinutes: 30
      };
      // Act
      const ok = await bundle.service.applySuggestionAction(suggestion);
      // Assert
      expect(ok).assertFalse();
    });

    it('regression: td-20260415-timeline-weather-replace-should-fallback-to-shorten-when-reorder-fails', 0, async () => {
      // Arrange
      const bundle = createBundleForO();
      const hooks = new StaticHooksForO();
      let updateSingleCalls = 0;
      hooks.setUpdateSingleField(async (_id: number, _column: string, _value: Object, _planIdHint?: number): Promise<void> => {
        updateSingleCalls += 1;
        return;
      });
      const event = createEventForO(201, 1, 120);
      bundle.host.events = [event];
      const suggestion = createSuggestionForO('REPLACE_NODE');
      suggestion.actionPayload = {
        targetNodeIds: ['201'],
        targetOrderNodeIds: ['201'],
        suggestedStayMinutes: 40
      };
      // Act
      const ok = await bundle.service.applySuggestionAction(suggestion);
      // Assert
      expect(ok).assertTrue();
      expect(event.duration).assertEqual(40);
      expect(updateSingleCalls).assertEqual(1);
      hooks.restore();
    });

    it('combined: timeline_weather_apply_action_none_and_reorder_target_filter_should_cover_remaining_paths', 0, async () => {
      // Arrange
      const bundle = createBundleForO();
      const noneSuggestion = createSuggestionForO('NONE');
      noneSuggestion.relatedNodeIds = [];

      const eventA = createEventForO(301);
      const eventB = createEventForO(302);
      bundle.host.events = [eventA, eventB];
      const hooks = new StaticHooksForO();
      let updateTimelineCalls = 0;
      hooks.setUpdateTimelineConsistency(async (_events: Object[], _planIdHint?: number): Promise<void> => {
        updateTimelineCalls += 1;
        return;
      });
      // Act
      const noneOk = await bundle.service.applySuggestionAction(noneSuggestion);
      const reorderOk = await bundle.service.applySoftReorder(['301', '999']);
      // Assert
      expect(noneOk).assertTrue();
      expect(reorderOk).assertFalse();
      expect(updateTimelineCalls).assertEqual(0);
      hooks.restore();
    });

    it('conflict: timeline_weather_apply_action_should_hit_immutable_guard_for_locked_pending_node', 0, async () => {
      // Arrange
      const bundle = createBundleForO();
      const immutable = createEventForO(401, 1, 80);
      immutable.completion_status = EventEntity.STATE_PENDING;
      immutable.lock_status = 1;
      immutable.fixed_start_time = '2026-04-16 09:00:00';
      bundle.host.events = [immutable];
      const suggestion = createSuggestionForO('SHORTEN_STAY');
      suggestion.actionPayload = {
        targetNodeIds: ['401'],
        suggestedStayMinutes: 30
      };
      // Act
      const ok = await bundle.service.applySuggestionAction(suggestion);
      // Assert
      expect(ok).assertFalse();
    });

    it('normal: timeline_weather_build_preview_and_hint_should_cover_order_reason_and_current_source_path', 0, () => {
      // Arrange
      const bundle = createBundleForO();
      bundle.host.executionWeatherDisplaySource = 'CURRENT';
      bundle.host.executionWeatherHint = '当前天气稳定';
      bundle.host.weatherCollabSummary = '跨城协同良好';
      const reorderSuggestion = createSuggestionForO('REORDER');
      reorderSuggestion.level = 'INFO';
      reorderSuggestion.actionPayload = {
        targetNodeIds: ['501', '502']
      };
      // Act
      const preview = bundle.service.buildSoftReplanPreview(reorderSuggestion, undefined, 501);
      const explanation = bundle.service.buildWeatherHintExplanation();
      // Assert
      expect(preview.reasonCode).assertEqual('order_adjusted');
      expect(preview.riskDelta).assertEqual(-5);
      expect(explanation.indexOf('当前定位天气') >= 0).assertTrue();
      expect(explanation.indexOf('跨城协同良好') >= 0).assertTrue();
    });

    it('boundary: timeline_weather_resolve_coordinates_should_cover_empty_name_and_geocode_hit_paths', 0, async () => {
      // Arrange
      const bundle = createBundleForO();
      const hooks = new StaticHooksForO();
      hooks.setGeocode(async (_address: string): Promise<GeoCoordinate | null> => {
        return new GeoCoordinate(31.23, 121.47);
      });
      // Act
      const emptyName = await bundle.service.resolveCoordinatesForPlaceName('   ', undefined, undefined, 'add', 10.1, 20.2);
      const geocodeHit = await bundle.service.resolveCoordinatesForPlaceName('上海外滩', undefined, undefined, 'add', 0, 0);
      // Assert
      expect(emptyName.latitude).assertEqual(10.1);
      expect(emptyName.longitude).assertEqual(20.2);
      expect(geocodeHit.latitude).assertEqual(31.23);
      expect(geocodeHit.longitude).assertEqual(121.47);
      hooks.restore();
    });
  });
}
