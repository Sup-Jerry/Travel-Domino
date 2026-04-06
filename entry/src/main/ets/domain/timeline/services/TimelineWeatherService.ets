import { hilog } from '@kit.PerformanceAnalysisKit';
import { EventEntity } from '../../../model/entity/EventEntity';
import { EventFieldUpdate } from '../../../infrastructure/persistence/EventRepositoryImpl';
import { EventRepositoryImpl } from '../../../infrastructure/persistence/EventRepositoryImpl';
import { PlanRepositoryImpl } from '../../../infrastructure/persistence/PlanRepositoryImpl';
import { AmapService } from '../../../infrastructure/services/AmapService';
import { TimelineExecutionState } from '../../policy/TimelineExecutionState';
import { PlanStatus } from '../../statemachine/PlanStatus';
import { PreferenceManager } from '../../../common/utils/PreferenceManager';
import { ComposableStrategy } from '../../strategy/TravelStrategyDimensions';
import { StrategyAdaptationEngine } from '../../strategy/StrategyAdaptationEngine';
import { WeatherFacade } from '../../services/WeatherFacade';
import { WeatherRefreshScheduler } from '../../services/WeatherRefreshScheduler';
import { WeatherReminderStore, WeatherStrategyAdjustment } from '../../../common/utils/weather/WeatherReminderStore';
import { ArrivalReminderEngine } from '../../../infrastructure/services/ArrivalReminderEngine';
import {
  DEFAULT_WEATHER_USER_PREFERENCE,
  GeoPointInput,
  PlanNodeWeatherBinding,
  ReplanChangeSummaryItem,
  WeatherCollabOptions,
  SoftReplanApplyResult,
  SoftReplanMode,
  SoftReplanPreview,
  WeatherContextBuildResult,
  WeatherSchedulePolicy,
  WeatherStageType,
  WeatherSuggestion,
  WeatherSuggestionActionType,
  WeatherUserPreference
} from '../../services/WeatherModels';

const TAG = 'TimelineViewModel';

interface WeatherPlanStateTransitionRequest {
  planId: string;
  reason: string;
  currentNodeId?: string;
  preserveCompletedNodes: boolean;
  preserveStartedWindow: boolean;
  useWeatherConstraint: boolean;
}

interface WeatherPlanStateGateResult {
  success: boolean;
  reasonCode?: string;
  startFromEventId?: number;
}

interface WeatherPlanStateMachine {
  requestSoftReplan(args: WeatherPlanStateTransitionRequest): WeatherPlanStateGateResult;
}

interface ReplanNodeSnapshot {
  id: number;
  sortOrder: number;
  duration: number;
  startTs: number;
  endTs: number;
}

interface PlanningWeatherSnapshot {
  hint: string;
  score: number;
  collabSummary: string;
  strategyHint: string;
  refreshedAt: number;
}

export interface ITimelineWeatherHost {
  events: EventEntity[];
  planId: number;
  currentStrategyMode: number;
  weatherFeatureEnabled: boolean;
  weatherLoading: boolean;
  weatherUserPreference: WeatherUserPreference;
  weatherCollabOptions: WeatherCollabOptions;
  executionWeatherEnabled: boolean;
  executionWeatherLoading: boolean;
  currentPlanStatus: PlanStatus;
  executionWeatherLastTrigger: string;
  executionWeatherErrorCode: string;
  executionWeatherScore: number;
  executionWeatherRefreshAt: number;
  executionWeatherCollabSummary: string;
  executionWeatherCollabBadge: string;
  executionWeatherDisplaySource: 'CURRENT' | 'NEXT_FALLBACK' | 'UNKNOWN';
  executionWeatherCurrentText: string;
  executionWeatherNextText: string;
  executionWeatherSuggestions: WeatherSuggestion[];
  executionSuggestionMap: Map<string, WeatherSuggestion>;
  executionWeatherHint: string;
  executionWeatherLevel: 'INFO' | 'NOTICE' | 'WARNING';
  executionWeatherLastLocation: GeoPointInput | null;
  executionWeatherLocationTriggerCooldownMs: number;
  executionWeatherLastLocationTriggerAt: number;
  currentWeatherSchedulePolicy: WeatherSchedulePolicy;
  executionReplanBusy: boolean;
  executionWeatherApplying: boolean;
  executionWeatherAppliedSummary: string;
  executionWeatherLastEmitAt: number;
  executionWeatherLocationDeltaMeters: number;
  executionSuggestionCooldownMs: number;
  executionSuggestionCooldownMap: Map<string, number>;

  weatherPlanningHint: string;
  weatherRouteScore: number;
  weatherCollabSummary: string;
  weatherCollabLabel: string;
  weatherStrategyHint: string;
  weatherLastRefreshAt: number;

  resolveCurrentWeatherStage(): WeatherStageType;
  getCurrentStrategy(): Promise<ComposableStrategy>;

  getCurrentPlanStatus(): PlanStatus;
  findCurrentActiveEvent(): EventEntity | null;
  getOrderedScheduleEvents(): EventEntity[];
  getMinEventDurationLimit(): number;
  skipEvent(item: EventEntity): Promise<void>;
  planStateMachine: WeatherPlanStateMachine;
  recalculateFromEventId(eventId: number): void;
  recalculateFromIndex(startIndex: number): void;
  markScheduleChanged(): void;
}

export interface ITimelineWeatherService {
  refreshPlanningWeather(forceRefresh?: boolean): Promise<void>;
  applyPlanningWeatherResult(result: WeatherContextBuildResult, forceRefresh: boolean): Promise<void>;
  refreshExecutionWeather(
    forceRefresh?: boolean,
    trigger?: 'ENTER_EXECUTION' | 'LOCATION_CHANGE' | 'TIMER' | 'MANUAL',
    stage?: WeatherStageType
  ): Promise<void>;
  requestSoftReplan(planId: number, suggestionId: string, mode: SoftReplanMode): Promise<SoftReplanApplyResult>;
  applyWeatherSuggestion(suggestionId: string): Promise<SoftReplanApplyResult>;
  dismissExecutionSuggestion(suggestionId: string): void;
  isExecutionWeatherStage(): boolean;
  startExecutionWeatherScheduler(planId?: number, stage?: WeatherStageType): void;
  stopExecutionWeatherScheduler(): void;
  getWeatherUserPreference(): WeatherUserPreference;
  isWeatherFeatureEnabled(): boolean;
  buildWeatherScoreExplanation(score: number): string;
  buildWeatherHintExplanation(): string;
  buildPlanningWeatherHintExplanation(): string;
  getExecutionWeatherDisplaySource(): 'CURRENT' | 'NEXT_FALLBACK' | 'UNKNOWN';
  shouldAutoRefreshPlanningWeather(maxAgeMs?: number): boolean;
  clearWeatherRuntimeState(): void;
  resolveCoordinatesForPlaceName(
    placeName: string,
    lat?: number,
    lng?: number,
    source?: 'add' | 'update',
    fallbackLat?: number,
    fallbackLng?: number
  ): Promise<GeoPointInput>;
  isCoordinateMissingForWeather(latitude: number, longitude: number): boolean;
  isValidCoordinate(latitude: number, longitude: number): boolean;
  reloadWeatherUserPreference(): Promise<void>;
  restorePlanningWeatherSnapshot(planId: number): void;
  setWeatherFeatureEnabled(enabled: boolean): Promise<void>;
  updateWeatherUserPreference(preference: WeatherUserPreference): Promise<void>;
}

export class TimelineWeatherService implements ITimelineWeatherService {
  private host: ITimelineWeatherHost;
  private weatherFacade: WeatherFacade;
  private weatherScheduler: WeatherRefreshScheduler;
  private weatherStrategyAppliedKey: string = '';

  constructor(host: ITimelineWeatherHost, weatherFacade: WeatherFacade, weatherScheduler: WeatherRefreshScheduler) {
    this.host = host;
    this.weatherFacade = weatherFacade;
    this.weatherScheduler = weatherScheduler;
  }

