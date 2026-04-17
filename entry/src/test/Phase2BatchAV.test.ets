import { describe, it, expect } from '@ohos/hypium';
import { MapServiceImpl } from '../main/ets/model/acl/MapServiceImpl';
import { DriveStrategy, LocationInfo } from '../main/ets/model/interface/IMapService';
import { GeoCoordinate } from '../main/ets/infrastructure/services/AmapService';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { WeatherFacade } from '../main/ets/domain/services/WeatherFacade';
import { WeatherDomainService } from '../main/ets/domain/services/WeatherDomainService';
import { WeatherStageCoordinator } from '../main/ets/domain/services/WeatherStageCoordinator';
import { PlanStatus } from '../main/ets/domain/statemachine/PlanStatus';
import {
  GeoPointInput,
  PlanNodeWeatherBinding,
  WeatherCollabOptions,
  WeatherContext,
  WeatherContextBuildResult,
  WeatherSchedulePolicy,
  WeatherStageType,
  WeatherSuggestion,
  WeatherUserPreference
} from '../main/ets/domain/services/WeatherModels';
import { WeatherRefreshScheduler } from '../main/ets/domain/services/WeatherRefreshScheduler';
import {
  PlanWeatherConsumeInput,
  WeatherReminderCoordinator,
  WeatherReminderSubscriptionHandlers
} from '../main/ets/infrastructure/services/WeatherReminderCoordinator';
import { WeatherReminderPayload, WeatherReminderStore } from '../main/ets/common/utils/weather/WeatherReminderStore';

function buildLocationAV(name: string, latitude: number, longitude: number, address: string = ''): LocationInfo {
  return {
    name: name,
    address: address,
    latitude: latitude,
    longitude: longitude
  };
}

function createEventAV(id: number, name: string = `event_${id}`): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = name;
  event.status = 1;
  event.duration = 60;
  return event;
}

function createWeatherContextAV(stage: WeatherStageType = 'CONFIRMED'): WeatherContext {
  return {
    stage: stage,
    generatedAt: 1700000000000,
    bindings: [],
    routeSuitability: {
      routeScore: 88,
      riskTags: [],
      summaryText: 'ok_phase2_av'
    }
  };
}

function createBuildResultAV(
  stage: WeatherStageType = 'CONFIRMED',
  sourceEvents: EventEntity[] = []
): WeatherContextBuildResult {
  const eventMap: Map<number, PlanNodeWeatherBinding> = new Map<number, PlanNodeWeatherBinding>();
  return {
    context: createWeatherContextAV(stage),
    eventMap: eventMap,
    sourceEvents: sourceEvents
  };
}

function createSchedulePolicyAV(stage: WeatherStageType, pollIntervalMs: number): WeatherSchedulePolicy {
  return {
    stage: stage,
    pollIntervalMs: pollIntervalMs,
    allowLocationTrigger: stage === 'READY' || stage === 'IN_PROGRESS' || stage === 'PAUSED',
    allowManualBypass: true,
    forceRefreshOnEnter: stage !== 'PLANNING'
  };
}

function createSuggestionAV(id: string): WeatherSuggestion {
  return {
    suggestionId: id,
    level: 'NOTICE',
    triggerType: 'RAIN',
    actionType: 'PREPARE',
    title: 'weather_title',
    message: 'weather_message',
    relatedNodeIds: ['1'],
    createdAt: 1700000000100,
    reason: 'rain_reason',
    expectedBenefit: 'benefit',
    canRollback: true,
    cooldownKey: `cooldown_${id}`,
    expiresAt: 1700003600000
  };
}

function createPayloadAV(seq: number, planId: number): WeatherReminderPayload {
  return {
    seq: seq,
    planId: planId,
    level: 'NOTICE',
    title: 'weather_title',
    message: 'weather_message',
    relatedNodeIds: ['1'],
    createdAt: 1700000000200
  };
}

class FakeRouteCostAV {
  private readonly duration: number;

  constructor(duration: number) {
    this.duration = duration;
  }

  getDuration(): number {
    return this.duration;
  }
}

class FakeRoutePathAV {
  private readonly duration: number;
  private readonly costDuration: number;

  constructor(duration: number, costDuration: number = -1) {
    this.duration = duration;
    this.costDuration = costDuration;
  }

  getDuration(): number {
    return this.duration;
  }

  getCost(): FakeRouteCostAV | null {
    if (this.costDuration < 0) {
      return null;
    }
    return new FakeRouteCostAV(this.costDuration);
  }
}

class FakeRouteResultAV {
  private readonly paths: FakeRoutePathAV[];

  constructor(paths: FakeRoutePathAV[]) {
    this.paths = paths;
  }

  getPaths(): FakeRoutePathAV[] {
    return this.paths;
  }
}

class FakeRouteSearchAV {
  public rideCalls: number = 0;
  public driveCalls: number = 0;
  public rideResult: FakeRouteResultAV = new FakeRouteResultAV([]);
  public driveResult: FakeRouteResultAV = new FakeRouteResultAV([]);
  public driveError: Error | null = null;

  public async calculateRideRoute(_query: Object): Promise<FakeRouteResultAV> {
    this.rideCalls += 1;
    return this.rideResult;
  }

  public async calculateDriveRoute(_query: Object): Promise<FakeRouteResultAV> {
    this.driveCalls += 1;
    if (this.driveError) {
      throw this.driveError;
    }
    return this.driveResult;
  }
}

class FakeWeatherStageCoordinatorAV extends WeatherStageCoordinator {
  public resolveStageCalls: number = 0;
  public resolveSchedulePolicyCalls: number = 0;
  public throwOnResolveStage: boolean = false;
  public throwOnResolveSchedulePolicy: boolean = false;
  public lastStatus: PlanStatus = PlanStatus.DRAFT;
  public lastEventsLength: number = -1;
  public lastRuntimeState: string = '';
  public lastScheduleStage: WeatherStageType = 'PLANNING';
  public stageResult: WeatherStageType = 'READY';
  public policyResult: WeatherSchedulePolicy = createSchedulePolicyAV('READY', 15000);

