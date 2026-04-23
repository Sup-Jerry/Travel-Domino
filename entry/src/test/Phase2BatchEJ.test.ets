import { describe, expect, it } from '@ohos/hypium';
import { AiParserItem, AiResponseParser } from '../main/ets/infrastructure/services/AiResponseParser';
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
import { WeatherFacade } from '../main/ets/domain/services/WeatherFacade';
import { WeatherRefreshScheduler } from '../main/ets/domain/services/WeatherRefreshScheduler';
import { ITimelineWeatherHost, TimelineWeatherService } from '../main/ets/domain/timeline/services/TimelineWeatherService';
import { TrafficEngine } from '../main/ets/infrastructure/services/TrafficEngine';
import { DriveStrategy, LocationInfo } from '../main/ets/model/interface/IMapService';
import { ArrivalReminderCoordinator } from '../main/ets/infrastructure/services/ArrivalReminderCoordinator';

class StrategyDataForEJ implements ComposableStrategy {
  density: DensityLevel = DensityLevel.MEDIUM;
  pace: PaceLevel = PaceLevel.BALANCED;
  preference: PreferenceType = PreferenceType.BALANCED;
  energy: EnergyLevel = EnergyLevel.MEDIUM;
}

class UserPreferenceDataForEJ implements WeatherUserPreference {
  heatSensitivity: 0 | 1 | 2 = 1;
  rainSensitivity: 0 | 1 | 2 = 1;
  weatherRiskTolerance: 0 | 1 | 2 = 1;
}

class CollabOptionsDataForEJ implements WeatherCollabOptions {
  enableMultiDay?: boolean = true;
  enableMultiCity?: boolean = true;
}

class SchedulePolicyDataForEJ implements WeatherSchedulePolicy {
  stage: WeatherStageType = 'READY';
  pollIntervalMs: number = 1_000;
  allowLocationTrigger: boolean = true;
  allowManualBypass: boolean = true;
  forceRefreshOnEnter: boolean = false;
}

class PlanStateGateResultDataForEJ {
  success: boolean = true;
  reasonCode?: string = 'ok';
  startFromEventId?: number = 1;
}

class PlanStateMachineMockForEJ {
  requestSoftReplan(_args: Object): PlanStateGateResultDataForEJ {
    return new PlanStateGateResultDataForEJ();
  }
}

class HostMockForEJ implements ITimelineWeatherHost {
  events: EventEntity[] = [];
  planId: number = 1;
  currentStrategyMode: number = 0;
  weatherFeatureEnabled: boolean = true;
  weatherLoading: boolean = false;
  weatherUserPreference: WeatherUserPreference = new UserPreferenceDataForEJ();
  weatherCollabOptions: WeatherCollabOptions = new CollabOptionsDataForEJ();
  executionWeatherEnabled: boolean = false;
  executionWeatherLoading: boolean = false;
  currentPlanStatus: PlanStatus = PlanStatus.READY;
  executionWeatherLastTrigger: string = '';
  executionWeatherErrorCode: string = '';
  executionWeatherScore: number = 0;
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
  currentWeatherSchedulePolicy: WeatherSchedulePolicy = new SchedulePolicyDataForEJ();
  executionReplanBusy: boolean = false;
  executionWeatherApplying: boolean = false;
  executionWeatherAppliedSummary: string = '';
  executionWeatherLastEmitAt: number = 0;
  executionWeatherLocationDeltaMeters: number = 0;
  executionSuggestionCooldownMs: number = 0;
  executionSuggestionCooldownMap: Map<string, number> = new Map<string, number>();
  weatherPlanningHint: string = '';
  weatherRouteScore: number = 0;
  weatherCollabSummary: string = '';
  weatherCollabLabel: string = '';
  weatherStrategyHint: string = '';
  weatherLastRefreshAt: number = 0;
  planStateMachine: PlanStateMachineMockForEJ = new PlanStateMachineMockForEJ();