  public async refreshPlanningWeather(forceRefresh: boolean = false): Promise<void> {
    if (!this.host.weatherFeatureEnabled) {
      this.clearWeatherRuntimeState();
      return;
    }
    if (this.host.weatherLoading) {
      return;
    }
    this.host.weatherLoading = true;
    try {
      const stage = this.host.resolveCurrentWeatherStage();
      const scheduleEvents = this.host.events.filter((item: EventEntity) => item.status === 1);
      await this.backfillPlanningCoordinatesByName(scheduleEvents);
      const validGeoCount = scheduleEvents.filter((item: EventEntity) =>
        this.isValidCoordinate(item.latitude, item.longitude)
      ).length;
      const missingGeoEvents = scheduleEvents.filter((item: EventEntity) =>
        this.isCoordinateMissingForWeather(item.latitude, item.longitude)
      );
      const missingNamePreview = missingGeoEvents
        .slice(0, 3)
        .map((item: EventEntity) => item.name.trim())
        .join('|');
      hilog.info(0x0000, TAG, `[WEATHER_STAGE][planning] stage=${stage}`);
      hilog.info(0x0000, TAG, `[WEATHER_PREF][planning_begin] schedule=${scheduleEvents.length}, validGeo=${validGeoCount}, forceRefresh=${forceRefresh}`);
      if (missingGeoEvents.length > 0) {
        hilog.warn(
          0x0000,
          TAG,
          `[WEATHER_PREF][planning_geo_missing] count=${missingGeoEvents.length}, sample=${missingNamePreview}`
        );
      }
      const result = await this.weatherFacade.buildPlanningContext(
        this.host.events,
        this.host.weatherUserPreference,
        this.host.weatherCollabOptions,
        stage
      );
      await this.applyPlanningWeatherResult(result, forceRefresh);
      hilog.info(
        0x0000,
        TAG,
        `[WEATHER_PREF][planning] heat=${this.host.weatherUserPreference.heatSensitivity}, rain=${this.host.weatherUserPreference.rainSensitivity}, tolerance=${this.host.weatherUserPreference.weatherRiskTolerance}`
      );
    } finally {
      this.host.weatherLoading = false;
    }
  }

  public async applyPlanningWeatherResult(result: WeatherContextBuildResult, forceRefresh: boolean): Promise<void> {
    const context = result.context;
    this.host.weatherRouteScore = context.routeSuitability.routeScore;
    this.host.weatherPlanningHint = context.routeSuitability.summaryText;
    this.host.weatherCollabSummary = context.collabContext?.collabSummary ?? '';
    this.host.weatherCollabLabel = this.host.weatherCollabSummary.trim().length > 0 ? '多日/多城' : '';
    this.host.weatherLastRefreshAt = Date.now();
    this.persistPlanningWeatherSnapshot();

    this.host.events.forEach((event: EventEntity) => {
      const binding = result.eventMap.get(event.id);
      if (!binding) {
        if (event.status === 1 && (event.latitude !== 0 || event.longitude !== 0)) {
          event.weather_text = '天气未知';
          event.weather_condition = 'UNKNOWN';
          event.weather_temperature = 0;
          event.weather_fetch_time = Date.now();
        }
        return;
      }
      event.weather_text = binding.weather?.conditionText || '天气未知';
      event.weather_condition = binding.weather?.conditionCode || 'UNKNOWN';
      event.weather_temperature = binding.weather?.temperatureCelsius ?? 0;
      event.weather_fetch_time = binding.weather?.fetchTime ?? Date.now();
      if (forceRefresh && event.id > 0) {
        const updates: EventFieldUpdate[] = [
          { column: EventEntity.WEATHER_CONDITION, value: event.weather_condition },
          { column: EventEntity.WEATHER_TEMPERATURE, value: event.weather_temperature },
          { column: EventEntity.WEATHER_TEXT, value: event.weather_text },
          { column: EventEntity.WEATHER_FETCH_TIME, value: event.weather_fetch_time }
        ];
        void EventRepositoryImpl.updateFields(event.id, updates, this.host.planId);
      }
    });

    const unknownCount = this.host.events.filter((event: EventEntity) =>
      event.status === 1 && (((event.weather_text || '').trim().length === 0) || event.weather_text === '天气未知')
    ).length;
    hilog.info(
      0x0000,
      TAG,
      `[WEATHER_PREF][planning_apply] total=${this.host.events.filter((item: EventEntity) => item.status === 1).length}, unknown=${unknownCount}, routeScore=${this.host.weatherRouteScore}`
    );

    const currentStrategy = await this.host.getCurrentStrategy();
    const weatherDecision = StrategyAdaptationEngine.adaptToWeather(
      context.collabContext,
      context.routeSuitability.routeScore,
      currentStrategy
    );
    if (weatherDecision) {
      const nextStrategy = StrategyAdaptationEngine.applyAdjustment(currentStrategy, weatherDecision);
      const hasStrategyChange = nextStrategy.density !== currentStrategy.density ||
        nextStrategy.pace !== currentStrategy.pace ||
        nextStrategy.preference !== currentStrategy.preference ||
        nextStrategy.energy !== currentStrategy.energy;
      const adaptationKey = this.buildWeatherStrategyAdaptationKey(
        context.generatedAt,
        context.routeSuitability.routeScore
      );
      if (hasStrategyChange && adaptationKey !== this.weatherStrategyAppliedKey) {
        await PlanRepositoryImpl.updateStrategyDimensions(
          this.host.planId,
          nextStrategy.density,
          nextStrategy.pace,
          nextStrategy.preference,
          nextStrategy.energy
        );
        this.host.currentStrategyMode = -1;
        this.host.weatherStrategyHint = weatherDecision.message;
        this.weatherStrategyAppliedKey = adaptationKey;
        hilog.info(
          0x0000,
          TAG,
          `[WEATHER_STRATEGY][planning_applied] reason=${weatherDecision.reason}, generatedAt=${context.generatedAt}, score=${context.routeSuitability.routeScore}, trend=${context.collabContext?.trendTag ?? 'UNKNOWN'}`
        );
      } else if (hasStrategyChange) {
        this.host.weatherStrategyHint = weatherDecision.message;
      } else {
        this.host.weatherStrategyHint = '';
      }
    } else {
      this.host.weatherStrategyHint = '';
    }
    this.host.events = [...this.host.events];
  }

  public clearWeatherRuntimeState(): void {
    this.host.weatherRouteScore = -1;
    this.host.weatherPlanningHint = '';
    this.host.weatherStrategyHint = '';
    this.host.weatherCollabSummary = '';
    this.host.weatherCollabLabel = '';
    this.host.executionWeatherHint = '';
    this.host.executionWeatherCurrentText = '';
    this.host.executionWeatherDisplaySource = 'UNKNOWN';
    this.host.executionWeatherNextText = '';
    this.host.executionWeatherScore = -1;
    this.host.executionWeatherErrorCode = '';
    this.host.executionWeatherSuggestions = [];
    this.host.executionWeatherAppliedSummary = '';
    this.host.executionWeatherCollabBadge = '';
    this.host.executionWeatherCollabSummary = '';
    this.weatherStrategyAppliedKey = '';
  }

  private buildWeatherStrategyAdaptationKey(generatedAt: number, routeScore: number): string {
    return `${generatedAt}_${routeScore}`;
  }

  private getPlanningWeatherSnapshotKey(planId: number): string {
    return `PlanningWeatherSnapshot_${planId}`;
  }

  private persistPlanningWeatherSnapshot(): void {
    if (this.host.planId <= 0) {
      return;
    }
    const snapshot: PlanningWeatherSnapshot = {
      hint: this.host.weatherPlanningHint,
      score: this.host.weatherRouteScore,
      collabSummary: this.host.weatherCollabSummary,
      strategyHint: this.host.weatherStrategyHint,
      refreshedAt: this.host.weatherLastRefreshAt
    };
    AppStorage.setOrCreate(this.getPlanningWeatherSnapshotKey(this.host.planId), JSON.stringify(snapshot));
  }

  private async backfillPlanningCoordinatesByName(scheduleEvents: EventEntity[]): Promise<void> {
    const geocodeCache: Map<string, GeoPointInput | null> = new Map();
    for (const event of scheduleEvents) {
      if (!this.isCoordinateMissingForWeather(event.latitude, event.longitude)) {
        continue;
      }
      const placeName = event.name.trim();
      if (placeName.length === 0) {
        continue;
      }
      let cached = geocodeCache.get(placeName);
      if (cached === undefined) {
        const geocode = await AmapService.getGeocode(placeName);
        if (geocode && this.isValidCoordinate(geocode.lat, geocode.lng)) {
          cached = { latitude: geocode.lat, longitude: geocode.lng };
          hilog.info(0x0000, TAG, `[WEATHER_GEO][planning_fill] geocode_hit id=${event.id}, name=${placeName}, lat=${geocode.lat}, lng=${geocode.lng}`);
        } else {
          cached = null;
          hilog.warn(0x0000, TAG, `[WEATHER_GEO][planning_fill] geocode_miss id=${event.id}, name=${placeName}`);
        }
        geocodeCache.set(placeName, cached);
      }
      if (!cached) {
        continue;
      }
      event.latitude = cached.latitude;
      event.longitude = cached.longitude;
      if (event.id > 0) {
        const updates: EventFieldUpdate[] = [
          { column: 'latitude', value: cached.latitude },
          { column: 'longitude', value: cached.longitude }
        ];
        await EventRepositoryImpl.updateFields(event.id, updates, this.host.planId);
      }
    }
  }