  public resolveStage(
    status: PlanStatus,
    events: EventEntity[],
    runtimeState?: 'IDLE' | 'READY' | 'ACTIVE' | 'PAUSED' | 'GAP'
  ): WeatherStageType {
    this.resolveStageCalls += 1;
    this.lastStatus = status;
    this.lastEventsLength = events.length;
    this.lastRuntimeState = runtimeState ?? '';
    if (this.throwOnResolveStage) {
      throw new Error('resolve_stage_failed_av');
    }
    return this.stageResult;
  }

  public resolveSchedulePolicy(stage: WeatherStageType): WeatherSchedulePolicy {
    this.resolveSchedulePolicyCalls += 1;
    this.lastScheduleStage = stage;
    if (this.throwOnResolveSchedulePolicy) {
      throw new Error('resolve_schedule_policy_failed_av');
    }
    return this.policyResult;
  }
}

class FakeWeatherDomainServiceAV extends WeatherDomainService {
  public planningCalls: number = 0;
  public executionCalls: number = 0;
  public adjustmentCalls: number = 0;
  public promptCalls: number = 0;
  public throwOnPlanning: boolean = false;
  public throwOnExecution: boolean = false;
  public throwOnAdjustments: boolean = false;
  public throwOnPrompt: boolean = false;
  public lastPlanningEventsLength: number = -1;
  public lastPlanningStage: string = '';
  public lastExecutionEventsLength: number = -1;
  public lastExecutionForceRefresh: boolean = false;
  public lastExecutionStage: string = '';
  public lastExecutionLocation: GeoPointInput | null = null;
  public lastAdjustmentPlanId: number = -1;
  public lastAdjustmentFutureNodesLength: number = -1;
  public lastPromptStage: string = '';
  public planningResult: WeatherContextBuildResult = createBuildResultAV('CONFIRMED');
  public executionResult: WeatherContextBuildResult = createBuildResultAV('IN_PROGRESS');
  public adjustmentsResult: WeatherSuggestion[] = [createSuggestionAV('adjust_av')];
  public promptResult: string = 'prompt_summary_av';

  public async buildPlanningContext(
    events: EventEntity[],
    _preference?: WeatherUserPreference,
    _options?: WeatherCollabOptions,
    stage?: WeatherStageType
  ): Promise<WeatherContextBuildResult> {
    this.planningCalls += 1;
    this.lastPlanningEventsLength = events.length;
    this.lastPlanningStage = stage ?? '';
    if (this.throwOnPlanning) {
      throw new Error('planning_context_failed_av');
    }
    return this.planningResult;
  }

  public async buildExecutionContext(
    events: EventEntity[],
    currentLocation?: GeoPointInput,
    forceRefresh: boolean = false,
    _preference?: WeatherUserPreference,
    _options?: WeatherCollabOptions,
    stage?: WeatherStageType
  ): Promise<WeatherContextBuildResult> {
    this.executionCalls += 1;
    this.lastExecutionEventsLength = events.length;
    this.lastExecutionForceRefresh = forceRefresh;
    this.lastExecutionStage = stage ?? '';
    this.lastExecutionLocation = currentLocation ?? null;
    if (this.throwOnExecution) {
      throw new Error('execution_context_failed_av');
    }
    return this.executionResult;
  }

  public buildExecutionAdjustments(
    planId: number,
    _context: WeatherContext,
    futureNodes: EventEntity[],
    _preference?: WeatherUserPreference
  ): WeatherSuggestion[] {
    this.adjustmentCalls += 1;
    this.lastAdjustmentPlanId = planId;
    this.lastAdjustmentFutureNodesLength = futureNodes.length;
    if (this.throwOnAdjustments) {
      throw new Error('execution_adjustments_failed_av');
    }
    return this.adjustmentsResult;
  }

  public buildPromptSummary(context: WeatherContext, _preference?: WeatherUserPreference): string {
    this.promptCalls += 1;
    this.lastPromptStage = context.stage;
    if (this.throwOnPrompt) {
      throw new Error('prompt_summary_failed_av');
    }
    return this.promptResult;
  }
}

class IntervalHooksAV {
  private readonly originSetInterval: Object;
  private readonly originClearInterval: Object;
  public clearCalls: number[] = [];
  public intervals: Map<number, number> = new Map<number, number>();
  public callbacks: Map<number, () => void> = new Map<number, () => void>();
  private nextId: number = 1;

  constructor() {
    this.originSetInterval = Reflect.get(globalThis, 'setInterval') as Object;
    this.originClearInterval = Reflect.get(globalThis, 'clearInterval') as Object;
  }

  public install(): void {
    Reflect.set(globalThis, 'setInterval', (callback: () => void, intervalMs: number): number => {
      const timerId = this.nextId;
      this.nextId += 1;
      this.callbacks.set(timerId, callback);
      this.intervals.set(timerId, intervalMs);
      return timerId;
    });
    Reflect.set(globalThis, 'clearInterval', (timerId: number): void => {
      this.clearCalls.push(timerId);
      this.callbacks.delete(timerId);
      this.intervals.delete(timerId);
    });
  }

  public trigger(timerId: number): void {
    const callback = this.callbacks.get(timerId);
    callback?.();
  }

  public latestTimerId(): number {
    let latest = 0;
    this.intervals.forEach((_value: number, key: number) => {
      if (key > latest) {
        latest = key;
      }
    });
    return latest;
  }

  public restore(): void {
    Reflect.set(globalThis, 'setInterval', this.originSetInterval);
    Reflect.set(globalThis, 'clearInterval', this.originClearInterval);
  }
}

class PlanTransitionEventAV {
  toStatus: PlanStatus;

  constructor(toStatus: PlanStatus) {
    this.toStatus = toStatus;
  }
}

class PlanStatusSnapshotAV {
  status: PlanStatus;

  constructor(status: PlanStatus) {
    this.status = status;
  }
}

class FakePlanStateMachineAV {
  public status: PlanStatus = PlanStatus.READY;
  public subscribeCalls: number = 0;
  public unsubscribeCalls: number = 0;
  private transitionListener: ((event: PlanTransitionEventAV) => void) | null = null;

  public subscribePlanTransition(_planId: string, listener: (event: PlanTransitionEventAV) => void): () => void {
    this.subscribeCalls += 1;
    this.transitionListener = listener;
    return () => {
      this.unsubscribeCalls += 1;
    };
  }