  resolveCurrentWeatherStage(): WeatherStageType { return 'READY'; }
  async getCurrentStrategy(): Promise<ComposableStrategy> { return new StrategyDataForEJ(); }
  getCurrentPlanStatus(): PlanStatus { return this.currentPlanStatus; }
  findCurrentActiveEvent(): EventEntity | null { return null; }
  getOrderedScheduleEvents(): EventEntity[] { return this.events; }
  getMinEventDurationLimit(): number { return 15; }
  async skipEvent(_item: EventEntity): Promise<void> { return; }
  recalculateFromEventId(_eventId: number): void { return; }
  recalculateFromIndex(_startIndex: number): void { return; }
  markScheduleChanged(): void { return; }
}

class WeatherFacadeMockForEJ {
  policy: WeatherSchedulePolicy = new SchedulePolicyDataForEJ();

  resolveSchedulePolicy(stage: WeatherStageType): WeatherSchedulePolicy {
    this.policy.stage = stage;
    return this.policy;
  }
}

class WeatherSchedulerMockForEJ {
  startCalls: number = 0;
  lastCallback: (() => void) | null = null;

  start(_intervalMs: number, callback: () => void): void {
    this.startCalls += 1;
    this.lastCallback = callback;
  }

  stop(): void {
    return;
  }
}

class WeatherBundleForEJ {
  host: HostMockForEJ = new HostMockForEJ();
  service: TimelineWeatherService = new TimelineWeatherService(this.host, new WeatherFacade(), new WeatherRefreshScheduler());
  facade: WeatherFacadeMockForEJ = new WeatherFacadeMockForEJ();
  scheduler: WeatherSchedulerMockForEJ = new WeatherSchedulerMockForEJ();
}

function createWeatherBundleEJ(): WeatherBundleForEJ {
  const bundle = new WeatherBundleForEJ();
  Reflect.set(bundle.service as Object, 'weatherFacade', bundle.facade);
  Reflect.set(bundle.service as Object, 'weatherScheduler', bundle.scheduler);
  return bundle;
}

function identityEJ(item: AiParserItem): AiParserItem {
  return item;
}

interface TrafficEnginePrivateForEJ {
  cache: Map<string, number>;
  transientFailureUntil: Map<string, number>;
  markTransientFailure(key: string, reason: string): void;
  fetchAmapTrafficAsync(from: LocationInfo, to: LocationInfo, strategy: DriveStrategy, key: string): Promise<void>;
}

interface ArrivalReminderCoordinatorPrivateForEJ {
  isTerminalStatus(status: PlanStatus): boolean;
}

function createLocationEJ(name: string): LocationInfo {
  const location = {} as LocationInfo;
  location.name = name;
  location.latitude = 31.2;
  location.longitude = 121.5;
  return location;
}

function resetTrafficEngineEJ(): TrafficEnginePrivateForEJ {
  Reflect.set(TrafficEngine as Object, 'instance', null);
  return TrafficEngine.getInstance() as Object as TrafficEnginePrivateForEJ;
}

interface AiResponseParserPrivateForEJ {
  pickArrayFromObject(parsed: Object): AiParserItem[] | null;
}

class AiParserObjectRecordForEJ {
  items: AiParserItem[] = [];
}

