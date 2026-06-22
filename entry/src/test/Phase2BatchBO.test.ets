import { describe, expect, it } from '@ohos/hypium';
import { AppStorageKeys } from '../main/ets/common/constants/AppStorageKeys';
import { PreferenceManager } from '../main/ets/common/utils/PreferenceManager';
import { WeatherFacade } from '../main/ets/domain/services/WeatherFacade';
import {
  GeoPointInput,
  PlanNodeWeatherBinding,
  SoftReplanApplyResult,
  SoftReplanMode,
  SoftReplanPreview,
  WeatherContext,
  WeatherContextBuildResult,
  WeatherSchedulePolicy,
  WeatherStageType,
  WeatherSuggestion,
  WeatherUserPreference
} from '../main/ets/domain/services/WeatherModels';
import { PlanStatus } from '../main/ets/domain/statemachine/PlanStatus';
import { ComposableStrategy } from '../main/ets/domain/strategy/TravelStrategyDimensions';
import { UserBehaviorTracker } from '../main/ets/domain/strategy/UserBehaviorTracker';
import { EventRepositoryImpl } from '../main/ets/infrastructure/persistence/EventRepositoryImpl';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { TravelPlanItem } from '../main/ets/model/interface/IStandardEvent';
import { CompressionPlan, TimelineViewModel } from '../main/ets/viewmodel/TimelineViewModel';
import { ReflowHint } from '../main/ets/viewmodel/types/TimelineTypes';
import { PlanEventsSnapshot } from '../main/ets/viewmodel/internal/PlanPersistenceFacade';
import { ScheduleOrchestrator } from '../main/ets/viewmodel/internal/ScheduleOrchestrator';
import { ITimelineCompanionHost, TimelineCompanionManager } from '../main/ets/viewmodel/managers/TimelineCompanionManager';
import { TimelineEventMutationManager, ITimelineEventMutationHost } from '../main/ets/viewmodel/managers/TimelineEventMutationManager';
import { TimelinePlanStateManager, ITimelinePlanStateHost } from '../main/ets/viewmodel/managers/TimelinePlanStateManager';
import { TimelineStrategyManager } from '../main/ets/viewmodel/managers/TimelineStrategyManager';
import {
  AiReplanPreviewResult,
  AiReplanUndoToken,
  ExecutionSuggestionApplyResult
} from '../main/ets/domain/timeline/services/TimelineAiService';

interface PlanDatePreviewResultBO {
  hasRigidConflict: boolean;
  conflictItemId: number;
  conflictItemName: string;
  gapMinutes: number;
  conflictMsg: string;
}

interface StartConflictInfoBO {
  eventId: number;
  planId: number;
  name: string;
  actualStartTime: number;
}

interface ReflowHintPayloadBO {
  type: string;
  minutesDelta: number;
  message: string;
  updatedAt: number;
}

interface AdvanceAdjustContextBO {
  targetIndex: number;
  targetId: number;
  targetDayOffset: number;
  candidates: number[];
}

interface ApplyAdvanceResultBO {
  success: boolean;
  appliedCount: number;
  appliedShiftMinutes: number;
  remainingGapMinutes: number;
  message: string;
}

interface CompressionSelectionContextBO {
  targetIndex: number;
  targetTime: string;
  neededGapMinutes: number;
  naturalArrivalMinutes: number;
  chainStartIndex: number;
  candidates: number[];
}

interface HistorySummaryBO {
  planName: string;
  completedCount: number;
  skippedCount: number;
  activeCount: number;
}

interface CompanionActionsBO {
  canStart: boolean;
  canPause: boolean;
  canResume: boolean;
  canEnd: boolean;
  canSkip: boolean;
  canNavigate: boolean;
  canViewDetail: boolean;
}

interface CompanionContextBO {
  runtimeState: string;
  currentEvent: EventEntity | null;
  nextEvent: EventEntity | null;
  hint: ReflowHint | null;
  actions: CompanionActionsBO;
}

interface PlanStatusPayloadBO {
  status: PlanStatus;
}

interface EvaluationInputBO {
  ok: boolean;
}

interface PlanExecutionActionResultBO {
  success: boolean;
  toStatus: PlanStatus;
}

interface PlanStateMachineEventBO {
}

interface PlanStageViewModelBO {
  canPause: boolean;
  canResume: boolean;
}

interface CompanionPlanStateMachineBO {
  getPlanStageViewModel: (planId: string) => PlanStageViewModelBO;
}

interface CompressionPlanDraftBO {
  action: string;
  gapMinutes: number;
  targetIndex: number;
  targetTime: string;
  selectedIds: number[];
}

class EmptyPlanStateMachineEventBO implements PlanStateMachineEventBO {
}

class RuntimeStateContextBO {
  runtimeState: string;

  constructor(runtimeState: string) {
    this.runtimeState = runtimeState;
  }
}

interface AppStorageLikeBO {
  setOrCreate: (key: string, value: boolean | string | number | Object) => void;
}

class StaticPatchBO {
  private readonly target: Object;
  private readonly key: string;
  private readonly origin: Object;

  constructor(target: Object, key: string, replacement: Object) {
    this.target = target;
    this.key = key;
    this.origin = Reflect.get(target, key) as Object;
    Reflect.set(target, key, replacement);
  }

  restore(): void {
    Reflect.set(this.target, this.key, this.origin);
  }
}

class GeoPointBO implements GeoPointInput {
  latitude: number = 0;
  longitude: number = 0;
}

class PlanRecordBO {
  id: number = 1;
  title: string = '';
  createdAt: number = 1;
  startDate: number = 0;
  strategyMode: number = 0;
  status: number = 0;
  enableAutoAmapRoute: number = 1;
  lastAiPrompt: string = '';
  lastStrategyExplanation: string = '';
}

class PreferenceStubBO {
  minEventDuration: number = 45;
  idleGapEnabled: boolean = true;
  idleGapTriggerMinutes: number = 30;
  amapRouteApiEnabled: boolean = true;
  throwMinEventDuration: boolean = false;
  throwIdleGap: boolean = false;
  throwAmap: boolean = false;

  async getMinEventDuration(): Promise<number> {
    if (this.throwMinEventDuration) {
      throw new Error('min_duration_fail_bo');
    }
    return this.minEventDuration;
  }

  async getIdleGapDetectionEnabled(): Promise<boolean> {
    if (this.throwIdleGap) {
      throw new Error('idle_gap_enabled_fail_bo');
    }
    return this.idleGapEnabled;
  }

  async getIdleGapTriggerMinutes(): Promise<number> {
    if (this.throwIdleGap) {
      throw new Error('idle_gap_trigger_fail_bo');
    }
    return this.idleGapTriggerMinutes;
  }

  async isAmapRouteApiEnabled(): Promise<boolean> {
    if (this.throwAmap) {
      throw new Error('amap_route_fail_bo');
    }
    return this.amapRouteApiEnabled;
  }
}

class WeatherFacadeStubBO {
  stage: WeatherStageType = 'READY';
  resolveCalls: number = 0;
  lastRuntimeState: string = '';

  resolveStage(_status: PlanStatus, _events: EventEntity[], runtimeState: string): WeatherStageType {
    this.resolveCalls += 1;
    this.lastRuntimeState = runtimeState;
    return this.stage;
  }
}

class PlanStateDelegateBO {
  bindCalls: number = 0;
  unbindCalls: number = 0;
  evaluateCalls: number = 0;
  recoverCalls: number = 0;
  pauseCalls: number = 0;
  resumeCalls: number = 0;
  locationCalls: number = 0;
  previewCalls: number = 0;
  updatePlanDateCalls: number = 0;
  renameCalls: number = 0;
  lastBindPlanId: number = -1;
  lastLocationLatitude: number = 0;
  lastLocationLongitude: number = 0;
  lastLocationSampleTs: number = 0;
  lastUpdatePlanDate: number = 0;
  lastRenameValue: string = '';
  pauseResult: boolean = true;
  resumeResult: boolean = true;
  isConflict: boolean = true;
  previewResult: PlanDatePreviewResultBO = {
    hasRigidConflict: false,
    conflictItemId: 0,
    conflictItemName: '',
    gapMinutes: 0,
    conflictMsg: ''
  };
  updatePlanDateError: string = '';
  renameError: string = '';

