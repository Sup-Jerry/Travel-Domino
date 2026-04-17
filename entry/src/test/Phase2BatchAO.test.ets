import { describe, expect, it } from '@ohos/hypium';
import { notificationManager } from '@kit.NotificationKit';
import { abilityAccessCtrl, bundleManager, common } from '@kit.AbilityKit';
import { TimelineWeatherCoordinator } from '../main/ets/viewmodel/coordinators/TimelineWeatherCoordinator';
import {
  TimelineDistributionCoordinator,
  ITimelineDistributionCoordinatorHost
} from '../main/ets/viewmodel/coordinators/TimelineDistributionCoordinator';
import { TimelineCompressionCoordinator } from '../main/ets/viewmodel/coordinators/TimelineCompressionCoordinator';
import {
  DEFAULT_WEATHER_USER_PREFERENCE,
  GeoPointInput,
  PlanNodeWeatherBinding,
  SoftReplanApplyResult,
  SoftReplanMode,
  WeatherContext,
  WeatherContextBuildResult,
  WeatherStageType,
  WeatherUserPreference
} from '../main/ets/domain/services/WeatherModels';
import { ITimelineWeatherService } from '../main/ets/domain/timeline/services/TimelineWeatherService';
import { ITimelineDistributionService } from '../main/ets/domain/timeline/services/TimelineDistributionService';
import {
  AdvanceAdjustApplyResult,
  AdvanceAdjustContext,
  AdvanceAdjustPreview,
  CompressionMode,
  CompressionPlan,
  CompressionSelectionContext,
  ITimelineCompressionService
} from '../main/ets/domain/timeline/services/TimelineCompressionService';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { ArrivalReminderEngine } from '../main/ets/infrastructure/services/ArrivalReminderEngine';
import { PlanItem } from '../main/ets/infrastructure/persistence/PlanRepositoryImpl';
import { PreferenceManager } from '../main/ets/common/utils/PreferenceManager';
import { PlanAppService, PlanRepository } from '../main/ets/viewmodel/PlanAppService';
import { TimelineViewModel } from '../main/ets/viewmodel/TimelineViewModel';

interface StatusCallItemAO {
  id: number;
  status: number;
}

interface SetCallItemAO {
  key: string;
  value: boolean;
}

interface PermissionResultAO {
  authResults: number[];
}

interface AppInfoAO {
  accessTokenId: number;
}

interface BundleInfoAO {
  appInfo: AppInfoAO;
}

function captureSyncErrorAO(action: () => void): string {
  try {
    action();
    return '';
  } catch (error) {
    if (error instanceof Error) {
      return error.message;
    }
    return JSON.stringify(error);
  }
}

async function captureAsyncErrorAO(action: () => Promise<void | Object>): Promise<string> {
  try {
    await action();
    return '';
  } catch (error) {
    if (error instanceof Error) {
      return error.message;
    }
    return JSON.stringify(error);
  }
}

function createSoftReplanResultAO(tag: string): SoftReplanApplyResult {
  return {
    success: true,
    rolledBack: false,
    errorCode: '',
    preview: {
      suggestionId: `suggestion_${tag}`,
      actionType: 'NONE',
      changedOrder: false,
      changedDurations: false,
      skippedNodeIds: [],
      affectedNodeIds: [],
      changeSummary: [],
      summary: `summary_${tag}`,
      riskDelta: 0
    }
  };
}

function createWeatherResultAO(stage: WeatherStageType = 'PLANNING'): WeatherContextBuildResult {
  const context: WeatherContext = {
    stage: stage,
    generatedAt: 123456,
    bindings: [],
    routeSuitability: {
      routeScore: 88,
      riskTags: [],
      summaryText: `route_${stage}`
    }
  };
  return {
    context: context,
    eventMap: new Map<number, PlanNodeWeatherBinding>(),
    sourceEvents: []
  };
}

function buildCompressionPlanAO(
  status: 'NO_ACTION' | 'COMPRESS_CONFIRM' | 'OVERLOAD' | 'FAIL_TOO_SHORT',
  msg: string
): CompressionPlan {
  return {
    status: status,
    msg: msg,
    affectedItems: []
  };
}

function buildPlanItemAO(id: number, status: number, title: string): PlanItem {
  return {
    id: id,
    title: title,
    createdAt: 1700000000000 + id,
    startDate: 1700000000000,
    status: status,
    deleteTime: 0,
    enableAutoAmapRoute: 1
  };
}

function createDistributionEventAO(id: number, status: number, lockStatus: number, gapMinutes: number, name: string): EventEntity {
  const event = new EventEntity(name, 1);
  event.id = id;
  event.status = status;
  event.lock_status = lockStatus;
  event.gap_minutes = gapMinutes;
  return event;
}

function fakeUiContextAO(): common.UIAbilityContext {
  const obj: Record<string, Object> = {};
  return obj as Object as common.UIAbilityContext;
}

function fakeHostContextAO(): Context {
  const obj: Record<string, Object> = {};
  return obj as Object as Context;
}

class WeatherServiceSpyAO implements ITimelineWeatherService {
  public throwMethod: string = '';
  public calls: string[] = [];
  public planningForce: boolean = false;
  public planningResult: WeatherContextBuildResult | null = null;
  public planningApplyForce: boolean = false;
  public executionForce: boolean = false;
  public executionTrigger: 'ENTER_EXECUTION' | 'LOCATION_CHANGE' | 'TIMER' | 'MANUAL' = 'MANUAL';
  public executionStage: WeatherStageType | undefined = undefined;
  public requestPlanId: number = -1;
  public requestSuggestionId: string = '';
  public requestMode: SoftReplanMode = 'PREVIEW';
  public applySuggestionId: string = '';
  public dismissSuggestionId: string = '';
  public schedulerPlanId: number | undefined = undefined;
  public schedulerStage: WeatherStageType | undefined = undefined;
  public scoreArg: number = 0;
  public maxAgeMs: number = -1;
  public resolvePlaceName: string = '';
  public resolveLat: number = 0;
  public resolveLng: number = 0;
  public resolveSource: 'add' | 'update' = 'add';
  public resolveFallbackLat: number = 0;
  public resolveFallbackLng: number = 0;
  public coordinateLatitude: number = 0;
  public coordinateLongitude: number = 0;
  public restorePlanId: number = -1;
  public featureEnabledArg: boolean = true;
  public preferenceArg: WeatherUserPreference = DEFAULT_WEATHER_USER_PREFERENCE;

  public replanResult: SoftReplanApplyResult = createSoftReplanResultAO('default');
  public suggestionResult: SoftReplanApplyResult = createSoftReplanResultAO('apply');
  public weatherPreference: WeatherUserPreference = DEFAULT_WEATHER_USER_PREFERENCE;
  public featureEnabled: boolean = true;
  public executionStageResult: boolean = true;
  public scoreText: string = 'score_text';
  public hintText: string = 'hint_text';
  public planningHintText: string = 'planning_hint_text';
  public displaySource: 'CURRENT' | 'NEXT_FALLBACK' | 'UNKNOWN' = 'CURRENT';
  public autoRefreshResult: boolean = true;
  public resolvePoint: GeoPointInput = { latitude: 31.2, longitude: 121.5 };
  public coordinateMissingResult: boolean = false;
  public validCoordinateResult: boolean = true;

  private beforeCall(name: string): void {
    this.calls.push(name);
    if (this.throwMethod === name) {
      throw new Error(`${name}_failed_ao`);
    }
  }

  public async refreshPlanningWeather(forceRefresh?: boolean): Promise<void> {
    this.beforeCall('refreshPlanningWeather');
    this.planningForce = forceRefresh === true;
  }

  public async applyPlanningWeatherResult(result: WeatherContextBuildResult, forceRefresh: boolean): Promise<void> {
    this.beforeCall('applyPlanningWeatherResult');
    this.planningResult = result;
    this.planningApplyForce = forceRefresh;
  }

  public async refreshExecutionWeather(
    forceRefresh?: boolean,
    trigger?: 'ENTER_EXECUTION' | 'LOCATION_CHANGE' | 'TIMER' | 'MANUAL',
    stage?: WeatherStageType
  ): Promise<void> {
    this.beforeCall('refreshExecutionWeather');
    this.executionForce = forceRefresh === true;
    this.executionTrigger = trigger ?? 'MANUAL';
    this.executionStage = stage;
  }

  public async requestSoftReplan(planId: number, suggestionId: string, mode: SoftReplanMode): Promise<SoftReplanApplyResult> {
    this.beforeCall('requestSoftReplan');
    this.requestPlanId = planId;
    this.requestSuggestionId = suggestionId;
    this.requestMode = mode;
    return this.replanResult;
  }

  public async applyWeatherSuggestion(suggestionId: string): Promise<SoftReplanApplyResult> {
    this.beforeCall('applyWeatherSuggestion');
    this.applySuggestionId = suggestionId;
    return this.suggestionResult;
  }

  public dismissExecutionSuggestion(suggestionId: string): void {
    this.beforeCall('dismissExecutionSuggestion');
    this.dismissSuggestionId = suggestionId;
  }

  public isExecutionWeatherStage(): boolean {
    this.beforeCall('isExecutionWeatherStage');
    return this.executionStageResult;
  }

  public startExecutionWeatherScheduler(planId?: number, stage?: WeatherStageType): void {
    this.beforeCall('startExecutionWeatherScheduler');
    this.schedulerPlanId = planId;
    this.schedulerStage = stage;
  }

  public stopExecutionWeatherScheduler(): void {
    this.beforeCall('stopExecutionWeatherScheduler');
  }

  public getWeatherUserPreference(): WeatherUserPreference {
    this.beforeCall('getWeatherUserPreference');
    return this.weatherPreference;
  }

  public isWeatherFeatureEnabled(): boolean {
    this.beforeCall('isWeatherFeatureEnabled');
    return this.featureEnabled;
  }

  public buildWeatherScoreExplanation(score: number): string {
    this.beforeCall('buildWeatherScoreExplanation');
    this.scoreArg = score;
    return this.scoreText;
  }

  public buildWeatherHintExplanation(): string {
    this.beforeCall('buildWeatherHintExplanation');
    return this.hintText;
  }

  public buildPlanningWeatherHintExplanation(): string {
    this.beforeCall('buildPlanningWeatherHintExplanation');
    return this.planningHintText;
  }

  public getExecutionWeatherDisplaySource(): 'CURRENT' | 'NEXT_FALLBACK' | 'UNKNOWN' {
    this.beforeCall('getExecutionWeatherDisplaySource');
    return this.displaySource;
  }

  public shouldAutoRefreshPlanningWeather(maxAgeMs?: number): boolean {
    this.beforeCall('shouldAutoRefreshPlanningWeather');
    this.maxAgeMs = maxAgeMs ?? 24 * 60 * 60 * 1000;
    return this.autoRefreshResult;
  }

  public clearWeatherRuntimeState(): void {
    this.beforeCall('clearWeatherRuntimeState');
  }

  public async resolveCoordinatesForPlaceName(
    placeName: string,
    lat?: number,
    lng?: number,
    source: 'add' | 'update' = 'add',
    fallbackLat: number = 0,
    fallbackLng: number = 0
  ): Promise<GeoPointInput> {
    this.beforeCall('resolveCoordinatesForPlaceName');
    this.resolvePlaceName = placeName;
    this.resolveLat = lat ?? -999;
    this.resolveLng = lng ?? -999;
    this.resolveSource = source;
    this.resolveFallbackLat = fallbackLat;
    this.resolveFallbackLng = fallbackLng;
    return this.resolvePoint;
  }

  public isCoordinateMissingForWeather(latitude: number, longitude: number): boolean {
    this.beforeCall('isCoordinateMissingForWeather');
    this.coordinateLatitude = latitude;
    this.coordinateLongitude = longitude;
    return this.coordinateMissingResult;
  }

  public isValidCoordinate(latitude: number, longitude: number): boolean {
    this.beforeCall('isValidCoordinate');
    this.coordinateLatitude = latitude;
    this.coordinateLongitude = longitude;
    return this.validCoordinateResult;
  }

  public async reloadWeatherUserPreference(): Promise<void> {
    this.beforeCall('reloadWeatherUserPreference');
  }

  public restorePlanningWeatherSnapshot(planId: number): void {
    this.beforeCall('restorePlanningWeatherSnapshot');
    this.restorePlanId = planId;
  }

  public async setWeatherFeatureEnabled(enabled: boolean): Promise<void> {
    this.beforeCall('setWeatherFeatureEnabled');
    this.featureEnabledArg = enabled;
  }

  public async updateWeatherUserPreference(preference: WeatherUserPreference): Promise<void> {
    this.beforeCall('updateWeatherUserPreference');
    this.preferenceArg = preference;
  }
}

class DistributionServiceSpyAO implements ITimelineDistributionService {
  public throwMethod: string = '';
  public calls: string[] = [];
  public targetId: number = -1;
  public syncItemId: number = -1;
  public candidateGapId: number = -1;
  public safetyCandidateId: number = -1;
  public safetyGapId: number = -1;
  public previewGapId: number = -1;
  public previewCandidateCount: number = 0;
  public previewSelectedSize: number = 0;
  public previewStrategy: 'EQUAL' | 'SMART' = 'EQUAL';
  public previousNameGapId: number = -1;
  public applyDistributionSize: number = 0;

  public candidatesResult: EventEntity[] = [];
  public safetyCapResult: number = 30;
  public previewResult: Map<number, number> = new Map<number, number>();
  public sortedGapsResult: EventEntity[] = [];
  public previousNameResult: string = '前一站';

  private beforeCall(name: string): void {
    this.calls.push(name);
    if (this.throwMethod === name) {
      throw new Error(`${name}_failed_ao`);
    }
  }

  public async resolveGapByDistribution(targetItem: EventEntity): Promise<void> {
    this.beforeCall('resolveGapByDistribution');
    this.targetId = targetItem?.id ?? -1;
  }

  public resolveGapBySync(item: EventEntity): void {
    this.beforeCall('resolveGapBySync');
    this.syncItemId = item?.id ?? -1;
  }

  public getDistributionCandidates(gapItem: EventEntity): EventEntity[] {
    this.beforeCall('getDistributionCandidates');
    this.candidateGapId = gapItem?.id ?? -1;
    return this.candidatesResult;
  }

  public getSafetyCap(candidate: EventEntity, gapItem: EventEntity): number {
    this.beforeCall('getSafetyCap');
    this.safetyCandidateId = candidate?.id ?? -1;
    this.safetyGapId = gapItem?.id ?? -1;
    return this.safetyCapResult;
  }

  public calculateDistributionPreview(
    gapItem: EventEntity,
    candidates: EventEntity[],
    selectedIds: Set<number>,
    strategy: 'EQUAL' | 'SMART'
  ): Map<number, number> {
    this.beforeCall('calculateDistributionPreview');
    this.previewGapId = gapItem?.id ?? -1;
    this.previewCandidateCount = candidates.length;
    this.previewSelectedSize = selectedIds.size;
    this.previewStrategy = strategy;
    return this.previewResult;
  }

  public getSortedGaps(): EventEntity[] {
    this.beforeCall('getSortedGaps');
    return this.sortedGapsResult;
  }

  public getPreviousItemName(gapItem: EventEntity): string {
    this.beforeCall('getPreviousItemName');
    this.previousNameGapId = gapItem?.id ?? -1;
    return this.previousNameResult;
  }

