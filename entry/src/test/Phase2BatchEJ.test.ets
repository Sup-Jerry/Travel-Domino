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
import { PreferenceManager } from '../main/ets/common/utils/PreferenceManager';
import { AmapService } from '../main/ets/infrastructure/services/AmapService';

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
  stopCalls: number = 0;
  lastCallback: (() => void) | null = null;

  start(_intervalMs: number, callback: () => void): void {
    this.startCalls += 1;
    this.lastCallback = callback;
  }

  stop(): void {
    this.stopCalls += 1;
  }
}

class PreferenceManagerMockForEJ {
  featureEnabled: boolean = true;
  preference: WeatherUserPreference = new UserPreferenceDataForEJ();
  setFeatureEnabledCalls: boolean[] = [];
  setPreferenceCalls: WeatherUserPreference[] = [];

  async setWeatherFeatureEnabled(enabled: boolean): Promise<void> {
    this.setFeatureEnabledCalls.push(enabled);
    this.featureEnabled = enabled;
  }

  async setWeatherUserPreference(preference: WeatherUserPreference): Promise<void> {
    this.setPreferenceCalls.push(preference);
    this.preference = preference;
  }

  async getWeatherUserPreference(): Promise<WeatherUserPreference> {
    return this.preference;
  }

  async isWeatherFeatureEnabled(): Promise<boolean> {
    return this.featureEnabled;
  }
}

class PreferenceManagerThrowingMockForEJ {
  async getWeatherUserPreference(): Promise<WeatherUserPreference> {
    throw new Error('pref_failed');
  }

  async isWeatherFeatureEnabled(): Promise<boolean> {
    return false;
  }
}

class GeocodeResultForEJ {
  lat: number = 31.240;
  lng: number = 121.490;
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
  fetchMultiModalTrafficAsync(
    from: LocationInfo,
    to: LocationInfo,
    mode: number,
    key: string,
    startTime?: string
  ): Promise<void>;
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

class DriveMapServiceForEJ {
  duration: number = 26;
  throwOnDrive: boolean = false;
  driveCalls: number = 0;
  modeCalls: number = 0;

  public async getLocationInfo(_keyword: string): Promise<LocationInfo[]> {
    return [];
  }

  public async calculateCommute(_from: string, _to: string): Promise<number> {
    return 0;
  }

  public async getDriveDuration(
    _origin: LocationInfo,
    _destination: LocationInfo,
    _strategy: DriveStrategy
  ): Promise<number> {
    this.driveCalls += 1;
    if (this.throwOnDrive) {
      throw new Error('drive_fetch_failed_ej');
    }
    return this.duration;
  }

  public async getDurationByMode(
    _origin: LocationInfo,
    _destination: LocationInfo,
    _mode: number,
    _startTime?: string
  ): Promise<number> {
    this.modeCalls += 1;
    return this.duration;
  }
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

    it('boundary: ai_parser_should_extract_items_from_nested_message_content_string', 0, () => {
      // Arrange
      const raw = '{"message":{"content":"[{\\"name\\":\\"tower\\",\\"duration\\":35,\\"ai_reasoning\\":\\"nested\\",\\"type\\":0}]"}}';
      // Act
      const items = AiResponseParser.parseItemsFromContent(raw, identityEJ);
      // Assert
      expect(items.length).assertEqual(1);
      expect(items[0].name).assertEqual('tower');
    });

    it('boundary: ai_parser_should_extract_items_from_nested_result_text_object', 0, () => {
      // Arrange
      const raw = '{"result":{"text":"[{\\"name\\":\\"gallery\\",\\"duration\\":55,\\"ai_reasoning\\":\\"deep\\",\\"type\\":0}]"}}';
      // Act
      const items = AiResponseParser.parseItemsFromContent(raw, identityEJ);
      // Assert
      expect(items.length).assertEqual(1);
      expect(items[0].duration).assertEqual(55);
    });

    it('boundary: ai_parser_line_text_should_use_candidate_name_before_dash_when_name_missing', 0, () => {
      // Arrange
      const raw = '- River Walk - duration: 40min reason: relaxed';
      // Act
      const items = AiResponseParser.parseItemsFromContent(raw, identityEJ);
      // Assert
      expect(items.length).assertEqual(1);
      expect(items[0].name).assertEqual('River Walk');
      expect(items[0].type).assertEqual(0);
    });