  public isCoordinateMissingForWeather(latitude: number, longitude: number): boolean {
    if (!this.isValidCoordinate(latitude, longitude)) {
      return true;
    }
    return latitude === -1 || longitude === -1 || latitude === 0 || longitude === 0;
  }

  public isValidCoordinate(latitude: number, longitude: number): boolean {
    return Number.isFinite(latitude) &&
      Number.isFinite(longitude) &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180 &&
      !(latitude === 0 && longitude === 0);
  }

  public isExecutionWeatherStage(): boolean {
    return this.host.currentPlanStatus === PlanStatus.READY ||
      this.host.currentPlanStatus === PlanStatus.IN_PROGRESS ||
      this.host.currentPlanStatus === PlanStatus.PAUSED ||
      this.host.events.some((event: EventEntity) => TimelineExecutionState.isActive(event));
  }

  public startExecutionWeatherScheduler(_planId?: number, stage?: WeatherStageType): void {
    if (!this.host.weatherFeatureEnabled) {
      this.stopExecutionWeatherScheduler();
      return;
    }
    this.host.executionWeatherEnabled = true;
    const resolvedStage = stage ?? this.host.resolveCurrentWeatherStage();
    this.host.currentWeatherSchedulePolicy = this.weatherFacade.resolveSchedulePolicy(resolvedStage);
    hilog.info(
      0x0000,
      TAG,
      `[WEATHER_STAGE][scheduler_start] stage=${resolvedStage}, intervalMs=${this.host.currentWeatherSchedulePolicy.pollIntervalMs}`
    );
    this.weatherScheduler.start(this.host.currentWeatherSchedulePolicy.pollIntervalMs, () => {
      if (!this.host.weatherFeatureEnabled) {
        return;
      }
      if (this.host.currentPlanStatus === PlanStatus.CONFIRMED) {
        if (this.shouldAutoRefreshPlanningWeather()) {
          void this.refreshPlanningWeather(false);
        }
        return;
      }
      void this.refreshExecutionWeather(false, 'TIMER', resolvedStage);
    });
    if (this.host.currentWeatherSchedulePolicy.forceRefreshOnEnter) {
      if (resolvedStage === 'CONFIRMED' || resolvedStage === 'PLANNING') {
        if (this.shouldAutoRefreshPlanningWeather()) {
          void this.refreshPlanningWeather(true);
        }
      } else {
        void this.refreshExecutionWeather(true, 'ENTER_EXECUTION', resolvedStage);
      }
    }
  }

  public stopExecutionWeatherScheduler(): void {
    this.host.executionWeatherEnabled = false;
    this.weatherScheduler.stop();
  }

  public async refreshExecutionWeather(
    forceRefresh: boolean = false,
    trigger: 'ENTER_EXECUTION' | 'LOCATION_CHANGE' | 'TIMER' | 'MANUAL' = 'MANUAL',
    stage?: WeatherStageType
  ): Promise<void> {
    if (!this.host.weatherFeatureEnabled) {
      return;
    }
    if (!this.host.executionWeatherEnabled && trigger !== 'MANUAL') {
      return;
    }
    if (this.host.executionWeatherLoading) {
      return;
    }
    if (!this.isExecutionWeatherStage() && trigger !== 'MANUAL') {
      return;
    }
    const resolvedStage = stage ?? this.host.resolveCurrentWeatherStage();
    const policy = this.weatherFacade.resolveSchedulePolicy(resolvedStage);
    if (trigger === 'LOCATION_CHANGE' && !policy.allowLocationTrigger) {
      return;
    }
    this.host.executionWeatherLoading = true;
    this.host.executionWeatherLastTrigger = trigger;
    this.host.executionWeatherErrorCode = '';
    hilog.info(0x0000, TAG, `[WEATHER_STAGE][refresh_begin] stage=${resolvedStage}, trigger=${trigger}, forceRefresh=${forceRefresh}`);
    hilog.info(0x0000, TAG, `[WEATHER_EXEC][refresh_begin] trigger=${trigger}, forceRefresh=${forceRefresh}`);
    hilog.info(
      0x0000,
      TAG,
      `[WEATHER_REPLAN][refresh_begin] trigger=${trigger}, forceRefresh=${forceRefresh}, prefHeat=${this.host.weatherUserPreference.heatSensitivity}, prefRain=${this.host.weatherUserPreference.rainSensitivity}, prefTolerance=${this.host.weatherUserPreference.weatherRiskTolerance}`
    );

    try {
      const currentLocation = this.resolveExecutionCurrentLocation();
      if ((trigger === 'TIMER' || trigger === 'LOCATION_CHANGE') && !forceRefresh &&
        this.shouldSkipByLocationThreshold(currentLocation)) {
        this.host.executionWeatherLoading = false;
        return;
      }
      if (trigger === 'LOCATION_CHANGE' && !forceRefresh) {
        const nowTs = Date.now();
        if (nowTs - this.host.executionWeatherLastLocationTriggerAt < this.host.executionWeatherLocationTriggerCooldownMs) {
          this.host.executionWeatherLoading = false;
          return;
        }
        this.host.executionWeatherLastLocationTriggerAt = nowTs;
      }

      const result = await this.weatherFacade.buildExecutionContext(
        this.host.events,
        currentLocation ?? undefined,
        forceRefresh,
        this.host.weatherUserPreference,
        this.host.weatherCollabOptions,
        resolvedStage
      );
      const context = result.context;
      const collab = context.collabContext;
      this.host.executionWeatherScore = context.executionRiskScore ?? -1;
      this.host.executionWeatherRefreshAt = Date.now();
      this.host.executionWeatherCollabSummary = collab?.collabSummary ?? '';
      this.host.executionWeatherCollabBadge = this.host.executionWeatherCollabSummary.trim().length > 0
        ? (collab && collab.cityGroupCount > 1 ? '跨城协同中' : '多日趋势已纳入')
        : '';
      if (context.currentLocationWeather) {
        this.host.executionWeatherDisplaySource = 'CURRENT';
        this.host.executionWeatherCurrentText = `${context.currentLocationWeather.conditionText}${Number.isFinite(context.currentLocationWeather.temperatureCelsius) ? ` ${context.currentLocationWeather.temperatureCelsius}°C` : ''}`;
      } else if (context.nextNodeWeather) {
        this.host.executionWeatherDisplaySource = 'NEXT_FALLBACK';
        this.host.executionWeatherCurrentText = `按下一节点天气估算（${context.nextNodeWeather.conditionText}${Number.isFinite(context.nextNodeWeather.temperatureCelsius) ? ` ${context.nextNodeWeather.temperatureCelsius}°C` : ''}）`;
      } else {
        this.host.executionWeatherDisplaySource = 'UNKNOWN';
        this.host.executionWeatherCurrentText = '天气未知';
      }
      this.host.executionWeatherNextText = context.nextNodeWeather
        ? `${context.nextNodeWeather.conditionText}${Number.isFinite(context.nextNodeWeather.temperatureCelsius) ? ` ${context.nextNodeWeather.temperatureCelsius}°C` : ''}`
        : '天气未知';

      const suggestions = this.weatherFacade.buildExecutionAdjustments(
        this.host.planId,
        context,
        result.sourceEvents,
        this.host.weatherUserPreference
      );
      this.host.executionWeatherSuggestions = this.filterActiveExecutionSuggestions(suggestions);
      this.host.executionSuggestionMap.clear();
      this.host.executionWeatherSuggestions.forEach((item: WeatherSuggestion) => {
        this.host.executionSuggestionMap.set(item.suggestionId, item);
      });
      hilog.info(
        0x0000,
        TAG,
        `[WEATHER_REPLAN][suggestion_sync] listSize=${this.host.executionWeatherSuggestions.length}, mapSize=${this.host.executionSuggestionMap.size}`
      );
      if (this.host.executionWeatherSuggestions.length > 0) {
        this.applyExecutionSuggestion(this.host.executionWeatherSuggestions[0], trigger);
      } else {
        this.host.executionWeatherHint = '执行天气稳定，按当前节奏继续即可。';
        this.host.executionWeatherLevel = 'INFO';
      }
      this.patchExecutionWeatherToEvents(result.eventMap, forceRefresh);
      this.host.events = [...this.host.events];
      if (currentLocation) {
        this.host.executionWeatherLastLocation = {
          latitude: currentLocation.latitude,
          longitude: currentLocation.longitude
        };
      }
      hilog.info(
        0x0000,
        TAG,
        `[WEATHER_EXEC][refresh_done] trigger=${trigger}, targets=${result.sourceEvents.length}, suggestions=${this.host.executionWeatherSuggestions.length}, score=${this.host.executionWeatherScore}, level=${this.host.executionWeatherLevel}, dayWindowCount=${collab?.dayWindowCount ?? 0}, cityGroupCount=${collab?.cityGroupCount ?? 0}, cityCappedCount=${collab?.cityCappedCount ?? 0}, cityMissCount=${collab?.cityMissCount ?? 0}, trendTag=${collab?.trendTag ?? 'UNKNOWN'}, fallbackPath=${collab?.fallbackPath ?? ''}`
      );
      hilog.info(
        0x0000,
        TAG,
        `[WEATHER_REPLAN][refresh_done] trigger=${trigger}, requestTargets=${result.sourceEvents.length}, cacheHit=0, failures=${this.host.executionWeatherErrorCode || 'NONE'}, prefHeat=${this.host.weatherUserPreference.heatSensitivity}, prefRain=${this.host.weatherUserPreference.rainSensitivity}, dayWindowCount=${collab?.dayWindowCount ?? 0}, cityGroupCount=${collab?.cityGroupCount ?? 0}, cityCappedCount=${collab?.cityCappedCount ?? 0}, cityMissCount=${collab?.cityMissCount ?? 0}, trendTag=${collab?.trendTag ?? 'UNKNOWN'}, fallbackPath=${collab?.fallbackPath ?? ''}`
      );
    } catch (error) {
      this.host.executionWeatherErrorCode = 'WEATHER_002';
      this.host.executionWeatherHint = '执行天气刷新失败，已降级使用节点天气/缓存。';
      this.host.executionWeatherDisplaySource = 'UNKNOWN';
      this.host.executionWeatherCollabBadge = '';
      this.host.executionWeatherCollabSummary = '';
      hilog.warn(0x0000, TAG, `[WEATHER_EXEC][refresh_failed] trigger=${trigger}, reason=${JSON.stringify(error)}`);
      hilog.warn(0x0000, TAG, `[WEATHER_REPLAN][refresh_failed] trigger=${trigger}, reason=${JSON.stringify(error)}`);
    } finally {
      this.host.executionWeatherLoading = false;
    }
  }