  public async applyDistribution(distributionMap: Map<number, number>): Promise<void> {
    this.beforeCall('applyDistribution');
    this.applyDistributionSize = distributionMap.size;
  }
}

class DistributionHostAO implements ITimelineDistributionCoordinatorHost {
  public events: EventEntity[];

  constructor(events: EventEntity[]) {
    this.events = events;
  }
}

class CompressionServiceSpyAO implements ITimelineCompressionService {
  public throwMethod: string = '';
  public calls: string[] = [];
  public lastTargetIndex: number = -1;
  public lastTime: string = '';
  public lastForcedGap: number = -1;
  public lastSelectedSize: number = 0;
  public lastMode: CompressionMode = 'RATIO';
  public appliedPlanStatus: string = '';
  public smartFixTargetId: number = -1;
  public naturalArrivalResult: number = 600;

  public compressionPlanResult: CompressionPlan = buildCompressionPlanAO('COMPRESS_CONFIRM', 'compress_ok');
  public selectionContextResult: CompressionSelectionContext | null = null;
  public advanceContextResult: AdvanceAdjustContext | null = null;
  public previewResult: AdvanceAdjustPreview = {
    valid: true,
    message: 'preview_ok',
    selectedCount: 0,
    shiftMinutes: 0,
    requiredGapMinutes: 0,
    remainingGapMinutes: 0,
    firstNewStartTime: '',
    lastNewEndTime: '',
    items: []
  };
  public applyResult: AdvanceAdjustApplyResult = {
    success: true,
    appliedCount: 0,
    appliedShiftMinutes: 0,
    remainingGapMinutes: 0,
    message: 'apply_ok'
  };
  public selectionPlanResult: CompressionPlan = buildCompressionPlanAO('OVERLOAD', 'selection_overload');
  public delayPlanResult: CompressionPlan = buildCompressionPlanAO('COMPRESS_CONFIRM', 'delay_ok');
  public forceCompressPlanResult: CompressionPlan = buildCompressionPlanAO('FAIL_TOO_SHORT', 'too_short');

  private beforeCall(name: string): void {
    this.calls.push(name);
    if (this.throwMethod === name) {
      throw new Error(`${name}_failed_ao`);
    }
  }

  public async fixConflict(_item: EventEntity, _shiftMinutes: number): Promise<void> {
    this.beforeCall('fixConflict');
  }

  public async smartFixConflict(targetItem: EventEntity): Promise<void> {
    this.beforeCall('smartFixConflict');
    this.smartFixTargetId = targetItem?.id ?? -1;
  }

  public calculateCompressionPlan(targetIndex: number, newTimeStr: string, forcedGapMinutes?: number): CompressionPlan {
    this.beforeCall('calculateCompressionPlan');
    this.lastTargetIndex = targetIndex;
    this.lastTime = newTimeStr;
    this.lastForcedGap = forcedGapMinutes ?? -1;
    return this.compressionPlanResult;
  }

  public buildCompressionSelectionContext(targetIndex: number, targetTime: string, forcedGapMinutes?: number): CompressionSelectionContext | null {
    this.beforeCall('buildCompressionSelectionContext');
    this.lastTargetIndex = targetIndex;
    this.lastTime = targetTime;
    this.lastForcedGap = forcedGapMinutes ?? -1;
    return this.selectionContextResult;
  }

  public buildAdvanceAdjustContext(targetIndex: number): AdvanceAdjustContext | null {
    this.beforeCall('buildAdvanceAdjustContext');
    this.lastTargetIndex = targetIndex;
    return this.advanceContextResult;
  }

  public previewAdvanceAdjust(
    targetIndex: number,
    selectedIds: Set<number>,
    targetStartTime: string,
    forcedGapMinutes?: number
  ): AdvanceAdjustPreview {
    this.beforeCall('previewAdvanceAdjust');
    this.lastTargetIndex = targetIndex;
    this.lastSelectedSize = selectedIds.size;
    this.lastTime = targetStartTime;
    this.lastForcedGap = forcedGapMinutes ?? -1;
    return this.previewResult;
  }

  public async applyAdvanceAdjust(
    targetIndex: number,
    selectedIds: Set<number>,
    targetStartTime: string,
    forcedGapMinutes?: number
  ): Promise<AdvanceAdjustApplyResult> {
    this.beforeCall('applyAdvanceAdjust');
    this.lastTargetIndex = targetIndex;
    this.lastSelectedSize = selectedIds.size;
    this.lastTime = targetStartTime;
    this.lastForcedGap = forcedGapMinutes ?? -1;
    return this.applyResult;
  }

  public calculateCompressionPlanBySelection(
    targetIndex: number,
    targetTime: string,
    selectedIds: Set<number>,
    mode: CompressionMode = 'RATIO',
    forcedGapMinutes?: number
  ): CompressionPlan {
    this.beforeCall('calculateCompressionPlanBySelection');
    this.lastTargetIndex = targetIndex;
    this.lastTime = targetTime;
    this.lastSelectedSize = selectedIds.size;
    this.lastMode = mode;
    this.lastForcedGap = forcedGapMinutes ?? -1;
    return this.selectionPlanResult;
  }

  public applyCompressionPlan(plan: CompressionPlan): void {
    this.beforeCall('applyCompressionPlan');
    this.appliedPlanStatus = plan.status;
  }

  public calculateDelayPlan(targetIndex: number): CompressionPlan {
    this.beforeCall('calculateDelayPlan');
    this.lastTargetIndex = targetIndex;
    return this.delayPlanResult;
  }

  public calculateForceCompressPlan(targetIndex: number, newTimeStr: string): CompressionPlan {
    this.beforeCall('calculateForceCompressPlan');
    this.lastTargetIndex = targetIndex;
    this.lastTime = newTimeStr;
    return this.forceCompressPlanResult;
  }

  public calculateNaturalArrival(targetIndex: number): number {
    this.beforeCall('calculateNaturalArrival');
    this.lastTargetIndex = targetIndex;
    return this.naturalArrivalResult;
  }
}

class PlanRepositorySpyAO implements PlanRepository {
  public throwMethod: string = '';
  public createResult: number = 1001;
  public purgeResult: number = 0;
  public planList: PlanItem[] = [];
  public archivedList: PlanItem[] = [];
  public trashList: PlanItem[] = [];
  public createTitle: string = '';
  public createStartDate: number = 0;
  public statusCalls: StatusCallItemAO[] = [];
  public softDeleteCalls: number[] = [];
  public restoreCalls: number[] = [];
  public hardDeleteCalls: number[] = [];
  public purgeCalls: number = 0;

  private beforeCall(name: string): void {
    if (this.throwMethod === name) {
      throw new Error(`${name}_failed_ao`);
    }
  }

  public async createPlan(title: string, startDate: number): Promise<number> {
    this.beforeCall('createPlan');
    this.createTitle = title;
    this.createStartDate = startDate;
    return this.createResult;
  }

  public async purgeOldTrash(): Promise<number> {
    this.beforeCall('purgeOldTrash');
    this.purgeCalls += 1;
    return this.purgeResult;
  }

  public async getPlanList(): Promise<PlanItem[]> {
    this.beforeCall('getPlanList');
    return this.planList;
  }

  public async getArchivedPlans(): Promise<PlanItem[]> {
    this.beforeCall('getArchivedPlans');
    return this.archivedList;
  }

  public async getTrashPlans(): Promise<PlanItem[]> {
    this.beforeCall('getTrashPlans');
    return this.trashList;
  }

  public async updatePlanStatus(id: number, status: number): Promise<void> {
    this.beforeCall('updatePlanStatus');
    const item: StatusCallItemAO = { id: id, status: status };
    this.statusCalls.push(item);
  }

  public async softDeletePlan(id: number): Promise<void> {
    this.beforeCall('softDeletePlan');
    this.softDeleteCalls.push(id);
  }

  public async restorePlan(id: number): Promise<void> {
    this.beforeCall('restorePlan');
    this.restoreCalls.push(id);
  }

  public async hardDeletePlan(id: number): Promise<void> {
    this.beforeCall('hardDeletePlan');
    this.hardDeleteCalls.push(id);
  }
}

class PreferenceInstanceStubAO {
  public throwOnInit: boolean = false;
  public throwOnGet: boolean = false;
  public throwOnSet: boolean = false;
  public initCount: number = 0;
  public getCalls: string[] = [];
  public setCalls: SetCallItemAO[] = [];
  public values: Map<string, boolean> = new Map<string, boolean>();

  public async init(_ctx: Object): Promise<void> {
    this.initCount += 1;
    if (this.throwOnInit) {
      throw new Error('pref_init_failed_ao');
    }
  }

  public async getValue(key: string, defaultValue: boolean): Promise<boolean> {
    this.getCalls.push(key);
    if (this.throwOnGet) {
      throw new Error('pref_get_failed_ao');
    }
    return this.values.has(key) ? (this.values.get(key) ?? defaultValue) : defaultValue;
  }

  public async setValue(key: string, value: boolean): Promise<void> {
    this.setCalls.push({ key: key, value: value });
    if (this.throwOnSet) {
      throw new Error('pref_set_failed_ao');
    }
    this.values.set(key, value);
  }
}

class PreferenceHooksAO {
  private readonly originGetInstance: Object;

  constructor() {
    this.originGetInstance = Reflect.get(PreferenceManager, 'getInstance') as Object;
  }

  public setInstance(instance: Object): void {
    Reflect.set(PreferenceManager, 'getInstance', (): Object => instance);
  }

  public restore(): void {
    Reflect.set(PreferenceManager, 'getInstance', this.originGetInstance);
  }
}

class ArrivalEngineStubAO {
  public startCalls: number = 0;
  public stopCalls: number = 0;
  public requestCalls: number = 0;
  public lastPlanId: number = -1;
  public lastReason: string = '';
  public throwOnStart: boolean = false;
  public throwOnStop: boolean = false;
  public throwOnRequest: boolean = false;

  public start(planId: number, _vm: TimelineViewModel, _hostContext: Context): void {
    this.startCalls += 1;
    this.lastPlanId = planId;
    if (this.throwOnStart) {
      throw new Error('arrival_start_failed_ao');
    }
  }

  public stop(): void {
    this.stopCalls += 1;
    if (this.throwOnStop) {
      throw new Error('arrival_stop_failed_ao');
    }
  }

  public async requestImmediateDetection(reason: string): Promise<void> {
    this.requestCalls += 1;
    this.lastReason = reason;
    if (this.throwOnRequest) {
      throw new Error('arrival_request_failed_ao');
    }
  }
}

class ArrivalEngineHooksAO {
  private readonly originGetInstance: Object;

  constructor() {
    this.originGetInstance = Reflect.get(ArrivalReminderEngine, 'getInstance') as Object;
  }

  public setInstance(instance: Object): void {
    Reflect.set(ArrivalReminderEngine, 'getInstance', (): Object => instance);
  }

  public restore(): void {
    Reflect.set(ArrivalReminderEngine, 'getInstance', this.originGetInstance);
  }
}

class NotificationHooksAO {
  private readonly originIsEnabled: Object;
  private readonly originRequestEnable: Object;

  constructor() {
    const nmObj: Object = Reflect.get(globalThis, 'notificationManager') as Object;
    this.originIsEnabled = Reflect.get(nmObj, 'isNotificationEnabled') as Object;
    this.originRequestEnable = Reflect.get(nmObj, 'requestEnableNotification') as Object;
  }

  public setIsEnabled(handler: () => boolean): void {
    const nmObj: Object = Reflect.get(globalThis, 'notificationManager') as Object;
    Reflect.set(nmObj, 'isNotificationEnabled', handler);
  }

  public setRequestEnable(handler: (hostContext: common.UIAbilityContext) => Promise<void>): void {
    const nmObj: Object = Reflect.get(globalThis, 'notificationManager') as Object;
    Reflect.set(nmObj, 'requestEnableNotification', handler);
  }

  public restore(): void {
    const nmObj: Object = Reflect.get(globalThis, 'notificationManager') as Object;
    Reflect.set(nmObj, 'isNotificationEnabled', this.originIsEnabled);
    Reflect.set(nmObj, 'requestEnableNotification', this.originRequestEnable);
  }
}

class PermissionManagerStubAO {
  public checkResult: number = abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
  public requestResults: number[] = [0];
  public throwOnCheck: boolean = false;
  public throwOnRequest: boolean = false;

  public async checkAccessToken(_tokenId: number, _permissionName: string): Promise<number> {
    if (this.throwOnCheck) {
      throw new Error('check_access_failed_ao');
    }
    return this.checkResult;
  }

  public async requestPermissionsFromUser(
    _hostContext: common.UIAbilityContext,
    _permissions: string[]
  ): Promise<PermissionResultAO> {
    if (this.throwOnRequest) {
      throw new Error('request_permission_failed_ao');
    }
    const result: PermissionResultAO = {
      authResults: this.requestResults
    };
    return result;
  }
}

class AbilityHooksAO {
  private readonly originCreateAtManager: Object;
  private readonly originGetBundleInfoForSelf: Object;

  constructor() {
    const aacObj: Object = Reflect.get(globalThis, 'abilityAccessCtrl') as Object;
    const bmObj: Object = Reflect.get(globalThis, 'bundleManager') as Object;
    this.originCreateAtManager = Reflect.get(aacObj, 'createAtManager') as Object;
    this.originGetBundleInfoForSelf = Reflect.get(bmObj, 'getBundleInfoForSelf') as Object;
  }

  public setAtManager(manager: Object): void {
    const aacObj: Object = Reflect.get(globalThis, 'abilityAccessCtrl') as Object;
    Reflect.set(aacObj, 'createAtManager', (): Object => manager);
  }

  public setBundleInfo(tokenId: number): void {
    const bmObj: Object = Reflect.get(globalThis, 'bundleManager') as Object;
    Reflect.set(bmObj, 'getBundleInfoForSelf', async (): Promise<BundleInfoAO> => {
      const appInfo: AppInfoAO = { accessTokenId: tokenId };
      const info: BundleInfoAO = { appInfo: appInfo };
      return info;
    });
  }

  public setBundleInfoThrow(): void {
    const bmObj: Object = Reflect.get(globalThis, 'bundleManager') as Object;
    Reflect.set(bmObj, 'getBundleInfoForSelf', async (): Promise<BundleInfoAO> => {
      throw new Error('bundle_info_failed_ao');
    });
  }

  public restore(): void {
    const aacObj: Object = Reflect.get(globalThis, 'abilityAccessCtrl') as Object;
    const bmObj: Object = Reflect.get(globalThis, 'bundleManager') as Object;
    Reflect.set(aacObj, 'createAtManager', this.originCreateAtManager);
    Reflect.set(bmObj, 'getBundleInfoForSelf', this.originGetBundleInfoForSelf);
  }
}