  bindPlanState(planId: number): void {
    this.bindCalls += 1;
    this.lastBindPlanId = planId;
  }

  unbindPlanState(): void {
    this.unbindCalls += 1;
  }

  evaluatePlanStatusByRuntime(): void {
    this.evaluateCalls += 1;
  }

  onLocationSampleForStateMachine(
    latitude: number,
    longitude: number,
    _speed?: number,
    _accuracy?: number,
    sampleTs: number = 0
  ): void {
    this.locationCalls += 1;
    this.lastLocationLatitude = latitude;
    this.lastLocationLongitude = longitude;
    this.lastLocationSampleTs = sampleTs;
  }

  recoverPlanRuntimeState(): void {
    this.recoverCalls += 1;
  }

  pauseCurrentExecution(): boolean {
    this.pauseCalls += 1;
    return this.pauseResult;
  }

  resumeCurrentExecution(): boolean {
    this.resumeCalls += 1;
    return this.resumeResult;
  }

  previewPlanDateShift(timestamp: number): PlanDatePreviewResultBO {
    this.previewCalls += 1;
    this.lastUpdatePlanDate = timestamp;
    return this.previewResult;
  }

  async updatePlanDate(timestamp: number): Promise<void> {
    this.updatePlanDateCalls += 1;
    this.lastUpdatePlanDate = timestamp;
    if (this.updatePlanDateError !== '') {
      throw new Error(this.updatePlanDateError);
    }
  }

  async renamePlan(name: string): Promise<void> {
    this.renameCalls += 1;
    this.lastRenameValue = name;
    if (this.renameError !== '') {
      throw new Error(this.renameError);
    }
  }

  isDateConflict(_targetDateMs: number): boolean {
    return this.isConflict;
  }
}

class EventMutationDelegateBO {
  updateManualCommuteCalls: number = 0;
  moveEventCalls: number = 0;
  moveAllCalls: number = 0;
  moveToBacklogCalls: number = 0;
  addNewItemCalls: number = 0;
  hardDeleteCalls: number = 0;
  updateEventInfoCalls: number = 0;
  resolveConflictByBacklogCalls: number = 0;
  resolveConflictByMovingPlanCalls: number = 0;
  lastManualMinutes: number = 0;
  lastMoveIndex: number = -1;
  lastMoveDirection: string = '';
  moveAllResult: number = 2;
  throwMethod: string = '';

  updateManualCommute(_item: EventEntity, minutes: number): void {
    this.updateManualCommuteCalls += 1;
    this.lastManualMinutes = minutes;
  }

  async moveEvent(index: number, direction: 'up' | 'down'): Promise<void> {
    this.moveEventCalls += 1;
    this.lastMoveIndex = index;
    this.lastMoveDirection = direction;
    if (this.throwMethod === 'moveEvent') {
      throw new Error('move_event_fail_bo');
    }
  }

  async moveAllBacklogToSchedule(): Promise<number> {
    this.moveAllCalls += 1;
    if (this.throwMethod === 'moveAllBacklogToSchedule') {
      throw new Error('move_all_fail_bo');
    }
    return this.moveAllResult;
  }

  async moveToBacklog(_item: TravelPlanItem | EventEntity): Promise<void> {
    this.moveToBacklogCalls += 1;
    if (this.throwMethod === 'moveToBacklog') {
      throw new Error('move_to_backlog_fail_bo');
    }
  }

  async addNewItem(
    _name: string,
    _duration: number,
    _isSchedule?: boolean,
    _fixedTime?: string,
    _dayOffset?: number,
    _preTravel?: number,
    _isHardLock?: boolean,
    _note?: string,
    _priority?: number,
    _lat?: number,
    _lng?: number
  ): Promise<void> {
    this.addNewItemCalls += 1;
    if (this.throwMethod === 'addNewItem') {
      throw new Error('add_item_fail_bo');
    }
  }

  async hardDelete(_item: EventEntity): Promise<void> {
    this.hardDeleteCalls += 1;
    if (this.throwMethod === 'hardDelete') {
      throw new Error('hard_delete_fail_bo');
    }
  }

  async updateEventInfo(
    _id: number,
    _name: string,
    _duration: number,
    _fixedTime?: string,
    _dayOffset: number = 0,
    _isHardLock: boolean = false,
    _note: string = '',
    _priority: number = 0,
    _lat?: number,
    _lng?: number
  ): Promise<void> {
    this.updateEventInfoCalls += 1;
    if (this.throwMethod === 'updateEventInfo') {
      throw new Error('update_event_info_fail_bo');
    }
  }

  async resolveConflictByBacklog(
    _id: number,
    _name: string,
    _duration: number,
    _note: string = '',
    _priority: number = 0
  ): Promise<void> {
    this.resolveConflictByBacklogCalls += 1;
    if (this.throwMethod === 'resolveConflictByBacklog') {
      throw new Error('resolve_backlog_fail_bo');
    }
  }

  async resolveConflictByMovingPlan(
    _id: number,
    _targetDateMs: number,
    _name: string,
    _duration: number,
    _isSchedule: boolean,
    _fixedTime?: string,
    _note: string = '',
    _priority: number = 0
  ): Promise<void> {
    this.resolveConflictByMovingPlanCalls += 1;
    if (this.throwMethod === 'resolveConflictByMovingPlan') {
      throw new Error('resolve_move_plan_fail_bo');
    }
  }
}

class CompressionServiceDelegateBO {
  fixConflictCalls: number = 0;
  lastShiftMinutes: number = 0;
  throwError: string = '';

  async fixConflict(_item: TravelPlanItem | EventEntity, shiftMinutes: number): Promise<void> {
    this.fixConflictCalls += 1;
    this.lastShiftMinutes = shiftMinutes;
    if (this.throwError !== '') {
      throw new Error(this.throwError);
    }
  }
}

class RecalculationDelegateBO {
  testAllCommuteCalls: number = 0;
  updateTravelModeCalls: number = 0;
  resolveGlobalStartCalls: number = 0;
  logSnapshotCalls: number = 0;
  recalculateFromEventIdCalls: number = 0;
  recalculateFromIndexCalls: number = 0;
  recalculateCalls: number = 0;
  recalculateTrafficOnlyCalls: number = 0;
  resolvedGlobalStart: number = 555;

  testAllCommute(): void {
    this.testAllCommuteCalls += 1;
  }

  updateTravelMode(_item: EventEntity, _newMode: number): void {
    this.updateTravelModeCalls += 1;
  }

  resolveEffectiveGlobalStartMinutes(): number {
    this.resolveGlobalStartCalls += 1;
    return this.resolvedGlobalStart;
  }

  logTimelineSnapshot(_scene: string): void {
    this.logSnapshotCalls += 1;
  }

  recalculateFromEventId(_eventId: number): void {
    this.recalculateFromEventIdCalls += 1;
  }

  recalculateFromIndex(_startIndex: number): void {
    this.recalculateFromIndexCalls += 1;
  }

  recalculate(): void {
    this.recalculateCalls += 1;
  }

  recalculateTrafficOnly(): void {
    this.recalculateTrafficOnlyCalls += 1;
  }
}

