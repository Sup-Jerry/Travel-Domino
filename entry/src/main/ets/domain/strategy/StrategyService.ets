import { ComposableStrategy, DensityLevel, PaceLevel, PreferenceType, EnergyLevel } from './TravelStrategyDimensions';
import { StrategyBuilder } from './StrategyBuilder';

export class StrategyService {
  // 预设策略提示词生成
  static buildStrategyPrompt(mode: number): string {
    if (mode === 1) {
      return `
【策略：特种兵模式】
- 每日安排 6-8 个景点
- 单次移动时间可接受 45 分钟内
- 行程紧凑，留白时间约 10%
- 优先覆盖更多景点`.trim();
    } else if (mode === 2) {
      return `
【策略：休闲模式】
- 每日安排 2-4 个景点
- 单次移动时间控制在 30 分钟内
- 行程宽松，留白时间约 40%
- 避免频繁折返`.trim();
    }
    return '';
  }

  // 自定义策略提示词生成
  static buildComposablePrompt(strategy: ComposableStrategy): string {
    const profile = StrategyBuilder.buildProfile(strategy);
    const parts = [
      '【旅行策略】',
      `- 密度：每日${profile.dailyPoiTarget.min}-${profile.dailyPoiTarget.max}个景点`,
      `- 节奏：留白时间${Math.round(profile.slackRatio * 100)}%`,
      `- 体力：单次移动${profile.moveTolerance}分钟内`,
      StrategyService.buildPreferenceHint(strategy.preference)
    ];
    return parts.filter(p => p.length > 0).join('\n');
  }

  // 预设策略说明生成
  static buildStrategyExplanation(mode: number): string {
    if (mode === 1) return '已采用特种兵模式：高密度景点覆盖';
    if (mode === 2) return '已采用休闲模式：低密度慢节奏';
    return 'AI智能推荐';
  }

  // 自定义策略说明生成
  static buildComposableExplanation(strategy: ComposableStrategy): string {
    const densityText = StrategyService.getDensityText(strategy.density);
    const paceText = StrategyService.getPaceText(strategy.pace);
    const preferenceText = StrategyService.getPreferenceText(strategy.preference);
    const energyText = StrategyService.getEnergyText(strategy.energy);

    return `自定义策略：${densityText}密度 + ${paceText}节奏 + ${preferenceText}偏好 + ${energyText}体力`;
  }

  // 偏好提示词
  private static buildPreferenceHint(pref: PreferenceType): string {
    const hints: Record<number, string> = {
      1: '- 偏好：优先推荐知名景点和自然风光',
      2: '- 偏好：优先推荐特色美食和餐厅',
      3: '- 偏好：优先推荐博物馆、历史遗迹',
      4: '- 偏好：包含夜景、夜市等夜间活动'
    };
    return hints[pref] || '';
  }

  private static getDensityText(level: DensityLevel): string {
    const map: Record<number, string> = { 0: '低', 1: '中', 2: '高' };
    return map[level] || '中';
  }

  private static getPaceText(type: PaceLevel): string {
    const map: Record<number, string> = { 0: '松弛', 1: '平衡', 2: '紧凑' };
    return map[type] || '平衡';
  }

  private static getPreferenceText(pref: PreferenceType): string {
    const map: Record<number, string> = { 0: '均衡', 1: '景点', 2: '美食', 3: '文化', 4: '夜景' };
    return map[pref] || '均衡';
  }

  private static getEnergyText(level: EnergyLevel): string {
    const map: Record<number, string> = { 0: '轻松', 1: '中等', 2: '充沛' };
    return map[level] || '中等';
  }
}
