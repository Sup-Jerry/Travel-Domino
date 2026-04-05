import { hilog } from '@kit.PerformanceAnalysisKit';
import { ITimelineWeatherService } from '../../domain/timeline/services/TimelineWeatherService';
import {
  GeoPointInput,
  SoftReplanApplyResult,
  SoftReplanMode,
  WeatherContextBuildResult,
  WeatherStageType,
  WeatherUserPreference
} from '../../domain/services/WeatherModels';

const TAG = 'TimelineViewModel';

export class TimelineWeatherCoordinator {
  private readonly weatherService: ITimelineWeatherService;

  constructor(weatherService: ITimelineWeatherService) {
    this.weatherService = weatherService;
  }

  public async refreshPlanningWeather(forceRefresh: boolean = false): Promise<void> {
    hilog.info(0x0000, TAG, `[ACPT][WEATHER][refreshPlanningWeather] forceRefresh=${forceRefresh}`);
    await this.weatherService.refreshPlanningWeather(forceRefresh);
  }

  public async applyPlanningWeatherResult(result: WeatherContextBuildResult, forceRefresh: boolean): Promise<void> {
    await this.weatherService.applyPlanningWeatherResult(result, forceRefresh);
  }

  public async refreshExecutionWeather(
    forceRefresh: boolean = false,
    trigger: 'ENTER_EXECUTION' | 'LOCATION_CHANGE' | 'TIMER' | 'MANUAL' = 'MANUAL',
    stage?: WeatherStageType
  ): Promise<void> {
    hilog.info(0x0000, TAG, `[ACPT][WEATHER][refreshExecutionWeather] forceRefresh=${forceRefresh}, trigger=${trigger}, stage=${stage ?? 'auto'}`);
    await this.weatherService.refreshExecutionWeather(forceRefresh, trigger, stage);
  }

  public async requestSoftReplan(
    planId: number,
    suggestionId: string,
    mode: SoftReplanMode
  ): Promise<SoftReplanApplyResult> {
    hilog.info(0x0000, TAG, `[ACPT][WEATHER][requestSoftReplan] planId=${planId}, suggestionId=${suggestionId}, mode=${mode}`);
    return this.weatherService.requestSoftReplan(planId, suggestionId, mode);
  }

  public async applyWeatherSuggestion(suggestionId: string): Promise<SoftReplanApplyResult> {
    hilog.info(0x0000, TAG, `[ACPT][WEATHER][applyWeatherSuggestion] suggestionId=${suggestionId}`);
    return this.weatherService.applyWeatherSuggestion(suggestionId);
  }

  public dismissExecutionSuggestion(suggestionId: string): void {
    this.weatherService.dismissExecutionSuggestion(suggestionId);
  }

  public isExecutionWeatherStage(): boolean {
    return this.weatherService.isExecutionWeatherStage();
  }

  public startExecutionWeatherScheduler(planId?: number, stage?: WeatherStageType): void {
    this.weatherService.startExecutionWeatherScheduler(planId, stage);
  }

  public stopExecutionWeatherScheduler(): void {
    this.weatherService.stopExecutionWeatherScheduler();
  }

  public getWeatherUserPreference(): WeatherUserPreference {
    return this.weatherService.getWeatherUserPreference();
  }

  public isWeatherFeatureEnabled(): boolean {
    return this.weatherService.isWeatherFeatureEnabled();
  }

  public buildWeatherScoreExplanation(score: number): string {
    return this.weatherService.buildWeatherScoreExplanation(score);
  }

  public buildWeatherHintExplanation(): string {
    return this.weatherService.buildWeatherHintExplanation();
  }

  public buildPlanningWeatherHintExplanation(): string {
    return this.weatherService.buildPlanningWeatherHintExplanation();
  }

  public getExecutionWeatherDisplaySource(): 'CURRENT' | 'NEXT_FALLBACK' | 'UNKNOWN' {
    return this.weatherService.getExecutionWeatherDisplaySource();
  }

  public shouldAutoRefreshPlanningWeather(maxAgeMs: number = 24 * 60 * 60 * 1000): boolean {
    return this.weatherService.shouldAutoRefreshPlanningWeather(maxAgeMs);
  }

  public clearWeatherRuntimeState(): void {
    this.weatherService.clearWeatherRuntimeState();
  }

  public async resolveCoordinatesForPlaceName(
    placeName: string,
    lat?: number,
    lng?: number,
    source: 'add' | 'update' = 'add',
    fallbackLat: number = 0,
    fallbackLng: number = 0
  ): Promise<GeoPointInput> {
    return this.weatherService.resolveCoordinatesForPlaceName(placeName, lat, lng, source, fallbackLat, fallbackLng);
  }

  public isCoordinateMissingForWeather(latitude: number, longitude: number): boolean {
    return this.weatherService.isCoordinateMissingForWeather(latitude, longitude);
  }

  public isValidCoordinate(latitude: number, longitude: number): boolean {
    return this.weatherService.isValidCoordinate(latitude, longitude);
  }

  public async reloadWeatherUserPreference(): Promise<void> {
    await this.weatherService.reloadWeatherUserPreference();
  }

  public restorePlanningWeatherSnapshot(planId: number): void {
    this.weatherService.restorePlanningWeatherSnapshot(planId);
  }

  public async setWeatherFeatureEnabled(enabled: boolean): Promise<void> {
    await this.weatherService.setWeatherFeatureEnabled(enabled);
  }

  public async updateWeatherUserPreference(preference: WeatherUserPreference): Promise<void> {
    await this.weatherService.updateWeatherUserPreference(preference);
  }
}