class WeatherCoordinatorDelegateBO {
  refreshPlanningCalls: number = 0;
  applyPlanningCalls: number = 0;
  startSchedulerCalls: number = 0;
  stopSchedulerCalls: number = 0;
  refreshExecutionCalls: number = 0;
  requestSoftReplanCalls: number = 0;
  dismissCalls: number = 0;
  applySuggestionCalls: number = 0;
  resolveCoordinatesCalls: number = 0;
  reloadPreferenceCalls: number = 0;
  restoreSnapshotCalls: number = 0;
  setFeatureCalls: number = 0;
  updatePreferenceCalls: number = 0;
  executionStage: boolean = true;
  autoRefreshPlanning: boolean = true;
  featureEnabled: boolean = true;
  missingCoordinate: boolean = false;
  validCoordinate: boolean = true;
  executionDisplaySource: 'CURRENT' | 'NEXT_FALLBACK' | 'UNKNOWN' = 'CURRENT';
  softReplanResult: SoftReplanApplyResult = createSoftReplanResultBO(true, '');
  suggestionResult: SoftReplanApplyResult = createSoftReplanResultBO(false, 'apply_bo');
  resolvedPoint: GeoPointBO = (() => {
    const point = new GeoPointBO();
    point.latitude = 31.2;
    point.longitude = 121.4;
    return point;
  })();
  throwMethod: string = '';

  restorePlanningWeatherSnapshot(_planId: number): void {
    this.restoreSnapshotCalls += 1;
  }

  async reloadWeatherUserPreference(): Promise<void> {
    this.reloadPreferenceCalls += 1;
  }

  async refreshPlanningWeather(_forceRefresh?: boolean): Promise<void> {
    this.refreshPlanningCalls += 1;
    if (this.throwMethod === 'refreshPlanningWeather') {
      throw new Error('refresh_planning_fail_bo');
    }
  }

  async applyPlanningWeatherResult(_result: WeatherContextBuildResult, _forceRefresh: boolean): Promise<void> {
    this.applyPlanningCalls += 1;
    if (this.throwMethod === 'applyPlanningWeatherResult') {
      throw new Error('apply_planning_fail_bo');
    }
  }

  isExecutionWeatherStage(): boolean {
    return this.executionStage;
  }

  startExecutionWeatherScheduler(_planId?: number, _stage?: WeatherStageType): void {
    this.startSchedulerCalls += 1;
  }

  stopExecutionWeatherScheduler(): void {
    this.stopSchedulerCalls += 1;
  }

  async refreshExecutionWeather(
    _forceRefresh?: boolean,
    _trigger?: 'ENTER_EXECUTION' | 'LOCATION_CHANGE' | 'TIMER' | 'MANUAL',
    _stage?: WeatherStageType
  ): Promise<void> {
    this.refreshExecutionCalls += 1;
    if (this.throwMethod === 'refreshExecutionWeather') {
      throw new Error('refresh_execution_fail_bo');
    }
  }

  async requestSoftReplan(_planId: number, _suggestionId: string, _mode: SoftReplanMode): Promise<SoftReplanApplyResult> {
    this.requestSoftReplanCalls += 1;
    if (this.throwMethod === 'requestSoftReplan') {
      throw new Error('request_soft_replan_fail_bo');
    }
    return this.softReplanResult;
  }

  dismissExecutionSuggestion(_suggestionId: string): void {
    this.dismissCalls += 1;
  }

  async applyWeatherSuggestion(_suggestionId: string): Promise<SoftReplanApplyResult> {
    this.applySuggestionCalls += 1;
    if (this.throwMethod === 'applyWeatherSuggestion') {
      throw new Error('apply_suggestion_fail_bo');
    }
    return this.suggestionResult;
  }

  async resolveCoordinatesForPlaceName(
    _placeName: string,
    _lat?: number,
    _lng?: number,
    _source: 'add' | 'update' = 'add',
    _fallbackLat: number = 0,
    _fallbackLng: number = 0
  ): Promise<GeoPointInput> {
    this.resolveCoordinatesCalls += 1;
    if (this.throwMethod === 'resolveCoordinatesForPlaceName') {
      throw new Error('resolve_coordinates_fail_bo');
    }
    return this.resolvedPoint;
  }

  isCoordinateMissingForWeather(_latitude: number, _longitude: number): boolean {
    return this.missingCoordinate;
  }

  isValidCoordinate(_latitude: number, _longitude: number): boolean {
    return this.validCoordinate;
  }

  shouldAutoRefreshPlanningWeather(_maxAgeMs: number): boolean {
    return this.autoRefreshPlanning;
  }

  getExecutionWeatherDisplaySource(): 'CURRENT' | 'NEXT_FALLBACK' | 'UNKNOWN' {
    return this.executionDisplaySource;
  }

  async setWeatherFeatureEnabled(enabled: boolean): Promise<void> {
    this.setFeatureCalls += 1;
    this.featureEnabled = enabled;
    if (this.throwMethod === 'setWeatherFeatureEnabled') {
      throw new Error('set_feature_fail_bo');
    }
  }

  async updateWeatherUserPreference(_preference: WeatherUserPreference): Promise<void> {
    this.updatePreferenceCalls += 1;
    if (this.throwMethod === 'updateWeatherUserPreference') {
      throw new Error('update_weather_preference_fail_bo');
    }
  }
}

class StrategyDelegateBO {
  generateByAiCalls: number = 0;
  updateModeCalls: number = 0;
  switchCalls: number = 0;
  weatherAdjustmentCalls: number = 0;
  applyExecutionSuggestionCalls: number = 0;
  getStrategyCalls: number = 0;
  buildPreviewCalls: number = 0;
  applyPreviewCalls: number = 0;
  restoreCalls: number = 0;
  regenerateCustomCalls: number = 0;
  regenerateCurrentCalls: number = 0;
  changeRegenerateCalls: number = 0;
  mode: number = 2;
  hasHistory: boolean = true;
  weatherAdjustmentResult: boolean = true;
  executionSuggestionResult: ExecutionSuggestionApplyResult = {
    strategyApplied: true,
    replanSuccess: true,
    errorCode: ''
  };
  currentStrategy: ComposableStrategy = createStrategyBO();
  previewResult: AiReplanPreviewResult = createPreviewBO();
  undoToken: AiReplanUndoToken = createUndoTokenBO();
  clampResult: 0 | 1 | 2 = 1;
  promptResult: string = 'prompt_bo';
  throwMethod: string = '';

  async generateByAi(_userPrompt: string, _strategyMode?: number, _customStrategy?: ComposableStrategy): Promise<void> {
    this.generateByAiCalls += 1;
    if (this.throwMethod === 'generateByAi') {
      throw new Error('generate_by_ai_fail_bo');
    }
  }

  getStrategyMode(): number {
    return this.mode;
  }

  hasAiHistory(): boolean {
    return this.hasHistory;
  }

  async updateStrategyMode(_mode: number): Promise<void> {
    this.updateModeCalls += 1;
    if (this.throwMethod === 'updateStrategyMode') {
      throw new Error('update_strategy_mode_fail_bo');
    }
  }

  async switchToCustomStrategy(_strategy: ComposableStrategy): Promise<void> {
    this.switchCalls += 1;
    if (this.throwMethod === 'switchToCustomStrategy') {
      throw new Error('switch_strategy_fail_bo');
    }
  }

  async applyWeatherStrategyAdjustment(_adjustment?: Object, _hint?: string): Promise<boolean> {
    this.weatherAdjustmentCalls += 1;
    if (this.throwMethod === 'applyWeatherStrategyAdjustment') {
      throw new Error('apply_weather_adjustment_fail_bo');
    }
    return this.weatherAdjustmentResult;
  }

  async applyExecutionSuggestionWithStrategy(
    _planId: number,
    _suggestionId: string,
    _adjustment?: Object,
    _hint?: string
  ): Promise<ExecutionSuggestionApplyResult> {
    this.applyExecutionSuggestionCalls += 1;
    if (this.throwMethod === 'applyExecutionSuggestionWithStrategy') {
      throw new Error('apply_execution_suggestion_fail_bo');
    }
    return this.executionSuggestionResult;
  }

