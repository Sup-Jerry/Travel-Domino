/**
 * 策略自适应引擎 - 根据用户行为动态调整策略
 */

import { ComposableStrategy, PreferenceType } from './TravelStrategyDimensions';
import { WeatherCollabContext } from '../services/WeatherModels';

// 删除事件信息
export interface DeletedEventInfo {
  eventType: number;      // 1=景点, 2=餐饮, 3=交通
  duration: number;       // 时长（强度代理指标）
  trafficTime: number;    // 前置交通时间
  timestamp: number;
}

// 行为上下文
export interface BehaviorContext {
  recentDeletions: DeletedEventInfo[];
  recentSkips: number;
  avgTrafficMinutes: number;
  currentStrategy: ComposableStrategy;
  planId: number;
}

// 调整决策
export interface StrategyAdjustments {
  density?: -1 | 0 | 1;
  pace?: -1 | 0 | 1;
  energy?: -1 | 0 | 1;
  preference?: PreferenceType;
}

export interface AdaptationDecision {
  reason: 'HIGH_INTENSITY_DELETIONS' | 'EXCESSIVE_TRAFFIC' | 'USER_FEEDBACK' | 'WEATHER_RISK';
  adjustments: StrategyAdjustments;
  message: string;
}

// UI提示数据
export interface AdaptationPrompt {
  message: string;
  oldStrategy: ComposableStrategy;
  newStrategy: ComposableStrategy;
}

export class StrategyAdaptationEngine {
  /**
   * 分析行为并决定是否需要调整策略
   */
  static analyzeAndDecide(context: BehaviorContext): AdaptationDecision | null {
    const deletions = context.recentDeletions.slice(-5); // 最近5次

    if (deletions.length < 3) {
      return null; // 样本不足
    }

    // 规则1：高强度删除检测
    const highIntensityCount = deletions.filter(d => d.duration > 90).length;
    if (highIntensityCount >= 3) {
      const decision: AdaptationDecision = {
        reason: 'HIGH_INTENSITY_DELETIONS',
        adjustments: { pace: -1, energy: -1 },
        message: '检测到您频繁删除长时间项目，已自动降低行程节奏'
      };
      return decision;
    }

    // 规则2：交通时间检测
    const avgTraffic = deletions.reduce((sum, d) => sum + d.trafficTime, 0) / deletions.length;
    if (avgTraffic > 40) {
      const decision: AdaptationDecision = {
        reason: 'EXCESSIVE_TRAFFIC',
        adjustments: { density: -1 },
        message: '检测到交通时间较长，已自动降低景点密度'
      };
      return decision;
    }

    return null;
  }

  /**
   * 应用调整到当前策略
   */
  static applyAdjustment(current: ComposableStrategy, decision: AdaptationDecision): ComposableStrategy {
    const adjusted: ComposableStrategy = {
      density: current.density,
      pace: current.pace,
      preference: current.preference,
      energy: current.energy
    };

    // 应用调整，确保值在[0, 2]范围内
    if (decision.adjustments.density !== undefined) {
      adjusted.density = StrategyAdaptationEngine.clamp(current.density + decision.adjustments.density, 0, 2);
    }
    if (decision.adjustments.pace !== undefined) {
      adjusted.pace = StrategyAdaptationEngine.clamp(current.pace + decision.adjustments.pace, 0, 2);
    }
    if (decision.adjustments.energy !== undefined) {
      adjusted.energy = StrategyAdaptationEngine.clamp(current.energy + decision.adjustments.energy, 0, 2);
    }
    if (decision.adjustments.preference !== undefined) {
      adjusted.preference = decision.adjustments.preference;
    }

    return adjusted;
  }

  private static clamp(value: number, min: number, max: number): number {
    return Math.max(min, Math.min(max, value));
  }

  static adaptToWeather(
    collabContext: WeatherCollabContext | undefined,
    routeScore: number,
    currentStrategy: ComposableStrategy
  ): AdaptationDecision | null {
    if (routeScore < 60) {
      return {
        reason: 'WEATHER_RISK',
        adjustments: { density: -1 },
        message: '天气风险较高，已自动降低行程密度。'
      };
    }

    const trendTag = collabContext?.trendTag ?? 'UNKNOWN';
    if (trendTag === 'RAIN_PERSIST') {
      if (routeScore < 70) {
        return {
          reason: 'WEATHER_RISK',
          adjustments: {
            density: -1,
            preference: currentStrategy.preference === PreferenceType.CULTURE
              ? currentStrategy.preference
              : PreferenceType.CULTURE
          },
          message: '持续降雨，已降低密度并优先文化/室内偏好。'
        };
      }
      return {
        reason: 'WEATHER_RISK',
        adjustments: { density: -1 },
        message: '持续降雨，已自动降低行程密度。'
      };
    }

    if (trendTag === 'WARMING' && routeScore < 70) {
      return {
        reason: 'WEATHER_RISK',
        adjustments: { pace: -1, energy: -1 },
        message: '天气转热且适宜度偏低，已降低节奏与体力强度。'
      };
    }

    return null;
  }
}
