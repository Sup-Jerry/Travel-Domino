import { PreferenceType, EnergyLevel } from './TravelStrategyDimensions';

export interface DailyPoiTarget {
  min: number;
  max: number;
}

export interface TravelStrategyProfile {
  dailyPoiTarget: DailyPoiTarget;
  moveTolerance: number;
  slackRatio: number;
  preferCompactSchedule: boolean;
  avoidBacktracking: boolean;
  preferenceType?: PreferenceType;
  energyLevel?: EnergyLevel;
}