  async getCurrentStrategy(): Promise<ComposableStrategy> {
    this.getStrategyCalls += 1;
    return this.currentStrategy;
  }

  clampStrategyLevel(_value: number): 0 | 1 | 2 {
    return this.clampResult;
  }

  composeWeatherConstraintPrompt(_weatherAwareConstraint: string, _weatherSummary: string): string {
    return this.promptResult;
  }

  buildWeatherStrategyAdaptationKey(_generatedAt: number, _routeScore: number): string {
    return 'key_bo';
  }

  async regenerateWithCustomStrategy(_strategy: ComposableStrategy): Promise<void> {
    this.regenerateCustomCalls += 1;
    if (this.throwMethod === 'regenerateWithCustomStrategy') {
      throw new Error('regenerate_custom_fail_bo');
    }
  }

  async regenerateByCurrentStrategy(): Promise<void> {
    this.regenerateCurrentCalls += 1;
    if (this.throwMethod === 'regenerateByCurrentStrategy') {
      throw new Error('regenerate_current_fail_bo');
    }
  }

  async changeStrategyAndRegenerate(_mode: number): Promise<void> {
    this.changeRegenerateCalls += 1;
    if (this.throwMethod === 'changeStrategyAndRegenerate') {
      throw new Error('change_strategy_fail_bo');
    }
  }

  async buildReplanPreview(
    _strategyMode: number,
    _customStrategy?: ComposableStrategy,
    _keepCurrentMode?: boolean
  ): Promise<AiReplanPreviewResult> {
    this.buildPreviewCalls += 1;
    if (this.throwMethod === 'buildReplanPreview') {
      throw new Error('build_preview_fail_bo');
    }
    return this.previewResult;
  }

  async applyReplanPreview(
    _preview: AiReplanPreviewResult,
    _decision: 'KEEP' | 'OVERWRITE'
  ): Promise<AiReplanUndoToken> {
    this.applyPreviewCalls += 1;
    if (this.throwMethod === 'applyReplanPreview') {
      throw new Error('apply_preview_fail_bo');
    }
    return this.undoToken;
  }

  async restoreFromUndoToken(_token: AiReplanUndoToken): Promise<void> {
    this.restoreCalls += 1;
    if (this.throwMethod === 'restoreFromUndoToken') {
      throw new Error('restore_undo_fail_bo');
    }
  }
}

class ExecutionServiceDelegateBO {
  findCalls: number = 0;
  skipCalls: number = 0;
  reopenCalls: number = 0;
  calculateCalls: number = 0;
  checkOutCalls: number = 0;
  recordStartCalls: number = 0;
  updateActualCalls: number = 0;
  conflictInfoCalls: number = 0;
  activeEvent: EventEntity | null = null;
  reopenResult: boolean = true;
  updateActualResult: boolean = true;
  conflictInfo: StartConflictInfoBO | null = { eventId: 1, planId: 2, name: 'conflict_bo', actualStartTime: 3 };
  throwMethod: string = '';

  findCurrentActiveEvent(): EventEntity | null {
    this.findCalls += 1;
    return this.activeEvent;
  }

  async skipEvent(_item: EventEntity): Promise<void> {
    this.skipCalls += 1;
    if (this.throwMethod === 'skipEvent') {
      throw new Error('skip_event_fail_bo');
    }
  }

  async reopenSkippedEvent(_id: number): Promise<boolean> {
    this.reopenCalls += 1;
    if (this.throwMethod === 'reopenSkippedEvent') {
      throw new Error('reopen_event_fail_bo');
    }
    return this.reopenResult;
  }

  calculateRealtimeSchedule(): void {
    this.calculateCalls += 1;
    if (this.throwMethod === 'calculateRealtimeSchedule') {
      throw new Error('calculate_schedule_fail_bo');
    }
  }

  async checkOutEvent(_item: EventEntity): Promise<void> {
    this.checkOutCalls += 1;
    if (this.throwMethod === 'checkOutEvent') {
      throw new Error('checkout_event_fail_bo');
    }
  }

  async recordStartTime(_item: EventEntity): Promise<void> {
    this.recordStartCalls += 1;
    if (this.throwMethod === 'recordStartTime') {
      throw new Error('record_start_fail_bo');
    }
  }

  async updateActualTime(
    _id: number,
    _field: 'actual_start_time' | 'actual_end_time',
    _timestamp: number
  ): Promise<boolean> {
    this.updateActualCalls += 1;
    if (this.throwMethod === 'updateActualTime') {
      throw new Error('update_actual_time_fail_bo');
    }
    return this.updateActualResult;
  }

  async getStartConflictInfo(_excludeEventId: number): Promise<StartConflictInfoBO | null> {
    this.conflictInfoCalls += 1;
    if (this.throwMethod === 'getStartConflictInfo') {
      throw new Error('start_conflict_fail_bo');
    }
    return this.conflictInfo;
  }
}

class ExecutionCoordinatorDelegateBO {
  orderedSchedule: EventEntity[] = [];
  orderedIndex: number = 1;
  nextEvent: EventEntity | null = null;
  hint: ReflowHintPayloadBO = {
    type: 'reflow',
    minutesDelta: 5,
    message: 'hint_bo',
    updatedAt: 1
  };
  firstScheduledOfDay: boolean = true;

  getOrderedScheduleEvents(): EventEntity[] {
    return this.orderedSchedule;
  }

  getOrderedScheduleIndexById(_eventId: number, _schedule?: EventEntity[]): number {
    return this.orderedIndex;
  }

  getNextExecutableEvent(_afterId: number, _schedule?: EventEntity[]): EventEntity | null {
    return this.nextEvent;
  }

  buildReflowHint(
    _action: 'start' | 'end' | 'skip',
    _beforeTs: number,
    _afterTs: number,
    _targetName: string,
    _nextName: string
  ): ReflowHintPayloadBO {
    return this.hint;
  }

  isFirstScheduledItemOfDay(_item: EventEntity): boolean {
    return this.firstScheduledOfDay;
  }
}

class CompressionCoordinatorDelegateBO {
  naturalArrival: number = 333;
  delayPlan: CompressionPlan = createCompressionPlanBO('NO_ACTION');
  advanceContext: AdvanceAdjustContextBO | null = { targetIndex: 1, targetId: 2, targetDayOffset: 0, candidates: [] };
  applyAdvanceResult: ApplyAdvanceResultBO = {
    success: true,
    appliedCount: 1,
    appliedShiftMinutes: 10,
    remainingGapMinutes: 0,
    message: 'advance_bo'
  };
  selectionContext: CompressionSelectionContextBO | null = {
    targetIndex: 1,
    targetTime: '10:00',
    neededGapMinutes: 10,
    naturalArrivalMinutes: 600,
    chainStartIndex: 0,
    candidates: []
  };
  selectionPlan: CompressionPlan = createCompressionPlanBO('COMPRESS_CONFIRM');
  applyCompressionCalls: number = 0;
  throwMethod: string = '';

  calculateNaturalArrival(_targetIndex: number): number {
    return this.naturalArrival;
  }

  calculateDelayPlan(_targetIndex: number): CompressionPlan {
    return this.delayPlan;
  }

  buildAdvanceAdjustContext(_targetIndex: number): AdvanceAdjustContextBO | null {
    return this.advanceContext;
  }

  async applyAdvanceAdjust(
    _targetIndex: number,
    _selectedIds: Set<number>,
    _targetStartTime: string,
    _forcedGapMinutes?: number
  ): Promise<ApplyAdvanceResultBO> {
    if (this.throwMethod === 'applyAdvanceAdjust') {
      throw new Error('apply_advance_fail_bo');
    }
    return this.applyAdvanceResult;
  }

  buildCompressionSelectionContext(
    _targetIndex: number,
    _targetTime: string,
    _forcedGapMinutes?: number
  ): CompressionSelectionContextBO | null {
    return this.selectionContext;
  }

