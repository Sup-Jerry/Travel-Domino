import { TravelStrategyMode } from './TravelStrategyMode';
import { TravelStrategyProfile } from './TravelStrategyProfile';

export class StrategyPresets {
  private static readonly SOLDIER_PROFILE: TravelStrategyProfile = {
    dailyPoiTarget: { min: 5, max: 8 },
    moveTolerance: 45,
    slackRatio: 0.1,
    preferCompactSchedule: true,
    avoidBacktracking: false
  };

  private static readonly LEISURE_PROFILE: TravelStrategyProfile = {
    dailyPoiTarget: { min: 3, max: 5 },
    moveTolerance: 30,
    slackRatio: 0.4,
    preferCompactSchedule: false,
    avoidBacktracking: true
  };

  private static readonly DEFAULT_PROFILE: TravelStrategyProfile = {
    dailyPoiTarget: { min: 4, max: 6 },
    moveTolerance: 35,
    // 默认策略不额外注入留白，避免用户未显式选择节奏时产生隐式 +15min 漂移。
    slackRatio: 0,
    preferCompactSchedule: false,
    avoidBacktracking: false
  };

  static getProfile(mode: TravelStrategyMode): TravelStrategyProfile {
    if (mode === TravelStrategyMode.SOLDIER) return StrategyPresets.SOLDIER_PROFILE;
    if (mode === TravelStrategyMode.LEISURE) return StrategyPresets.LEISURE_PROFILE;
    return StrategyPresets.DEFAULT_PROFILE;
  }
}
