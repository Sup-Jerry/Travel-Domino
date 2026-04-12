import { describe, expect, it } from '@ohos/hypium';
import { TimelineWeatherCoordinator } from '../main/ets/viewmodel/coordinators/TimelineWeatherCoordinator';
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

class FakeTimelineWeatherService implements ITimelineWeatherService {
  planningRefreshCalls: number = 0;
  planningRefreshLastForce: boolean = false;
  planningApplyCalls: number = 0;
  planningApplyLastForce: boolean = false;
  executionRefreshCalls: number = 0;
  executionRefreshLastTrigger: 'ENTER_EXECUTION' | 'LOCATION_CHANGE' | 'TIMER' | 'MANUAL' = 'MANUAL';
  schedulerPlanId: number = -1;
  schedulerStage: WeatherStageType = 'PLANNING';
  dismissCount: number = 0;
  preferenceReloaded: boolean = false;
  featureEnabled: boolean = true;
  callOrder: string[] = [];
  autoRefreshMaxAgeMs: number = 0;

  private readonly defaultReplanResult: SoftReplanApplyResult = {
    success: true,
    rolledBack: false,
    errorCode: '',
    preview: {
      suggestionId: 'suggestion-default',
      actionType: 'NONE',
      changedOrder: false,
      changedDurations: false,
      skippedNodeIds: [],
      affectedNodeIds: [],
      changeSummary: [],
      summary: 'ok',
      riskDelta: 0
    }
  };

  async refreshPlanningWeather(forceRefresh?: boolean): Promise<void> {
    this.planningRefreshCalls += 1;
    this.planningRefreshLastForce = forceRefresh === true;
    this.callOrder.push('refreshPlanningWeather');
  }

  async applyPlanningWeatherResult(result: WeatherContextBuildResult, forceRefresh: boolean): Promise<void> {
    this.planningApplyCalls += 1;
    this.planningApplyLastForce = forceRefresh;
    this.callOrder.push(`applyPlanningWeatherResult:${result.context.stage}`);
  }

  async refreshExecutionWeather(
    forceRefresh?: boolean,
    trigger?: 'ENTER_EXECUTION' | 'LOCATION_CHANGE' | 'TIMER' | 'MANUAL',
    _stage?: WeatherStageType
  ): Promise<void> {
    this.executionRefreshCalls += 1;
    this.executionRefreshLastTrigger = trigger ?? 'MANUAL';
    this.callOrder.push(`refreshExecutionWeather:${forceRefresh === true ? 'force' : 'soft'}`);
  }

  async requestSoftReplan(_planId: number, suggestionId: string, mode: SoftReplanMode): Promise<SoftReplanApplyResult> {
    this.callOrder.push(`requestSoftReplan:${suggestionId}:${mode}`);
    return this.defaultReplanResult;
  }

  async applyWeatherSuggestion(suggestionId: string): Promise<SoftReplanApplyResult> {
    this.callOrder.push(`applyWeatherSuggestion:${suggestionId}`);
    return this.defaultReplanResult;
  }

  dismissExecutionSuggestion(_suggestionId: string): void {
    this.dismissCount += 1;
    this.callOrder.push('dismissExecutionSuggestion');
  }

  isExecutionWeatherStage(): boolean {
    return true;
  }

  startExecutionWeatherScheduler(planId?: number, stage?: WeatherStageType): void {
    this.schedulerPlanId = planId ?? -1;
    this.schedulerStage = stage ?? 'PLANNING';
    this.callOrder.push('startExecutionWeatherScheduler');
  }

  stopExecutionWeatherScheduler(): void {
    this.callOrder.push('stopExecutionWeatherScheduler');
  }

  getWeatherUserPreference(): WeatherUserPreference {
    return DEFAULT_WEATHER_USER_PREFERENCE;
  }

  isWeatherFeatureEnabled(): boolean {
    return this.featureEnabled;
  }

  buildWeatherScoreExplanation(score: number): string {
    return `score:${score}`;
  }

  buildWeatherHintExplanation(): string {
    return 'hint';
  }

  buildPlanningWeatherHintExplanation(): string {
    return 'planning-hint';
  }

  getExecutionWeatherDisplaySource(): 'CURRENT' | 'NEXT_FALLBACK' | 'UNKNOWN' {
    return 'CURRENT';
  }

  shouldAutoRefreshPlanningWeather(maxAgeMs?: number): boolean {
    this.autoRefreshMaxAgeMs = maxAgeMs ?? 0;
    return maxAgeMs !== undefined && maxAgeMs <= 24 * 60 * 60 * 1000;
  }

  clearWeatherRuntimeState(): void {
    this.callOrder.push('clearWeatherRuntimeState');
  }

  async resolveCoordinatesForPlaceName(
    placeName: string,
    lat?: number,
    lng?: number,
    _source?: 'add' | 'update',
    fallbackLat?: number,
    fallbackLng?: number
  ): Promise<GeoPointInput> {
    this.callOrder.push(`resolveCoordinatesForPlaceName:${placeName}`);
    if (lat !== undefined && lng !== undefined && Number.isFinite(lat) && Number.isFinite(lng)) {
      return { latitude: lat, longitude: lng };
    }
    return { latitude: fallbackLat ?? 0, longitude: fallbackLng ?? 0 };
  }