  calculateCompressionPlanBySelection(
    _targetIndex: number,
    _targetTime: string,
    _selectedIds: Set<number>,
    _mode?: 'EQUAL' | 'RATIO',
    _forcedGapMinutes?: number
  ): CompressionPlan {
    return this.selectionPlan;
  }

  applyCompressionPlan(_plan: CompressionPlan): void {
    this.applyCompressionCalls += 1;
    if (this.throwMethod === 'applyCompressionPlan') {
      throw new Error('apply_compression_fail_bo');
    }
  }
}

class HistoryManagerDelegateBO {
  summary: HistorySummaryBO = createHistorySummaryBO('history_bo', 1, 0, 0);
  items: Object[] = [];

  getCurrentPlanHistorySummary(): HistorySummaryBO {
    return this.summary;
  }

  getCurrentPlanHistoryTimelineItems(_abnormalThresholdMinutes: number = 10): Object[] {
    return this.items;
  }
}

class CompanionManagerDelegateBO {
  context: CompanionContextBO = createCompanionContextBO('READY', null);
  activeEvent: EventEntity | null = null;

  getCompanionContext(_nowTs: number = Date.now()): CompanionContextBO {
    return this.context;
  }

  getRealActiveEvent(_schedule?: EventEntity[]): EventEntity | null {
    return this.activeEvent;
  }
}

class DistributionCoordinatorDelegateBO {
  resolveGapCalls: number = 0;

  resolveGapBySync(_item: EventEntity): void {
    this.resolveGapCalls += 1;
  }
}

class PersistenceDelegateBO {
  updateStartDateCalls: number = 0;
  updateNameCalls: number = 0;
  getPlanAndEventsCalls: number = 0;
  lastPlanId: number = -1;
  lastUpdatedName: string = '';
  snapshot: PlanEventsSnapshot = { events: [] };
  throwGetPlanAndEvents: boolean = false;
  throwUpdateStartDate: boolean = false;
  throwUpdateName: boolean = false;

  async getPlanAndEvents(planId: number): Promise<PlanEventsSnapshot> {
    this.getPlanAndEventsCalls += 1;
    this.lastPlanId = planId;
    if (this.throwGetPlanAndEvents) {
      throw new Error('load_data_fail_bo');
    }
    return this.snapshot;
  }

  async updatePlanStartDate(planId: number, _startDate: number): Promise<void> {
    this.updateStartDateCalls += 1;
    this.lastPlanId = planId;
    if (this.throwUpdateStartDate) {
      throw new Error('persist_start_date_fail_bo');
    }
  }

  async updatePlanName(planId: number, name: string): Promise<void> {
    this.updateNameCalls += 1;
    this.lastPlanId = planId;
    this.lastUpdatedName = name;
    if (this.throwUpdateName) {
      throw new Error('persist_plan_name_fail_bo');
    }
  }
}

class ViewModelBundleBO {
  vm: TimelineViewModel = new TimelineViewModel();
  planState: PlanStateDelegateBO = new PlanStateDelegateBO();
  eventMutation: EventMutationDelegateBO = new EventMutationDelegateBO();
  compressionService: CompressionServiceDelegateBO = new CompressionServiceDelegateBO();
  recalculation: RecalculationDelegateBO = new RecalculationDelegateBO();
  weather: WeatherCoordinatorDelegateBO = new WeatherCoordinatorDelegateBO();
  strategy: StrategyDelegateBO = new StrategyDelegateBO();
  executionService: ExecutionServiceDelegateBO = new ExecutionServiceDelegateBO();
  executionCoordinator: ExecutionCoordinatorDelegateBO = new ExecutionCoordinatorDelegateBO();
  compressionCoordinator: CompressionCoordinatorDelegateBO = new CompressionCoordinatorDelegateBO();
  history: HistoryManagerDelegateBO = new HistoryManagerDelegateBO();
  companion: CompanionManagerDelegateBO = new CompanionManagerDelegateBO();
  distribution: DistributionCoordinatorDelegateBO = new DistributionCoordinatorDelegateBO();
  persistence: PersistenceDelegateBO = new PersistenceDelegateBO();
  weatherFacade: WeatherFacadeStubBO = new WeatherFacadeStubBO();
  refreshCalls: number = 0;

  constructor() {
    Reflect.set(this.vm as Object, 'planStateManager', this.planState);
    Reflect.set(this.vm as Object, 'eventMutationManager', this.eventMutation);
    Reflect.set(this.vm as Object, 'compressionService', this.compressionService);
    Reflect.set(this.vm as Object, 'recalculationManager', this.recalculation);
    Reflect.set(this.vm as Object, 'weatherCoordinator', this.weather);
    Reflect.set(this.vm as Object, 'strategyManager', this.strategy);
    Reflect.set(this.vm as Object, 'executionService', this.executionService);
    Reflect.set(this.vm as Object, 'executionCoordinator', this.executionCoordinator);
    Reflect.set(this.vm as Object, 'compressionCoordinator', this.compressionCoordinator);
    Reflect.set(this.vm as Object, 'historyManager', this.history);
    Reflect.set(this.vm as Object, 'companionManager', this.companion);
    Reflect.set(this.vm as Object, 'distributionCoordinator', this.distribution);
    Reflect.set(this.vm as Object, 'persistence', this.persistence);
    Reflect.set(this.vm as Object, 'weatherFacade', this.weatherFacade);
    Reflect.set(this.vm as Object, 'refreshTimelineView', (): void => {
      this.refreshCalls += 1;
    });
  }
}

class PlanStateMachineBO {
  status: PlanStatus = PlanStatus.READY;
  updateContextCalls: number = 0;
  refreshEvaluationCalls: number = 0;
  markRecoveryCalls: string[] = [];
  executionContext: Object | null = null;
  policyResult: WeatherSchedulePolicy = {
    stage: 'READY',
    pollIntervalMs: 60000,
    allowLocationTrigger: true,
    allowManualBypass: true,
    forceRefreshOnEnter: true
  };
  pauseResult: PlanExecutionActionResultBO = { success: true, toStatus: PlanStatus.PAUSED };
  resumeResult: PlanExecutionActionResultBO = { success: true, toStatus: PlanStatus.IN_PROGRESS };
  private planListener: ((event: PlanStateMachineEventBO) => void) | null = null;
  private locationListener: ((event: PlanStateMachineEventBO) => void) | null = null;

  getPlanStatus(_planId: string): PlanStatusPayloadBO {
    const payload: PlanStatusPayloadBO = { status: this.status };
    return payload;
  }

  subscribePlanTransition(_planId: string, listener: (event: PlanStateMachineEventBO) => void): () => void {
    this.planListener = listener;
    return (): void => {
      this.planListener = null;
    };
  }

  subscribeLocationChange(_planId: string, listener: (event: PlanStateMachineEventBO) => void): () => void {
    this.locationListener = listener;
    return (): void => {
      this.locationListener = null;
    };
  }

  updateExecutionContext(_payload: Object): void {
    this.updateContextCalls += 1;
  }

  buildEvaluationInput(_planId: string, _events: EventEntity[], _now: number): EvaluationInputBO {
    const input: EvaluationInputBO = { ok: true };
    return input;
  }

  evaluateAndApply(_input: EvaluationInputBO): void {
    this.refreshEvaluationCalls += 1;
  }

  getExecutionContext(_planId: string): Object | null {
    return this.executionContext;
  }

  markRecovery(_planId: string, ok: boolean, reason: string): void {
    this.markRecoveryCalls.push(`${ok ? 'ok' : 'fail'}:${reason}`);
  }

  pauseExecution(_planId: string): PlanExecutionActionResultBO {
    return this.pauseResult;
  }

  resumeExecution(_planId: string): PlanExecutionActionResultBO {
    return this.resumeResult;
  }