export default function phase2BatchEJTest() {
  describe('phase2BatchEJTest', () => {
    it('normal: ai_parser_should_pick_first_array_from_unknown_object_key', 0, () => {
      // Arrange
      const raw = '{"payload":[{"name":"museum","duration":45,"ai_reasoning":"r","type":0}]}';
      // Act
      const items = AiResponseParser.parseItemsFromContent(raw, identityEJ);
      // Assert
      expect(items.length).assertEqual(1);
      expect(items[0].name).assertEqual('museum');
    });

    it('normal: ai_parser_private_pick_array_should_return_preferred_items_array', 0, () => {
      // Arrange
      const parser = AiResponseParser as Object as AiResponseParserPrivateForEJ;
      const record = new AiParserObjectRecordForEJ();
      record.items = [{
        name: 'picked',
        duration: 35,
        ai_reasoning: 'r',
        type: 0
      }];
      // Act
      const items = parser.pickArrayFromObject(record);
      // Assert
      expect(items !== null).assertTrue();
      expect((items as AiParserItem[])[0].name).assertEqual('picked');
    });

    it('boundary: ai_parser_line_text_should_infer_food_type_when_type_missing', 0, () => {
      // Arrange
      const raw = '- Lunch stop duration: 50min reason: restaurant break';
      // Act
      const items = AiResponseParser.parseItemsFromContent(raw, identityEJ);
      // Assert
      expect(items.length).assertEqual(1);
      expect(items[0].type).assertEqual(1);
    });

    it('invalid: ai_parser_line_text_should_infer_accommodation_type_when_type_missing', 0, () => {
      // Arrange
      const raw = '- Hotel checkin duration: 30min reason: accommodation';
      // Act
      const items = AiResponseParser.parseItemsFromContent(raw, identityEJ);
      // Assert
      expect(items.length).assertEqual(1);
      expect(items[0].type).assertEqual(2);
    });

    it('conflict: weather_scheduler_callback_should_skip_when_feature_disabled', 0, () => {
      // Arrange
      const bundle = createWeatherBundleEJ();
      bundle.host.weatherFeatureEnabled = true;
      bundle.service.startExecutionWeatherScheduler(1, 'READY');
      bundle.host.weatherFeatureEnabled = false;
      // Act
      bundle.scheduler.lastCallback?.();
      // Assert
      expect(bundle.scheduler.startCalls).assertEqual(1);
      expect(bundle.host.executionWeatherEnabled).assertTrue();
    });

    it('regression: weather_scheduler_callback_should_refresh_planning_for_confirmed_status', 0, () => {
      // Arrange
      const bundle = createWeatherBundleEJ();
      let planningRefreshCalls = 0;
      bundle.host.currentPlanStatus = PlanStatus.CONFIRMED;
      Reflect.set(bundle.service as Object, 'shouldAutoRefreshPlanningWeather', (): boolean => true);
      Reflect.set(bundle.service as Object, 'refreshPlanningWeather', async (_force: boolean = false): Promise<void> => {
        planningRefreshCalls += 1;
      });
      bundle.service.startExecutionWeatherScheduler(1, 'CONFIRMED');
      // Act
      bundle.scheduler.lastCallback?.();
      // Assert
      expect(planningRefreshCalls).assertEqual(1);
    });

    it('combined: weather_scheduler_callback_should_refresh_execution_for_runtime_status', 0, () => {
      // Arrange
      const bundle = createWeatherBundleEJ();
      let executionRefreshCalls = 0;
      bundle.host.currentPlanStatus = PlanStatus.READY;
      Reflect.set(bundle.service as Object, 'refreshExecutionWeather', async (_force: boolean, trigger: string): Promise<void> => {
        if (trigger === 'TIMER') {
          executionRefreshCalls += 1;
        }
      });
      bundle.service.startExecutionWeatherScheduler(1, 'READY');
      // Act
      bundle.scheduler.lastCallback?.();
      // Assert
      expect(executionRefreshCalls).assertEqual(1);
    });

    it('normal: traffic_engine_private_mark_transient_failure_should_record_guard_window', 0, () => {
      // Arrange
      const engine = resetTrafficEngineEJ();
      const key = 'from->to_M0';
      // Act
      engine.markTransientFailure(key, 'unit_guard');
      // Assert
      expect((engine.transientFailureUntil.get(key) ?? 0) > Date.now()).assertTrue();
    });

    it('boundary: traffic_engine_drive_fetch_should_mark_transient_when_service_missing', 0, async () => {
      // Arrange
      const engine = resetTrafficEngineEJ();
      const key = 'drive_missing_service';
      // Act
      await engine.fetchAmapTrafficAsync(createLocationEJ('from'), createLocationEJ('to'), DriveStrategy.FASTEST, key);
      // Assert
      expect(engine.cache.has(key)).assertFalse();
      expect(engine.transientFailureUntil.has(key)).assertTrue();
    });

    it('invalid: arrival_coordinator_terminal_status_helper_should_reject_non_terminal_status', 0, () => {
      // Arrange
      const coordinator = ArrivalReminderCoordinator.getInstance() as Object as ArrivalReminderCoordinatorPrivateForEJ;
      // Act
      const completed = coordinator.isTerminalStatus(PlanStatus.COMPLETED);
      const ready = coordinator.isTerminalStatus(PlanStatus.READY);
      // Assert
      expect(completed).assertTrue();
      expect(ready).assertFalse();
    });
  });
}
