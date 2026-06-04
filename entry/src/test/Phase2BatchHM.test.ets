import { describe, expect, it } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { PlanStatus } from '../main/ets/domain/statemachine/PlanStatus';
import {
  ComposableStrategy,
  DensityLevel,
  EnergyLevel,
  PaceLevel,
  PreferenceType
} from '../main/ets/domain/strategy/TravelStrategyDimensions';
import {
  GeoPointInput,
  WeatherCollabOptions,
  WeatherSchedulePolicy,
  WeatherStageType,
  WeatherSuggestion,
  WeatherSuggestionTriggerType,
  WeatherUserPreference
} from '../main/ets/domain/services/WeatherModels';
import { ITimelineWeatherHost, TimelineWeatherService } from '../main/ets/domain/timeline/services/TimelineWeatherService';
import { WeatherFacade } from '../main/ets/domain/services/WeatherFacade';
import { WeatherRefreshScheduler } from '../main/ets/domain/services/WeatherRefreshScheduler';

class StrategyDataForHM implements ComposableStrategy {
  density: DensityLevel = DensityLevel.MEDIUM;
  pace: PaceLevel = PaceLevel.BALANCED;
  preference: PreferenceType = PreferenceType.BALANCED;
  energy: EnergyLevel = EnergyLevel.MEDIUM;
}

class UserPreferenceDataForHM implements WeatherUserPreference {
  heatSensitivity: 0 | 1 | 2 = 1;
  rainSensitivity: 0 | 1 | 2 = 1;
  weatherRiskTolerance: 0 | 1 | 2 = 1;
}

class CollabOptionsDataForHM implements WeatherCollabOptions {
  enableMultiDay?: boolean = true;
  enableMultiCity?: boolean = true;
}

class SchedulePolicyDataForHM implements WeatherSchedulePolicy {
  stage: WeatherStageType = 'IN_PROGRESS';
  pollIntervalMs: number = 60_000;
  allowLocationTrigger: boolean = true;
  allowManualBypass: boolean = true;
  forceRefreshOnEnter: boolean = false;
}

class GateResultDataForHM {
  success: boolean = true;
  reasonCode?: string = 'ok';
  startFromEventId?: number = 0;
}

class PlanStateMachineMockForHM {
  requestSoftReplan(_args: Object): GateResultDataForHM {
    return new GateResultDataForHM();
  }
}

class HostMockForHM implements ITimelineWeatherHost {
  events: EventEntity[] = [];
  planId: number = 1;
  currentStrategyMode: number = 0;
  weatherFeatureEnabled: boolean = true;
  weatherLoading: boolean = false;
  weatherUserPreference: WeatherUserPreference = new UserPreferenceDataForHM();
  weatherCollabOptions: WeatherCollabOptions = new CollabOptionsDataForHM();
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
  currentWeatherSchedulePolicy: WeatherSchedulePolicy = new SchedulePolicyDataForHM();
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
  planStateMachine: PlanStateMachineMockForHM = new PlanStateMachineMockForHM();
  activeEvent: EventEntity | null = null;
  recalcIndexes: number[] = [];

  resolveCurrentWeatherStage(): WeatherStageType { return 'IN_PROGRESS'; }
  async getCurrentStrategy(): Promise<ComposableStrategy> { return new StrategyDataForHM(); }
  getCurrentPlanStatus(): PlanStatus { return this.currentPlanStatus; }
  findCurrentActiveEvent(): EventEntity | null { return this.activeEvent; }
  getOrderedScheduleEvents(): EventEntity[] { return this.events; }
  getMinEventDurationLimit(): number { return 20; }
  async skipEvent(_item: EventEntity): Promise<void> { return; }
  recalculateFromEventId(_eventId: number): void { return; }
  recalculateFromIndex(startIndex: number): void { this.recalcIndexes.push(startIndex); }
  markScheduleChanged(): void { return; }
}

interface TimelineWeatherServicePrivateHM {
  buildExecutionStrategyHint(suggestion: WeatherSuggestion): string | undefined;
  buildExecutionStrategyAdjustment(suggestion: WeatherSuggestion): Object | undefined;
  findNextPendingEvent(activeEventId: number): EventEntity | null;
  shouldSkipByLocationThreshold(currentLocation: GeoPointInput | null): boolean;
  measureDistanceMeters(lat1: number, lng1: number, lat2: number, lng2: number): number;
  resolveExecutionCurrentLocation(): GeoPointInput | null;
}

class ServiceBundleForHM {
  host: HostMockForHM = new HostMockForHM();
  service: TimelineWeatherService = new TimelineWeatherService(this.host, new WeatherFacade(), new WeatherRefreshScheduler());
}

function createBundleForHM(): ServiceBundleForHM {
  return new ServiceBundleForHM();
}

function createEventForHM(id: number, lat: number = 0, lng: number = 0): EventEntity {
  const item = new EventEntity(`hm_${id}`, 1);
  item.id = id;
  item.status = 1;
  item.sort_order = id * 100;
  item.completion_status = EventEntity.STATE_PENDING;
  item.latitude = lat;
  item.longitude = lng;
  return item;
}