  confirmPlan(_planId: string): void {
    this.status = PlanStatus.CONFIRMED;
  }

  completeExecution(_planId: string): void {
    this.status = PlanStatus.COMPLETED;
  }

  emitLocation(): void {
    if (this.locationListener) {
      this.locationListener(new EmptyPlanStateMachineEventBO());
    }
  }
}

class PlanStateHostBO {
  planId: number = 8;
  planName: string = 'plan_state_bo';
  events: EventEntity[] = [];
  globalStartTime: string = '09:00';
  planStartDate: number = new Date(2026, 3, 17).getTime();
  idleGapDetectionEnabled: boolean = true;
  idleGapTriggerMinutes: number = 45;
  currentPlanStatus: PlanStatus = PlanStatus.READY;
  weatherFeatureEnabled: boolean = true;
  executionWeatherEnabled: boolean = true;
  executionWeatherHint: string = '';
  executionWeatherSuggestions: WeatherSuggestion[] = [];
  executionWeatherAppliedSummary: string = '';
  executionWeatherLevel: 'INFO' | 'NOTICE' | 'WARNING' = 'INFO';
  weatherFacade: WeatherFacade = new WeatherFacade();
  planStateMachine: PlanStateMachineBO;
  refreshWeatherCalls: number = 0;
  resolveStage: WeatherStageType = 'READY';
  private readonly machine: PlanStateMachineBO;

  constructor(machine: PlanStateMachineBO = new PlanStateMachineBO()) {
    this.machine = machine;
    this.planStateMachine = machine;
    Reflect.set(this.weatherFacade as Object, 'resolveSchedulePolicy', (_stage: WeatherStageType): WeatherSchedulePolicy => {
      return this.machine.policyResult;
    });
  }

  resolveCurrentWeatherStage(): WeatherStageType {
    return this.resolveStage;
  }

  startExecutionWeatherScheduler(_planId?: number, _stage?: WeatherStageType): void {
    return;
  }

  stopExecutionWeatherScheduler(): void {
    return;
  }

  async refreshExecutionWeather(
    _forceRefresh?: boolean,
    _trigger?: 'ENTER_EXECUTION' | 'LOCATION_CHANGE' | 'TIMER' | 'MANUAL',
    _stage?: WeatherStageType
  ): Promise<void> {
    this.refreshWeatherCalls += 1;
  }

  getCompanionContext(_nowTs?: number): Object {
    return new RuntimeStateContextBO('READY') as Object;
  }

  recalculateFromIndex(_startIndex: number): void {
    return;
  }

  getScheduleOrchestrator(): ScheduleOrchestrator {
    return new ScheduleOrchestrator();
  }

  isAutoRouteEnabled(): boolean {
    return false;
  }

  calculateRealtimeSchedule(): void {
    return;
  }

  regenerateGroups(): void {
    return;
  }

  markScheduleChanged(): void {
    return;
  }

  refreshTimelineView(): void {
    return;
  }

  async persistPlanStartDate(_planId: number, _startDate: number): Promise<void> {
    return;
  }

  async persistPlanName(_planId: number, _name: string): Promise<void> {
    return;
  }
}

class MutationHostBO {
  events: EventEntity[] = [];
  planId: number = 5;
  enableAutoAmapRoute: boolean = true;
  enableGlobalAmapRouteApi: boolean = true;
  tryBeginMutationResult: boolean = true;
  refreshCalls: number = 0;
  endMutationCalls: number = 0;
  saveCalls: number = 0;
  recalcFromEventIdCalls: number = 0;
  recalcFromIndexCalls: number = 0;
  updatePlanDateCalls: number = 0;
  firstScheduledIds: number[] = [];
  resolvedPoint: GeoPointBO = (() => {
    const point = new GeoPointBO();
    point.latitude = 39.9;
    point.longitude = 116.4;
    return point;
  })();

  isFirstScheduledItemOfDay(item: EventEntity): boolean {
    return this.firstScheduledIds.indexOf(item.id) >= 0;
  }

  async resolveCoordinatesForPlaceName(
    _placeName: string,
    lat?: number,
    lng?: number,
    _source?: 'add' | 'update',
    fallbackLat?: number,
    fallbackLng?: number
  ): Promise<GeoPointInput> {
    const point = new GeoPointBO();
    point.latitude = Number.isFinite(this.resolvedPoint.latitude) ? this.resolvedPoint.latitude : (lat ?? fallbackLat ?? 0);
    point.longitude = Number.isFinite(this.resolvedPoint.longitude) ? this.resolvedPoint.longitude : (lng ?? fallbackLng ?? 0);
    return point;
  }

  isCoordinateMissingForWeather(latitude: number, longitude: number): boolean {
    return latitude === 0 || longitude === 0;
  }

  recalculateFromEventId(_eventId: number): void {
    this.recalcFromEventIdCalls += 1;
  }

  recalculateFromIndex(_startIndex: number): void {
    this.recalcFromIndexCalls += 1;
  }

  async save(): Promise<void> {
    this.saveCalls += 1;
  }

  async updatePlanDate(_newDateTimestamp: number): Promise<void> {
    this.updatePlanDateCalls += 1;
  }

  tryBeginMutation(_itemId: number): boolean {
    return this.tryBeginMutationResult;
  }

  endMutation(_itemId: number): void {
    this.endMutationCalls += 1;
  }

  refreshTimelineView(): void {
    this.refreshCalls += 1;
  }
}
function createEventBO(id: number, name: string, status: number = 1): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = name;
  event.status = status;
  event.sort_order = id * 10;
  event.day_offset = 0;
  event.dynamic_day_offset = 0;
  event.has_gap = false;
  event.gap_minutes = 0;
  event.fixed_start_time = '';
  event.computed_time = '';
  event.dynamic_start_time = 0;
  event.dynamic_end_time = 0;
  event.actual_start_time = 0;
  event.actual_end_time = 0;
  event.pre_travel_min = 0;
  event.is_travel_manual = 0;
  event.completion_status = EventEntity.STATE_PENDING;
  return event;
}

function createStrategyBO(): ComposableStrategy {
  return {
    density: 1,
    pace: 1,
    preference: 1,
    energy: 1
  };
}

function createPreviewBO(): AiReplanPreviewResult {
  return {
    prompt: 'preview_bo',
    strategyMode: 1,
    generatedAt: Date.now(),
    itemCount: 1,
    items: [{
      name: 'preview_item_bo',
      duration: 60,
      itemType: 0,
      aiReasoning: 'reason_bo'
    }]
  };
}

function createUndoTokenBO(): AiReplanUndoToken {
  return {
    createdAt: Date.now(),
    events: [],
    strategyMode: 1,
    strategyDensity: 1,
    strategyPace: 1,
    strategyPreference: 1,
    strategyEnergy: 1,
    lastAiPrompt: 'undo_prompt_bo',
    lastStrategyExplanation: 'undo_explain_bo'
  };
}

function createSoftReplanResultBO(success: boolean, code: string): SoftReplanApplyResult {
  return {
    success: success,
    rolledBack: false,
    errorCode: success ? '' : 'REPLAN_INVALID',
    reasonCode: code,
    startFromEventId: success ? 1 : undefined,
    preview: {
      suggestionId: 'sg_bo',
      actionType: 'REORDER',
      changedOrder: success,
      changedDurations: false,
      skippedNodeIds: [],
      affectedNodeIds: ['1'],
      reasonCode: code,
      startFromEventId: success ? 1 : undefined,
      changeSummary: [],
      summary: success ? 'ok' : 'failed',
      riskDelta: 0
    }
  };
}

function createHistorySummaryBO(
  planName: string,
  completedCount: number,
  skippedCount: number,
  activeCount: number
): HistorySummaryBO {
  return {
    planName: planName,
    completedCount: completedCount,
    skippedCount: skippedCount,
    activeCount: activeCount
  };
}