  public async requestSoftReplan(
    planId: number,
    suggestionId: string,
    mode: SoftReplanMode
  ): Promise<SoftReplanApplyResult> {
    const emptyPreview: SoftReplanPreview = {
      suggestionId: suggestionId,
      actionType: 'NONE',
      changedOrder: false,
      changedDurations: false,
      skippedNodeIds: [],
      affectedNodeIds: [],
      reasonCode: 'no_suggestion',
      startFromEventId: 0,
      changeSummary: [],
      summary: '无可用建议',
      riskDelta: 0
    };
    const failWithLog = (
      errorCode: '' | 'REPLAN_CONFLICT' | 'REPLAN_IMMUTABLE' | 'REPLAN_NO_CANDIDATE' | 'REPLAN_TIMEOUT' | 'REPLAN_INVALID' | 'REPLAN_BUSY',
      reasonCode: string,
      startFromEventId: number,
      preview: SoftReplanPreview,
      rolledBack: boolean,
      actionType: WeatherSuggestionActionType = 'NONE'
    ): SoftReplanApplyResult => {
      this.logSoftReplanFailure(
        planId,
        suggestionId,
        mode,
        this.host.getCurrentPlanStatus(),
        errorCode,
        reasonCode,
        startFromEventId,
        actionType,
        preview.affectedNodeIds.length
      );
      return {
        success: false,
        rolledBack: rolledBack,
        errorCode: errorCode,
        reasonCode: reasonCode,
        startFromEventId: startFromEventId,
        preview: preview
      };
    };
    if (planId <= 0 || this.host.planId !== planId || !suggestionId || suggestionId.trim().length === 0) {
      return failWithLog('REPLAN_INVALID', 'invalid_input', 0, emptyPreview, false);
    }
    const status = this.host.getCurrentPlanStatus();
    const suggestionInList = this.host.executionWeatherSuggestions.some((item: WeatherSuggestion) => item.suggestionId === suggestionId);
    const mapHasSuggestion = this.host.executionSuggestionMap.has(suggestionId);
    hilog.info(
      0x0000,
      TAG,
      `[WEATHER_REPLAN][apply_begin] planId=${planId}, suggestionId=${suggestionId}, mode=${mode}, status=${status}, busy=${this.host.executionReplanBusy ? 1 : 0}, listSize=${this.host.executionWeatherSuggestions.length}, mapSize=${this.host.executionSuggestionMap.size}, suggestionInList=${suggestionInList ? 1 : 0}, mapHasSuggestion=${mapHasSuggestion ? 1 : 0}`
    );
    if (!(status === PlanStatus.READY || status === PlanStatus.IN_PROGRESS || status === PlanStatus.PAUSED)) {
      return failWithLog('REPLAN_INVALID', 'status_blocked', 0, emptyPreview, false);
    }
    if (this.host.executionReplanBusy) {
      return failWithLog('REPLAN_BUSY', 'busy', 0, emptyPreview, false);
    }
    const activeEvent = this.host.findCurrentActiveEvent();
    const softGate = this.host.planStateMachine.requestSoftReplan({
      planId: `${planId}`,
      reason: 'weather_suggestion',
      currentNodeId: activeEvent ? `${activeEvent.id}` : undefined,
      preserveCompletedNodes: true,
      preserveStartedWindow: true,
      useWeatherConstraint: true
    });
    if (!softGate.success) {
      return failWithLog(
        'REPLAN_INVALID',
        softGate.reasonCode ?? 'status_blocked',
        softGate.startFromEventId ?? 0,
        emptyPreview,
        false
      );
    }
    const suggestion = this.host.executionSuggestionMap.get(suggestionId);
    if (!suggestion) {
      return failWithLog('REPLAN_INVALID', 'suggestion_missing', 0, emptyPreview, false);
    }
    const preview = this.buildSoftReplanPreview(suggestion, softGate.reasonCode, softGate.startFromEventId ?? 0);
    if (mode === 'PREVIEW') {
      return {
        success: true,
        rolledBack: false,
        errorCode: '',
        reasonCode: preview.reasonCode,
        startFromEventId: preview.startFromEventId,
        preview: preview
      };
    }

    this.host.executionReplanBusy = true;
    this.host.executionWeatherApplying = true;
    const snapshot = this.cloneEventSnapshot();
    const beforeNodes = this.snapshotScheduleNodes();
    const startedAt = Date.now();
    try {
      if (this.containsImmutableNode(this.resolveSoftReplanTargetEventIds(suggestion.actionPayload?.targetNodeIds ?? suggestion.relatedNodeIds))) {
        preview.reasonCode = 'immutable_blocked';
        preview.changeSummary = [{
          type: 'IMMUTABLE_BLOCKED',
          nodeId: '',
          before: 'pending',
          after: 'blocked',
          deltaMinutes: 0
        }];
        return failWithLog(
          'REPLAN_IMMUTABLE',
          preview.reasonCode ?? 'immutable_blocked',
          preview.startFromEventId ?? 0,
          preview,
          false,
          suggestion.actionType
        );
      }
      const applyOk = await this.applySuggestionAction(suggestion);
      if (!applyOk) {
        this.restoreEventSnapshot(snapshot);
        return failWithLog(
          'REPLAN_CONFLICT',
          'apply_failed',
          preview.startFromEventId ?? 0,
          preview,
          true,
          suggestion.actionType
        );
      }
      const startFromEventId = softGate.startFromEventId && softGate.startFromEventId > 0
        ? softGate.startFromEventId
        : this.resolveSoftReplanStartEventId(preview);
      if (startFromEventId > 0) {
        this.host.recalculateFromEventId(startFromEventId);
      } else {
        this.host.recalculateFromIndex(0);
      }
      if (Date.now() - startedAt > 10_000) {
        this.restoreEventSnapshot(snapshot);
        return failWithLog(
          'REPLAN_TIMEOUT',
          'timeout',
          startFromEventId,
          preview,
          true,
          suggestion.actionType
        );
      }
      const afterNodes = this.snapshotScheduleNodes();
      const structuredSummary = this.buildStructuredReplanSummary(beforeNodes, afterNodes, preview.affectedNodeIds);
      preview.startFromEventId = startFromEventId;
      preview.changeSummary = structuredSummary;
      preview.summary = this.composeReplanSummaryText(preview, structuredSummary);
      this.host.executionWeatherAppliedSummary = preview.summary;
      this.host.executionWeatherHint = preview.summary;
      this.host.executionWeatherLevel = 'NOTICE';
      this.host.executionWeatherSuggestions = this.host.executionWeatherSuggestions.filter((item: WeatherSuggestion) =>
        item.suggestionId !== suggestionId
      );
      this.host.executionSuggestionMap.delete(suggestionId);
      this.host.markScheduleChanged();
      hilog.info(
        0x0000,
        TAG,
        `[WEATHER_REPLAN][apply_done] mode=${mode}, suggestionId=${suggestionId}, action=${suggestion.actionType}, affected=${preview.affectedNodeIds.length}, riskDelta=${preview.riskDelta}, reason=${softGate.reasonCode ?? ''}, startFromEventId=${softGate.startFromEventId ?? 0}, rolledBack=false, result=SUCCESS`
      );
      return {
        success: true,
        rolledBack: false,
        errorCode: '',
        reasonCode: preview.reasonCode,
        startFromEventId: preview.startFromEventId,
        preview: preview
      };
    } catch (error) {
      this.restoreEventSnapshot(snapshot);
      hilog.warn(0x0000, TAG, `[WEATHER_REPLAN][apply_failed] suggestionId=${suggestionId}, rolledBack=true, result=FAILED, reason=${JSON.stringify(error)}`);
      return failWithLog(
        'REPLAN_CONFLICT',
        'exception',
        preview.startFromEventId ?? 0,
        preview,
        true,
        suggestion.actionType
      );
    } finally {
      this.host.executionReplanBusy = false;
      this.host.executionWeatherApplying = false;
    }
  }