    it('combined: ai_parser_line_text_should_skip_invalid_lines_and_keep_valid_item', 0, () => {
      // Arrange
      const raw = '- duration: 0min reason: skip\n- Sunset Pier duration: 25min reason: photo stop';
      // Act
      const items = AiResponseParser.parseItemsFromContent(raw, identityEJ);
      // Assert
      expect(items.length).assertEqual(1);
      expect(items[0].name).assertEqual('Sunset Pier');
      expect(items[0].duration).assertEqual(25);
    });

    it('regression: ai_parser_model_response_should_join_segment_content_field_and_ignore_blank_segments', 0, () => {
      // Arrange
      const res =
        '{"choices":[{"message":{"content":["   ",{"content":"[{\\"name\\":\\"joined\\",\\"duration\\":65,\\"ai_reasoning\\":\\"segment\\",\\"type\\":1}]"}]}}]}';
      // Act
      const items = AiResponseParser.parseModelResponseForTest(res, identityEJ);
      // Assert
      expect(items.length).assertEqual(1);
      expect(items[0].name).assertEqual('joined');
      expect(items[0].type).assertEqual(1);
    });

    it('regression: ai_parser_model_response_should_read_message_content_text_object', 0, () => {
      // Arrange
      const res =
        '{"choices":[{"message":{"content":{"text":"[{\\"name\\":\\"objectText\\",\\"duration\\":30,\\"ai_reasoning\\":\\"obj\\",\\"type\\":2}]"}}}]}';
      // Act
      const items = AiResponseParser.parseModelResponseForTest(res, identityEJ);
      // Assert
      expect(items.length).assertEqual(1);
      expect(items[0].name).assertEqual('objectText');
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

    it('normal: weather_service_should_stop_scheduler_and_clear_runtime_when_feature_disabled', 0, async () => {
      // Arrange
      const bundle = createWeatherBundleEJ();
      const preferenceManager = new PreferenceManagerMockForEJ();
      const originalGetInstance = Reflect.get(PreferenceManager as Object, 'getInstance') as () => Object;
      const event = new EventEntity();
      event.id = 91;
      bundle.host.events = [event];
      bundle.host.executionWeatherEnabled = true;
      bundle.host.executionWeatherHint = 'storm';
      bundle.host.executionWeatherCurrentText = 'rain';
      bundle.host.executionWeatherScore = 42;
      bundle.host.executionWeatherSuggestions = [{} as WeatherSuggestion];
      Reflect.set(PreferenceManager as Object, 'getInstance', (): Object => preferenceManager as Object);

      // Act
      try {
        await bundle.service.setWeatherFeatureEnabled(false);
      } finally {
        Reflect.set(PreferenceManager as Object, 'getInstance', originalGetInstance);
      }

      // Assert
      expect(preferenceManager.setFeatureEnabledCalls.length).assertEqual(1);
      expect(bundle.scheduler.stopCalls).assertEqual(1);
      expect(bundle.host.weatherFeatureEnabled).assertFalse();
      expect(bundle.host.executionWeatherEnabled).assertFalse();
      expect(bundle.host.executionWeatherHint).assertEqual('');
      expect(bundle.host.executionWeatherScore).assertEqual(-1);
      expect(bundle.host.executionWeatherSuggestions.length).assertEqual(0);
      expect(bundle.host.events.length).assertEqual(1);
    });

    it('boundary: weather_service_should_refresh_preference_state_and_restart_scheduler_when_feature_enabled', 0, async () => {
      // Arrange
      const bundle = createWeatherBundleEJ();
      const preferenceManager = new PreferenceManagerMockForEJ();
      const originalGetInstance = Reflect.get(PreferenceManager as Object, 'getInstance') as () => Object;
      let refreshPlanningCalls = 0;
      preferenceManager.featureEnabled = true;
      preferenceManager.preference = {
        heatSensitivity: 2,
        rainSensitivity: 0,
        weatherRiskTolerance: 1
      };
      bundle.facade.policy.pollIntervalMs = 2_000;
      Reflect.set(PreferenceManager as Object, 'getInstance', (): Object => preferenceManager as Object);
      Reflect.set(bundle.service as Object, 'refreshPlanningWeather', async (): Promise<void> => {
        refreshPlanningCalls += 1;
      });

      // Act
      try {
        await bundle.service.setWeatherFeatureEnabled(true);
        await bundle.service.updateWeatherUserPreference({
          heatSensitivity: 2,
          rainSensitivity: 0,
          weatherRiskTolerance: 1
        });
      } finally {
        Reflect.set(PreferenceManager as Object, 'getInstance', originalGetInstance);
      }

      // Assert
      expect(preferenceManager.setFeatureEnabledCalls[0]).assertTrue();
      expect(preferenceManager.setPreferenceCalls.length).assertEqual(1);
      expect(bundle.host.weatherFeatureEnabled).assertTrue();
      expect(bundle.host.weatherUserPreference.heatSensitivity).assertEqual(2);
      expect(bundle.scheduler.startCalls > 0).assertTrue();
      expect(refreshPlanningCalls).assertEqual(1);
    });

    it('invalid: weather_service_reload_preference_should_fallback_and_clear_when_manager_throws', 0, async () => {
      // Arrange
      const bundle = createWeatherBundleEJ();
      const originalGetInstance = Reflect.get(PreferenceManager as Object, 'getInstance') as () => Object;
      bundle.host.weatherFeatureEnabled = false;
      bundle.host.executionWeatherHint = 'old_hint';
      Reflect.set(PreferenceManager as Object, 'getInstance', (): Object => new PreferenceManagerThrowingMockForEJ() as Object);

      // Act
      try {
        await bundle.service.reloadWeatherUserPreference();
      } finally {
        Reflect.set(PreferenceManager as Object, 'getInstance', originalGetInstance);
      }

      // Assert
      expect(bundle.host.weatherFeatureEnabled).assertTrue();
      expect(bundle.host.weatherUserPreference.heatSensitivity).assertEqual(1);
      expect(bundle.host.weatherUserPreference.rainSensitivity).assertEqual(1);
      expect(bundle.host.weatherUserPreference.weatherRiskTolerance).assertEqual(1);
    });

    it('combined: weather_service_coordinate_helpers_should_cover_base_empty_name_and_geocode_hit_paths', 0, async () => {
      // Arrange
      const bundle = createWeatherBundleEJ();
      const originalGetGeocode = Reflect.get(AmapService as Object, 'getGeocode') as (name: string) => Promise<Object | null>;
      Reflect.set(AmapService as Object, 'getGeocode', async (name: string): Promise<Object | null> => {
        if (name === 'Bund') {
          return new GeocodeResultForEJ() as Object;
        }
        return null;
      });

      // Act
      try {
        const base = await bundle.service.resolveCoordinatesForPlaceName('Base', 30.2, 120.1);
        const emptyName = await bundle.service.resolveCoordinatesForPlaceName('   ', undefined, undefined, 'add', 22.3, 113.9);
        const geocoded = await bundle.service.resolveCoordinatesForPlaceName('Bund', 0, 0);

        // Assert
        expect(bundle.service.isCoordinateMissingForWeather(0, 0)).assertTrue();
        expect(bundle.service.isValidCoordinate(31.24, 121.49)).assertTrue();
        expect(bundle.service.isExecutionWeatherStage()).assertTrue();
        expect(base.latitude).assertEqual(30.2);
        expect(base.longitude).assertEqual(120.1);
        expect(emptyName.latitude).assertEqual(22.3);
        expect(emptyName.longitude).assertEqual(113.9);
        expect(geocoded.latitude).assertEqual(31.24);
        expect(geocoded.longitude).assertEqual(121.49);
      } finally {
        Reflect.set(AmapService as Object, 'getGeocode', originalGetGeocode);
      }
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

    it('boundary: traffic_engine_drive_fetch_should_short_circuit_when_same_key_is_already_loading', 0, async () => {
      // Arrange
      const engine = resetTrafficEngineEJ();
      const mapService = new DriveMapServiceForEJ();
      const key = 'drive_loading_short_circuit';
      engine.cache.set(key, -1);
      Reflect.set(engine as Object, 'mapService', mapService as Object);

      // Act
      await engine.fetchAmapTrafficAsync(createLocationEJ('from'), createLocationEJ('to'), DriveStrategy.FASTEST, key);

      // Assert
      expect(mapService.driveCalls).assertEqual(0);
      expect(engine.cache.get(key)).assertEqual(-1);
    });

    it('normal: traffic_engine_drive_fetch_should_cache_duration_and_clear_transient_failure_after_success', 0, async () => {
      // Arrange
      const engine = resetTrafficEngineEJ();
      const mapService = new DriveMapServiceForEJ();
      const key = 'drive_success_cache';
      mapService.duration = 34;
      engine.markTransientFailure(key, 'stale_guard');
      Reflect.set(engine as Object, 'mapService', mapService as Object);

      // Act
      await engine.fetchAmapTrafficAsync(createLocationEJ('from'), createLocationEJ('to'), DriveStrategy.AVOID_CONGESTION, key);

      // Assert
      expect(mapService.driveCalls).assertEqual(1);
      expect(engine.cache.get(key)).assertEqual(34);
      expect(engine.transientFailureUntil.has(key)).assertFalse();
    });

    it('regression: traffic_engine_drive_fetch_should_delete_loading_cache_and_restore_transient_failure_after_exception', 0, async () => {
      // Arrange
      const engine = resetTrafficEngineEJ();
      const mapService = new DriveMapServiceForEJ();
      const key = 'drive_exception_guard';
      mapService.throwOnDrive = true;
      Reflect.set(engine as Object, 'mapService', mapService as Object);

      // Act
      await engine.fetchAmapTrafficAsync(createLocationEJ('from'), createLocationEJ('to'), DriveStrategy.ECONOMICAL, key);

      // Assert
      expect(mapService.driveCalls).assertEqual(1);
      expect(engine.cache.has(key)).assertFalse();
      expect((engine.transientFailureUntil.get(key) ?? 0) > Date.now()).assertTrue();
    });

    it('boundary: traffic_engine_multi_modal_fetch_should_mark_transient_when_service_missing', 0, async () => {
      // Arrange
      const engine = resetTrafficEngineEJ();
      const key = 'multi_modal_missing_service';

      // Act
      await engine.fetchMultiModalTrafficAsync(createLocationEJ('from'), createLocationEJ('to'), 0, key, '09:00');

      // Assert
      expect(engine.cache.has(key)).assertFalse();
      expect(engine.transientFailureUntil.has(key)).assertTrue();
    });

    it('conflict: traffic_engine_multi_modal_fetch_should_short_circuit_when_same_key_is_already_loading', 0, async () => {
      // Arrange
      const engine = resetTrafficEngineEJ();
      const mapService = new DriveMapServiceForEJ();
      const key = 'multi_modal_loading_short_circuit';
      engine.cache.set(key, -1);
      Reflect.set(engine as Object, 'mapService', mapService as Object);

      // Act
      await engine.fetchMultiModalTrafficAsync(createLocationEJ('from'), createLocationEJ('to'), 2, key, '10:30');

      // Assert
      expect(mapService.modeCalls).assertEqual(0);
      expect(engine.cache.get(key)).assertEqual(-1);
    });

    it('combined: traffic_engine_multi_modal_fetch_should_drop_non_positive_duration_and_clear_stale_guard', 0, async () => {
      // Arrange
      const engine = resetTrafficEngineEJ();
      const mapService = new DriveMapServiceForEJ();
      const key = 'multi_modal_non_positive_duration';
      mapService.duration = 0;
      engine.markTransientFailure(key, 'stale_guard');
      Reflect.set(engine as Object, 'mapService', mapService as Object);

      // Act
      await engine.fetchMultiModalTrafficAsync(createLocationEJ('from'), createLocationEJ('to'), 3, key, '11:15');

      // Assert
      expect(mapService.modeCalls).assertEqual(1);
      expect(engine.cache.has(key)).assertFalse();
      expect(engine.transientFailureUntil.has(key)).assertFalse();
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