function createCompanionActionsBO(
  canStart: boolean,
  canPause: boolean,
  canResume: boolean
): CompanionActionsBO {
  return {
    canStart: canStart,
    canPause: canPause,
    canResume: canResume,
    canEnd: false,
    canSkip: true,
    canNavigate: true,
    canViewDetail: true
  };
}

function createCompanionContextBO(runtimeState: string, currentEvent: EventEntity | null): CompanionContextBO {
  return {
    runtimeState: runtimeState,
    currentEvent: currentEvent,
    nextEvent: null,
    hint: null,
    actions: createCompanionActionsBO(true, false, false)
  };
}

function createCompanionPlanStateMachineBO(canPause: boolean, canResume: boolean): CompanionPlanStateMachineBO {
  return {
    getPlanStageViewModel: (_planId: string): PlanStageViewModelBO => ({
      canPause: canPause,
      canResume: canResume
    })
  };
}

function createCompressionPlanBO(action: string): CompressionPlan {
  const plan: CompressionPlanDraftBO = {
    action: action,
    gapMinutes: 0,
    targetIndex: 0,
    targetTime: '10:00',
    selectedIds: []
  };
  return plan as Object as CompressionPlan;
}

function ensureAppStorageBO(): void {
  if (!Reflect.has(globalThis as Object, 'AppStorage')) {
    const appStorageLike: AppStorageLikeBO = {
      setOrCreate: (_key: string, _value: boolean | string | number | Object): void => {
        return;
      }
    };
    Reflect.set(globalThis as Object, 'AppStorage', appStorageLike);
  }
}

class CompanionHostBO implements ITimelineCompanionHost {
  planId: number = 77;
  latestReflowHint: ReflowHint | null = null;
  planStateMachine: CompanionPlanStateMachineBO = {
    getPlanStageViewModel: (_planId: string): PlanStageViewModelBO => ({
      canPause: false,
      canResume: false
    })
  };
  schedule: EventEntity[] = [];
  nextById: Map<number, EventEntity> = new Map<number, EventEntity>();

  getOrderedScheduleEvents(): EventEntity[] {
    return this.schedule;
  }

  getNextExecutableEvent(afterId: number, _schedule?: EventEntity[]): EventEntity | null {
    return this.nextById.get(afterId) ?? null;
  }
}