  public applyExecutionSuggestion(suggestion: WeatherSuggestion, trigger: string): void {
    this.host.executionSuggestionMap.set(suggestion.suggestionId, suggestion);
    this.host.executionWeatherHint = suggestion.message;
    this.host.executionWeatherLevel = suggestion.level;

    const now = Date.now();
    if (now - this.host.executionWeatherLastEmitAt < 90_000 && trigger !== 'MANUAL') {
      return;
    }
    if (this.isExecutionSuggestionCoolingDown(suggestion, now) && trigger !== 'MANUAL') {
      return;
    }
    this.host.executionWeatherLastEmitAt = now;
    this.markExecutionSuggestionCooldown(suggestion, now);

    if (suggestion.level === 'NOTICE' || suggestion.level === 'WARNING') {
      const strategyHint = this.buildExecutionStrategyHint(suggestion);
      const strategyAdjustment = this.buildExecutionStrategyAdjustment(suggestion);
      const payload = WeatherReminderStore.fromSuggestion(this.host.planId, suggestion, strategyHint, strategyAdjustment);
      WeatherReminderStore.writePayload(payload);
      const candidateCount = suggestion.actionPayload?.replacementCandidates?.length ?? 0;
      hilog.info(
        0x0000,
        TAG,
        `[WEATHER_REPLAN][reminder_emit] level=${suggestion.level}, trigger=${trigger}, action=${suggestion.actionType}, candidates=${candidateCount}, message=${suggestion.message}`
      );
    }
  }

  private buildExecutionStrategyHint(suggestion: WeatherSuggestion): string | undefined {
    if (suggestion.triggerType === 'RAIN') {
      return '明日有雨，建议降低行程密度。';
    }
    if (suggestion.triggerType === 'HEAT') {
      return '持续高温，建议减少体力消耗。';
    }
    return undefined;
  }

  private buildExecutionStrategyAdjustment(suggestion: WeatherSuggestion): WeatherStrategyAdjustment | undefined {
    if (suggestion.triggerType === 'RAIN') {
      return { density: -1 };
    }
    if (suggestion.triggerType === 'HEAT') {
      return { pace: -1, energy: -1 };
    }
    return undefined;
  }

  public filterActiveExecutionSuggestions(items: WeatherSuggestion[]): WeatherSuggestion[] {
    const now = Date.now();
    const filtered = items.filter((item: WeatherSuggestion) => {
      if (!item) {
        return false;
      }
      if (item.expiresAt > 0 && item.expiresAt < now) {
        return false;
      }
      return !this.isExecutionSuggestionCoolingDown(item, now);
    });
    filtered.sort((a: WeatherSuggestion, b: WeatherSuggestion) => {
      const levelWeight = (level: 'INFO' | 'NOTICE' | 'WARNING'): number =>
        level === 'WARNING' ? 3 : (level === 'NOTICE' ? 2 : 1);
      if (levelWeight(a.level) !== levelWeight(b.level)) {
        return levelWeight(b.level) - levelWeight(a.level);
      }
      return a.createdAt - b.createdAt;
    });
    return filtered;
  }

  private isExecutionSuggestionCoolingDown(suggestion: WeatherSuggestion, now: number): boolean {
    const key = suggestion.cooldownKey || suggestion.suggestionId;
    const last = this.host.executionSuggestionCooldownMap.get(key) ?? 0;
    return last > 0 && now - last < this.host.executionSuggestionCooldownMs;
  }

  private markExecutionSuggestionCooldown(suggestion: WeatherSuggestion, now: number): void {
    const key = suggestion.cooldownKey || suggestion.suggestionId;
    this.host.executionSuggestionCooldownMap.set(key, now);
  }

  public logSoftReplanFailure(
    planId: number,
    suggestionId: string,
    mode: SoftReplanMode,
    status: PlanStatus,
    errorCode: string,
    reasonCode: string,
    startFromEventId: number,
    actionType: WeatherSuggestionActionType,
    affectedNodeCount: number
  ): void {
    hilog.warn(
      0x0000,
      TAG,
      `[WEATHER_REPLAN][apply_fail] planId=${planId}, suggestionId=${suggestionId}, mode=${mode}, status=${status}, errorCode=${errorCode}, reasonCode=${reasonCode}, startFromEventId=${startFromEventId}, actionType=${actionType}, affectedNodeCount=${affectedNodeCount}`
    );
  }

  public buildSoftReplanPreview(
    suggestion: WeatherSuggestion,
    reasonCode: string | undefined,
    startFromEventId: number
  ): SoftReplanPreview {
    const payload = suggestion.actionPayload;
    const affectedNodeIds = payload?.targetNodeIds ?? suggestion.relatedNodeIds ?? [];
    const skippedNodeIds = suggestion.actionType === 'SKIP_NODE' ? affectedNodeIds.slice(0, 1) : [];
    const changedOrder = suggestion.actionType === 'REORDER' || suggestion.actionType === 'REPLACE_NODE';
    const changedDurations = suggestion.actionType === 'SHORTEN_STAY';
    let summary = '天气建议已准备，可应用调整。';
    if (suggestion.actionType === 'REORDER') {
      summary = `已应用顺序调整，影响 ${affectedNodeIds.length} 个节点。`;
    } else if (suggestion.actionType === 'SHORTEN_STAY') {
      const mins = payload?.suggestedStayMinutes ?? 45;
      summary = `已缩短停留时长至约 ${mins} 分钟。`;
    } else if (suggestion.actionType === 'SKIP_NODE') {
      summary = '已跳过高风险节点，继续后续安排。';
    } else if (suggestion.actionType === 'REPLACE_NODE') {
      summary = '已切换到保守执行策略（替代建议）。';
    }
    return {
      suggestionId: suggestion.suggestionId,
      actionType: suggestion.actionType,
      changedOrder: changedOrder,
      changedDurations: changedDurations,
      skippedNodeIds: skippedNodeIds,
      affectedNodeIds: affectedNodeIds,
      reasonCode: reasonCode ?? this.resolveReplanReasonCode(suggestion.actionType),
      startFromEventId: startFromEventId,
      changeSummary: [],
      summary: summary,
      riskDelta: suggestion.level === 'WARNING' ? -20 : (suggestion.level === 'NOTICE' ? -10 : -5)
    };
  }

