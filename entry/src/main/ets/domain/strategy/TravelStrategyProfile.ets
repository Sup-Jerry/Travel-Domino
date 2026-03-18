import { PreferenceType, EnergyLevel } from './TravelStrategyDimensions';

export interface TravelStrategyProfile {
  dailyPoiTarget: { min: number; max: number };
  moveTolerance: number;
  slackRatio: number;
  preferCompactSchedule: boolean;
  avoidBacktracking: boolean;
  preferenceType?: PreferenceType;
  energyLevel?: EnergyLevel;
}
