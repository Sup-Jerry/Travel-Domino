import { EventEntity } from '../../model/entity/EventEntity';
import {
  CityWeatherBucket,
  DEFAULT_WEATHER_USER_PREFERENCE,
  PlanNodeWeatherBinding,
  RouteWeatherSuitability,
  WeatherCollabContext,
  WeatherDayWindow,
  WeatherSnapshot,
  WeatherUserPreference
} from './WeatherModels';

export interface NodeSuitabilityResult {
  score: number;
  riskTags: string[];
}

export class WeatherRiskEvaluator {
  public evaluateNodeSuitability(
    event: EventEntity,
    weather?: WeatherSnapshot,
    preference?: WeatherUserPreference
  ): NodeSuitabilityResult {
    const pref = preference ?? DEFAULT_WEATHER_USER_PREFERENCE;
    let score = 100;
    const tags: string[] = [];

    if (!weather) {
      score -= this.adjustByTolerance(10, pref);
      tags.push('UNKNOWN');
      const unknownResult: NodeSuitabilityResult = { score: this.clampScore(score), riskTags: tags };
      return unknownResult;
    }

    const conditionText = (weather.conditionText || weather.conditionCode || '').toLowerCase();
    const isOutdoor = event.type !== 2;
    const temperature = weather.temperatureCelsius ?? 0;

    if (isOutdoor && (conditionText.indexOf('雨') >= 0 || conditionText.indexOf('snow') >= 0 || conditionText.indexOf('storm') >= 0)) {
      score -= this.adjustBySensitivity(30, pref.rainSensitivity, pref);
      tags.push('RAIN');
    }
    if (isOutdoor && temperature > 35) {
      score -= this.adjustBySensitivity(20, pref.heatSensitivity, pref);
      tags.push('HEAT');
    }
    if (isOutdoor && temperature > 0 && temperature < 5) {
      score -= this.adjustByTolerance(15, pref);
      tags.push('COLD');
    }

    const result: NodeSuitabilityResult = { score: this.clampScore(score), riskTags: tags };
    return result;
  }

  public evaluateRouteSuitability(
    bindings: PlanNodeWeatherBinding[],
    preference?: WeatherUserPreference,
    collabContext?: WeatherCollabContext
  ): RouteWeatherSuitability {
    const pref = preference ?? DEFAULT_WEATHER_USER_PREFERENCE;
    if (!bindings || bindings.length === 0) {
      const emptyResult: RouteWeatherSuitability = {
        routeScore: -1,
        riskTags: [],
        summaryText: '暂无天气约束，路线可正常规划'
      };
      return emptyResult;
    }

    let total = 0;
    const tags: Set<string> = new Set<string>();
    bindings.forEach((binding: PlanNodeWeatherBinding) => {
      total += binding.suitabilityScore;
      binding.riskTags.forEach((tag: string) => tags.add(tag));
    });
    let routeScore = Math.round(total / bindings.length);

    const cityWeighted = this.calculateCityWeightedScore(collabContext?.cityBuckets);
    if (cityWeighted >= 0) {
      routeScore = cityWeighted;
    }
    routeScore = this.applyDayTrendAdjustment(routeScore, collabContext?.dayWindows);
    collabContext?.dayWindows.forEach((item: WeatherDayWindow) => {
      item.riskTags.forEach((tag: string) => tags.add(tag));
    });

    let summaryText = '天气条件较稳定，当前路线可执行性较高';
    if (routeScore < 70) {
      summaryText = '当前路线存在天气风险，建议优先室内节点';
    } else if (routeScore < 85) {
      summaryText = '部分节点受天气影响，建议关注时段变化';
    }
    if (collabContext && collabContext.collabSummary.trim().length > 0) {
      summaryText = `${summaryText}；${collabContext.collabSummary}`;
    }
    const prefHint = this.buildPreferenceHint(pref);
    summaryText = `${summaryText}（${prefHint}）`;

    const routeResult: RouteWeatherSuitability = {
      routeScore: this.clampScore(routeScore),
      riskTags: Array.from(tags.values()),
      summaryText: summaryText
    };
    return routeResult;
  }

  private clampScore(score: number): number {
    if (score < 0) {
      return 0;
    }
    if (score > 100) {
      return 100;
    }
    return score;
  }

  private adjustBySensitivity(basePenalty: number, level: number, preference: WeatherUserPreference): number {
    const safeLevel = level < 0 ? 0 : (level > 2 ? 2 : level);
    const multiplier = safeLevel === 2 ? 1.35 : (safeLevel === 0 ? 0.7 : 1);
    const adjusted = Math.round(basePenalty * multiplier);
    return this.adjustByTolerance(adjusted, preference);
  }

  private adjustByTolerance(basePenalty: number, preference: WeatherUserPreference): number {
    const tolerance = preference.weatherRiskTolerance;
    if (tolerance === 2) {
      return Math.max(1, Math.round(basePenalty * 0.7));
    }
    if (tolerance === 0) {
      return Math.max(1, Math.round(basePenalty * 1.25));
    }
    return basePenalty;
  }

  private buildPreferenceHint(preference: WeatherUserPreference): string {
    const levelText = (level: number): string => level === 2 ? '高' : (level === 0 ? '低' : '中');
    return `基于偏好：怕热${levelText(preference.heatSensitivity)}、怕雨${levelText(preference.rainSensitivity)}、风险容忍${levelText(preference.weatherRiskTolerance)}`;
  }

  private calculateCityWeightedScore(cityBuckets?: CityWeatherBucket[]): number {
    if (!cityBuckets || cityBuckets.length === 0) {
      return -1;
    }
    let weightedTotal = 0;
    let weightCount = 0;
    cityBuckets.forEach((bucket: CityWeatherBucket) => {
      const weight = Math.max(1, bucket.nodeIds.length);
      weightedTotal += bucket.bucketScore * weight;
      weightCount += weight;
    });
    if (weightCount <= 0) {
      return -1;
    }
    return Math.round(weightedTotal / weightCount);
  }

  private applyDayTrendAdjustment(baseScore: number, dayWindows?: WeatherDayWindow[]): number {
    if (!dayWindows || dayWindows.length === 0) {
      return this.clampScore(baseScore);
    }
    let score = baseScore;
    dayWindows.forEach((window: WeatherDayWindow) => {
      if (window.trendTag === 'RAIN_PERSIST') {
        score -= 5;
      } else if (window.trendTag === 'WARMING') {
        score -= 3;
      } else if (window.trendTag === 'IMPROVING') {
        score += 3;
      }
    });
    return this.clampScore(score);
  }
}