  public getPlanStatus(_planId: string): PlanStatusSnapshotAV {
    return new PlanStatusSnapshotAV(this.status);
  }

  public emit(toStatus: PlanStatus): void {
    this.transitionListener?.(new PlanTransitionEventAV(toStatus));
  }
}

class WeatherReminderStoreHooksAV {
  private readonly originRead: Object;
  private readonly originClear: Object;

  constructor() {
    this.originRead = Reflect.get(WeatherReminderStore, 'readPayload') as Object;
    this.originClear = Reflect.get(WeatherReminderStore, 'clearPayload') as Object;
  }

  public setRead(fn: (planId?: number) => WeatherReminderPayload | null): void {
    Reflect.set(WeatherReminderStore, 'readPayload', fn);
  }

  public setClear(fn: (planId?: number) => void): void {
    Reflect.set(WeatherReminderStore, 'clearPayload', fn);
  }

  public restore(): void {
    Reflect.set(WeatherReminderStore, 'readPayload', this.originRead);
    Reflect.set(WeatherReminderStore, 'clearPayload', this.originClear);
  }
}

function resetWeatherReminderCoordinatorAV(): void {
  Reflect.set(WeatherReminderCoordinator as Object, 'instance', null);
}

export default function phase2BatchAVTest() {
  describe('phase2BatchAVTest_map_service_impl', () => {
    it('normal: get_duration_by_mode_should_resolve_geocode_and_round_minutes', 0, async () => {
      // Arrange
      const search = new FakeRouteSearchAV();
      search.rideResult = new FakeRouteResultAV([new FakeRoutePathAV(125)]);
      const service = new MapServiceImpl(null);
      Reflect.set(service as Object, 'routeSearch', search as Object);
      const origin = buildLocationAV('origin', 0, 0, 'origin_address_av');
      const destination = buildLocationAV('destination', 0, 0, 'destination_address_av');
      const geocodeKeywords: string[] = [];
      MapServiceImpl.setTestHooks({
        routeApiEnabledResolver: async (): Promise<boolean> => true,
        geocodeResolver: async (address: string): Promise<GeoCoordinate | null> => {
          geocodeKeywords.push(address);
          if (address === 'origin_address_av') {
            return new GeoCoordinate(30.10, 120.10);
          }
          return new GeoCoordinate(30.20, 120.20);
        }
      });
      // Act
      const minutes = await service.getDurationByMode(origin, destination, 1, '08:00');
      // Assert
      MapServiceImpl.setTestHooks(null);
      expect(minutes).assertEqual(3);
      expect(search.rideCalls).assertEqual(1);
      expect(geocodeKeywords.length).assertEqual(2);
      expect(Math.round(origin.latitude ?? 0)).assertEqual(30);
      expect(Math.round(destination.longitude ?? 0)).assertEqual(120);
    });

    it('boundary: get_duration_by_mode_should_return_minus_five_when_walk_distance_too_far', 0, async () => {
      // Arrange
      const search = new FakeRouteSearchAV();
      const service = new MapServiceImpl(null);
      Reflect.set(service as Object, 'routeSearch', search as Object);
      MapServiceImpl.setTestHooks({
        routeApiEnabledResolver: async (): Promise<boolean> => true
      });
      // Act
      const minutes = await service.getDurationByMode(
        buildLocationAV('far_a', 39.9042, 116.4074),
        buildLocationAV('far_b', 39.9742, 116.5074),
        0,
        '09:30'
      );
      // Assert
      MapServiceImpl.setTestHooks(null);
      expect(minutes).assertEqual(-5);
    });

    it('invalid: get_duration_by_mode_should_fallback_when_hook_returns_invalid_seconds', 0, async () => {
      // Arrange
      const service = new MapServiceImpl(null);
      MapServiceImpl.setTestHooks({
        routeApiEnabledResolver: async (): Promise<boolean> => true,
        modeSecondsResolver: async (): Promise<number> => 0
      });
      // Act
      const minutes = await service.getDurationByMode(
        buildLocationAV('a', 31.23, 121.47),
        buildLocationAV('b', 31.22, 121.49),
        2,
        '10:00'
      );
      // Assert
      MapServiceImpl.setTestHooks(null);
      expect(minutes).assertEqual(60);
    });

    it('normal: get_drive_duration_should_return_rounded_minutes_for_drive_path', 0, async () => {
      // Arrange
      const search = new FakeRouteSearchAV();
      search.driveResult = new FakeRouteResultAV([new FakeRoutePathAV(180)]);
      const service = new MapServiceImpl(null);
      Reflect.set(service as Object, 'routeSearch', search as Object);
      MapServiceImpl.setTestHooks({
        routeApiEnabledResolver: async (): Promise<boolean> => true
      });
      // Act
      const minutes = await service.getDriveDuration(
        buildLocationAV('start', 31.23, 121.47),
        buildLocationAV('end', 31.22, 121.49),
        DriveStrategy.FASTEST
      );
      // Assert
      MapServiceImpl.setTestHooks(null);
      expect(minutes).assertEqual(3);
      expect(search.driveCalls).assertEqual(1);
    });

    it('boundary: get_drive_duration_should_use_cost_duration_when_path_duration_is_zero', 0, async () => {
      // Arrange
      const search = new FakeRouteSearchAV();
      search.driveResult = new FakeRouteResultAV([new FakeRoutePathAV(0, 61)]);
      const service = new MapServiceImpl(null);
      Reflect.set(service as Object, 'routeSearch', search as Object);
      MapServiceImpl.setTestHooks({
        routeApiEnabledResolver: async (): Promise<boolean> => true
      });
      // Act
      const minutes = await service.getDriveDuration(
        buildLocationAV('start', 31.24, 121.40),
        buildLocationAV('end', 31.25, 121.50),
        DriveStrategy.ECONOMICAL
      );
      // Assert
      MapServiceImpl.setTestHooks(null);
      expect(minutes).assertEqual(2);
    });

    it('invalid: get_drive_duration_should_fallback_when_route_search_throws', 0, async () => {
      // Arrange
      const search = new FakeRouteSearchAV();
      search.driveError = new Error('drive_failed_av');
      const service = new MapServiceImpl(null);
      Reflect.set(service as Object, 'routeSearch', search as Object);
      MapServiceImpl.setTestHooks({
        routeApiEnabledResolver: async (): Promise<boolean> => true
      });
      // Act
      const minutes = await service.getDriveDuration(
        buildLocationAV('start', 31.21, 121.41),
        buildLocationAV('end', 31.22, 121.42),
        DriveStrategy.AVOID_CONGESTION
      );
      // Assert
      MapServiceImpl.setTestHooks(null);
      expect(minutes).assertEqual(60);
    });

    it('normal: get_location_info_should_return_empty_array_for_regular_keyword', 0, async () => {
      // Arrange
      const service = new MapServiceImpl(null);
      // Act
      const result = await service.getLocationInfo('museum');
      // Assert
      expect(result.length).assertEqual(0);
    });

    it('boundary: get_location_info_should_return_empty_array_for_blank_keyword', 0, async () => {
      // Arrange
      const service = new MapServiceImpl(null);
      // Act
      const result = await service.getLocationInfo('');
      // Assert
      expect(result.length).assertEqual(0);
    });

    it('invalid: get_location_info_should_return_empty_array_for_whitespace_keyword', 0, async () => {
      // Arrange
      const service = new MapServiceImpl(null);
      // Act
      const result = await service.getLocationInfo('   ');
      // Assert
      expect(result.length).assertEqual(0);
    });

    it('normal: calculate_commute_should_return_default_minutes_for_regular_places', 0, async () => {
      // Arrange
      const service = new MapServiceImpl(null);
      // Act
      const minutes = await service.calculateCommute('hotel', 'museum');
      // Assert
      expect(minutes).assertEqual(30);
    });

    it('boundary: calculate_commute_should_return_default_minutes_for_blank_places', 0, async () => {
      // Arrange
      const service = new MapServiceImpl(null);
      // Act
      const minutes = await service.calculateCommute('', '');
      // Assert
      expect(minutes).assertEqual(30);
    });

    it('invalid: calculate_commute_should_return_default_minutes_for_symbolic_input', 0, async () => {
      // Arrange
      const service = new MapServiceImpl(null);
      // Act
      const minutes = await service.calculateCommute('@@@', '###');
      // Assert
      expect(minutes).assertEqual(30);
    });
  });

  describe('phase2BatchAVTest_weather_facade', () => {
    it('normal: resolve_stage_should_delegate_to_stage_coordinator', 0, () => {
      // Arrange
      const stageCoordinator = new FakeWeatherStageCoordinatorAV();
      stageCoordinator.stageResult = 'IN_PROGRESS';
      const facade = new WeatherFacade(new FakeWeatherDomainServiceAV(), stageCoordinator);
      const events = [createEventAV(1), createEventAV(2)];
      // Act
      const stage = facade.resolveStage(PlanStatus.READY, events, 'ACTIVE');
      // Assert
      expect(stage).assertEqual('IN_PROGRESS');
      expect(stageCoordinator.resolveStageCalls).assertEqual(1);
      expect(stageCoordinator.lastEventsLength).assertEqual(2);
      expect(stageCoordinator.lastRuntimeState).assertEqual('ACTIVE');
    });

    it('boundary: resolve_stage_should_support_missing_runtime_state', 0, () => {
      // Arrange
      const stageCoordinator = new FakeWeatherStageCoordinatorAV();
      stageCoordinator.stageResult = 'CONFIRMED';
      const facade = new WeatherFacade(new FakeWeatherDomainServiceAV(), stageCoordinator);
      // Act
      const stage = facade.resolveStage(PlanStatus.CONFIRMED, []);
      // Assert
      expect(stage).assertEqual('CONFIRMED');
      expect(stageCoordinator.lastRuntimeState).assertEqual('');
    });

    it('invalid: resolve_stage_should_bubble_stage_coordinator_error', 0, () => {
      // Arrange
      const stageCoordinator = new FakeWeatherStageCoordinatorAV();
      stageCoordinator.throwOnResolveStage = true;
      const facade = new WeatherFacade(new FakeWeatherDomainServiceAV(), stageCoordinator);
      let message = '';
      // Act
      try {
        facade.resolveStage(PlanStatus.DRAFT, []);
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }
      // Assert
      expect(message).assertEqual('resolve_stage_failed_av');
    });

    it('normal: resolve_schedule_policy_should_delegate_stage_to_coordinator', 0, () => {
      // Arrange
      const stageCoordinator = new FakeWeatherStageCoordinatorAV();
      stageCoordinator.policyResult = createSchedulePolicyAV('READY', 120000);
      const facade = new WeatherFacade(new FakeWeatherDomainServiceAV(), stageCoordinator);
      // Act
      const policy = facade.resolveSchedulePolicy('READY');
      // Assert
      expect(policy.stage).assertEqual('READY');
      expect(policy.pollIntervalMs).assertEqual(120000);
      expect(stageCoordinator.resolveSchedulePolicyCalls).assertEqual(1);
    });

    it('boundary: resolve_schedule_policy_should_support_planning_stage', 0, () => {
      // Arrange
      const stageCoordinator = new FakeWeatherStageCoordinatorAV();
      stageCoordinator.policyResult = createSchedulePolicyAV('PLANNING', 0);
      const facade = new WeatherFacade(new FakeWeatherDomainServiceAV(), stageCoordinator);
      // Act
      const policy = facade.resolveSchedulePolicy('PLANNING');
      // Assert
      expect(policy.stage).assertEqual('PLANNING');
      expect(stageCoordinator.lastScheduleStage).assertEqual('PLANNING');
    });

    it('invalid: resolve_schedule_policy_should_bubble_coordinator_error', 0, () => {
      // Arrange
      const stageCoordinator = new FakeWeatherStageCoordinatorAV();
      stageCoordinator.throwOnResolveSchedulePolicy = true;
      const facade = new WeatherFacade(new FakeWeatherDomainServiceAV(), stageCoordinator);
      let message = '';
      // Act
      try {
        facade.resolveSchedulePolicy('PAUSED');
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }
      // Assert
      expect(message).assertEqual('resolve_schedule_policy_failed_av');
    });

    it('normal: build_planning_context_should_delegate_events_and_stage', 0, async () => {
      // Arrange
      const domainService = new FakeWeatherDomainServiceAV();
      domainService.planningResult = createBuildResultAV('CONFIRMED', [createEventAV(11)]);
      const facade = new WeatherFacade(domainService, new FakeWeatherStageCoordinatorAV());
      // Act
      const result = await facade.buildPlanningContext([createEventAV(11)], undefined, undefined, 'CONFIRMED');
      // Assert
      expect(result.context.stage).assertEqual('CONFIRMED');
      expect(domainService.planningCalls).assertEqual(1);
      expect(domainService.lastPlanningEventsLength).assertEqual(1);
      expect(domainService.lastPlanningStage).assertEqual('CONFIRMED');
    });

    it('boundary: build_planning_context_should_support_empty_events', 0, async () => {
      // Arrange
      const domainService = new FakeWeatherDomainServiceAV();
      const facade = new WeatherFacade(domainService, new FakeWeatherStageCoordinatorAV());
      // Act
      const result = await facade.buildPlanningContext([]);
      // Assert
      expect(result.sourceEvents.length).assertEqual(0);
      expect(domainService.lastPlanningEventsLength).assertEqual(0);
    });

    it('invalid: build_planning_context_should_bubble_domain_error', 0, async () => {
      // Arrange
      const domainService = new FakeWeatherDomainServiceAV();
      domainService.throwOnPlanning = true;
      const facade = new WeatherFacade(domainService, new FakeWeatherStageCoordinatorAV());
      let message = '';
      // Act
      try {
        await facade.buildPlanningContext([createEventAV(12)]);
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }
      // Assert
      expect(message).assertEqual('planning_context_failed_av');
    });

    it('normal: build_execution_context_should_delegate_location_and_force_refresh', 0, async () => {
      // Arrange
      const domainService = new FakeWeatherDomainServiceAV();
      domainService.executionResult = createBuildResultAV('IN_PROGRESS');
      const facade = new WeatherFacade(domainService, new FakeWeatherStageCoordinatorAV());
      const currentLocation: GeoPointInput = { latitude: 31.23, longitude: 121.47 };
      // Act
      const result = await facade.buildExecutionContext([createEventAV(21)], currentLocation, true, undefined, undefined, 'IN_PROGRESS');
      // Assert
      expect(result.context.stage).assertEqual('IN_PROGRESS');
      expect(domainService.executionCalls).assertEqual(1);
      expect(domainService.lastExecutionForceRefresh).assertTrue();
      expect(domainService.lastExecutionLocation?.latitude ?? 0).assertEqual(31.23);
      expect(domainService.lastExecutionStage).assertEqual('IN_PROGRESS');
    });

    it('boundary: build_execution_context_should_keep_default_force_refresh_false', 0, async () => {
      // Arrange
      const domainService = new FakeWeatherDomainServiceAV();
      const facade = new WeatherFacade(domainService, new FakeWeatherStageCoordinatorAV());
      // Act
      const result = await facade.buildExecutionContext([]);
      // Assert
      expect(result.context.stage).assertEqual('IN_PROGRESS');
      expect(domainService.lastExecutionForceRefresh).assertFalse();
      expect(domainService.lastExecutionEventsLength).assertEqual(0);
    });

    it('invalid: build_execution_context_should_bubble_domain_error', 0, async () => {
      // Arrange
      const domainService = new FakeWeatherDomainServiceAV();
      domainService.throwOnExecution = true;
      const facade = new WeatherFacade(domainService, new FakeWeatherStageCoordinatorAV());
      let message = '';
      // Act
      try {
        await facade.buildExecutionContext([createEventAV(22)]);
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }
      // Assert
      expect(message).assertEqual('execution_context_failed_av');
    });

    it('normal: build_execution_adjustments_should_delegate_plan_and_future_nodes', 0, () => {
      // Arrange
      const domainService = new FakeWeatherDomainServiceAV();
      domainService.adjustmentsResult = [createSuggestionAV('adjustment_one_av')];
      const facade = new WeatherFacade(domainService, new FakeWeatherStageCoordinatorAV());
      // Act
      const suggestions = facade.buildExecutionAdjustments(301, createWeatherContextAV('IN_PROGRESS'), [createEventAV(31), createEventAV(32)]);
      // Assert
      expect(suggestions.length).assertEqual(1);
      expect(domainService.adjustmentCalls).assertEqual(1);
      expect(domainService.lastAdjustmentPlanId).assertEqual(301);
      expect(domainService.lastAdjustmentFutureNodesLength).assertEqual(2);
    });

    it('boundary: build_execution_adjustments_should_support_empty_future_nodes', 0, () => {
      // Arrange
      const domainService = new FakeWeatherDomainServiceAV();
      domainService.adjustmentsResult = [];
      const facade = new WeatherFacade(domainService, new FakeWeatherStageCoordinatorAV());
      // Act
      const suggestions = facade.buildExecutionAdjustments(0, createWeatherContextAV('READY'), []);
      // Assert
      expect(suggestions.length).assertEqual(0);
      expect(domainService.lastAdjustmentFutureNodesLength).assertEqual(0);
    });

    it('invalid: build_execution_adjustments_should_bubble_domain_error', 0, () => {
      // Arrange
      const domainService = new FakeWeatherDomainServiceAV();
      domainService.throwOnAdjustments = true;
      const facade = new WeatherFacade(domainService, new FakeWeatherStageCoordinatorAV());
      let message = '';
      // Act
      try {
        facade.buildExecutionAdjustments(302, createWeatherContextAV('PAUSED'), [createEventAV(33)]);
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }
      // Assert
      expect(message).assertEqual('execution_adjustments_failed_av');
    });

    it('normal: build_prompt_summary_should_delegate_context_to_domain_service', 0, () => {
      // Arrange
      const domainService = new FakeWeatherDomainServiceAV();
      domainService.promptResult = 'prompt_ok_av';
      const facade = new WeatherFacade(domainService, new FakeWeatherStageCoordinatorAV());
      // Act
      const summary = facade.buildPromptSummary(createWeatherContextAV('CONFIRMED'));
      // Assert
      expect(summary).assertEqual('prompt_ok_av');
      expect(domainService.promptCalls).assertEqual(1);
      expect(domainService.lastPromptStage).assertEqual('CONFIRMED');
    });

    it('boundary: build_prompt_summary_should_support_optional_preference', 0, () => {
      // Arrange
      const domainService = new FakeWeatherDomainServiceAV();
      const facade = new WeatherFacade(domainService, new FakeWeatherStageCoordinatorAV());
      const preference: WeatherUserPreference = {
        heatSensitivity: 2,
        rainSensitivity: 1,
        weatherRiskTolerance: 0
      };
      // Act
      const summary = facade.buildPromptSummary(createWeatherContextAV('READY'), preference);
      // Assert
      expect(summary).assertEqual('prompt_summary_av');
    });

    it('invalid: build_prompt_summary_should_bubble_domain_error', 0, () => {
      // Arrange
      const domainService = new FakeWeatherDomainServiceAV();
      domainService.throwOnPrompt = true;
      const facade = new WeatherFacade(domainService, new FakeWeatherStageCoordinatorAV());
      let message = '';
      // Act
      try {
        facade.buildPromptSummary(createWeatherContextAV('PAUSED'));
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }
      // Assert
      expect(message).assertEqual('prompt_summary_failed_av');
    });
  });

  describe('phase2BatchAVTest_weather_refresh_scheduler', () => {
    it('normal: start_should_register_timer_and_callback_should_run', 0, () => {
      // Arrange
      const hooks = new IntervalHooksAV();
      hooks.install();
      const scheduler = new WeatherRefreshScheduler();
      let called = 0;
      // Act
      scheduler.start(5000, (): void => {
        called += 1;
      });
      hooks.trigger(hooks.latestTimerId());
      // Assert
      hooks.restore();
      expect(scheduler.isRunning()).assertTrue();
      expect(called).assertEqual(1);
    });

    it('boundary: start_should_clear_previous_timer_before_restarting', 0, () => {
      // Arrange
      const hooks = new IntervalHooksAV();
      hooks.install();
      const scheduler = new WeatherRefreshScheduler();
      // Act
      scheduler.start(1000, (): void => {});
      const firstTimerId = hooks.latestTimerId();
      scheduler.start(2000, (): void => {});
      const secondTimerId = hooks.latestTimerId();
      // Assert
      hooks.restore();
      expect(firstTimerId < secondTimerId).assertTrue();
      expect(hooks.clearCalls.length).assertEqual(1);
      expect(hooks.clearCalls[0]).assertEqual(firstTimerId);
    });

    it('invalid: start_should_ignore_non_positive_interval', 0, () => {
      // Arrange
      const hooks = new IntervalHooksAV();
      hooks.install();
      const scheduler = new WeatherRefreshScheduler();
      // Act
      scheduler.start(0, (): void => {});
      // Assert
      hooks.restore();
      expect(scheduler.isRunning()).assertFalse();
      expect(hooks.intervals.size).assertEqual(0);
    });

    it('normal: stop_should_clear_active_timer', 0, () => {
      // Arrange
      const hooks = new IntervalHooksAV();
      hooks.install();
      const scheduler = new WeatherRefreshScheduler();
      scheduler.start(1000, (): void => {});
      const timerId = hooks.latestTimerId();
      // Act
      scheduler.stop();
      // Assert
      hooks.restore();
      expect(hooks.clearCalls.length).assertEqual(1);
      expect(hooks.clearCalls[0]).assertEqual(timerId);
      expect(scheduler.isRunning()).assertFalse();
    });

    it('boundary: stop_should_be_safe_when_called_twice', 0, () => {
      // Arrange
      const hooks = new IntervalHooksAV();
      hooks.install();
      const scheduler = new WeatherRefreshScheduler();
      scheduler.start(1000, (): void => {});
      // Act
      scheduler.stop();
      scheduler.stop();
      // Assert
      hooks.restore();
      expect(hooks.clearCalls.length).assertEqual(1);
      expect(scheduler.isRunning()).assertFalse();
    });

    it('invalid: stop_should_ignore_missing_timer', 0, () => {
      // Arrange
      const hooks = new IntervalHooksAV();
      hooks.install();
      const scheduler = new WeatherRefreshScheduler();
      // Act
      scheduler.stop();
      // Assert
      hooks.restore();
      expect(hooks.clearCalls.length).assertEqual(0);
      expect(scheduler.isRunning()).assertFalse();
    });

    it('normal: is_running_should_return_true_after_start', 0, () => {
      // Arrange
      const hooks = new IntervalHooksAV();
      hooks.install();
      const scheduler = new WeatherRefreshScheduler();
      // Act
      scheduler.start(2000, (): void => {});
      const running = scheduler.isRunning();
      // Assert
      hooks.restore();
      expect(running).assertTrue();
    });

    it('boundary: is_running_should_return_false_after_stop', 0, () => {
      // Arrange
      const hooks = new IntervalHooksAV();
      hooks.install();
      const scheduler = new WeatherRefreshScheduler();
      scheduler.start(2000, (): void => {});
      scheduler.stop();
      // Act
      const running = scheduler.isRunning();
      // Assert
      hooks.restore();
      expect(running).assertFalse();
    });

    it('invalid: is_running_should_stay_false_after_invalid_start', 0, () => {
      // Arrange
      const hooks = new IntervalHooksAV();
      hooks.install();
      const scheduler = new WeatherRefreshScheduler();
      // Act
      scheduler.start(Number.NaN, (): void => {});
      const running = scheduler.isRunning();
      // Assert
      hooks.restore();
      expect(running).assertFalse();
    });
  });

  describe('phase2BatchAVTest_weather_reminder_coordinator', () => {
    it('normal: get_instance_should_return_same_singleton', 0, () => {
      // Arrange
      resetWeatherReminderCoordinatorAV();
      // Act
      const first = WeatherReminderCoordinator.getInstance();
      const second = WeatherReminderCoordinator.getInstance();
      // Assert
      resetWeatherReminderCoordinatorAV();
      expect(first === second).assertTrue();
    });

    it('boundary: get_instance_should_create_new_object_after_reset', 0, () => {
      // Arrange
      resetWeatherReminderCoordinatorAV();
      const first = WeatherReminderCoordinator.getInstance();
      resetWeatherReminderCoordinatorAV();
      // Act
      const second = WeatherReminderCoordinator.getInstance();
      // Assert
      resetWeatherReminderCoordinatorAV();
      expect(first === second).assertFalse();
    });

    it('invalid: get_instance_should_return_existing_polluted_instance', 0, () => {
      // Arrange
      const polluted = WeatherReminderCoordinator.getInstance();
      Reflect.set(WeatherReminderCoordinator as Object, 'instance', polluted);
      // Act
      const current = WeatherReminderCoordinator.getInstance();
      // Assert
      resetWeatherReminderCoordinatorAV();
      expect(current === polluted).assertTrue();
    });

    it('normal: subscribe_plan_should_show_payload_once_and_cleanup_on_unsubscribe', 0, () => {
      // Arrange
      resetWeatherReminderCoordinatorAV();
      const timerHooks = new IntervalHooksAV();
      timerHooks.install();
      const storeHooks = new WeatherReminderStoreHooksAV();
      const machine = new FakePlanStateMachineAV();
      storeHooks.setRead((planId?: number): WeatherReminderPayload | null => createPayloadAV(1, planId ?? 101));
      storeHooks.setClear((_planId?: number): void => {});
      const coordinator = WeatherReminderCoordinator.getInstance();
      Reflect.set(coordinator as Object, 'planStateMachine', machine);
      let showCount = 0;
      const handlers: WeatherReminderSubscriptionHandlers = {
        isDialogOpen: (): boolean => false,
        onShow: (_payload: WeatherReminderPayload): void => {
          showCount += 1;
        },
        pollIntervalMs: 500
      };
      // Act
      const unsubscribe = coordinator.subscribePlan(101, handlers);
      unsubscribe();
      // Assert
      storeHooks.restore();
      timerHooks.restore();
      resetWeatherReminderCoordinatorAV();
      expect(showCount).assertEqual(1);
      expect(machine.subscribeCalls).assertEqual(1);
      expect(machine.unsubscribeCalls).assertEqual(1);
      expect(timerHooks.clearCalls.length).assertEqual(1);
    });

    it('boundary: subscribe_plan_should_clear_and_notify_when_terminal_status_arrives', 0, () => {
      // Arrange
      resetWeatherReminderCoordinatorAV();
      const timerHooks = new IntervalHooksAV();
      timerHooks.install();
      const storeHooks = new WeatherReminderStoreHooksAV();
      const machine = new FakePlanStateMachineAV();
      let clearedPlanId = 0;
      let clearCount = 0;
      let onClearCount = 0;
      storeHooks.setRead((_planId?: number): WeatherReminderPayload | null => createPayloadAV(1, 202));
      storeHooks.setClear((planId?: number): void => {
        clearCount += 1;
        clearedPlanId = planId ?? 0;
      });
      const coordinator = WeatherReminderCoordinator.getInstance();
      Reflect.set(coordinator as Object, 'planStateMachine', machine);
      const handlers: WeatherReminderSubscriptionHandlers = {
        isDialogOpen: (): boolean => true,
        onShow: (_payload: WeatherReminderPayload): void => {},
        onClear: (): void => {
          onClearCount += 1;
        },
        pollIntervalMs: 500
      };
      const unsubscribe = coordinator.subscribePlan(202, handlers);
      // Act
      machine.emit(PlanStatus.COMPLETED);
      unsubscribe();
      // Assert
      storeHooks.restore();
      timerHooks.restore();
      resetWeatherReminderCoordinatorAV();
      expect(clearCount).assertEqual(1);
      expect(clearedPlanId).assertEqual(202);
      expect(onClearCount).assertEqual(1);
    });

    it('invalid: subscribe_plan_should_return_noop_when_plan_id_invalid', 0, () => {
      // Arrange
      resetWeatherReminderCoordinatorAV();
      const timerHooks = new IntervalHooksAV();
      timerHooks.install();
      const storeHooks = new WeatherReminderStoreHooksAV();
      let readCount = 0;
      storeHooks.setRead((_planId?: number): WeatherReminderPayload | null => {
        readCount += 1;
        return createPayloadAV(1, 0);
      });
      const coordinator = WeatherReminderCoordinator.getInstance();
      // Act
      const unsubscribe = coordinator.subscribePlan(0, {
        isDialogOpen: (): boolean => false,
        onShow: (_payload: WeatherReminderPayload): void => {},
        pollIntervalMs: 500
      });
      unsubscribe();
      // Assert
      storeHooks.restore();
      timerHooks.restore();
      resetWeatherReminderCoordinatorAV();
      expect(readCount).assertEqual(0);
      expect(timerHooks.intervals.size).assertEqual(0);
    });

    it('normal: consume_on_plan_should_show_matching_payload', 0, () => {
      // Arrange
      resetWeatherReminderCoordinatorAV();
      const storeHooks = new WeatherReminderStoreHooksAV();
      storeHooks.setRead((_planId?: number): WeatherReminderPayload | null => createPayloadAV(2, 301));
      const coordinator = WeatherReminderCoordinator.getInstance();
      let showCount = 0;
      const input: PlanWeatherConsumeInput = {
        isDialogOpen: false,
        currentPlanId: 301,
        onShow: (_payload: WeatherReminderPayload): void => {
          showCount += 1;
        }
      };
      // Act
      coordinator.consumeOnPlan(input);
      // Assert
      storeHooks.restore();
      resetWeatherReminderCoordinatorAV();
      expect(showCount).assertEqual(1);
    });

    it('boundary: consume_on_plan_should_skip_when_dialog_is_open', 0, () => {
      // Arrange
      resetWeatherReminderCoordinatorAV();
      const storeHooks = new WeatherReminderStoreHooksAV();
      storeHooks.setRead((_planId?: number): WeatherReminderPayload | null => createPayloadAV(3, 302));
      const coordinator = WeatherReminderCoordinator.getInstance();
      let showCount = 0;
      // Act
      coordinator.consumeOnPlan({
        isDialogOpen: true,
        currentPlanId: 302,
        onShow: (_payload: WeatherReminderPayload): void => {
          showCount += 1;
        }
      });
      // Assert
      storeHooks.restore();
      resetWeatherReminderCoordinatorAV();
      expect(showCount).assertEqual(0);
    });

    it('invalid: consume_on_plan_should_skip_when_payload_plan_mismatch', 0, () => {
      // Arrange
      resetWeatherReminderCoordinatorAV();
      const storeHooks = new WeatherReminderStoreHooksAV();
      storeHooks.setRead((_planId?: number): WeatherReminderPayload | null => createPayloadAV(4, 999));
      const coordinator = WeatherReminderCoordinator.getInstance();
      let showCount = 0;
      // Act
      coordinator.consumeOnPlan({
        isDialogOpen: false,
        currentPlanId: 303,
        onShow: (_payload: WeatherReminderPayload): void => {
          showCount += 1;
        }
      });
      // Assert
      storeHooks.restore();
      resetWeatherReminderCoordinatorAV();
      expect(showCount).assertEqual(0);
    });

    it('normal: clear_should_forward_valid_plan_id_to_store', 0, () => {
      // Arrange
      resetWeatherReminderCoordinatorAV();
      const storeHooks = new WeatherReminderStoreHooksAV();
      let capturedPlanId = 0;
      storeHooks.setClear((planId?: number): void => {
        capturedPlanId = planId ?? 0;
      });
      const coordinator = WeatherReminderCoordinator.getInstance();
      // Act
      coordinator.clear(401);
      // Assert
      storeHooks.restore();
      resetWeatherReminderCoordinatorAV();
      expect(capturedPlanId).assertEqual(401);
    });

    it('boundary: clear_should_allow_undefined_plan_id', 0, () => {
      // Arrange
      resetWeatherReminderCoordinatorAV();
      const storeHooks = new WeatherReminderStoreHooksAV();
      let called = false;
      storeHooks.setClear((_planId?: number): void => {
        called = true;
      });
      const coordinator = WeatherReminderCoordinator.getInstance();
      // Act
      coordinator.clear();
      // Assert
      storeHooks.restore();
      resetWeatherReminderCoordinatorAV();
      expect(called).assertTrue();
    });

    it('invalid: clear_should_forward_negative_plan_id_without_throwing', 0, () => {
      // Arrange
      resetWeatherReminderCoordinatorAV();
      const storeHooks = new WeatherReminderStoreHooksAV();
      let capturedPlanId = 0;
      storeHooks.setClear((planId?: number): void => {
        capturedPlanId = planId ?? 0;
      });
      const coordinator = WeatherReminderCoordinator.getInstance();
      // Act
      coordinator.clear(-1);
      // Assert
      storeHooks.restore();
      resetWeatherReminderCoordinatorAV();
      expect(capturedPlanId).assertEqual(-1);
    });

    it('conflict: subscribe_plan_should_ignore_repeated_payload_seq_on_followup_ticks', 0, () => {
      // Arrange
      resetWeatherReminderCoordinatorAV();
      const timerHooks = new IntervalHooksAV();
      timerHooks.install();
      const storeHooks = new WeatherReminderStoreHooksAV();
      const machine = new FakePlanStateMachineAV();
      const payload = createPayloadAV(7, 501);
      let showCount = 0;
      storeHooks.setRead((_planId?: number): WeatherReminderPayload | null => payload);
      const coordinator = WeatherReminderCoordinator.getInstance();
      Reflect.set(coordinator as Object, 'planStateMachine', machine);
      // Act
      const unsubscribe = coordinator.subscribePlan(501, {
        isDialogOpen: (): boolean => false,
        onShow: (_payload: WeatherReminderPayload): void => {
          showCount += 1;
        },
        pollIntervalMs: 300
      });
      timerHooks.trigger(timerHooks.latestTimerId());
      unsubscribe();
      // Assert
      storeHooks.restore();
      timerHooks.restore();
      resetWeatherReminderCoordinatorAV();
      expect(showCount).assertEqual(1);
    });

    it('regression: unsubscribe_should_be_idempotent_after_subscribe_plan', 0, () => {
      // Arrange
      resetWeatherReminderCoordinatorAV();
      const timerHooks = new IntervalHooksAV();
      timerHooks.install();
      const storeHooks = new WeatherReminderStoreHooksAV();
      const machine = new FakePlanStateMachineAV();
      storeHooks.setRead((_planId?: number): WeatherReminderPayload | null => createPayloadAV(8, 502));
      const coordinator = WeatherReminderCoordinator.getInstance();
      Reflect.set(coordinator as Object, 'planStateMachine', machine);
      // Act
      const unsubscribe = coordinator.subscribePlan(502, {
        isDialogOpen: (): boolean => false,
        onShow: (_payload: WeatherReminderPayload): void => {},
        pollIntervalMs: 300
      });
      unsubscribe();
      unsubscribe();
      // Assert
      storeHooks.restore();
      timerHooks.restore();
      resetWeatherReminderCoordinatorAV();
      expect(machine.unsubscribeCalls).assertEqual(1);
      expect(timerHooks.clearCalls.length).assertEqual(1);
    });

    it('combined: consume_and_clear_should_stop_followup_payload_delivery_for_same_plan', 0, () => {
      // Arrange
      resetWeatherReminderCoordinatorAV();
      const storeHooks = new WeatherReminderStoreHooksAV();
      let payload: WeatherReminderPayload | null = createPayloadAV(9, 503);
      let clearedPlanId = 0;
      let showCount = 0;
      storeHooks.setRead((_planId?: number): WeatherReminderPayload | null => payload);
      storeHooks.setClear((planId?: number): void => {
        clearedPlanId = planId ?? 0;
        payload = null;
      });
      const coordinator = WeatherReminderCoordinator.getInstance();
      // Act
      coordinator.consumeOnPlan({
        isDialogOpen: false,
        currentPlanId: 503,
        onShow: (_payload: WeatherReminderPayload): void => {
          showCount += 1;
        }
      });
      coordinator.clear(503);
      coordinator.consumeOnPlan({
        isDialogOpen: false,
        currentPlanId: 503,
        onShow: (_payload: WeatherReminderPayload): void => {
          showCount += 1;
        }
      });
      // Assert
      storeHooks.restore();
      resetWeatherReminderCoordinatorAV();
      expect(showCount).assertEqual(1);
      expect(clearedPlanId).assertEqual(503);
    });
  });
}