export default function phase2BatchBOTest() {
  describe('phase2BatchBOTest_timeline_view_model', () => {
    it('normal: plan_state_wrappers_should_delegate_to_manager', 0, () => {
      // Arrange
      const bundle = new ViewModelBundleBO();
      // Act
      bundle.vm.bindPlanState(31);
      bundle.vm.evaluatePlanStatusByRuntime();
      bundle.vm.recoverPlanRuntimeState();
      bundle.vm.unbindPlanState();
      // Assert
      expect(bundle.planState.bindCalls).assertEqual(1);
      expect(bundle.planState.lastBindPlanId).assertEqual(31);
      expect(bundle.planState.evaluateCalls).assertEqual(1);
      expect(bundle.planState.recoverCalls).assertEqual(1);
      expect(bundle.planState.unbindCalls).assertEqual(1);
    });

    it('boundary: update_commute_should_ignore_invalid_index', 0, () => {
      // Arrange
      const bundle = new ViewModelBundleBO();
      bundle.vm.events = [createEventBO(1, 'event_bo', 1)];
      // Act
      bundle.vm.updateCommute(-1, 20);
      bundle.vm.updateCommute(2, 20);
      // Assert
      expect(bundle.eventMutation.updateManualCommuteCalls).assertEqual(0);
    });

    it('invalid: update_commute_should_forward_valid_event', 0, () => {
      // Arrange
      const bundle = new ViewModelBundleBO();
      bundle.vm.events = [createEventBO(2, 'event_forward_bo', 1)];
      // Act
      bundle.vm.updateCommute(0, 28);
      // Assert
      expect(bundle.eventMutation.updateManualCommuteCalls).assertEqual(1);
      expect(bundle.eventMutation.lastManualMinutes).assertEqual(28);
    });

    it('normal: weather_wrappers_should_forward_and_return', 0, async () => {
      // Arrange
      const bundle = new ViewModelBundleBO();
      bundle.weather.executionStage = true;
      bundle.weather.validCoordinate = true;
      // Act
      await bundle.vm.refreshPlanningWeather(true);
      bundle.vm.startExecutionWeatherScheduler(8, 'READY');
      await bundle.vm.refreshExecutionWeather(true, 'MANUAL', 'READY');
      const point = await bundle.vm.resolveCoordinatesForPlaceName('x', 30.1, 120.2);
      const stage = bundle.vm.isExecutionWeatherStage();
      const valid = bundle.vm.isValidCoordinate(30.1, 120.2);
      // Assert
      expect(bundle.weather.refreshPlanningCalls).assertEqual(1);
      expect(bundle.weather.startSchedulerCalls).assertEqual(1);
      expect(bundle.weather.refreshExecutionCalls).assertEqual(1);
      expect(point.latitude > 0).assertTrue();
      expect(stage).assertTrue();
      expect(valid).assertTrue();
    });

    it('invalid: weather_wrapper_should_propagate_refresh_error', 0, async () => {
      // Arrange
      const bundle = new ViewModelBundleBO();
      bundle.weather.throwMethod = 'refreshPlanningWeather';
      // Act
      let message = '';
      try {
        await bundle.vm.refreshPlanningWeather(true);
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }
      // Assert
      expect(message).assertEqual('refresh_planning_fail_bo');
    });

    it('normal: strategy_wrapper_should_return_delegate_values', 0, async () => {
      // Arrange
      const bundle = new ViewModelBundleBO();
      // Act
      const mode = bundle.vm.getStrategyMode();
      const hasHistory = bundle.vm.hasAiHistory();
      await bundle.vm.updateStrategyMode(2);
      const current = await bundle.vm.getCurrentStrategy();
      const applied = await bundle.vm.applyWeatherStrategyAdjustment(undefined, 'hint_bo');
      // Assert
      expect(mode).assertEqual(2);
      expect(hasHistory).assertTrue();
      expect(bundle.strategy.updateModeCalls).assertEqual(1);
      expect(current.energy).assertEqual(1);
      expect(applied).assertTrue();
    });

    it('combined: ai_replan_wrappers_should_update_undo_state_and_refresh', 0, async () => {
      // Arrange
      ensureAppStorageBO();
      const bundle = new ViewModelBundleBO();
      const preview = createPreviewBO();
      // Act
      await bundle.vm.applyAiReplanPreview(preview, 'OVERWRITE');
      const hasUndoAfterApply = bundle.vm.hasAiReplanUndo();
      await bundle.vm.undoLastAiReplanApply();
      const hasUndoAfterUndo = bundle.vm.hasAiReplanUndo();
      // Assert
      expect(hasUndoAfterApply).assertTrue();
      expect(hasUndoAfterUndo).assertFalse();
      expect(bundle.strategy.applyPreviewCalls).assertEqual(1);
      expect(bundle.strategy.restoreCalls).assertEqual(1);
      expect(bundle.refreshCalls >= 2).assertTrue();
    });

    it('invalid: undo_last_ai_replan_should_throw_without_token', 0, async () => {
      // Arrange
      ensureAppStorageBO();
      const bundle = new ViewModelBundleBO();
      // Act
      let message = '';
      try {
        await bundle.vm.undoLastAiReplanApply();
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }
      // Assert
      expect(message.length > 0).assertTrue();
    });

    it('conflict: fix_conflict_should_delegate_to_compression_service', 0, async () => {
      // Arrange
      const bundle = new ViewModelBundleBO();
      const event = createEventBO(8, 'conflict_bo', 1);
      // Act
      await bundle.vm.fixConflict(event, 18);
      // Assert
      expect(bundle.compressionService.fixConflictCalls).assertEqual(1);
    });

    it('regression: save_should_shortcut_without_plan_and_enqueue_with_plan', 0, async () => {
      // Arrange
      const vm = new TimelineViewModel();
      let saveCount = 0;
      const patch = new StaticPatchBO(EventRepositoryImpl as Object, 'saveAllEvents', async (): Promise<void> => {
        saveCount += 1;
      });
      // Act
      vm.planId = -1;
      await vm.save();
      vm.planId = 12;
      const manyEvents: EventEntity[] = [];
      for (let index = 0; index < 21; index++) {
        manyEvents.push(createEventBO(81 + index, `save_${index}_bo`, index % 2));
      }
      vm.events = manyEvents;
      await Promise.all([vm.save(), vm.save()]);
      // Assert
      patch.restore();
      expect(saveCount).assertEqual(2);
    });

    it('normal: execution_compression_history_companion_wrappers_should_forward', 0, async () => {
      // Arrange
      const bundle = new ViewModelBundleBO();
      const active = createEventBO(51, 'active_bo', 1);
      bundle.executionService.activeEvent = active;
      bundle.executionService.reopenResult = true;
      bundle.executionCoordinator.orderedSchedule = [active];
      bundle.history.summary = createHistorySummaryBO('history_bo', 3, 1, 0);
      bundle.companion.context = createCompanionContextBO('READY', active);
      // Act
      const found = bundle.vm.findCurrentActiveEvent();
      await bundle.vm.skipEvent(active);
      const reopened = await bundle.vm.reopenSkippedEvent(51);
      bundle.vm.calculateRealtimeSchedule();
      const natural = bundle.vm._calculateNaturalArrival(0);
      const summary = bundle.vm.getCurrentPlanHistorySummary();
      const companion = bundle.vm.getCompanionContext(Date.now());
      // Assert
      expect(found?.id ?? -1).assertEqual(51);
      expect(reopened).assertTrue();
      expect(bundle.executionService.skipCalls).assertEqual(1);
      expect(bundle.executionService.calculateCalls).assertEqual(1);
      expect(natural).assertEqual(333);
      expect(summary.completedCount).assertEqual(3);
      expect(companion.runtimeState).assertEqual('READY');
    });
  });

  describe('phase2BatchBOTest_timeline_plan_state_manager', () => {
    it('normal: location_change_should_refresh_weather_when_policy_allows', 0, () => {
      // Arrange
      const machine = new PlanStateMachineBO();
      machine.policyResult = {
        stage: 'READY',
        pollIntervalMs: 60000,
        allowLocationTrigger: true,
        allowManualBypass: true,
        forceRefreshOnEnter: true
      };
      const host = new PlanStateHostBO(machine);
      host.resolveStage = 'READY';
      const manager = new TimelinePlanStateManager(host as Object as ITimelinePlanStateHost);
      // Act
      manager.bindPlanState(8);
      machine.emitLocation();
      manager.unbindPlanState();
      // Assert
      expect(host.refreshWeatherCalls).assertEqual(1);
    });

    it('boundary: location_change_should_skip_when_stage_not_supported', 0, () => {
      // Arrange
      const machine = new PlanStateMachineBO();
      const host = new PlanStateHostBO(machine);
      host.resolveStage = 'CONFIRMED';
      const manager = new TimelinePlanStateManager(host as Object as ITimelinePlanStateHost);
      // Act
      manager.bindPlanState(8);
      machine.emitLocation();
      manager.unbindPlanState();
      // Assert
      expect(host.refreshWeatherCalls).assertEqual(0);
    });

    it('invalid: location_change_should_skip_when_weather_disabled', 0, () => {
      // Arrange
      const machine = new PlanStateMachineBO();
      const host = new PlanStateHostBO(machine);
      host.weatherFeatureEnabled = false;
      const manager = new TimelinePlanStateManager(host as Object as ITimelinePlanStateHost);
      // Act
      manager.bindPlanState(8);
      machine.emitLocation();
      manager.unbindPlanState();
      // Assert
      expect(host.refreshWeatherCalls).assertEqual(0);
    });
  });

  describe('phase2BatchBOTest_timeline_event_mutation_manager', () => {
    it('normal: add_new_item_should_insert_and_recalculate', 0, async () => {
      // Arrange
      const host = new MutationHostBO();
      const manager = new TimelineEventMutationManager(
        host as Object as ITimelineEventMutationHost,
        new UserBehaviorTracker(),
        new StrategyDelegateBO() as Object as TimelineStrategyManager
      );
      const patch = new StaticPatchBO(EventRepositoryImpl as Object, 'insertEvent', async (): Promise<number> => 501);
      // Act
      await manager.addNewItem('new_schedule_bo', 60, true, '10:00', 0, 15, false, '', 0, 30.1, 120.2);
      // Assert
      patch.restore();
      expect(host.events.length).assertEqual(1);
      expect(host.events[0].id).assertEqual(501);
      expect(host.recalcFromEventIdCalls).assertEqual(1);
    });

    it('boundary: update_manual_commute_should_ignore_non_positive_minutes', 0, () => {
      // Arrange
      const host = new MutationHostBO();
      const manager = new TimelineEventMutationManager(
        host as Object as ITimelineEventMutationHost,
        new UserBehaviorTracker(),
        new StrategyDelegateBO() as Object as TimelineStrategyManager
      );
      const event = createEventBO(601, 'manual_bo', 1);
      // Act
      manager.updateManualCommute(event, 0);
      // Assert
      expect(host.recalcFromEventIdCalls).assertEqual(0);
    });

    it('invalid: move_to_backlog_should_throw_on_invalid_item', 0, async () => {
      // Arrange
      const host = new MutationHostBO();
      const manager = new TimelineEventMutationManager(
        host as Object as ITimelineEventMutationHost,
        new UserBehaviorTracker(),
        new StrategyDelegateBO() as Object as TimelineStrategyManager
      );
      // Act
      let message = '';
      try {
        await manager.moveToBacklog(new EventEntity() as Object as TravelPlanItem);
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }
      // Assert
      expect(message.indexOf('invalid_item') >= 0).assertTrue();
    });
  });

  describe('phase2BatchBOTest_timeline_companion_manager', () => {
    it('normal: get_companion_context_should_return_paused_when_stage_resumable', 0, () => {
      // Arrange
      const active = createEventBO(701, 'active_bo', 1);
      active.actual_start_time = Date.now() - 60 * 1000;
      const next = createEventBO(702, 'next_bo', 1);
      const host = new CompanionHostBO();
      host.schedule = [active, next];
      host.nextById.set(701, next);
      host.planStateMachine = createCompanionPlanStateMachineBO(false, true);
      const manager = new TimelineCompanionManager(host);
      // Act
      const context = manager.getCompanionContext(Date.now());
      // Assert
      expect(context.runtimeState).assertEqual('PAUSED');
      expect(context.currentEvent?.id ?? -1).assertEqual(701);
    });

    it('boundary: get_companion_context_should_return_idle_on_empty_schedule', 0, () => {
      // Arrange
      const host = new CompanionHostBO();
      host.schedule = [];
      const manager = new TimelineCompanionManager(host);
      // Act
      const context = manager.getCompanionContext(Date.now());
      // Assert
      expect(context.runtimeState).assertEqual('IDLE');
      expect(context.actions.canStart).assertFalse();
    });

    it('invalid: get_real_active_event_should_return_null_when_pending_expired', 0, () => {
      // Arrange
      const pending = createEventBO(703, 'pending_expired_bo', 1);
      pending.dynamic_end_time = Date.now() - 1;
      const host = new CompanionHostBO();
      host.schedule = [pending];
      const manager = new TimelineCompanionManager(host);
      // Act
      const event = manager.getRealActiveEvent();
      // Assert
      expect(event === null).assertTrue();
    });
  });
}
