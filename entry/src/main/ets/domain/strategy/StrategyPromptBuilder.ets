import { TravelStrategyMode } from './TravelStrategyMode';
import { StrategyPresets } from './StrategyPresets';

export class StrategyPromptBuilder {
  static buildSystemPromptFragment(mode: TravelStrategyMode): string {
    const profile = StrategyPresets.getProfile(mode);

    if (mode === TravelStrategyMode.SOLDIER) {
      return `
【策略：特种兵模式】
- 每日安排 ${profile.dailyPoiTarget.min}-${profile.dailyPoiTarget.max} 个景点
- 单次移动时间可接受 ${profile.moveTolerance} 分钟内
- 行程紧凑，留白时间约 ${profile.slackRatio * 100}%
- 优先覆盖更多景点，可接受较长移动距离`.trim();
    } else if (mode === TravelStrategyMode.LEISURE) {
      return `
【策略：休闲模式】
- 每日安排 ${profile.dailyPoiTarget.min}-${profile.dailyPoiTarget.max} 个景点
- 单次移动时间控制在 ${profile.moveTolerance} 分钟内
- 行程宽松，留白时间约 ${profile.slackRatio * 100}%
- 避免频繁折返，优先就近游玩`.trim();
    }
    return '';
  }

  static buildExplanation(mode: TravelStrategyMode): string {
    if (mode === TravelStrategyMode.SOLDIER) {
      return '已采用特种兵模式：高密度景点覆盖，适合体力充沛的旅行者';
    } else if (mode === TravelStrategyMode.LEISURE) {
      return '已采用休闲模式：低密度慢节奏，适合放松度假';
    }
    return 'AI智能推荐';
  }
}