  private resolveReplanReasonCode(actionType: WeatherSuggestionActionType): string {
    if (actionType === 'REORDER') {
      return 'order_adjusted';
    }
    if (actionType === 'SHORTEN_STAY') {
      return 'duration_adjusted';
    }
    if (actionType === 'SKIP_NODE') {
      return 'node_skipped';
    }
    if (actionType === 'REPLACE_NODE') {
      return 'node_replaced';
    }
    return 'soft_replan';
  }

  public snapshotScheduleNodes(): Map<number, ReplanNodeSnapshot> {
    const map = new Map<number, ReplanNodeSnapshot>();
    this.host.events.filter((item: EventEntity) => item.status === 1).forEach((item: EventEntity) => {
      map.set(item.id, {
        id: item.id,
        sortOrder: item.sort_order,
        duration: item.duration,
        startTs: item.dynamic_start_time,
        endTs: item.dynamic_end_time
      });
    });
    return map;
  }

  public buildStructuredReplanSummary(
    beforeMap: Map<number, ReplanNodeSnapshot>,
    afterMap: Map<number, ReplanNodeSnapshot>,
    affectedNodeIds: string[]
  ): ReplanChangeSummaryItem[] {
    const summary: ReplanChangeSummaryItem[] = [];
    const ids: number[] = [];
    (affectedNodeIds || []).forEach((idText: string) => {
      const id = Number(idText);
      if (Number.isFinite(id) && id > 0) {
        ids.push(id);
      }
    });
    ids.forEach((id: number) => {
      const before = beforeMap.get(id);
      const after = afterMap.get(id);
      if (!before || !after) {
        return;
      }
      if (before.sortOrder !== after.sortOrder) {
        summary.push({
          type: 'ORDER_CHANGED',
          nodeId: `${id}`,
          before: `${before.sortOrder}`,
          after: `${after.sortOrder}`
        });
      }
      if (before.duration !== after.duration) {
        summary.push({
          type: 'DURATION_CHANGED',
          nodeId: `${id}`,
          before: `${before.duration}`,
          after: `${after.duration}`,
          deltaMinutes: after.duration - before.duration
        });
      }
      if (before.startTs !== after.startTs || before.endTs !== after.endTs) {
        summary.push({
          type: 'TIME_SHIFTED',
          nodeId: `${id}`,
          before: `${before.startTs}-${before.endTs}`,
          after: `${after.startTs}-${after.endTs}`,
          deltaMinutes: Math.round((after.startTs - before.startTs) / 60000)
        });
      }
    });
    if (summary.length === 0) {
      summary.push({
        type: 'NO_OP',
        nodeId: '',
        before: 'stable',
        after: 'stable',
        deltaMinutes: 0
      });
    }
    return summary;
  }

  public composeReplanSummaryText(preview: SoftReplanPreview, structured: ReplanChangeSummaryItem[]): string {
    const orderCount = structured.filter((item: ReplanChangeSummaryItem) => item.type === 'ORDER_CHANGED').length;
    const durationCount = structured.filter((item: ReplanChangeSummaryItem) => item.type === 'DURATION_CHANGED').length;
    const shiftCount = structured.filter((item: ReplanChangeSummaryItem) => item.type === 'TIME_SHIFTED').length;
    if (preview.reasonCode === 'immutable_blocked') {
      return '命中已完成/锁定节点保护，未执行重排。';
    }
    if (orderCount === 0 && durationCount === 0 && shiftCount === 0) {
      return '重排执行完成，计划保持稳定。';
    }
    return `重排完成：顺序变更 ${orderCount} 项，时长变更 ${durationCount} 项，时间偏移 ${shiftCount} 项。`;
  }

  public async applySuggestionAction(suggestion: WeatherSuggestion): Promise<boolean> {
    const payload = suggestion.actionPayload;
    const targetIds = this.resolveSoftReplanTargetEventIds(payload?.targetNodeIds ?? suggestion.relatedNodeIds);
    if (targetIds.length === 0 && suggestion.actionType !== 'NONE') {
      return false;
    }
    if (this.containsImmutableNode(targetIds)) {
      return false;
    }
    if (suggestion.actionType === 'REORDER') {
      return await this.applySoftReorder(payload?.targetOrderNodeIds ?? []);
    }
    if (suggestion.actionType === 'SHORTEN_STAY') {
      return await this.applySoftShorten(targetIds, payload?.suggestedStayMinutes);
    }
    if (suggestion.actionType === 'SKIP_NODE') {
      return await this.applySoftSkip(targetIds);
    }
    if (suggestion.actionType === 'REPLACE_NODE') {
      const candidateCount = suggestion.actionPayload?.replacementCandidates?.length ?? 0;
      hilog.info(0x0000, TAG, `[WEATHER_REPLAN][replace_quality] candidates=${candidateCount}, suggestionId=${suggestion.suggestionId}`);
      const reordered = await this.applySoftReorder(payload?.targetOrderNodeIds ?? []);
      if (reordered) {
        return true;
      }
      hilog.info(0x0000, TAG, `[WEATHER_REPLAN][replace_fallback] suggestionId=${suggestion.suggestionId}, fallback=SHORTEN_STAY, targetCount=${targetIds.length}`);
      return await this.applySoftShorten(targetIds, payload?.suggestedStayMinutes ?? 45);
    }
    return true;
  }

  public resolveSoftReplanTargetEventIds(nodeIds: string[]): number[] {
    const allowed = this.getSoftReplanFutureCandidates().map((item: EventEntity) => item.id);
    const allowSet = new Set<number>(allowed);
    const resolved: number[] = [];
    (nodeIds || []).forEach((idText: string) => {
      const id = Number(idText);
      if (Number.isFinite(id) && allowSet.has(id)) {
        resolved.push(id);
      }
    });
    return resolved;
  }

  public resolveSoftReplanStartEventId(preview: SoftReplanPreview): number {
    const ids = preview.affectedNodeIds ?? [];
    if (ids.length === 0) {
      return 0;
    }
    let minId = Number.MAX_SAFE_INTEGER;
    ids.forEach((idText: string) => {
      const id = Number(idText);
      if (Number.isFinite(id) && id > 0 && id < minId) {
        minId = id;
      }
    });
    return minId === Number.MAX_SAFE_INTEGER ? 0 : minId;
  }

  public getSoftReplanFutureCandidates(): EventEntity[] {
    const ordered = this.host.getOrderedScheduleEvents();
    const pending = ordered.filter((item: EventEntity) => item.completion_status === EventEntity.STATE_PENDING);
    const active = pending.find((item: EventEntity) => TimelineExecutionState.isActive(item));
    let start = 0;
    if (active) {
      const idx = pending.findIndex((item: EventEntity) => item.id === active.id);
      start = idx >= 0 ? Math.min(idx + 1, Math.max(0, pending.length - 1)) : 0;
    }
    return pending.slice(start, start + 3);
  }

  public containsImmutableNode(targetIds: number[]): boolean {
    return targetIds.some((id: number) => {
      const event = this.host.events.find((item: EventEntity) => item.id === id);
      if (!event) {
        return true;
      }
      if (event.completion_status !== EventEntity.STATE_PENDING) {
        return true;
      }
      return event.lock_status === 1 && !!event.fixed_start_time;
    });
  }

  public async applySoftReorder(orderNodeIds: string[]): Promise<boolean> {
    if (!orderNodeIds || orderNodeIds.length < 2) {
      return false;
    }
    const targetIds = this.resolveSoftReplanTargetEventIds(orderNodeIds);
    if (targetIds.length < 2) {
      return false;
    }
    const schedule = this.host.events.filter((item: EventEntity) => item.status === 1);
    const byId = new Map<number, EventEntity>();
    schedule.forEach((item: EventEntity) => byId.set(item.id, item));

    const reorderedTargets: EventEntity[] = [];
    targetIds.forEach((id: number) => {
      const found = byId.get(id);
      if (found) {
        reorderedTargets.push(found);
      }
    });
    if (reorderedTargets.length < 2) {
      return false;
    }

    const targetSet = new Set<number>(reorderedTargets.map((item: EventEntity) => item.id));
    const merged: EventEntity[] = [];
    let writeIdx = 0;
    schedule.forEach((item: EventEntity) => {
      if (targetSet.has(item.id)) {
        if (writeIdx < reorderedTargets.length) {
          merged.push(reorderedTargets[writeIdx]);
          writeIdx += 1;
        } else {
          merged.push(item);
        }
      } else {
        merged.push(item);
      }
    });
    merged.forEach((item: EventEntity, idx: number) => {
      item.sort_order = idx * 100;
    });
    await EventRepositoryImpl.updateTimelineConsistency(merged.map((item: EventEntity) => item.toInterface()), this.host.planId);
    this.host.events.sort((a: EventEntity, b: EventEntity) => {
      if (a.status !== b.status) {
        return b.status - a.status;
      }
      return a.sort_order - b.sort_order;
    });
    this.host.recalculateFromIndex(0);
    return true;
  }

