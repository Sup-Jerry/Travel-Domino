import { TravelStrategyMode } from '../strategy/TravelStrategyMode';
import { StrategyPresets } from '../strategy/StrategyPresets';
import { TravelStrategyProfile } from '../strategy/TravelStrategyProfile';

export class StrategyService {
  public getProfile(mode: TravelStrategyMode): TravelStrategyProfile {
    return StrategyPresets.getProfile(mode);
  }

  public getModeName(mode: number): string {
    if (mode === 1) return '特种兵';
    if (mode === 2) return '休闲';
    return '默认';
  }

  public getModeDescription(mode: number): string {
    if (mode === 1) return '高密度景点覆盖，适合体力充沛的旅行者';
    if (mode === 2) return '低密度慢节奏，适合放松度假';
    return 'AI智能推荐，平衡节奏';
  }

  public getModeExplanation(mode: number): string {
    if (mode === 1) {
      return '已采用特种兵模式：优先提高每日覆盖率与景点数量，推荐更多经典必打卡景点，接受较高移动强度';
    }
    if (mode === 2) {
      return '已采用休闲模式：优先降低日内移动强度与景点密度，推荐更长停留时间，减少跨区折返';
    }
    return 'AI智能推荐，平衡节奏与覆盖率';
  }

  public validateMode(mode: number): boolean {
    return mode >= 0 && mode <= 2;
  }
}