export default function phase2BatchAOTest() {
  describe('phase2BatchAO_timeline_weather_coordinator', () => {
    it('normal: weather_refresh_planning_should_forward_true_force_flag', 0, async () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      await coordinator.refreshPlanningWeather(true);
      // Assert
      expect(service.calls[0]).assertEqual('refreshPlanningWeather');
      expect(service.planningForce).assertTrue();
    });

    it('boundary: weather_refresh_planning_should_use_default_false_flag', 0, async () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      await coordinator.refreshPlanningWeather();
      // Assert
      expect(service.calls[0]).assertEqual('refreshPlanningWeather');
      expect(service.planningForce).assertFalse();
    });

    it('invalid: weather_refresh_planning_should_bubble_service_error', 0, async () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      service.throwMethod = 'refreshPlanningWeather';
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      const message = await captureAsyncErrorAO(async (): Promise<void> => {
        await coordinator.refreshPlanningWeather(true);
      });
      // Assert
      expect(message).assertEqual('refreshPlanningWeather_failed_ao');
    });

    it('normal: weather_apply_planning_result_should_forward_result_and_true', 0, async () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      const coordinator = new TimelineWeatherCoordinator(service);
      const result = createWeatherResultAO('PLANNING');
      // Act
      await coordinator.applyPlanningWeatherResult(result, true);
      // Assert
      expect(service.calls[0]).assertEqual('applyPlanningWeatherResult');
      expect(service.planningResult?.context.stage ?? '').assertEqual('PLANNING');
      expect(service.planningApplyForce).assertTrue();
    });

    it('boundary: weather_apply_planning_result_should_forward_false_force_flag', 0, async () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      const coordinator = new TimelineWeatherCoordinator(service);
      const result = createWeatherResultAO('CONFIRMED');
      // Act
      await coordinator.applyPlanningWeatherResult(result, false);
      // Assert
      expect(service.planningResult?.context.stage ?? '').assertEqual('CONFIRMED');
      expect(service.planningApplyForce).assertFalse();
    });

    it('invalid: weather_apply_planning_result_should_bubble_service_error', 0, async () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      service.throwMethod = 'applyPlanningWeatherResult';
      const coordinator = new TimelineWeatherCoordinator(service);
      const result = createWeatherResultAO('PLANNING');
      // Act
      const message = await captureAsyncErrorAO(async (): Promise<void> => {
        await coordinator.applyPlanningWeatherResult(result, true);
      });
      // Assert
      expect(message).assertEqual('applyPlanningWeatherResult_failed_ao');
    });

    it('normal: weather_refresh_execution_should_forward_explicit_args', 0, async () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      await coordinator.refreshExecutionWeather(true, 'TIMER', 'IN_PROGRESS');
      // Assert
      expect(service.calls[0]).assertEqual('refreshExecutionWeather');
      expect(service.executionForce).assertTrue();
      expect(service.executionTrigger).assertEqual('TIMER');
      expect(service.executionStage ?? '').assertEqual('IN_PROGRESS');
    });

    it('boundary: weather_refresh_execution_should_use_manual_defaults', 0, async () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      await coordinator.refreshExecutionWeather();
      // Assert
      expect(service.executionForce).assertFalse();
      expect(service.executionTrigger).assertEqual('MANUAL');
      expect(service.executionStage === undefined).assertTrue();
    });

    it('invalid: weather_refresh_execution_should_bubble_service_error', 0, async () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      service.throwMethod = 'refreshExecutionWeather';
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      const message = await captureAsyncErrorAO(async (): Promise<void> => {
        await coordinator.refreshExecutionWeather(false, 'LOCATION_CHANGE', 'EXECUTION');
      });
      // Assert
      expect(message).assertEqual('refreshExecutionWeather_failed_ao');
    });

    it('normal: weather_request_soft_replan_should_return_service_result', 0, async () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      service.replanResult = createSoftReplanResultAO('normal');
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      const result = await coordinator.requestSoftReplan(10, 'sg_10', 'APPLY');
      // Assert
      expect(service.requestPlanId).assertEqual(10);
      expect(service.requestSuggestionId).assertEqual('sg_10');
      expect(service.requestMode).assertEqual('APPLY');
      expect(result.preview.suggestionId).assertEqual('suggestion_normal');
    });

    it('boundary: weather_request_soft_replan_should_forward_zero_plan_and_preview_mode', 0, async () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      service.replanResult = createSoftReplanResultAO('boundary');
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      const result = await coordinator.requestSoftReplan(0, '', 'PREVIEW');
      // Assert
      expect(service.requestPlanId).assertEqual(0);
      expect(service.requestSuggestionId).assertEqual('');
      expect(service.requestMode).assertEqual('PREVIEW');
      expect(result.preview.suggestionId).assertEqual('suggestion_boundary');
    });

    it('invalid: weather_request_soft_replan_should_bubble_service_error', 0, async () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      service.throwMethod = 'requestSoftReplan';
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      const message = await captureAsyncErrorAO(async (): Promise<void> => {
        await coordinator.requestSoftReplan(-1, 'bad', 'APPLY');
      });
      // Assert
      expect(message).assertEqual('requestSoftReplan_failed_ao');
    });

    it('normal: weather_apply_suggestion_should_return_apply_result', 0, async () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      service.suggestionResult = createSoftReplanResultAO('apply_normal');
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      const result = await coordinator.applyWeatherSuggestion('sg_apply');
      // Assert
      expect(service.applySuggestionId).assertEqual('sg_apply');
      expect(result.preview.suggestionId).assertEqual('suggestion_apply_normal');
    });

    it('boundary: weather_apply_suggestion_should_allow_empty_id', 0, async () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      const result = await coordinator.applyWeatherSuggestion('');
      // Assert
      expect(service.applySuggestionId).assertEqual('');
      expect(result.success).assertTrue();
    });

    it('invalid: weather_apply_suggestion_should_bubble_service_error', 0, async () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      service.throwMethod = 'applyWeatherSuggestion';
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      const message = await captureAsyncErrorAO(async (): Promise<void> => {
        await coordinator.applyWeatherSuggestion('sg_bad');
      });
      // Assert
      expect(message).assertEqual('applyWeatherSuggestion_failed_ao');
    });

    it('normal: weather_dismiss_suggestion_should_forward_identifier', 0, () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      coordinator.dismissExecutionSuggestion('dismiss_1');
      // Assert
      expect(service.calls[0]).assertEqual('dismissExecutionSuggestion');
      expect(service.dismissSuggestionId).assertEqual('dismiss_1');
    });

    it('boundary: weather_dismiss_suggestion_should_allow_empty_identifier', 0, () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      coordinator.dismissExecutionSuggestion('');
      // Assert
      expect(service.dismissSuggestionId).assertEqual('');
    });

    it('invalid: weather_dismiss_suggestion_should_bubble_service_error', 0, () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      service.throwMethod = 'dismissExecutionSuggestion';
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      const message = captureSyncErrorAO((): void => {
        coordinator.dismissExecutionSuggestion('boom');
      });
      // Assert
      expect(message).assertEqual('dismissExecutionSuggestion_failed_ao');
    });

    it('normal: weather_is_execution_stage_should_return_true', 0, () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      service.executionStageResult = true;
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      const result = coordinator.isExecutionWeatherStage();
      // Assert
      expect(result).assertTrue();
    });

    it('boundary: weather_is_execution_stage_should_return_false', 0, () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      service.executionStageResult = false;
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      const result = coordinator.isExecutionWeatherStage();
      // Assert
      expect(result).assertFalse();
    });

    it('invalid: weather_is_execution_stage_should_bubble_service_error', 0, () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      service.throwMethod = 'isExecutionWeatherStage';
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      const message = captureSyncErrorAO((): void => {
        coordinator.isExecutionWeatherStage();
      });
      // Assert
      expect(message).assertEqual('isExecutionWeatherStage_failed_ao');
    });

    it('normal: weather_start_scheduler_should_forward_explicit_plan_and_stage', 0, () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      coordinator.startExecutionWeatherScheduler(66, 'READY');
      // Assert
      expect(service.schedulerPlanId ?? -1).assertEqual(66);
      expect(service.schedulerStage ?? '').assertEqual('READY');
    });

    it('boundary: weather_start_scheduler_should_allow_undefined_arguments', 0, () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      coordinator.startExecutionWeatherScheduler();
      // Assert
      expect(service.schedulerPlanId === undefined).assertTrue();
      expect(service.schedulerStage === undefined).assertTrue();
    });

    it('invalid: weather_start_scheduler_should_bubble_service_error', 0, () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      service.throwMethod = 'startExecutionWeatherScheduler';
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      const message = captureSyncErrorAO((): void => {
        coordinator.startExecutionWeatherScheduler(1, 'EXECUTION');
      });
      // Assert
      expect(message).assertEqual('startExecutionWeatherScheduler_failed_ao');
    });

    it('normal: weather_stop_scheduler_should_delegate_once', 0, () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      coordinator.stopExecutionWeatherScheduler();
      // Assert
      expect(service.calls[0]).assertEqual('stopExecutionWeatherScheduler');
    });

    it('boundary: weather_stop_scheduler_should_allow_repeated_calls', 0, () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      coordinator.stopExecutionWeatherScheduler();
      coordinator.stopExecutionWeatherScheduler();
      // Assert
      expect(service.calls.length).assertEqual(2);
    });

    it('invalid: weather_stop_scheduler_should_bubble_service_error', 0, () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      service.throwMethod = 'stopExecutionWeatherScheduler';
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      const message = captureSyncErrorAO((): void => {
        coordinator.stopExecutionWeatherScheduler();
      });
      // Assert
      expect(message).assertEqual('stopExecutionWeatherScheduler_failed_ao');
    });

    it('normal: weather_get_preference_should_return_service_preference', 0, () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      service.weatherPreference = {
        heatSensitivity: 2,
        rainSensitivity: 1,
        weatherRiskTolerance: 0
      };
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      const preference = coordinator.getWeatherUserPreference();
      // Assert
      expect(preference.heatSensitivity).assertEqual(2);
      expect(preference.rainSensitivity).assertEqual(1);
      expect(preference.weatherRiskTolerance).assertEqual(0);
    });

    it('boundary: weather_get_preference_should_allow_default_preference', 0, () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      service.weatherPreference = DEFAULT_WEATHER_USER_PREFERENCE;
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      const preference = coordinator.getWeatherUserPreference();
      // Assert
      expect(preference.heatSensitivity).assertEqual(DEFAULT_WEATHER_USER_PREFERENCE.heatSensitivity);
    });

    it('invalid: weather_get_preference_should_bubble_service_error', 0, () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      service.throwMethod = 'getWeatherUserPreference';
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      const message = captureSyncErrorAO((): void => {
        coordinator.getWeatherUserPreference();
      });
      // Assert
      expect(message).assertEqual('getWeatherUserPreference_failed_ao');
    });

    it('normal: weather_is_feature_enabled_should_return_true', 0, () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      service.featureEnabled = true;
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      const enabled = coordinator.isWeatherFeatureEnabled();
      // Assert
      expect(enabled).assertTrue();
    });

    it('boundary: weather_is_feature_enabled_should_return_false', 0, () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      service.featureEnabled = false;
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      const enabled = coordinator.isWeatherFeatureEnabled();
      // Assert
      expect(enabled).assertFalse();
    });

    it('invalid: weather_is_feature_enabled_should_bubble_service_error', 0, () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      service.throwMethod = 'isWeatherFeatureEnabled';
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      const message = captureSyncErrorAO((): void => {
        coordinator.isWeatherFeatureEnabled();
      });
      // Assert
      expect(message).assertEqual('isWeatherFeatureEnabled_failed_ao');
    });

    it('normal: weather_score_explanation_should_return_service_text', 0, () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      service.scoreText = 'score_normal_text';
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      const text = coordinator.buildWeatherScoreExplanation(92);
      // Assert
      expect(service.scoreArg).assertEqual(92);
      expect(text).assertEqual('score_normal_text');
    });

    it('boundary: weather_score_explanation_should_allow_zero_score', 0, () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      service.scoreText = 'score_zero_text';
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      const text = coordinator.buildWeatherScoreExplanation(0);
      // Assert
      expect(service.scoreArg).assertEqual(0);
      expect(text).assertEqual('score_zero_text');
    });

    it('invalid: weather_score_explanation_should_bubble_service_error', 0, () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      service.throwMethod = 'buildWeatherScoreExplanation';
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      const message = captureSyncErrorAO((): void => {
        coordinator.buildWeatherScoreExplanation(-1);
      });
      // Assert
      expect(message).assertEqual('buildWeatherScoreExplanation_failed_ao');
    });

    it('normal: weather_hint_explanation_should_return_service_text', 0, () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      service.hintText = 'hint_normal_text';
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      const text = coordinator.buildWeatherHintExplanation();
      // Assert
      expect(text).assertEqual('hint_normal_text');
    });

    it('boundary: weather_hint_explanation_should_allow_empty_text', 0, () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      service.hintText = '';
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      const text = coordinator.buildWeatherHintExplanation();
      // Assert
      expect(text).assertEqual('');
    });

    it('invalid: weather_hint_explanation_should_bubble_service_error', 0, () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      service.throwMethod = 'buildWeatherHintExplanation';
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      const message = captureSyncErrorAO((): void => {
        coordinator.buildWeatherHintExplanation();
      });
      // Assert
      expect(message).assertEqual('buildWeatherHintExplanation_failed_ao');
    });

    it('normal: weather_planning_hint_explanation_should_return_service_text', 0, () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      service.planningHintText = 'planning_hint_normal_text';
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      const text = coordinator.buildPlanningWeatherHintExplanation();
      // Assert
      expect(text).assertEqual('planning_hint_normal_text');
    });

    it('boundary: weather_planning_hint_explanation_should_allow_empty_text', 0, () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      service.planningHintText = '';
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      const text = coordinator.buildPlanningWeatherHintExplanation();
      // Assert
      expect(text).assertEqual('');
    });

    it('invalid: weather_planning_hint_explanation_should_bubble_service_error', 0, () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      service.throwMethod = 'buildPlanningWeatherHintExplanation';
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      const message = captureSyncErrorAO((): void => {
        coordinator.buildPlanningWeatherHintExplanation();
      });
      // Assert
      expect(message).assertEqual('buildPlanningWeatherHintExplanation_failed_ao');
    });

    it('normal: weather_display_source_should_return_current', 0, () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      service.displaySource = 'CURRENT';
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      const source = coordinator.getExecutionWeatherDisplaySource();
      // Assert
      expect(source).assertEqual('CURRENT');
    });

    it('boundary: weather_display_source_should_return_unknown', 0, () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      service.displaySource = 'UNKNOWN';
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      const source = coordinator.getExecutionWeatherDisplaySource();
      // Assert
      expect(source).assertEqual('UNKNOWN');
    });

    it('invalid: weather_display_source_should_bubble_service_error', 0, () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      service.throwMethod = 'getExecutionWeatherDisplaySource';
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      const message = captureSyncErrorAO((): void => {
        coordinator.getExecutionWeatherDisplaySource();
      });
      // Assert
      expect(message).assertEqual('getExecutionWeatherDisplaySource_failed_ao');
    });

    it('normal: weather_should_auto_refresh_should_forward_custom_threshold', 0, () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      service.autoRefreshResult = true;
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      const shouldRefresh = coordinator.shouldAutoRefreshPlanningWeather(5000);
      // Assert
      expect(shouldRefresh).assertTrue();
      expect(service.maxAgeMs).assertEqual(5000);
    });

    it('boundary: weather_should_auto_refresh_should_use_default_day_threshold', 0, () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      service.autoRefreshResult = false;
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      coordinator.shouldAutoRefreshPlanningWeather();
      // Assert
      expect(service.maxAgeMs).assertEqual(24 * 60 * 60 * 1000);
    });

    it('invalid: weather_should_auto_refresh_should_bubble_service_error', 0, () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      service.throwMethod = 'shouldAutoRefreshPlanningWeather';
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      const message = captureSyncErrorAO((): void => {
        coordinator.shouldAutoRefreshPlanningWeather(-1);
      });
      // Assert
      expect(message).assertEqual('shouldAutoRefreshPlanningWeather_failed_ao');
    });

    it('normal: weather_clear_runtime_state_should_delegate_once', 0, () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      coordinator.clearWeatherRuntimeState();
      // Assert
      expect(service.calls[0]).assertEqual('clearWeatherRuntimeState');
    });

    it('boundary: weather_clear_runtime_state_should_allow_repeated_calls', 0, () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      coordinator.clearWeatherRuntimeState();
      coordinator.clearWeatherRuntimeState();
      // Assert
      expect(service.calls.length).assertEqual(2);
    });

    it('invalid: weather_clear_runtime_state_should_bubble_service_error', 0, () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      service.throwMethod = 'clearWeatherRuntimeState';
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      const message = captureSyncErrorAO((): void => {
        coordinator.clearWeatherRuntimeState();
      });
      // Assert
      expect(message).assertEqual('clearWeatherRuntimeState_failed_ao');
    });

    it('normal: weather_resolve_coordinates_should_forward_full_arguments', 0, async () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      service.resolvePoint = { latitude: 30.1, longitude: 120.2 };
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      const point = await coordinator.resolveCoordinatesForPlaceName('West Lake', 30.1, 120.2, 'update', 1.1, 2.2);
      // Assert
      expect(service.resolvePlaceName).assertEqual('West Lake');
      expect(service.resolveLat).assertEqual(30.1);
      expect(service.resolveLng).assertEqual(120.2);
      expect(service.resolveSource).assertEqual('update');
      expect(service.resolveFallbackLat).assertEqual(1.1);
      expect(service.resolveFallbackLng).assertEqual(2.2);
      expect(point.latitude).assertEqual(30.1);
      expect(point.longitude).assertEqual(120.2);
    });

    it('boundary: weather_resolve_coordinates_should_use_default_fallback_values', 0, async () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      service.resolvePoint = { latitude: 0, longitude: 0 };
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      const point = await coordinator.resolveCoordinatesForPlaceName('Unknown');
      // Assert
      expect(service.resolvePlaceName).assertEqual('Unknown');
      expect(service.resolveSource).assertEqual('add');
      expect(service.resolveFallbackLat).assertEqual(0);
      expect(service.resolveFallbackLng).assertEqual(0);
      expect(point.latitude).assertEqual(0);
      expect(point.longitude).assertEqual(0);
    });

    it('invalid: weather_resolve_coordinates_should_bubble_service_error', 0, async () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      service.throwMethod = 'resolveCoordinatesForPlaceName';
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      const message = await captureAsyncErrorAO(async (): Promise<void> => {
        await coordinator.resolveCoordinatesForPlaceName('', Number.NaN, Number.NaN);
      });
      // Assert
      expect(message).assertEqual('resolveCoordinatesForPlaceName_failed_ao');
    });

    it('normal: weather_coordinate_missing_should_return_false_for_valid_input', 0, () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      service.coordinateMissingResult = false;
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      const missing = coordinator.isCoordinateMissingForWeather(31.2, 121.5);
      // Assert
      expect(missing).assertFalse();
      expect(service.coordinateLatitude).assertEqual(31.2);
      expect(service.coordinateLongitude).assertEqual(121.5);
    });

    it('boundary: weather_coordinate_missing_should_return_true_on_zero_coordinate', 0, () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      service.coordinateMissingResult = true;
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      const missing = coordinator.isCoordinateMissingForWeather(0, 0);
      // Assert
      expect(missing).assertTrue();
    });

    it('invalid: weather_coordinate_missing_should_bubble_service_error', 0, () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      service.throwMethod = 'isCoordinateMissingForWeather';
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      const message = captureSyncErrorAO((): void => {
        coordinator.isCoordinateMissingForWeather(Number.NaN, Number.NaN);
      });
      // Assert
      expect(message).assertEqual('isCoordinateMissingForWeather_failed_ao');
    });

    it('normal: weather_valid_coordinate_should_return_true_for_valid_input', 0, () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      service.validCoordinateResult = true;
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      const valid = coordinator.isValidCoordinate(39.9, 116.3);
      // Assert
      expect(valid).assertTrue();
      expect(service.coordinateLatitude).assertEqual(39.9);
    });

    it('boundary: weather_valid_coordinate_should_allow_edge_values', 0, () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      service.validCoordinateResult = true;
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      const valid = coordinator.isValidCoordinate(90, 180);
      // Assert
      expect(valid).assertTrue();
    });

    it('invalid: weather_valid_coordinate_should_bubble_service_error', 0, () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      service.throwMethod = 'isValidCoordinate';
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      const message = captureSyncErrorAO((): void => {
        coordinator.isValidCoordinate(Number.NaN, Number.NaN);
      });
      // Assert
      expect(message).assertEqual('isValidCoordinate_failed_ao');
    });

    it('normal: weather_reload_preference_should_delegate_once', 0, async () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      await coordinator.reloadWeatherUserPreference();
      // Assert
      expect(service.calls[0]).assertEqual('reloadWeatherUserPreference');
    });

    it('boundary: weather_reload_preference_should_allow_repeated_calls', 0, async () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      await coordinator.reloadWeatherUserPreference();
      await coordinator.reloadWeatherUserPreference();
      // Assert
      expect(service.calls.length).assertEqual(2);
    });

    it('invalid: weather_reload_preference_should_bubble_service_error', 0, async () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      service.throwMethod = 'reloadWeatherUserPreference';
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      const message = await captureAsyncErrorAO(async (): Promise<void> => {
        await coordinator.reloadWeatherUserPreference();
      });
      // Assert
      expect(message).assertEqual('reloadWeatherUserPreference_failed_ao');
    });

    it('normal: weather_restore_snapshot_should_forward_plan_id', 0, () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      coordinator.restorePlanningWeatherSnapshot(77);
      // Assert
      expect(service.restorePlanId).assertEqual(77);
    });

    it('boundary: weather_restore_snapshot_should_allow_zero_plan_id', 0, () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      coordinator.restorePlanningWeatherSnapshot(0);
      // Assert
      expect(service.restorePlanId).assertEqual(0);
    });

    it('invalid: weather_restore_snapshot_should_bubble_service_error', 0, () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      service.throwMethod = 'restorePlanningWeatherSnapshot';
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      const message = captureSyncErrorAO((): void => {
        coordinator.restorePlanningWeatherSnapshot(-1);
      });
      // Assert
      expect(message).assertEqual('restorePlanningWeatherSnapshot_failed_ao');
    });

    it('normal: weather_set_feature_enabled_should_forward_true', 0, async () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      await coordinator.setWeatherFeatureEnabled(true);
      // Assert
      expect(service.featureEnabledArg).assertTrue();
    });

    it('boundary: weather_set_feature_enabled_should_forward_false', 0, async () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      await coordinator.setWeatherFeatureEnabled(false);
      // Assert
      expect(service.featureEnabledArg).assertFalse();
    });

    it('invalid: weather_set_feature_enabled_should_bubble_service_error', 0, async () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      service.throwMethod = 'setWeatherFeatureEnabled';
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      const message = await captureAsyncErrorAO(async (): Promise<void> => {
        await coordinator.setWeatherFeatureEnabled(false);
      });
      // Assert
      expect(message).assertEqual('setWeatherFeatureEnabled_failed_ao');
    });

    it('normal: weather_update_preference_should_forward_custom_value', 0, async () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      const coordinator = new TimelineWeatherCoordinator(service);
      const preference: WeatherUserPreference = {
        heatSensitivity: 0,
        rainSensitivity: 2,
        weatherRiskTolerance: 1
      };
      // Act
      await coordinator.updateWeatherUserPreference(preference);
      // Assert
      expect(service.preferenceArg.heatSensitivity).assertEqual(0);
      expect(service.preferenceArg.rainSensitivity).assertEqual(2);
      expect(service.preferenceArg.weatherRiskTolerance).assertEqual(1);
    });

    it('boundary: weather_update_preference_should_forward_default_value', 0, async () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      await coordinator.updateWeatherUserPreference(DEFAULT_WEATHER_USER_PREFERENCE);
      // Assert
      expect(service.preferenceArg.heatSensitivity).assertEqual(DEFAULT_WEATHER_USER_PREFERENCE.heatSensitivity);
    });

    it('invalid: weather_update_preference_should_bubble_service_error', 0, async () => {
      // Arrange
      const service = new WeatherServiceSpyAO();
      service.throwMethod = 'updateWeatherUserPreference';
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      const message = await captureAsyncErrorAO(async (): Promise<void> => {
        await coordinator.updateWeatherUserPreference(DEFAULT_WEATHER_USER_PREFERENCE);
      });
      // Assert
      expect(message).assertEqual('updateWeatherUserPreference_failed_ao');
    });
  });

  describe('phase2BatchAO_timeline_distribution_coordinator', () => {
    it('normal: distribution_resolve_gap_by_distribution_should_delegate_target_item', 0, async () => {
      // Arrange
      const service = new DistributionServiceSpyAO();
      const target = createDistributionEventAO(101, 1, 0, 20, 'Gap');
      const coordinator = new TimelineDistributionCoordinator(new DistributionHostAO([target]), service);
      // Act
      await coordinator.resolveGapByDistribution(target);
      // Assert
      expect(service.calls[0]).assertEqual('resolveGapByDistribution');
      expect(service.targetId).assertEqual(101);
    });

    it('boundary: distribution_resolve_gap_by_distribution_should_allow_zero_id_target', 0, async () => {
      // Arrange
      const service = new DistributionServiceSpyAO();
      const target = createDistributionEventAO(0, 1, 0, 1, 'GapZero');
      const coordinator = new TimelineDistributionCoordinator(new DistributionHostAO([target]), service);
      // Act
      await coordinator.resolveGapByDistribution(target);
      // Assert
      expect(service.targetId).assertEqual(0);
    });

    it('invalid: distribution_resolve_gap_by_distribution_should_bubble_service_error', 0, async () => {
      // Arrange
      const service = new DistributionServiceSpyAO();
      service.throwMethod = 'resolveGapByDistribution';
      const target = createDistributionEventAO(999, 1, 0, 50, 'GapBad');
      const coordinator = new TimelineDistributionCoordinator(new DistributionHostAO([target]), service);
      // Act
      const message = await captureAsyncErrorAO(async (): Promise<void> => {
        await coordinator.resolveGapByDistribution(target);
      });
      // Assert
      expect(message).assertEqual('resolveGapByDistribution_failed_ao');
    });

    it('normal: distribution_resolve_gap_by_sync_should_delegate_item', 0, () => {
      // Arrange
      const service = new DistributionServiceSpyAO();
      const item = createDistributionEventAO(201, 1, 0, 0, 'SyncItem');
      const coordinator = new TimelineDistributionCoordinator(new DistributionHostAO([item]), service);
      // Act
      coordinator.resolveGapBySync(item);
      // Assert
      expect(service.calls[0]).assertEqual('resolveGapBySync');
      expect(service.syncItemId).assertEqual(201);
    });

    it('boundary: distribution_resolve_gap_by_sync_should_allow_empty_name_item', 0, () => {
      // Arrange
      const service = new DistributionServiceSpyAO();
      const item = createDistributionEventAO(0, 1, 0, 0, '');
      const coordinator = new TimelineDistributionCoordinator(new DistributionHostAO([item]), service);
      // Act
      coordinator.resolveGapBySync(item);
      // Assert
      expect(service.syncItemId).assertEqual(0);
    });

    it('invalid: distribution_resolve_gap_by_sync_should_bubble_service_error', 0, () => {
      // Arrange
      const service = new DistributionServiceSpyAO();
      service.throwMethod = 'resolveGapBySync';
      const item = createDistributionEventAO(-1, 1, 0, 0, 'InvalidSync');
      const coordinator = new TimelineDistributionCoordinator(new DistributionHostAO([item]), service);
      // Act
      const message = captureSyncErrorAO((): void => {
        coordinator.resolveGapBySync(item);
      });
      // Assert
      expect(message).assertEqual('resolveGapBySync_failed_ao');
    });

    it('normal: distribution_get_candidates_should_return_service_candidates', 0, () => {
      // Arrange
      const service = new DistributionServiceSpyAO();
      const gap = createDistributionEventAO(301, 1, 0, 30, 'Gap');
      const candidate = createDistributionEventAO(302, 1, 0, 0, 'Candidate');
      service.candidatesResult = [candidate];
      const coordinator = new TimelineDistributionCoordinator(new DistributionHostAO([candidate, gap]), service);
      // Act
      const result = coordinator.getDistributionCandidates(gap);
      // Assert
      expect(service.candidateGapId).assertEqual(301);
      expect(result.length).assertEqual(1);
      expect(result[0].id).assertEqual(302);
    });

    it('boundary: distribution_get_candidates_should_allow_empty_result', 0, () => {
      // Arrange
      const service = new DistributionServiceSpyAO();
      service.candidatesResult = [];
      const gap = createDistributionEventAO(303, 1, 0, 15, 'Gap');
      const coordinator = new TimelineDistributionCoordinator(new DistributionHostAO([gap]), service);
      // Act
      const result = coordinator.getDistributionCandidates(gap);
      // Assert
      expect(result.length).assertEqual(0);
    });

    it('invalid: distribution_get_candidates_should_bubble_service_error', 0, () => {
      // Arrange
      const service = new DistributionServiceSpyAO();
      service.throwMethod = 'getDistributionCandidates';
      const gap = createDistributionEventAO(304, 1, 0, 10, 'Gap');
      const coordinator = new TimelineDistributionCoordinator(new DistributionHostAO([gap]), service);
      // Act
      const message = captureSyncErrorAO((): void => {
        coordinator.getDistributionCandidates(gap);
      });
      // Assert
      expect(message).assertEqual('getDistributionCandidates_failed_ao');
    });

    it('normal: distribution_get_safety_cap_should_return_service_value', 0, () => {
      // Arrange
      const service = new DistributionServiceSpyAO();
      service.safetyCapResult = 45;
      const candidate = createDistributionEventAO(401, 1, 0, 0, 'Candidate');
      const gap = createDistributionEventAO(402, 1, 0, 20, 'Gap');
      const coordinator = new TimelineDistributionCoordinator(new DistributionHostAO([candidate, gap]), service);
      // Act
      const cap = coordinator.getSafetyCap(candidate, gap);
      // Assert
      expect(cap).assertEqual(45);
      expect(service.safetyCandidateId).assertEqual(401);
      expect(service.safetyGapId).assertEqual(402);
    });

    it('boundary: distribution_get_safety_cap_should_allow_zero_cap', 0, () => {
      // Arrange
      const service = new DistributionServiceSpyAO();
      service.safetyCapResult = 0;
      const candidate = createDistributionEventAO(403, 1, 0, 0, 'Candidate');
      const gap = createDistributionEventAO(404, 1, 0, 20, 'Gap');
      const coordinator = new TimelineDistributionCoordinator(new DistributionHostAO([candidate, gap]), service);
      // Act
      const cap = coordinator.getSafetyCap(candidate, gap);
      // Assert
      expect(cap).assertEqual(0);
    });

    it('invalid: distribution_get_safety_cap_should_bubble_service_error', 0, () => {
      // Arrange
      const service = new DistributionServiceSpyAO();
      service.throwMethod = 'getSafetyCap';
      const candidate = createDistributionEventAO(405, 1, 0, 0, 'Candidate');
      const gap = createDistributionEventAO(406, 1, 0, 20, 'Gap');
      const coordinator = new TimelineDistributionCoordinator(new DistributionHostAO([candidate, gap]), service);
      // Act
      const message = captureSyncErrorAO((): void => {
        coordinator.getSafetyCap(candidate, gap);
      });
      // Assert
      expect(message).assertEqual('getSafetyCap_failed_ao');
    });

    it('normal: distribution_preview_should_return_service_map', 0, () => {
      // Arrange
      const service = new DistributionServiceSpyAO();
      const preview = new Map<number, number>();
      preview.set(501, 8);
      service.previewResult = preview;
      const gap = createDistributionEventAO(502, 1, 0, 25, 'Gap');
      const candidate = createDistributionEventAO(501, 1, 0, 0, 'Candidate');
      const selected = new Set<number>([501]);
      const coordinator = new TimelineDistributionCoordinator(new DistributionHostAO([candidate, gap]), service);
      // Act
      const result = coordinator.calculateDistributionPreview(gap, [candidate], selected, 'SMART');
      // Assert
      expect(service.previewGapId).assertEqual(502);
      expect(service.previewCandidateCount).assertEqual(1);
      expect(service.previewSelectedSize).assertEqual(1);
      expect(service.previewStrategy).assertEqual('SMART');
      expect(result.get(501) ?? 0).assertEqual(8);
    });

    it('boundary: distribution_preview_should_allow_empty_selection', 0, () => {
      // Arrange
      const service = new DistributionServiceSpyAO();
      const gap = createDistributionEventAO(503, 1, 0, 12, 'Gap');
      const candidate = createDistributionEventAO(504, 1, 0, 0, 'Candidate');
      const coordinator = new TimelineDistributionCoordinator(new DistributionHostAO([candidate, gap]), service);
      // Act
      coordinator.calculateDistributionPreview(gap, [candidate], new Set<number>(), 'EQUAL');
      // Assert
      expect(service.previewSelectedSize).assertEqual(0);
      expect(service.previewStrategy).assertEqual('EQUAL');
    });

    it('invalid: distribution_preview_should_bubble_service_error', 0, () => {
      // Arrange
      const service = new DistributionServiceSpyAO();
      service.throwMethod = 'calculateDistributionPreview';
      const gap = createDistributionEventAO(505, 1, 0, 12, 'Gap');
      const coordinator = new TimelineDistributionCoordinator(new DistributionHostAO([gap]), service);
      // Act
      const message = captureSyncErrorAO((): void => {
        coordinator.calculateDistributionPreview(gap, [], new Set<number>(), 'EQUAL');
      });
      // Assert
      expect(message).assertEqual('calculateDistributionPreview_failed_ao');
    });

    it('normal: distribution_get_sorted_gaps_should_return_service_gaps', 0, () => {
      // Arrange
      const service = new DistributionServiceSpyAO();
      const gap = createDistributionEventAO(601, 1, 0, 40, 'Gap');
      service.sortedGapsResult = [gap];
      const coordinator = new TimelineDistributionCoordinator(new DistributionHostAO([gap]), service);
      // Act
      const result = coordinator.getSortedGaps();
      // Assert
      expect(result.length).assertEqual(1);
      expect(result[0].id).assertEqual(601);
    });

    it('boundary: distribution_get_sorted_gaps_should_allow_empty_list', 0, () => {
      // Arrange
      const service = new DistributionServiceSpyAO();
      service.sortedGapsResult = [];
      const coordinator = new TimelineDistributionCoordinator(new DistributionHostAO([]), service);
      // Act
      const result = coordinator.getSortedGaps();
      // Assert
      expect(result.length).assertEqual(0);
    });

    it('invalid: distribution_get_sorted_gaps_should_bubble_service_error', 0, () => {
      // Arrange
      const service = new DistributionServiceSpyAO();
      service.throwMethod = 'getSortedGaps';
      const coordinator = new TimelineDistributionCoordinator(new DistributionHostAO([]), service);
      // Act
      const message = captureSyncErrorAO((): void => {
        coordinator.getSortedGaps();
      });
      // Assert
      expect(message).assertEqual('getSortedGaps_failed_ao');
    });

    it('normal: distribution_get_previous_name_should_return_service_text', 0, () => {
      // Arrange
      const service = new DistributionServiceSpyAO();
      service.previousNameResult = 'Museum';
      const gap = createDistributionEventAO(701, 1, 0, 22, 'Gap');
      const coordinator = new TimelineDistributionCoordinator(new DistributionHostAO([gap]), service);
      // Act
      const name = coordinator.getPreviousItemName(gap);
      // Assert
      expect(name).assertEqual('Museum');
      expect(service.previousNameGapId).assertEqual(701);
    });

    it('boundary: distribution_get_previous_name_should_allow_start_marker', 0, () => {
      // Arrange
      const service = new DistributionServiceSpyAO();
      service.previousNameResult = '日程开始';
      const gap = createDistributionEventAO(702, 1, 0, 22, 'Gap');
      const coordinator = new TimelineDistributionCoordinator(new DistributionHostAO([gap]), service);
      // Act
      const name = coordinator.getPreviousItemName(gap);
      // Assert
      expect(name).assertEqual('日程开始');
    });

    it('invalid: distribution_get_previous_name_should_bubble_service_error', 0, () => {
      // Arrange
      const service = new DistributionServiceSpyAO();
      service.throwMethod = 'getPreviousItemName';
      const gap = createDistributionEventAO(703, 1, 0, 22, 'Gap');
      const coordinator = new TimelineDistributionCoordinator(new DistributionHostAO([gap]), service);
      // Act
      const message = captureSyncErrorAO((): void => {
        coordinator.getPreviousItemName(gap);
      });
      // Assert
      expect(message).assertEqual('getPreviousItemName_failed_ao');
    });

    it('normal: distribution_apply_should_delegate_map_size', 0, async () => {
      // Arrange
      const service = new DistributionServiceSpyAO();
      const distributionMap = new Map<number, number>();
      distributionMap.set(801, 5);
      const coordinator = new TimelineDistributionCoordinator(new DistributionHostAO([]), service);
      // Act
      await coordinator.applyDistribution(distributionMap);
      // Assert
      expect(service.applyDistributionSize).assertEqual(1);
    });

    it('boundary: distribution_apply_should_allow_empty_map', 0, async () => {
      // Arrange
      const service = new DistributionServiceSpyAO();
      const coordinator = new TimelineDistributionCoordinator(new DistributionHostAO([]), service);
      // Act
      await coordinator.applyDistribution(new Map<number, number>());
      // Assert
      expect(service.applyDistributionSize).assertEqual(0);
    });

    it('invalid: distribution_apply_should_bubble_service_error', 0, async () => {
      // Arrange
      const service = new DistributionServiceSpyAO();
      service.throwMethod = 'applyDistribution';
      const coordinator = new TimelineDistributionCoordinator(new DistributionHostAO([]), service);
      // Act
      const message = await captureAsyncErrorAO(async (): Promise<void> => {
        await coordinator.applyDistribution(new Map<number, number>());
      });
      // Assert
      expect(message).assertEqual('applyDistribution_failed_ao');
    });

    it('normal: distribution_check_risk_should_return_false_when_locked_buffer_not_overrun', 0, () => {
      // Arrange
      const a = createDistributionEventAO(901, 1, 0, 0, 'A');
      const locked = createDistributionEventAO(902, 1, 1, 10, 'Locked');
      const gap = createDistributionEventAO(903, 1, 0, 30, 'Gap');
      const distributionMap = new Map<number, number>();
      distributionMap.set(901, 5);
      const coordinator = new TimelineDistributionCoordinator(new DistributionHostAO([a, locked, gap]), new DistributionServiceSpyAO());
      // Act
      const risk = coordinator.checkDistributionRisk(gap, distributionMap);
      // Assert
      expect(risk).assertFalse();
    });

    it('boundary: distribution_check_risk_should_return_false_when_map_empty', 0, () => {
      // Arrange
      const a = createDistributionEventAO(904, 1, 0, 0, 'A');
      const gap = createDistributionEventAO(905, 1, 0, 15, 'Gap');
      const coordinator = new TimelineDistributionCoordinator(new DistributionHostAO([a, gap]), new DistributionServiceSpyAO());
      // Act
      const risk = coordinator.checkDistributionRisk(gap, new Map<number, number>());
      // Assert
      expect(risk).assertFalse();
    });

    it('invalid: distribution_check_risk_should_return_false_when_gap_not_in_schedule', 0, () => {
      // Arrange
      const a = createDistributionEventAO(906, 1, 0, 0, 'A');
      const gap = createDistributionEventAO(907, 0, 0, 15, 'BacklogGap');
      const distributionMap = new Map<number, number>();
      distributionMap.set(906, 12);
      const coordinator = new TimelineDistributionCoordinator(new DistributionHostAO([a, gap]), new DistributionServiceSpyAO());
      // Act
      const risk = coordinator.checkDistributionRisk(gap, distributionMap);
      // Assert
      expect(risk).assertFalse();
    });

    it('conflict: distribution_check_risk_should_detect_locked_buffer_overrun', 0, () => {
      // Arrange
      const a = createDistributionEventAO(908, 1, 0, 0, 'A');
      const locked = createDistributionEventAO(909, 1, 1, 5, 'Locked');
      const gap = createDistributionEventAO(910, 1, 0, 25, 'Gap');
      const distributionMap = new Map<number, number>();
      distributionMap.set(908, 8);
      const coordinator = new TimelineDistributionCoordinator(new DistributionHostAO([a, locked, gap]), new DistributionServiceSpyAO());
      // Act
      const risk = coordinator.checkDistributionRisk(gap, distributionMap);
      // Assert
      expect(risk).assertTrue();
    });

    it('regression: distribution_check_risk_should_ignore_unknown_ids_before_first_modified_item', 0, () => {
      // Arrange
      const a = createDistributionEventAO(911, 1, 0, 0, 'A');
      const locked = createDistributionEventAO(912, 1, 1, 10, 'Locked');
      const gap = createDistributionEventAO(913, 1, 0, 25, 'Gap');
      const distributionMap = new Map<number, number>();
      distributionMap.set(9999, 100);
      distributionMap.set(911, 4);
      const coordinator = new TimelineDistributionCoordinator(new DistributionHostAO([a, locked, gap]), new DistributionServiceSpyAO());
      // Act
      const risk = coordinator.checkDistributionRisk(gap, distributionMap);
      // Assert
      expect(risk).assertFalse();
    });
  });

  describe('phase2BatchAO_timeline_compression_coordinator', () => {
    it('normal: compression_smart_fix_conflict_should_delegate_target_item', 0, async () => {
      // Arrange
      const service = new CompressionServiceSpyAO();
      const coordinator = new TimelineCompressionCoordinator(service);
      const target = new EventEntity('Target', 1);
      target.id = 1001;
      // Act
      await coordinator.smartFixConflict(target);
      // Assert
      expect(service.calls[0]).assertEqual('smartFixConflict');
      expect(service.smartFixTargetId).assertEqual(1001);
    });

    it('boundary: compression_smart_fix_conflict_should_allow_zero_id_item', 0, async () => {
      // Arrange
      const service = new CompressionServiceSpyAO();
      const coordinator = new TimelineCompressionCoordinator(service);
      const target = new EventEntity('ZeroTarget', 1);
      target.id = 0;
      // Act
      await coordinator.smartFixConflict(target);
      // Assert
      expect(service.smartFixTargetId).assertEqual(0);
    });

    it('invalid: compression_smart_fix_conflict_should_bubble_service_error', 0, async () => {
      // Arrange
      const service = new CompressionServiceSpyAO();
      service.throwMethod = 'smartFixConflict';
      const coordinator = new TimelineCompressionCoordinator(service);
      const target = new EventEntity('InvalidTarget', 1);
      target.id = -1;
      // Act
      const message = await captureAsyncErrorAO(async (): Promise<void> => {
        await coordinator.smartFixConflict(target);
      });
      // Assert
      expect(message).assertEqual('smartFixConflict_failed_ao');
    });

    it('normal: compression_calculate_plan_should_forward_args_and_return_plan', 0, () => {
      // Arrange
      const service = new CompressionServiceSpyAO();
      service.compressionPlanResult = buildCompressionPlanAO('COMPRESS_CONFIRM', 'ok');
      const coordinator = new TimelineCompressionCoordinator(service);
      // Act
      const plan = coordinator.calculateCompressionPlan(3, '10:00', 15);
      // Assert
      expect(plan.status).assertEqual('COMPRESS_CONFIRM');
      expect(service.lastTargetIndex).assertEqual(3);
      expect(service.lastTime).assertEqual('10:00');
      expect(service.lastForcedGap).assertEqual(15);
    });

    it('boundary: compression_calculate_plan_should_allow_zero_forced_gap', 0, () => {
      // Arrange
      const service = new CompressionServiceSpyAO();
      service.compressionPlanResult = buildCompressionPlanAO('NO_ACTION', 'enough');
      const coordinator = new TimelineCompressionCoordinator(service);
      // Act
      const plan = coordinator.calculateCompressionPlan(0, '00:00', 0);
      // Assert
      expect(plan.status).assertEqual('NO_ACTION');
      expect(service.lastTargetIndex).assertEqual(0);
      expect(service.lastForcedGap).assertEqual(0);
    });

    it('invalid: compression_calculate_plan_should_bubble_service_error', 0, () => {
      // Arrange
      const service = new CompressionServiceSpyAO();
      service.throwMethod = 'calculateCompressionPlan';
      const coordinator = new TimelineCompressionCoordinator(service);
      // Act
      const message = captureSyncErrorAO((): void => {
        coordinator.calculateCompressionPlan(-1, 'bad', -5);
      });
      // Assert
      expect(message).assertEqual('calculateCompressionPlan_failed_ao');
    });

    it('normal: compression_build_selection_context_should_return_context', 0, () => {
      // Arrange
      const service = new CompressionServiceSpyAO();
      service.selectionContextResult = {
        targetIndex: 2,
        targetTime: '09:30',
        neededGapMinutes: 20,
        naturalArrivalMinutes: 600,
        chainStartIndex: 1,
        candidates: []
      };
      const coordinator = new TimelineCompressionCoordinator(service);
      // Act
      const context = coordinator.buildCompressionSelectionContext(2, '09:30', 20);
      // Assert
      expect(context?.neededGapMinutes ?? -1).assertEqual(20);
      expect(service.lastTargetIndex).assertEqual(2);
      expect(service.lastTime).assertEqual('09:30');
    });

    it('boundary: compression_build_selection_context_should_return_null_when_service_returns_null', 0, () => {
      // Arrange
      const service = new CompressionServiceSpyAO();
      service.selectionContextResult = null;
      const coordinator = new TimelineCompressionCoordinator(service);
      // Act
      const context = coordinator.buildCompressionSelectionContext(1, '08:00');
      // Assert
      expect(context === null).assertTrue();
      expect(service.lastForcedGap).assertEqual(-1);
    });

    it('invalid: compression_build_selection_context_should_bubble_service_error', 0, () => {
      // Arrange
      const service = new CompressionServiceSpyAO();
      service.throwMethod = 'buildCompressionSelectionContext';
      const coordinator = new TimelineCompressionCoordinator(service);
      // Act
      const message = captureSyncErrorAO((): void => {
        coordinator.buildCompressionSelectionContext(-1, 'bad');
      });
      // Assert
      expect(message).assertEqual('buildCompressionSelectionContext_failed_ao');
    });

    it('normal: compression_build_advance_context_should_return_service_context', 0, () => {
      // Arrange
      const service = new CompressionServiceSpyAO();
      service.advanceContextResult = {
        targetIndex: 4,
        targetId: 44,
        targetDayOffset: 1,
        candidates: []
      };
      const coordinator = new TimelineCompressionCoordinator(service);
      // Act
      const context = coordinator.buildAdvanceAdjustContext(4);
      // Assert
      expect(context?.targetId ?? -1).assertEqual(44);
      expect(service.lastTargetIndex).assertEqual(4);
    });

    it('boundary: compression_build_advance_context_should_allow_null_context', 0, () => {
      // Arrange
      const service = new CompressionServiceSpyAO();
      service.advanceContextResult = null;
      const coordinator = new TimelineCompressionCoordinator(service);
      // Act
      const context = coordinator.buildAdvanceAdjustContext(0);
      // Assert
      expect(context === null).assertTrue();
    });

    it('invalid: compression_build_advance_context_should_bubble_service_error', 0, () => {
      // Arrange
      const service = new CompressionServiceSpyAO();
      service.throwMethod = 'buildAdvanceAdjustContext';
      const coordinator = new TimelineCompressionCoordinator(service);
      // Act
      const message = captureSyncErrorAO((): void => {
        coordinator.buildAdvanceAdjustContext(-1);
      });
      // Assert
      expect(message).assertEqual('buildAdvanceAdjustContext_failed_ao');
    });

    it('normal: compression_preview_advance_adjust_should_return_service_preview', 0, () => {
      // Arrange
      const service = new CompressionServiceSpyAO();
      service.previewResult = {
        valid: true,
        message: 'preview_ok',
        selectedCount: 2,
        shiftMinutes: 15,
        requiredGapMinutes: 20,
        remainingGapMinutes: 5,
        firstNewStartTime: '09:00',
        lastNewEndTime: '10:30',
        items: []
      };
      const coordinator = new TimelineCompressionCoordinator(service);
      const selected = new Set<number>([1, 2]);
      // Act
      const preview = coordinator.previewAdvanceAdjust(5, selected, '09:00', 20);
      // Assert
      expect(preview.valid).assertTrue();
      expect(preview.selectedCount).assertEqual(2);
      expect(service.lastSelectedSize).assertEqual(2);
      expect(service.lastForcedGap).assertEqual(20);
    });

    it('boundary: compression_preview_advance_adjust_should_allow_empty_selection', 0, () => {
      // Arrange
      const service = new CompressionServiceSpyAO();
      service.previewResult = {
        valid: false,
        message: 'need_selection',
        selectedCount: 0,
        shiftMinutes: 0,
        requiredGapMinutes: 10,
        remainingGapMinutes: 10,
        firstNewStartTime: '',
        lastNewEndTime: '',
        items: []
      };
      const coordinator = new TimelineCompressionCoordinator(service);
      // Act
      const preview = coordinator.previewAdvanceAdjust(2, new Set<number>(), '08:30');
      // Assert
      expect(preview.valid).assertFalse();
      expect(service.lastSelectedSize).assertEqual(0);
    });

    it('invalid: compression_preview_advance_adjust_should_bubble_service_error', 0, () => {
      // Arrange
      const service = new CompressionServiceSpyAO();
      service.throwMethod = 'previewAdvanceAdjust';
      const coordinator = new TimelineCompressionCoordinator(service);
      // Act
      const message = captureSyncErrorAO((): void => {
        coordinator.previewAdvanceAdjust(-1, new Set<number>(), 'bad', -1);
      });
      // Assert
      expect(message).assertEqual('previewAdvanceAdjust_failed_ao');
    });

    it('normal: compression_apply_advance_adjust_should_return_apply_result', 0, async () => {
      // Arrange
      const service = new CompressionServiceSpyAO();
      service.applyResult = {
        success: true,
        appliedCount: 2,
        appliedShiftMinutes: 8,
        remainingGapMinutes: 0,
        message: 'applied'
      };
      const coordinator = new TimelineCompressionCoordinator(service);
      const selected = new Set<number>([11, 12]);
      // Act
      const result = await coordinator.applyAdvanceAdjust(6, selected, '10:00', 12);
      // Assert
      expect(result.success).assertTrue();
      expect(result.appliedCount).assertEqual(2);
      expect(service.lastSelectedSize).assertEqual(2);
      expect(service.lastForcedGap).assertEqual(12);
    });

    it('boundary: compression_apply_advance_adjust_should_allow_empty_selection_result', 0, async () => {
      // Arrange
      const service = new CompressionServiceSpyAO();
      service.applyResult = {
        success: false,
        appliedCount: 0,
        appliedShiftMinutes: 0,
        remainingGapMinutes: 10,
        message: 'no_change'
      };
      const coordinator = new TimelineCompressionCoordinator(service);
      // Act
      const result = await coordinator.applyAdvanceAdjust(1, new Set<number>(), '08:00');
      // Assert
      expect(result.success).assertFalse();
      expect(result.appliedCount).assertEqual(0);
      expect(service.lastForcedGap).assertEqual(-1);
    });

    it('invalid: compression_apply_advance_adjust_should_bubble_service_error', 0, async () => {
      // Arrange
      const service = new CompressionServiceSpyAO();
      service.throwMethod = 'applyAdvanceAdjust';
      const coordinator = new TimelineCompressionCoordinator(service);
      // Act
      const message = await captureAsyncErrorAO(async (): Promise<void> => {
        await coordinator.applyAdvanceAdjust(-1, new Set<number>(), 'bad', -2);
      });
      // Assert
      expect(message).assertEqual('applyAdvanceAdjust_failed_ao');
    });

    it('normal: compression_calculate_plan_by_selection_should_forward_selection_and_mode', 0, () => {
      // Arrange
      const service = new CompressionServiceSpyAO();
      service.selectionPlanResult = buildCompressionPlanAO('OVERLOAD', 'need_more');
      const coordinator = new TimelineCompressionCoordinator(service);
      const selected = new Set<number>([21, 22]);
      // Act
      const plan = coordinator.calculateCompressionPlanBySelection(4, '11:00', selected, 'RATIO', 30);
      // Assert
      expect(plan.status).assertEqual('OVERLOAD');
      expect(service.lastSelectedSize).assertEqual(2);
      expect(service.lastMode).assertEqual('RATIO');
      expect(service.lastForcedGap).assertEqual(30);
    });

    it('boundary: compression_calculate_plan_by_selection_should_use_default_ratio_mode', 0, () => {
      // Arrange
      const service = new CompressionServiceSpyAO();
      service.selectionPlanResult = buildCompressionPlanAO('COMPRESS_CONFIRM', 'ok');
      const coordinator = new TimelineCompressionCoordinator(service);
      // Act
      const plan = coordinator.calculateCompressionPlanBySelection(2, '07:00', new Set<number>());
      // Assert
      expect(plan.status).assertEqual('COMPRESS_CONFIRM');
      expect(service.lastMode).assertEqual('RATIO');
      expect(service.lastSelectedSize).assertEqual(0);
    });

    it('invalid: compression_calculate_plan_by_selection_should_bubble_service_error', 0, () => {
      // Arrange
      const service = new CompressionServiceSpyAO();
      service.throwMethod = 'calculateCompressionPlanBySelection';
      const coordinator = new TimelineCompressionCoordinator(service);
      // Act
      const message = captureSyncErrorAO((): void => {
        coordinator.calculateCompressionPlanBySelection(-1, 'bad', new Set<number>(), 'EQUAL', -3);
      });
      // Assert
      expect(message).assertEqual('calculateCompressionPlanBySelection_failed_ao');
    });

    it('normal: compression_apply_plan_should_forward_plan_status', 0, () => {
      // Arrange
      const service = new CompressionServiceSpyAO();
      const coordinator = new TimelineCompressionCoordinator(service);
      const plan = buildCompressionPlanAO('COMPRESS_CONFIRM', 'ok');
      // Act
      coordinator.applyCompressionPlan(plan);
      // Assert
      expect(service.appliedPlanStatus).assertEqual('COMPRESS_CONFIRM');
    });

    it('boundary: compression_apply_plan_should_allow_overload_status', 0, () => {
      // Arrange
      const service = new CompressionServiceSpyAO();
      const coordinator = new TimelineCompressionCoordinator(service);
      const plan = buildCompressionPlanAO('OVERLOAD', 'need_more');
      // Act
      coordinator.applyCompressionPlan(plan);
      // Assert
      expect(service.appliedPlanStatus).assertEqual('OVERLOAD');
    });

    it('invalid: compression_apply_plan_should_bubble_service_error', 0, () => {
      // Arrange
      const service = new CompressionServiceSpyAO();
      service.throwMethod = 'applyCompressionPlan';
      const coordinator = new TimelineCompressionCoordinator(service);
      // Act
      const message = captureSyncErrorAO((): void => {
        coordinator.applyCompressionPlan(buildCompressionPlanAO('FAIL_TOO_SHORT', 'bad'));
      });
      // Assert
      expect(message).assertEqual('applyCompressionPlan_failed_ao');
    });

    it('normal: compression_calculate_delay_plan_should_return_service_plan', 0, () => {
      // Arrange
      const service = new CompressionServiceSpyAO();
      service.delayPlanResult = buildCompressionPlanAO('COMPRESS_CONFIRM', 'delay');
      const coordinator = new TimelineCompressionCoordinator(service);
      // Act
      const plan = coordinator.calculateDelayPlan(7);
      // Assert
      expect(plan.msg).assertEqual('delay');
      expect(service.lastTargetIndex).assertEqual(7);
    });

    it('boundary: compression_calculate_delay_plan_should_allow_zero_index', 0, () => {
      // Arrange
      const service = new CompressionServiceSpyAO();
      service.delayPlanResult = buildCompressionPlanAO('NO_ACTION', 'none');
      const coordinator = new TimelineCompressionCoordinator(service);
      // Act
      const plan = coordinator.calculateDelayPlan(0);
      // Assert
      expect(plan.status).assertEqual('NO_ACTION');
      expect(service.lastTargetIndex).assertEqual(0);
    });

    it('invalid: compression_calculate_delay_plan_should_bubble_service_error', 0, () => {
      // Arrange
      const service = new CompressionServiceSpyAO();
      service.throwMethod = 'calculateDelayPlan';
      const coordinator = new TimelineCompressionCoordinator(service);
      // Act
      const message = captureSyncErrorAO((): void => {
        coordinator.calculateDelayPlan(-1);
      });
      // Assert
      expect(message).assertEqual('calculateDelayPlan_failed_ao');
    });

    it('normal: compression_calculate_force_compress_plan_should_return_service_plan', 0, () => {
      // Arrange
      const service = new CompressionServiceSpyAO();
      service.forceCompressPlanResult = buildCompressionPlanAO('FAIL_TOO_SHORT', 'too_short');
      const coordinator = new TimelineCompressionCoordinator(service);
      // Act
      const plan = coordinator.calculateForceCompressPlan(8, '12:00');
      // Assert
      expect(plan.msg).assertEqual('too_short');
      expect(service.lastTargetIndex).assertEqual(8);
      expect(service.lastTime).assertEqual('12:00');
    });

    it('boundary: compression_calculate_force_compress_plan_should_allow_midnight_time', 0, () => {
      // Arrange
      const service = new CompressionServiceSpyAO();
      service.forceCompressPlanResult = buildCompressionPlanAO('NO_ACTION', 'enough');
      const coordinator = new TimelineCompressionCoordinator(service);
      // Act
      const plan = coordinator.calculateForceCompressPlan(0, '00:00');
      // Assert
      expect(plan.status).assertEqual('NO_ACTION');
      expect(service.lastTime).assertEqual('00:00');
    });

    it('invalid: compression_calculate_force_compress_plan_should_bubble_service_error', 0, () => {
      // Arrange
      const service = new CompressionServiceSpyAO();
      service.throwMethod = 'calculateForceCompressPlan';
      const coordinator = new TimelineCompressionCoordinator(service);
      // Act
      const message = captureSyncErrorAO((): void => {
        coordinator.calculateForceCompressPlan(-1, 'bad');
      });
      // Assert
      expect(message).assertEqual('calculateForceCompressPlan_failed_ao');
    });

    it('normal: compression_calculate_natural_arrival_should_return_service_minutes', 0, () => {
      // Arrange
      const service = new CompressionServiceSpyAO();
      service.naturalArrivalResult = 615;
      const coordinator = new TimelineCompressionCoordinator(service);
      // Act
      const minutes = coordinator.calculateNaturalArrival(9);
      // Assert
      expect(minutes).assertEqual(615);
      expect(service.lastTargetIndex).assertEqual(9);
    });

    it('boundary: compression_calculate_natural_arrival_should_allow_zero_minutes', 0, () => {
      // Arrange
      const service = new CompressionServiceSpyAO();
      service.naturalArrivalResult = 0;
      const coordinator = new TimelineCompressionCoordinator(service);
      // Act
      const minutes = coordinator.calculateNaturalArrival(0);
      // Assert
      expect(minutes).assertEqual(0);
    });

    it('invalid: compression_calculate_natural_arrival_should_bubble_service_error', 0, () => {
      // Arrange
      const service = new CompressionServiceSpyAO();
      service.throwMethod = 'calculateNaturalArrival';
      const coordinator = new TimelineCompressionCoordinator(service);
      // Act
      const message = captureSyncErrorAO((): void => {
        coordinator.calculateNaturalArrival(-1);
      });
      // Assert
      expect(message).assertEqual('calculateNaturalArrival_failed_ao');
    });
  });

  describe('phase2BatchAO_plan_app_service_repository', () => {
    it('normal: plan_app_service_create_plan_should_delegate_to_test_repo', 0, async () => {
      // Arrange
      const repo = new PlanRepositorySpyAO();
      repo.createResult = 2001;
      PlanAppService.setPlanRepositoryForTest(repo);
      const service = PlanAppService.getInstance();
      // Act
      const planId = await service.createPlan('Trip A', 1700000000000);
      // Assert
      expect(planId).assertEqual(2001);
      expect(repo.createTitle).assertEqual('Trip A');
      expect(repo.createStartDate).assertEqual(1700000000000);
      PlanAppService.setPlanRepositoryForTest(null);
    });

    it('boundary: plan_app_service_create_plan_should_allow_empty_title', 0, async () => {
      // Arrange
      const repo = new PlanRepositorySpyAO();
      repo.createResult = 2002;
      PlanAppService.setPlanRepositoryForTest(repo);
      const service = PlanAppService.getInstance();
      // Act
      const planId = await service.createPlan('', 0);
      // Assert
      expect(planId).assertEqual(2002);
      expect(repo.createTitle).assertEqual('');
      expect(repo.createStartDate).assertEqual(0);
      PlanAppService.setPlanRepositoryForTest(null);
    });

    it('invalid: plan_app_service_create_plan_should_bubble_repo_error', 0, async () => {
      // Arrange
      const repo = new PlanRepositorySpyAO();
      repo.throwMethod = 'createPlan';
      PlanAppService.setPlanRepositoryForTest(repo);
      const service = PlanAppService.getInstance();
      // Act
      const message = await captureAsyncErrorAO(async (): Promise<void> => {
        await service.createPlan('Bad', 1);
      });
      // Assert
      expect(message).assertEqual('createPlan_failed_ao');
      PlanAppService.setPlanRepositoryForTest(null);
    });

    it('normal: plan_app_service_load_visible_plans_should_filter_archived_items', 0, async () => {
      // Arrange
      const repo = new PlanRepositorySpyAO();
      repo.planList = [
        buildPlanItemAO(1, 0, 'active'),
        buildPlanItemAO(2, 2, 'archived'),
        buildPlanItemAO(3, 1, 'ready')
      ];
      PlanAppService.setPlanRepositoryForTest(repo);
      const service = PlanAppService.getInstance();
      // Act
      const visible = await service.loadVisiblePlans();
      // Assert
      expect(repo.purgeCalls).assertEqual(1);
      expect(visible.length).assertEqual(2);
      expect(visible[0].id).assertEqual(1);
      expect(visible[1].id).assertEqual(3);
      PlanAppService.setPlanRepositoryForTest(null);
    });

    it('boundary: plan_app_service_load_visible_plans_should_return_empty_when_all_archived', 0, async () => {
      // Arrange
      const repo = new PlanRepositorySpyAO();
      repo.planList = [buildPlanItemAO(4, 2, 'archived_only')];
      PlanAppService.setPlanRepositoryForTest(repo);
      const service = PlanAppService.getInstance();
      // Act
      const visible = await service.loadVisiblePlans();
      // Assert
      expect(visible.length).assertEqual(0);
      PlanAppService.setPlanRepositoryForTest(null);
    });

    it('invalid: plan_app_service_load_visible_plans_should_bubble_repo_error', 0, async () => {
      // Arrange
      const repo = new PlanRepositorySpyAO();
      repo.throwMethod = 'getPlanList';
      PlanAppService.setPlanRepositoryForTest(repo);
      const service = PlanAppService.getInstance();
      // Act
      const message = await captureAsyncErrorAO(async (): Promise<void> => {
        await service.loadVisiblePlans();
      });
      // Assert
      expect(message).assertEqual('getPlanList_failed_ao');
      PlanAppService.setPlanRepositoryForTest(null);
    });

    it('normal: plan_app_service_load_archived_plans_should_return_archived_list', 0, async () => {
      // Arrange
      const repo = new PlanRepositorySpyAO();
      repo.archivedList = [buildPlanItemAO(5, 2, 'archived_a')];
      PlanAppService.setPlanRepositoryForTest(repo);
      const service = PlanAppService.getInstance();
      // Act
      const archived = await service.loadArchivedPlans();
      // Assert
      expect(repo.purgeCalls).assertEqual(1);
      expect(archived.length).assertEqual(1);
      expect(archived[0].id).assertEqual(5);
      PlanAppService.setPlanRepositoryForTest(null);
    });

    it('boundary: plan_app_service_load_archived_plans_should_allow_empty_result', 0, async () => {
      // Arrange
      const repo = new PlanRepositorySpyAO();
      repo.archivedList = [];
      PlanAppService.setPlanRepositoryForTest(repo);
      const service = PlanAppService.getInstance();
      // Act
      const archived = await service.loadArchivedPlans();
      // Assert
      expect(archived.length).assertEqual(0);
      PlanAppService.setPlanRepositoryForTest(null);
    });

    it('invalid: plan_app_service_load_archived_plans_should_bubble_purge_error', 0, async () => {
      // Arrange
      const repo = new PlanRepositorySpyAO();
      repo.throwMethod = 'purgeOldTrash';
      PlanAppService.setPlanRepositoryForTest(repo);
      const service = PlanAppService.getInstance();
      // Act
      const message = await captureAsyncErrorAO(async (): Promise<void> => {
        await service.loadArchivedPlans();
      });
      // Assert
      expect(message).assertEqual('purgeOldTrash_failed_ao');
      PlanAppService.setPlanRepositoryForTest(null);
    });

    it('normal: plan_app_service_load_trash_plans_should_return_trash_list', 0, async () => {
      // Arrange
      const repo = new PlanRepositorySpyAO();
      repo.trashList = [buildPlanItemAO(6, 0, 'trash_a')];
      PlanAppService.setPlanRepositoryForTest(repo);
      const service = PlanAppService.getInstance();
      // Act
      const trash = await service.loadTrashPlans();
      // Assert
      expect(repo.purgeCalls).assertEqual(1);
      expect(trash.length).assertEqual(1);
      expect(trash[0].id).assertEqual(6);
      PlanAppService.setPlanRepositoryForTest(null);
    });

    it('boundary: plan_app_service_load_trash_plans_should_allow_empty_result', 0, async () => {
      // Arrange
      const repo = new PlanRepositorySpyAO();
      repo.trashList = [];
      PlanAppService.setPlanRepositoryForTest(repo);
      const service = PlanAppService.getInstance();
      // Act
      const trash = await service.loadTrashPlans();
      // Assert
      expect(trash.length).assertEqual(0);
      PlanAppService.setPlanRepositoryForTest(null);
    });

    it('invalid: plan_app_service_load_trash_plans_should_bubble_repo_error', 0, async () => {
      // Arrange
      const repo = new PlanRepositorySpyAO();
      repo.throwMethod = 'getTrashPlans';
      PlanAppService.setPlanRepositoryForTest(repo);
      const service = PlanAppService.getInstance();
      // Act
      const message = await captureAsyncErrorAO(async (): Promise<void> => {
        await service.loadTrashPlans();
      });
      // Assert
      expect(message).assertEqual('getTrashPlans_failed_ao');
      PlanAppService.setPlanRepositoryForTest(null);
    });

    it('normal: plan_app_service_archive_plan_should_update_status_to_two', 0, async () => {
      // Arrange
      const repo = new PlanRepositorySpyAO();
      PlanAppService.setPlanRepositoryForTest(repo);
      const service = PlanAppService.getInstance();
      // Act
      await service.archivePlan(7);
      // Assert
      expect(repo.statusCalls.length).assertEqual(1);
      expect(repo.statusCalls[0].id).assertEqual(7);
      expect(repo.statusCalls[0].status).assertEqual(2);
      PlanAppService.setPlanRepositoryForTest(null);
    });

    it('boundary: plan_app_service_archive_plan_should_allow_zero_id', 0, async () => {
      // Arrange
      const repo = new PlanRepositorySpyAO();
      PlanAppService.setPlanRepositoryForTest(repo);
      const service = PlanAppService.getInstance();
      // Act
      await service.archivePlan(0);
      // Assert
      expect(repo.statusCalls[0].id).assertEqual(0);
      PlanAppService.setPlanRepositoryForTest(null);
    });

    it('invalid: plan_app_service_archive_plan_should_bubble_repo_error', 0, async () => {
      // Arrange
      const repo = new PlanRepositorySpyAO();
      repo.throwMethod = 'updatePlanStatus';
      PlanAppService.setPlanRepositoryForTest(repo);
      const service = PlanAppService.getInstance();
      // Act
      const message = await captureAsyncErrorAO(async (): Promise<void> => {
        await service.archivePlan(8);
      });
      // Assert
      expect(message).assertEqual('updatePlanStatus_failed_ao');
      PlanAppService.setPlanRepositoryForTest(null);
    });

    it('normal: plan_app_service_activate_plan_should_update_status_to_zero', 0, async () => {
      // Arrange
      const repo = new PlanRepositorySpyAO();
      PlanAppService.setPlanRepositoryForTest(repo);
      const service = PlanAppService.getInstance();
      // Act
      await service.activatePlan(9);
      // Assert
      expect(repo.statusCalls[0].id).assertEqual(9);
      expect(repo.statusCalls[0].status).assertEqual(0);
      PlanAppService.setPlanRepositoryForTest(null);
    });

    it('boundary: plan_app_service_activate_plan_should_allow_negative_id_passthrough', 0, async () => {
      // Arrange
      const repo = new PlanRepositorySpyAO();
      PlanAppService.setPlanRepositoryForTest(repo);
      const service = PlanAppService.getInstance();
      // Act
      await service.activatePlan(-9);
      // Assert
      expect(repo.statusCalls[0].id).assertEqual(-9);
      PlanAppService.setPlanRepositoryForTest(null);
    });

    it('invalid: plan_app_service_activate_plan_should_bubble_repo_error', 0, async () => {
      // Arrange
      const repo = new PlanRepositorySpyAO();
      repo.throwMethod = 'updatePlanStatus';
      PlanAppService.setPlanRepositoryForTest(repo);
      const service = PlanAppService.getInstance();
      // Act
      const message = await captureAsyncErrorAO(async (): Promise<void> => {
        await service.activatePlan(10);
      });
      // Assert
      expect(message).assertEqual('updatePlanStatus_failed_ao');
      PlanAppService.setPlanRepositoryForTest(null);
    });

    it('normal: plan_app_service_soft_delete_plan_should_delegate_id', 0, async () => {
      // Arrange
      const repo = new PlanRepositorySpyAO();
      PlanAppService.setPlanRepositoryForTest(repo);
      const service = PlanAppService.getInstance();
      // Act
      await service.softDeletePlan(11);
      // Assert
      expect(repo.softDeleteCalls[0]).assertEqual(11);
      PlanAppService.setPlanRepositoryForTest(null);
    });

    it('boundary: plan_app_service_soft_delete_plan_should_allow_zero_id', 0, async () => {
      // Arrange
      const repo = new PlanRepositorySpyAO();
      PlanAppService.setPlanRepositoryForTest(repo);
      const service = PlanAppService.getInstance();
      // Act
      await service.softDeletePlan(0);
      // Assert
      expect(repo.softDeleteCalls[0]).assertEqual(0);
      PlanAppService.setPlanRepositoryForTest(null);
    });

    it('invalid: plan_app_service_soft_delete_plan_should_bubble_repo_error', 0, async () => {
      // Arrange
      const repo = new PlanRepositorySpyAO();
      repo.throwMethod = 'softDeletePlan';
      PlanAppService.setPlanRepositoryForTest(repo);
      const service = PlanAppService.getInstance();
      // Act
      const message = await captureAsyncErrorAO(async (): Promise<void> => {
        await service.softDeletePlan(12);
      });
      // Assert
      expect(message).assertEqual('softDeletePlan_failed_ao');
      PlanAppService.setPlanRepositoryForTest(null);
    });

    it('normal: plan_app_service_restore_plan_should_delegate_id', 0, async () => {
      // Arrange
      const repo = new PlanRepositorySpyAO();
      PlanAppService.setPlanRepositoryForTest(repo);
      const service = PlanAppService.getInstance();
      // Act
      await service.restorePlan(13);
      // Assert
      expect(repo.restoreCalls[0]).assertEqual(13);
      PlanAppService.setPlanRepositoryForTest(null);
    });

    it('boundary: plan_app_service_restore_plan_should_allow_zero_id', 0, async () => {
      // Arrange
      const repo = new PlanRepositorySpyAO();
      PlanAppService.setPlanRepositoryForTest(repo);
      const service = PlanAppService.getInstance();
      // Act
      await service.restorePlan(0);
      // Assert
      expect(repo.restoreCalls[0]).assertEqual(0);
      PlanAppService.setPlanRepositoryForTest(null);
    });

    it('invalid: plan_app_service_restore_plan_should_bubble_repo_error', 0, async () => {
      // Arrange
      const repo = new PlanRepositorySpyAO();
      repo.throwMethod = 'restorePlan';
      PlanAppService.setPlanRepositoryForTest(repo);
      const service = PlanAppService.getInstance();
      // Act
      const message = await captureAsyncErrorAO(async (): Promise<void> => {
        await service.restorePlan(14);
      });
      // Assert
      expect(message).assertEqual('restorePlan_failed_ao');
      PlanAppService.setPlanRepositoryForTest(null);
    });

    it('normal: plan_app_service_hard_delete_plan_should_delegate_id', 0, async () => {
      // Arrange
      const repo = new PlanRepositorySpyAO();
      PlanAppService.setPlanRepositoryForTest(repo);
      const service = PlanAppService.getInstance();
      // Act
      await service.hardDeletePlan(15);
      // Assert
      expect(repo.hardDeleteCalls[0]).assertEqual(15);
      PlanAppService.setPlanRepositoryForTest(null);
    });

    it('boundary: plan_app_service_hard_delete_plan_should_allow_zero_id', 0, async () => {
      // Arrange
      const repo = new PlanRepositorySpyAO();
      PlanAppService.setPlanRepositoryForTest(repo);
      const service = PlanAppService.getInstance();
      // Act
      await service.hardDeletePlan(0);
      // Assert
      expect(repo.hardDeleteCalls[0]).assertEqual(0);
      PlanAppService.setPlanRepositoryForTest(null);
    });

    it('invalid: plan_app_service_hard_delete_plan_should_bubble_repo_error', 0, async () => {
      // Arrange
      const repo = new PlanRepositorySpyAO();
      repo.throwMethod = 'hardDeletePlan';
      PlanAppService.setPlanRepositoryForTest(repo);
      const service = PlanAppService.getInstance();
      // Act
      const message = await captureAsyncErrorAO(async (): Promise<void> => {
        await service.hardDeletePlan(16);
      });
      // Assert
      expect(message).assertEqual('hardDeletePlan_failed_ao');
      PlanAppService.setPlanRepositoryForTest(null);
    });
  });

  describe('phase2BatchAO_plan_app_service_runtime_and_permissions', () => {
    it('normal: plan_app_service_start_arrival_engine_should_delegate_to_engine', 0, () => {
      // Arrange
      const hooks = new ArrivalEngineHooksAO();
      const engine = new ArrivalEngineStubAO();
      hooks.setInstance(engine as Object);
      const service = PlanAppService.getInstance();
      // Act
      service.startArrivalEngine(21, new TimelineViewModel() as Object as TimelineViewModel, fakeHostContextAO());
      // Assert
      expect(engine.startCalls).assertEqual(1);
      expect(engine.lastPlanId).assertEqual(21);
      hooks.restore();
    });

    it('boundary: plan_app_service_start_arrival_engine_should_allow_zero_plan_id', 0, () => {
      // Arrange
      const hooks = new ArrivalEngineHooksAO();
      const engine = new ArrivalEngineStubAO();
      hooks.setInstance(engine as Object);
      const service = PlanAppService.getInstance();
      // Act
      service.startArrivalEngine(0, new TimelineViewModel() as Object as TimelineViewModel, fakeHostContextAO());
      // Assert
      expect(engine.lastPlanId).assertEqual(0);
      hooks.restore();
    });

    it('invalid: plan_app_service_start_arrival_engine_should_swallow_engine_error', 0, () => {
      // Arrange
      const hooks = new ArrivalEngineHooksAO();
      const engine = new ArrivalEngineStubAO();
      engine.throwOnStart = true;
      hooks.setInstance(engine as Object);
      const service = PlanAppService.getInstance();
      // Act
      const message = captureSyncErrorAO((): void => {
      service.startArrivalEngine(22, new TimelineViewModel() as Object as TimelineViewModel, fakeHostContextAO());
      });
      // Assert
      expect(message).assertEqual('');
      expect(engine.startCalls).assertEqual(1);
      hooks.restore();
    });

    it('normal: plan_app_service_stop_arrival_engine_should_delegate_once', 0, () => {
      // Arrange
      const hooks = new ArrivalEngineHooksAO();
      const engine = new ArrivalEngineStubAO();
      hooks.setInstance(engine as Object);
      const service = PlanAppService.getInstance();
      // Act
      service.stopArrivalEngine();
      // Assert
      expect(engine.stopCalls).assertEqual(1);
      hooks.restore();
    });

    it('boundary: plan_app_service_stop_arrival_engine_should_allow_repeated_calls', 0, () => {
      // Arrange
      const hooks = new ArrivalEngineHooksAO();
      const engine = new ArrivalEngineStubAO();
      hooks.setInstance(engine as Object);
      const service = PlanAppService.getInstance();
      // Act
      service.stopArrivalEngine();
      service.stopArrivalEngine();
      // Assert
      expect(engine.stopCalls).assertEqual(2);
      hooks.restore();
    });

    it('invalid: plan_app_service_stop_arrival_engine_should_bubble_engine_error', 0, () => {
      // Arrange
      const hooks = new ArrivalEngineHooksAO();
      const engine = new ArrivalEngineStubAO();
      engine.throwOnStop = true;
      hooks.setInstance(engine as Object);
      const service = PlanAppService.getInstance();
      // Act
      const message = captureSyncErrorAO((): void => {
        service.stopArrivalEngine();
      });
      // Assert
      expect(message).assertEqual('arrival_stop_failed_ao');
      hooks.restore();
    });

    it('normal: plan_app_service_request_arrival_check_should_forward_explicit_reason', 0, async () => {
      // Arrange
      const hooks = new ArrivalEngineHooksAO();
      const engine = new ArrivalEngineStubAO();
      hooks.setInstance(engine as Object);
      const service = PlanAppService.getInstance();
      // Act
      await service.requestArrivalCheckNow('toolbar');
      // Assert
      expect(engine.requestCalls).assertEqual(1);
      expect(engine.lastReason).assertEqual('toolbar');
      hooks.restore();
    });

    it('boundary: plan_app_service_request_arrival_check_should_use_default_reason', 0, async () => {
      // Arrange
      const hooks = new ArrivalEngineHooksAO();
      const engine = new ArrivalEngineStubAO();
      hooks.setInstance(engine as Object);
      const service = PlanAppService.getInstance();
      // Act
      await service.requestArrivalCheckNow();
      // Assert
      expect(engine.lastReason).assertEqual('manual_refresh');
      hooks.restore();
    });

    it('invalid: plan_app_service_request_arrival_check_should_bubble_engine_error', 0, async () => {
      // Arrange
      const hooks = new ArrivalEngineHooksAO();
      const engine = new ArrivalEngineStubAO();
      engine.throwOnRequest = true;
      hooks.setInstance(engine as Object);
      const service = PlanAppService.getInstance();
      // Act
      const message = await captureAsyncErrorAO(async (): Promise<void> => {
        await service.requestArrivalCheckNow('bad_reason');
      });
      // Assert
      expect(message).assertEqual('arrival_request_failed_ao');
      hooks.restore();
    });

    it('normal: plan_app_service_get_arrival_prompt_state_should_read_both_flags', 0, async () => {
      // Arrange
      const hooks = new PreferenceHooksAO();
      const pref = new PreferenceInstanceStubAO();
      pref.values.set(PreferenceManager.KEY_ARRIVAL_NOTIFY_PROMPTED, true);
      pref.values.set(PreferenceManager.KEY_ARRIVAL_LOCATION_PROMPTED, false);
      hooks.setInstance(pref as Object);
      const service = PlanAppService.getInstance();
      // Act
      const state = await service.getArrivalPromptState(fakeUiContextAO());
      // Assert
      expect(state.notifyPrompted).assertTrue();
      expect(state.locationPrompted).assertFalse();
      expect(pref.initCount).assertEqual(1);
      hooks.restore();
    });

    it('boundary: plan_app_service_get_arrival_prompt_state_should_allow_both_false', 0, async () => {
      // Arrange
      const hooks = new PreferenceHooksAO();
      const pref = new PreferenceInstanceStubAO();
      pref.values.set(PreferenceManager.KEY_ARRIVAL_NOTIFY_PROMPTED, false);
      pref.values.set(PreferenceManager.KEY_ARRIVAL_LOCATION_PROMPTED, false);
      hooks.setInstance(pref as Object);
      const service = PlanAppService.getInstance();
      // Act
      const state = await service.getArrivalPromptState(fakeUiContextAO());
      // Assert
      expect(state.notifyPrompted).assertFalse();
      expect(state.locationPrompted).assertFalse();
      hooks.restore();
    });

    it('invalid: plan_app_service_get_arrival_prompt_state_should_bubble_preference_error', 0, async () => {
      // Arrange
      const hooks = new PreferenceHooksAO();
      const pref = new PreferenceInstanceStubAO();
      pref.throwOnInit = true;
      hooks.setInstance(pref as Object);
      const service = PlanAppService.getInstance();
      // Act
      const message = await captureAsyncErrorAO(async (): Promise<void> => {
        await service.getArrivalPromptState(fakeUiContextAO());
      });
      // Assert
      expect(message).assertEqual('pref_init_failed_ao');
      hooks.restore();
    });

    it('normal: plan_app_service_mark_notify_prompted_should_set_notify_flag', 0, async () => {
      // Arrange
      const hooks = new PreferenceHooksAO();
      const pref = new PreferenceInstanceStubAO();
      hooks.setInstance(pref as Object);
      const service = PlanAppService.getInstance();
      // Act
      await service.markNotifyPrompted(fakeUiContextAO());
      // Assert
      expect(pref.setCalls.length).assertEqual(1);
      expect(pref.setCalls[0].key).assertEqual(PreferenceManager.KEY_ARRIVAL_NOTIFY_PROMPTED);
      expect(pref.setCalls[0].value).assertTrue();
      hooks.restore();
    });

    it('boundary: plan_app_service_mark_notify_prompted_should_allow_repeated_sets', 0, async () => {
      // Arrange
      const hooks = new PreferenceHooksAO();
      const pref = new PreferenceInstanceStubAO();
      hooks.setInstance(pref as Object);
      const service = PlanAppService.getInstance();
      // Act
      await service.markNotifyPrompted(fakeUiContextAO());
      await service.markNotifyPrompted(fakeUiContextAO());
      // Assert
      expect(pref.setCalls.length).assertEqual(2);
      hooks.restore();
    });

    it('invalid: plan_app_service_mark_notify_prompted_should_bubble_preference_error', 0, async () => {
      // Arrange
      const hooks = new PreferenceHooksAO();
      const pref = new PreferenceInstanceStubAO();
      pref.throwOnSet = true;
      hooks.setInstance(pref as Object);
      const service = PlanAppService.getInstance();
      // Act
      const message = await captureAsyncErrorAO(async (): Promise<void> => {
        await service.markNotifyPrompted(fakeUiContextAO());
      });
      // Assert
      expect(message).assertEqual('pref_set_failed_ao');
      hooks.restore();
    });

    it('normal: plan_app_service_mark_location_prompted_should_set_location_flag', 0, async () => {
      // Arrange
      const hooks = new PreferenceHooksAO();
      const pref = new PreferenceInstanceStubAO();
      hooks.setInstance(pref as Object);
      const service = PlanAppService.getInstance();
      // Act
      await service.markLocationPrompted(fakeUiContextAO());
      // Assert
      expect(pref.setCalls.length).assertEqual(1);
      expect(pref.setCalls[0].key).assertEqual(PreferenceManager.KEY_ARRIVAL_LOCATION_PROMPTED);
      expect(pref.setCalls[0].value).assertTrue();
      hooks.restore();
    });

    it('boundary: plan_app_service_mark_location_prompted_should_allow_repeated_sets', 0, async () => {
      // Arrange
      const hooks = new PreferenceHooksAO();
      const pref = new PreferenceInstanceStubAO();
      hooks.setInstance(pref as Object);
      const service = PlanAppService.getInstance();
      // Act
      await service.markLocationPrompted(fakeUiContextAO());
      await service.markLocationPrompted(fakeUiContextAO());
      // Assert
      expect(pref.setCalls.length).assertEqual(2);
      hooks.restore();
    });

    it('invalid: plan_app_service_mark_location_prompted_should_bubble_preference_error', 0, async () => {
      // Arrange
      const hooks = new PreferenceHooksAO();
      const pref = new PreferenceInstanceStubAO();
      pref.throwOnSet = true;
      hooks.setInstance(pref as Object);
      const service = PlanAppService.getInstance();
      // Act
      const message = await captureAsyncErrorAO(async (): Promise<void> => {
        await service.markLocationPrompted(fakeUiContextAO());
      });
      // Assert
      expect(message).assertEqual('pref_set_failed_ao');
      hooks.restore();
    });

    it('normal: plan_app_service_is_notification_enabled_should_return_true_when_kit_returns_true', 0, async () => {
      // Arrange
      const hooks = new NotificationHooksAO();
      hooks.setIsEnabled((): boolean => true);
      const service = PlanAppService.getInstance();
      // Act
      const enabled = await service.isNotificationEnabled();
      // Assert
      expect(enabled).assertTrue();
      hooks.restore();
    });

    it('boundary: plan_app_service_is_notification_enabled_should_return_false_when_kit_returns_false', 0, async () => {
      // Arrange
      const hooks = new NotificationHooksAO();
      hooks.setIsEnabled((): boolean => false);
      const service = PlanAppService.getInstance();
      // Act
      const enabled = await service.isNotificationEnabled();
      // Assert
      expect(enabled).assertFalse();
      hooks.restore();
    });

    it('invalid: plan_app_service_is_notification_enabled_should_fallback_false_on_exception', 0, async () => {
      // Arrange
      const hooks = new NotificationHooksAO();
      hooks.setIsEnabled((): boolean => {
        throw new Error('notify_check_failed_ao');
      });
      const service = PlanAppService.getInstance();
      // Act
      const enabled = await service.isNotificationEnabled();
      // Assert
      expect(enabled).assertFalse();
      hooks.restore();
    });

    it('normal: plan_app_service_request_enable_notification_should_resolve_when_kit_succeeds', 0, async () => {
      // Arrange
      const hooks = new NotificationHooksAO();
      let called = 0;
      hooks.setRequestEnable(async (_hostContext: common.UIAbilityContext): Promise<void> => {
        called += 1;
      });
      const service = PlanAppService.getInstance();
      // Act
      await service.requestEnableNotification(fakeUiContextAO());
      // Assert
      expect(called).assertEqual(1);
      hooks.restore();
    });

    it('boundary: plan_app_service_request_enable_notification_should_stringify_non_error_reason', 0, async () => {
      // Arrange
      const hooks = new NotificationHooksAO();
      hooks.setRequestEnable(async (_hostContext: common.UIAbilityContext): Promise<void> => {
        throw new Error(JSON.stringify({ code: 403, reason: 'denied' }));
      });
      const service = PlanAppService.getInstance();
      // Act
      const message = await captureAsyncErrorAO(async (): Promise<void> => {
        await service.requestEnableNotification(fakeUiContextAO());
      });
      // Assert
      expect(message).assertEqual('{"code":403,"reason":"denied"}');
      hooks.restore();
    });

    it('invalid: plan_app_service_request_enable_notification_should_throw_error_message', 0, async () => {
      // Arrange
      const hooks = new NotificationHooksAO();
      hooks.setRequestEnable(async (_hostContext: common.UIAbilityContext): Promise<void> => {
        throw new Error('notify_request_failed_ao');
      });
      const service = PlanAppService.getInstance();
      // Act
      const message = await captureAsyncErrorAO(async (): Promise<void> => {
        await service.requestEnableNotification(fakeUiContextAO());
      });
      // Assert
      expect(message).assertEqual('notify_request_failed_ao');
      hooks.restore();
    });

    it('normal: plan_app_service_is_location_permission_granted_should_return_true_on_grant', 0, async () => {
      // Arrange
      const hooks = new AbilityHooksAO();
      const manager = new PermissionManagerStubAO();
      manager.checkResult = abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
      hooks.setAtManager(manager as Object);
      hooks.setBundleInfo(123);
      const service = PlanAppService.getInstance();
      // Act
      const granted = await service.isLocationPermissionGranted();
      // Assert
      expect(granted).assertTrue();
      hooks.restore();
    });

    it('boundary: plan_app_service_is_location_permission_granted_should_return_false_on_deny', 0, async () => {
      // Arrange
      const hooks = new AbilityHooksAO();
      const manager = new PermissionManagerStubAO();
      manager.checkResult = -1;
      hooks.setAtManager(manager as Object);
      hooks.setBundleInfo(456);
      const service = PlanAppService.getInstance();
      // Act
      const granted = await service.isLocationPermissionGranted();
      // Assert
      expect(granted).assertFalse();
      hooks.restore();
    });

    it('invalid: plan_app_service_is_location_permission_granted_should_fallback_false_on_exception', 0, async () => {
      // Arrange
      const hooks = new AbilityHooksAO();
      const manager = new PermissionManagerStubAO();
      manager.throwOnCheck = true;
      hooks.setAtManager(manager as Object);
      hooks.setBundleInfo(789);
      const service = PlanAppService.getInstance();
      // Act
      const granted = await service.isLocationPermissionGranted();
      // Assert
      expect(granted).assertFalse();
      hooks.restore();
    });

    it('normal: plan_app_service_request_location_permissions_should_return_true_when_any_granted', 0, async () => {
      // Arrange
      const hooks = new AbilityHooksAO();
      const manager = new PermissionManagerStubAO();
      manager.requestResults = [1, 0];
      hooks.setAtManager(manager as Object);
      hooks.setBundleInfo(321);
      const service = PlanAppService.getInstance();
      // Act
      const granted = await service.requestLocationPermissions(fakeUiContextAO());
      // Assert
      expect(granted).assertTrue();
      hooks.restore();
    });

    it('boundary: plan_app_service_request_location_permissions_should_return_false_when_all_denied', 0, async () => {
      // Arrange
      const hooks = new AbilityHooksAO();
      const manager = new PermissionManagerStubAO();
      manager.requestResults = [2, 1];
      hooks.setAtManager(manager as Object);
      hooks.setBundleInfo(654);
      const service = PlanAppService.getInstance();
      // Act
      const granted = await service.requestLocationPermissions(fakeUiContextAO());
      // Assert
      expect(granted).assertFalse();
      hooks.restore();
    });

    it('invalid: plan_app_service_request_location_permissions_should_fallback_false_on_exception', 0, async () => {
      // Arrange
      const hooks = new AbilityHooksAO();
      const manager = new PermissionManagerStubAO();
      manager.throwOnRequest = true;
      hooks.setAtManager(manager as Object);
      hooks.setBundleInfo(987);
      const service = PlanAppService.getInstance();
      // Act
      const granted = await service.requestLocationPermissions(fakeUiContextAO());
      // Assert
      expect(granted).assertFalse();
      hooks.restore();
    });

    it('combined: plan_app_service_repo_and_permission_paths_should_work_together', 0, async () => {
      // Arrange
      const repo = new PlanRepositorySpyAO();
      repo.planList = [buildPlanItemAO(31, 0, 'visible')];
      PlanAppService.setPlanRepositoryForTest(repo);
      const notificationHooks = new NotificationHooksAO();
      notificationHooks.setIsEnabled((): boolean => true);
      const service = PlanAppService.getInstance();
      // Act
      const visible = await service.loadVisiblePlans();
      const enabled = await service.isNotificationEnabled();
      // Assert
      expect(visible.length).assertEqual(1);
      expect(enabled).assertTrue();
      notificationHooks.restore();
      PlanAppService.setPlanRepositoryForTest(null);
    });
  });
}