  public async applySoftShorten(targetIds: number[], suggestedStayMinutes?: number): Promise<boolean> {
    if (!targetIds || targetIds.length === 0) {
      return false;
    }
    const normalizedSuggestion = suggestedStayMinutes ?? 45;
    const minutes = Number.isFinite(normalizedSuggestion) && normalizedSuggestion > 0
      ? Math.floor(normalizedSuggestion)
      : 45;
    const minAllowed = Math.max(20, this.host.getMinEventDurationLimit());
    const newDuration = Math.max(minAllowed, minutes);
    let changed = false;
    for (let i = 0; i < targetIds.length; i++) {
      const target = this.host.events.find((item: EventEntity) => item.id === targetIds[i]);
      if (!target || target.duration <= newDuration) {
        continue;
      }
      target.duration = newDuration;
      await EventRepositoryImpl.updateSingleField(target.id, EventEntity.DURATION, target.duration, this.host.planId);
      changed = true;
    }
    if (changed) {
      this.host.recalculateFromIndex(0);
    }
    return changed;
  }

  public async applySoftSkip(targetIds: number[]): Promise<boolean> {
    if (!targetIds || targetIds.length === 0) {
      return false;
    }
    const target = this.host.events.find((item: EventEntity) => item.id === targetIds[0]);
    if (!target) {
      return false;
    }
    await this.host.skipEvent(target);
    return true;
  }

  public cloneEventSnapshot(): EventEntity[] {
    return this.host.events.map((item: EventEntity) => EventEntity.fromInterface(item.toInterface(), this.host.planId));
  }

  public restoreEventSnapshot(snapshot: EventEntity[]): void {
    this.host.events = snapshot.map((item: EventEntity) => EventEntity.fromInterface(item.toInterface(), this.host.planId));
    this.host.recalculateFromIndex(0);
  }

  public patchExecutionWeatherToEvents(eventMap: Map<number, PlanNodeWeatherBinding>, forceRefresh: boolean): void {
    this.host.events.forEach((event: EventEntity) => {
      if (event.completion_status !== EventEntity.STATE_PENDING) {
        return;
      }
      const binding = eventMap.get(event.id);
      if (!binding) {
        return;
      }
      event.weather_text = binding.weather?.conditionText ?? '天气未知';
      event.weather_condition = binding.weather?.conditionCode ?? 'UNKNOWN';
      event.weather_temperature = binding.weather?.temperatureCelsius ?? 0;
      event.weather_fetch_time = binding.weather?.fetchTime ?? Date.now();
      if (forceRefresh && event.id > 0) {
        const updates: EventFieldUpdate[] = [
          { column: EventEntity.WEATHER_CONDITION, value: event.weather_condition },
          { column: EventEntity.WEATHER_TEMPERATURE, value: event.weather_temperature },
          { column: EventEntity.WEATHER_TEXT, value: event.weather_text },
          { column: EventEntity.WEATHER_FETCH_TIME, value: event.weather_fetch_time }
        ];
        void EventRepositoryImpl.updateFields(event.id, updates, this.host.planId);
      }
    });
  }

  private resolveExecutionCurrentLocation(): GeoPointInput | null {
    const snapshot = ArrivalReminderEngine.getInstance().getLastKnownLocation();
    if (snapshot && this.isValidCoordinate(snapshot.latitude, snapshot.longitude)) {
      return { latitude: snapshot.latitude, longitude: snapshot.longitude };
    }

    const active = this.host.findCurrentActiveEvent();
    if (active && this.isValidCoordinate(active.latitude, active.longitude)) {
      return { latitude: active.latitude, longitude: active.longitude };
    }

    const next = this.findNextPendingEvent(active?.id ?? 0);
    if (next && this.isValidCoordinate(next.latitude, next.longitude)) {
      return { latitude: next.latitude, longitude: next.longitude };
    }
    return null;
  }

  private findNextPendingEvent(activeEventId: number): EventEntity | null {
    const ordered = this.host.getOrderedScheduleEvents();
    if (ordered.length === 0) {
      return null;
    }
    let startIndex = 0;
    if (activeEventId > 0) {
      const idx = ordered.findIndex((item: EventEntity) => item.id === activeEventId);
      startIndex = idx >= 0 ? idx + 1 : 0;
    }
    for (let i = startIndex; i < ordered.length; i++) {
      const item = ordered[i];
      if (item.completion_status === EventEntity.STATE_PENDING) {
        return item;
      }
    }
    return null;
  }

  private shouldSkipByLocationThreshold(currentLocation: GeoPointInput | null): boolean {
    if (!currentLocation || !this.host.executionWeatherLastLocation) {
      return false;
    }
    const delta = this.measureDistanceMeters(
      currentLocation.latitude,
      currentLocation.longitude,
      this.host.executionWeatherLastLocation.latitude,
      this.host.executionWeatherLastLocation.longitude
    );
    return delta < this.host.executionWeatherLocationDeltaMeters;
  }

