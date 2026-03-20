/**
 * 用户行为追踪器 - 内存滑动窗口
 */

import { DeletedEventInfo, BehaviorContext } from './StrategyAdaptationEngine';
import { ComposableStrategy } from './TravelStrategyDimensions';

export class UserBehaviorTracker {
  private deletions: DeletedEventInfo[] = [];
  private skips: number = 0;
  private readonly MAX_RECORDS = 10;

  /**
   * 记录删除行为
   */
  recordDeletion(eventType: number, duration: number, trafficTime: number): void {
    this.deletions.push({
      eventType,
      duration,
      trafficTime,
      timestamp: Date.now()
    });

    // 保持滑动窗口大小
    if (this.deletions.length > this.MAX_RECORDS) {
      this.deletions.shift();
    }
  }

  /**
   * 记录跳过行为
   */
  recordSkip(eventId: number): void {
    this.skips++;
  }

  /**
   * 判断是否应该触发策略调整
   */
  shouldTriggerAdaptation(): boolean {
    // 至少需要5次删除记录才能触发
    return this.deletions.length >= 5;
  }

  /**
   * 获取行为上下文
   */
  getBehaviorContext(planId: number, currentStrategy: ComposableStrategy): BehaviorContext {
    const avgTraffic = this.deletions.length > 0
      ? this.deletions.reduce((sum, d) => sum + d.trafficTime, 0) / this.deletions.length
      : 0;

    return {
      recentDeletions: [...this.deletions],
      recentSkips: this.skips,
      avgTrafficMinutes: avgTraffic,
      currentStrategy,
      planId
    };
  }

  /**
   * 重置计数器（调整后清空）
   */
  reset(): void {
    this.deletions = [];
    this.skips = 0;
  }
}