function createSuggestionForHM(triggerType: WeatherSuggestionTriggerType): WeatherSuggestion {
  return {
    suggestionId: `hm_${triggerType}`,
    level: 'NOTICE',
    triggerType: triggerType,
    actionType: 'PREPARE',
    title: 'title_hm',
    message: 'message_hm',
    relatedNodeIds: [],
    createdAt: Date.now(),
    reason: 'reason_hm',
    expectedBenefit: 'benefit_hm',
    canRollback: true,
    cooldownKey: `cool_hm_${triggerType}`,
    expiresAt: Date.now() + 60_000,
    actionPayload: {}
  };
}

export default function phase2BatchHMTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchHM_timeline_weather_private_helpers', () => {
    it('normal: execution_strategy_hint_should_match_rain_and_heat_triggers', 0, () => {
      // Arrange
      const bundle = createBundleForHM();
      const service = bundle.service as Object as TimelineWeatherServicePrivateHM;
      // Act
      const rainHint = service.buildExecutionStrategyHint(createSuggestionForHM('RAIN'));
      const heatHint = service.buildExecutionStrategyHint(createSuggestionForHM('HEAT'));
      // Assert
      expect((rainHint ?? '').length > 0).assertTrue();
      expect((heatHint ?? '').length > 0).assertTrue();
      expect(rainHint === heatHint).assertFalse();
    });

    it('boundary: execution_strategy_adjustment_should_return_density_or_pace_energy', 0, () => {
      // Arrange
      const bundle = createBundleForHM();
      const service = bundle.service as Object as TimelineWeatherServicePrivateHM;
      // Act
      const rainAdjustment = service.buildExecutionStrategyAdjustment(createSuggestionForHM('RAIN')) as Object;
      const heatAdjustment = service.buildExecutionStrategyAdjustment(createSuggestionForHM('HEAT')) as Object;
      // Assert
      expect(Reflect.get(rainAdjustment, 'density') as number).assertEqual(-1);
      expect(Reflect.get(heatAdjustment, 'pace') as number).assertEqual(-1);
      expect(Reflect.get(heatAdjustment, 'energy') as number).assertEqual(-1);
    });

    it('invalid: execution_strategy_helpers_should_ignore_unknown_trigger', 0, () => {
      // Arrange
      const bundle = createBundleForHM();
      const service = bundle.service as Object as TimelineWeatherServicePrivateHM;
      // Act
      const hint = service.buildExecutionStrategyHint(createSuggestionForHM('UNKNOWN'));
      const adjustment = service.buildExecutionStrategyAdjustment(createSuggestionForHM('UNKNOWN'));
      // Assert
      expect(hint === undefined).assertTrue();
      expect(adjustment === undefined).assertTrue();
    });

    it('conflict: next_pending_event_should_start_after_active_event_and_skip_done_items', 0, () => {
      // Arrange
      const bundle = createBundleForHM();
      const service = bundle.service as Object as TimelineWeatherServicePrivateHM;
      const active = createEventForHM(1);
      const done = createEventForHM(2);
      const next = createEventForHM(3);
      done.completion_status = EventEntity.STATE_COMPLETED;
      bundle.host.events = [active, done, next];
      // Act
      const found = service.findNextPendingEvent(active.id);
      const missing = service.findNextPendingEvent(999);
      // Assert
      expect(found?.id ?? 0).assertEqual(3);
      expect(missing?.id ?? 0).assertEqual(1);
    });

    it('regression: location_threshold_should_only_skip_when_delta_is_below_configured_meters', 0, () => {
      // Arrange
      const bundle = createBundleForHM();
      const service = bundle.service as Object as TimelineWeatherServicePrivateHM;
      bundle.host.executionWeatherLastLocation = { latitude: 31.2304, longitude: 121.4737 };
      bundle.host.executionWeatherLocationDeltaMeters = 1000;
      // Act
      const smallMoveSkipped = service.shouldSkipByLocationThreshold({ latitude: 31.23041, longitude: 121.47371 });
      const largeMoveSkipped = service.shouldSkipByLocationThreshold({ latitude: 32.0, longitude: 122.0 });
      const noCurrentSkipped = service.shouldSkipByLocationThreshold(null);
      // Assert
      expect(smallMoveSkipped).assertTrue();
      expect(largeMoveSkipped).assertFalse();
      expect(noCurrentSkipped).assertFalse();
    });

    it('combined: execution_current_location_should_fallback_from_active_to_next_pending_event', 0, () => {
      // Arrange
      const bundle = createBundleForHM();
      const service = bundle.service as Object as TimelineWeatherServicePrivateHM;
      const active = createEventForHM(10, 0, 0);
      const next = createEventForHM(11, 30.12, 120.56);
      bundle.host.activeEvent = active;
      bundle.host.events = [active, next];
      // Act
      const location = service.resolveExecutionCurrentLocation();
      const distance = service.measureDistanceMeters(31.2304, 121.4737, 31.2305, 121.4738);
      // Assert
      expect((location?.latitude ?? 0) !== 0).assertTrue();
      expect((location?.longitude ?? 0) !== 0).assertTrue();
      expect(distance > 0).assertTrue();
    });
  });
}
