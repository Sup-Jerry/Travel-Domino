import { EventEntity } from '../../model/entity/EventEntity';

export type WeatherSourceType = 'CURRENT_LOCATION' | 'PLAN_LOCATION';
export type WeatherStageType = 'PLANNING' | 'EXECUTION';
export type WeatherTriggerSource = 'ENTER_EXECUTION' | 'LOCATION_CHANGE' | 'TIMER' | 'MANUAL';
export type WeatherSuggestionLevel = 'INFO' | 'NOTICE' | 'WARNING';
export type WeatherSuggestionTriggerType = 'RAIN' | 'HEAT' | 'COLD' | 'WIND' | 'SEVERE_ALERT' | 'UNKNOWN';
export type WeatherSuggestionActionType = 'NONE' | 'PREPARE' | 'REORDER' | 'SHORTEN_STAY' | 'REPLACE_NODE' | 'SKIP_NODE';
export type SoftReplanMode = 'PREVIEW' | 'APPLY';
export type WeatherPreferenceLevel = 0 | 1 | 2; // 0=LOW, 1=MEDIUM, 2=HIGH

export interface WeatherUserPreference {
  heatSensitivity: WeatherPreferenceLevel;
  rainSensitivity: WeatherPreferenceLevel;
  weatherRiskTolerance: WeatherPreferenceLevel;
}

export const DEFAULT_WEATHER_USER_PREFERENCE: WeatherUserPreference = {
  heatSensitivity: 1,
  rainSensitivity: 1,
  weatherRiskTolerance: 1
};

export interface WeatherSnapshot {
  locationKey: string;
  sourceType: WeatherSourceType;
  weatherTime: number;
  fetchTime: number;
  conditionCode: string;
  conditionText: string;
  temperatureCelsius?: number;
  humidity?: number;
  windSpeed?: number;
  reportTime?: string;
  cityCode?: string;
}

export interface PlanNodeWeatherBinding {
  nodeId: string;
  eventId: number;
  nodeName?: string;
  weather?: WeatherSnapshot;
  suitabilityScore: number;
  riskTags: string[];
}

export interface RouteWeatherSuitability {
  routeScore: number;
  riskTags: string[];
  summaryText: string;
}

export type WeatherTrendTag = 'STABLE' | 'WARMING' | 'RAIN_PERSIST' | 'IMPROVING' | 'UNKNOWN';

export interface WeatherDayWindow {
  dayOffset: number;
  windowScore: number;
  riskTags: string[];
  trendTag: WeatherTrendTag;
}

export interface CityWeatherBucket {
  cityKey: string;
  nodeIds: string[];
  bucketScore: number;
  summaryText: string;
}

export interface WeatherCollabContext {
  dayWindows: WeatherDayWindow[];
  cityBuckets: CityWeatherBucket[];
  collabSummary: string;
  dayWindowCount: number;
  cityGroupCount: number;
  cityMissCount: number;
  trendTag: WeatherTrendTag;
  fallbackPath: string;
}

export interface WeatherCollabOptions {
  enableMultiDay?: boolean;
  enableMultiCity?: boolean;
}

export interface WeatherContext {
  stage: WeatherStageType;
  generatedAt: number;
  bindings: PlanNodeWeatherBinding[];
  routeSuitability: RouteWeatherSuitability;
  currentLocationWeather?: WeatherSnapshot;
  nextNodeWeather?: WeatherSnapshot;
  futureNodeWeatherList?: PlanNodeWeatherBinding[];
  executionRiskScore?: number;
  executionRiskTags?: string[];
  collabContext?: WeatherCollabContext;
}

export interface WeatherContextBuildResult {
  context: WeatherContext;
  eventMap: Map<number, PlanNodeWeatherBinding>;
  sourceEvents: EventEntity[];
}

export interface GeoPointInput {
  latitude: number;
  longitude: number;
}

export interface WeatherSuggestion {
  suggestionId: string;
  level: WeatherSuggestionLevel;
  triggerType: WeatherSuggestionTriggerType;
  actionType: WeatherSuggestionActionType;
  title: string;
  message: string;
  relatedNodeIds: string[];
  createdAt: number;
  reason: string;
  expectedBenefit: string;
  canRollback: boolean;
  cooldownKey: string;
  expiresAt: number;
  actionPayload?: WeatherSuggestionActionPayload;
}

export interface WeatherSuggestionAlternativeCandidate {
  eventId: number;
  nodeId: string;
  name: string;
  matchReason?: string;
  matchScore?: number;
}

export interface WeatherSuggestionActionPayload {
  targetNodeIds?: string[];
  targetOrderNodeIds?: string[];
  suggestedStayMinutes?: number;
  replacementCandidates?: WeatherSuggestionAlternativeCandidate[];
}

export type ReplanChangeType = 'ORDER_CHANGED' | 'DURATION_CHANGED' | 'TIME_SHIFTED' | 'IMMUTABLE_BLOCKED' | 'NO_OP';

export interface ReplanChangeSummaryItem {
  type: ReplanChangeType;
  nodeId: string;
  before?: string;
  after?: string;
  deltaMinutes?: number;
}

export interface SoftReplanPreview {
  suggestionId: string;
  actionType: WeatherSuggestionActionType;
  changedOrder: boolean;
  changedDurations: boolean;
  skippedNodeIds: string[];
  affectedNodeIds: string[];
  reasonCode?: string;
  startFromEventId?: number;
  changeSummary: ReplanChangeSummaryItem[];
  summary: string;
  riskDelta: number;
}

export interface SoftReplanApplyResult {
  success: boolean;
  rolledBack: boolean;
  errorCode: '' | 'REPLAN_CONFLICT' | 'REPLAN_IMMUTABLE' | 'REPLAN_NO_CANDIDATE' | 'REPLAN_TIMEOUT' | 'REPLAN_INVALID' | 'REPLAN_BUSY';
  reasonCode?: string;
  startFromEventId?: number;
  preview: SoftReplanPreview;
}