  private measureDistanceMeters(lat1: number, lng1: number, lat2: number, lng2: number): number {
    const rad = (deg: number): number => deg * Math.PI / 180;
    const earthRadius = 6378137;
    const dLat = rad(lat2 - lat1);
    const dLng = rad(lng2 - lng1);
    const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(rad(lat1)) * Math.cos(rad(lat2)) * Math.sin(dLng / 2) * Math.sin(dLng / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return earthRadius * c;
  }

  public async applyWeatherSuggestion(suggestionId: string): Promise<SoftReplanApplyResult> {
    return this.requestSoftReplan(this.host.planId, suggestionId, 'APPLY');
  }

  public dismissExecutionSuggestion(suggestionId: string): void {
    if (!suggestionId || suggestionId.trim().length === 0) {
      return;
    }
    this.host.executionWeatherSuggestions = this.host.executionWeatherSuggestions.filter((item: WeatherSuggestion) =>
      item.suggestionId !== suggestionId
    );
    this.host.executionSuggestionMap.delete(suggestionId);
  }

  public getWeatherUserPreference(): WeatherUserPreference {
    return {
      heatSensitivity: this.host.weatherUserPreference.heatSensitivity,
      rainSensitivity: this.host.weatherUserPreference.rainSensitivity,
      weatherRiskTolerance: this.host.weatherUserPreference.weatherRiskTolerance
    };
  }

  public isWeatherFeatureEnabled(): boolean {
    return this.host.weatherFeatureEnabled;
  }

  public buildWeatherScoreExplanation(score: number): string {
    if (!Number.isFinite(score) || score < 0) {
      return '暂无可用天气评分。评分范围 0-100，分值越高代表路线受天气影响越小。';
    }
    const safeScore = Math.max(0, Math.min(100, Math.floor(score)));
    let level = '低风险';
    let desc = '天气条件较稳定，可按当前计划执行。';
    if (safeScore < 70) {
      level = '高风险';
      desc = '天气对路线影响明显，建议优先室内点位或减少暴露时长。';
    } else if (safeScore < 85) {
      level = '中风险';
      desc = '部分节点受天气影响，建议关注时段变化并准备替代方案。';
    }
    const riskMeaning = safeScore < 70
      ? '含义：后续节点更容易发生顺序变化、停留压缩或替代建议。'
      : (safeScore < 85
        ? '含义：计划可执行，但部分时段可能触发轻量调整。'
        : '含义：总体稳定，通常不需要对行程做结构性改动。');
    return `天气评分：${safeScore}\n等级：${level}\n区间：0-69 高风险，70-84 中风险，85-100 低风险。\n说明：评分会综合降雨/温度风险、你的怕热/怕雨/风险容忍偏好，以及多日多城协同结果。\n${riskMeaning}\n建议：${desc}`;
  }

  public buildWeatherHintExplanation(): string {
    const sourceText = this.host.executionWeatherDisplaySource === 'CURRENT'
      ? '当前定位天气'
      : (this.host.executionWeatherDisplaySource === 'NEXT_FALLBACK' ? '下一节点天气估算' : '当前定位缺失');
    const hint = this.host.executionWeatherHint && this.host.executionWeatherHint.trim().length > 0
      ? this.host.executionWeatherHint
      : this.host.weatherPlanningHint;
    const safeHint = hint && hint.trim().length > 0 ? hint : '当前暂无额外天气提示。';
    const collab = this.host.weatherCollabSummary && this.host.weatherCollabSummary.trim().length > 0
      ? this.host.weatherCollabSummary
      : this.host.executionWeatherCollabSummary;
    const collabExplain = collab && collab.trim().length > 0
      ? `多日/多城说明：${collab}\n作用：表示系统在跨城市、跨日期对天气趋势做了联合评估，用于提前发现“后续转差/转好”。`
      : '多日/多城说明：当前无跨日跨城协同摘要。';
    return `提示来源：${sourceText}\n当前提示：${safeHint}\n${collabExplain}\n该提示仅用于辅助决策，不会自动修改行程。`;
  }

  public buildPlanningWeatherHintExplanation(): string {
    const sourceText = '计划节点天气（已按地点批量计算）';
    const safeHint = this.host.weatherPlanningHint && this.host.weatherPlanningHint.trim().length > 0
      ? this.host.weatherPlanningHint
      : '当前暂无额外天气提示。';
    const collabExplain = this.host.weatherCollabSummary && this.host.weatherCollabSummary.trim().length > 0
      ? `多日/多城说明：${this.host.weatherCollabSummary}\n作用：用于提前判断跨日跨城趋势变化，减少后续被动改计划。`
      : '多日/多城说明：当前无跨日跨城协同摘要。';
    return `提示来源：${sourceText}\n当前提示：${safeHint}\n${collabExplain}\n该提示仅用于辅助决策，不会自动修改行程。`;
  }

  public getExecutionWeatherDisplaySource(): 'CURRENT' | 'NEXT_FALLBACK' | 'UNKNOWN' {
    return this.host.executionWeatherDisplaySource;
  }

  public shouldAutoRefreshPlanningWeather(maxAgeMs: number = 24 * 60 * 60 * 1000): boolean {
    if (this.host.planId <= 0) {
      return true;
    }
    let latestTs = this.host.weatherLastRefreshAt;
    this.host.events.forEach((event: EventEntity) => {
      if (event.status !== 1) {
        return;
      }
      const fetchTs = Number(event.weather_fetch_time ?? 0);
      if (Number.isFinite(fetchTs) && fetchTs > latestTs) {
        latestTs = fetchTs;
      }
    });
    if (!Number.isFinite(latestTs) || latestTs <= 0) {
      return true;
    }
    return Date.now() - latestTs >= maxAgeMs;
  }

  public async resolveCoordinatesForPlaceName(
    placeName: string,
    lat?: number,
    lng?: number,
    source: 'add' | 'update' = 'add',
    fallbackLat: number = 0,
    fallbackLng: number = 0
  ): Promise<GeoPointInput> {
    const baseLat = lat ?? fallbackLat;
    const baseLng = lng ?? fallbackLng;
    hilog.info(
      0x0000,
      TAG,
      `[COORD_DIAG][${source}] name=${placeName.trim()}, inputLat=${lat ?? -999}, inputLng=${lng ?? -999}, fallbackLat=${fallbackLat}, fallbackLng=${fallbackLng}, baseLat=${baseLat}, baseLng=${baseLng}`
    );
    if (!this.isCoordinateMissingForWeather(baseLat, baseLng)) {
      hilog.info(0x0000, TAG, `[COORD_DIAG][${source}] use_base name=${placeName.trim()}, lat=${baseLat}, lng=${baseLng}`);
      return { latitude: baseLat, longitude: baseLng };
    }
    const trimmedName = placeName.trim();
    if (trimmedName.length === 0) {
      hilog.warn(0x0000, TAG, `[COORD_DIAG][${source}] empty_name use_base lat=${baseLat}, lng=${baseLng}`);
      return { latitude: baseLat, longitude: baseLng };
    }
    const geocode = await AmapService.getGeocode(trimmedName);
    if (geocode && this.isValidCoordinate(geocode.lat, geocode.lng)) {
      hilog.info(0x0000, TAG, `[WEATHER_GEO][${source}] geocode_hit name=${trimmedName}, lat=${geocode.lat}, lng=${geocode.lng}`);
      return { latitude: geocode.lat, longitude: geocode.lng };
    }
    hilog.warn(0x0000, TAG, `[WEATHER_GEO][${source}] geocode_miss name=${trimmedName}, fallbackLat=${baseLat}, fallbackLng=${baseLng}`);
    hilog.warn(0x0000, TAG, `[COORD_DIAG][${source}] geocode_miss_use_base name=${trimmedName}, lat=${baseLat}, lng=${baseLng}`);
    return { latitude: baseLat, longitude: baseLng };
  }

  public async reloadWeatherUserPreference(): Promise<void> {
    try {
      const manager = PreferenceManager.getInstance();
      this.host.weatherUserPreference = await manager.getWeatherUserPreference();
      this.host.weatherFeatureEnabled = await manager.isWeatherFeatureEnabled();
      hilog.info(
        0x0000,
        TAG,
        `[WEATHER_PREF][load] enabled=${this.host.weatherFeatureEnabled}, heat=${this.host.weatherUserPreference.heatSensitivity}, rain=${this.host.weatherUserPreference.rainSensitivity}, tolerance=${this.host.weatherUserPreference.weatherRiskTolerance}`
      );
      if (!this.host.weatherFeatureEnabled) {
        this.clearWeatherRuntimeState();
      }
    } catch (error) {
      this.host.weatherUserPreference = {
        heatSensitivity: DEFAULT_WEATHER_USER_PREFERENCE.heatSensitivity,
        rainSensitivity: DEFAULT_WEATHER_USER_PREFERENCE.rainSensitivity,
        weatherRiskTolerance: DEFAULT_WEATHER_USER_PREFERENCE.weatherRiskTolerance
      };
      this.host.weatherFeatureEnabled = true;
      hilog.warn(0x0000, TAG, `[WEATHER_PREF][fallback] reason=${JSON.stringify(error)}`);
    }
  }

  public restorePlanningWeatherSnapshot(planId: number): void {
    const raw = AppStorage.get<string>(this.getPlanningWeatherSnapshotKey(planId)) ?? '';
    if (!raw || raw.trim().length === 0) {
      return;
    }
    try {
      const parsed = JSON.parse(raw) as PlanningWeatherSnapshot;
      this.host.weatherPlanningHint = parsed.hint ?? '';
      this.host.weatherRouteScore = Number.isFinite(parsed.score) ? parsed.score : -1;
      this.host.weatherCollabSummary = parsed.collabSummary ?? '';
      this.host.weatherCollabLabel = this.host.weatherCollabSummary.trim().length > 0 ? '多日/多城' : '';
      this.host.weatherStrategyHint = parsed.strategyHint ?? '';
      this.host.weatherLastRefreshAt = Number.isFinite(parsed.refreshedAt) ? parsed.refreshedAt : 0;
    } catch (_error) {
    }
  }

  public async setWeatherFeatureEnabled(enabled: boolean): Promise<void> {
    const manager = PreferenceManager.getInstance();
    await manager.setWeatherFeatureEnabled(enabled);
    this.host.weatherFeatureEnabled = enabled;
    if (!enabled) {
      this.stopExecutionWeatherScheduler();
      this.clearWeatherRuntimeState();
      this.host.events = [...this.host.events];
    } else {
      void this.refreshPlanningWeather(false);
      const stage = this.host.resolveCurrentWeatherStage();
      const policy = this.weatherFacade.resolveSchedulePolicy(stage);
      if (policy.pollIntervalMs > 0) {
        this.startExecutionWeatherScheduler(this.host.planId, stage);
      }
    }
    hilog.info(0x0000, TAG, `[WEATHER_SWITCH][update] enabled=${this.host.weatherFeatureEnabled}`);
  }

  public async updateWeatherUserPreference(preference: WeatherUserPreference): Promise<void> {
    const manager = PreferenceManager.getInstance();
    await manager.setWeatherUserPreference(preference);
    this.host.weatherUserPreference = await manager.getWeatherUserPreference();
    this.host.weatherFeatureEnabled = await manager.isWeatherFeatureEnabled();
    if (!this.host.weatherFeatureEnabled) {
      this.clearWeatherRuntimeState();
    }
    hilog.info(
      0x0000,
      TAG,
      `[WEATHER_PREF][update] heat=${this.host.weatherUserPreference.heatSensitivity}, rain=${this.host.weatherUserPreference.rainSensitivity}, tolerance=${this.host.weatherUserPreference.weatherRiskTolerance}`
    );
  }
}