  isCoordinateMissingForWeather(latitude: number, longitude: number): boolean {
    return latitude === 0 || longitude === 0;
  }

  isValidCoordinate(latitude: number, longitude: number): boolean {
    return Number.isFinite(latitude) && Number.isFinite(longitude) && latitude !== 0 && longitude !== 0;
  }

  async reloadWeatherUserPreference(): Promise<void> {
    this.preferenceReloaded = true;
    this.callOrder.push('reloadWeatherUserPreference');
  }

  restorePlanningWeatherSnapshot(_planId: number): void {
    this.callOrder.push('restorePlanningWeatherSnapshot');
  }

  async setWeatherFeatureEnabled(enabled: boolean): Promise<void> {
    this.featureEnabled = enabled;
    this.callOrder.push(`setWeatherFeatureEnabled:${enabled ? 'true' : 'false'}`);
  }

  async updateWeatherUserPreference(_preference: WeatherUserPreference): Promise<void> {
    this.callOrder.push('updateWeatherUserPreference');
  }
}

function createPlanningResult(): WeatherContextBuildResult {
  const bindings: PlanNodeWeatherBinding[] = [];
  const context: WeatherContext = {
    stage: 'PLANNING',
    generatedAt: Date.now(),
    bindings: bindings,
    routeSuitability: {
      routeScore: 92,
      riskTags: [],
      summaryText: 'clear'
    }
  };
  return {
    context: context,
    eventMap: new Map<number, PlanNodeWeatherBinding>(),
    sourceEvents: []
  };
}

export default function timelineWeatherCoordinatorTest() {
  describe('timelineWeatherCoordinatorTest', () => {
    it('normal: refresh_planning_weather_should_forward_force_flag', 0, async () => {
      // Arrange
      const service = new FakeTimelineWeatherService();
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      await coordinator.refreshPlanningWeather(true);
      // Assert
      expect(service.planningRefreshCalls).assertEqual(1);
      expect(service.planningRefreshLastForce).assertTrue();
    });

    it('boundary: should_auto_refresh_planning_weather_should_use_large_threshold', 0, () => {
      // Arrange
      const service = new FakeTimelineWeatherService();
      const coordinator = new TimelineWeatherCoordinator(service);
      const maxAgeMs = 24 * 60 * 60 * 1000;
      // Act
      const shouldRefresh = coordinator.shouldAutoRefreshPlanningWeather(maxAgeMs);
      // Assert
      expect(shouldRefresh).assertTrue();
      expect(service.autoRefreshMaxAgeMs).assertEqual(maxAgeMs);
    });

    it('invalid: resolve_coordinates_should_fallback_when_input_coordinate_invalid', 0, async () => {
      // Arrange
      const service = new FakeTimelineWeatherService();
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      const point = await coordinator.resolveCoordinatesForPlaceName('unknown-place', Number.NaN, Number.NaN, 'add', 39.9, 116.3);
      // Assert
      expect(point.latitude).assertEqual(39.9);
      expect(point.longitude).assertEqual(116.3);
    });

    it('conflict: start_scheduler_should_keep_explicit_planid_and_stage', 0, () => {
      // Arrange
      const service = new FakeTimelineWeatherService();
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      coordinator.startExecutionWeatherScheduler(88, 'IN_PROGRESS');
      // Assert
      expect(service.schedulerPlanId).assertEqual(88);
      expect(service.schedulerStage).assertEqual('IN_PROGRESS');
    });

    it('regression: td-20260412-c4-apply-planning-result-should-forward-force-refresh', 0, async () => {
      // Arrange
      const service = new FakeTimelineWeatherService();
      const coordinator = new TimelineWeatherCoordinator(service);
      const result = createPlanningResult();
      // Act
      await coordinator.applyPlanningWeatherResult(result, true);
      // Assert
      expect(service.planningApplyCalls).assertEqual(1);
      expect(service.planningApplyLastForce).assertTrue();
    });

    it('combined: feature_toggle_and_preference_reload_should_keep_call_sequence', 0, async () => {
      // Arrange
      const service = new FakeTimelineWeatherService();
      const coordinator = new TimelineWeatherCoordinator(service);
      // Act
      await coordinator.setWeatherFeatureEnabled(false);
      await coordinator.updateWeatherUserPreference(DEFAULT_WEATHER_USER_PREFERENCE);
      await coordinator.reloadWeatherUserPreference();
      coordinator.clearWeatherRuntimeState();
      // Assert
      expect(service.featureEnabled).assertFalse();
      expect(service.preferenceReloaded).assertTrue();
      expect(service.callOrder[0]).assertEqual('setWeatherFeatureEnabled:false');
      expect(service.callOrder[1]).assertEqual('updateWeatherUserPreference');
      expect(service.callOrder[2]).assertEqual('reloadWeatherUserPreference');
      expect(service.callOrder[3]).assertEqual('clearWeatherRuntimeState');
    });
  });
}
