import { PlanStatus } from './PlanStatus';
import { WeatherPolicyResolver } from './WeatherPolicyResolver';

// Deprecated naming note:
// This planner is internal to state-machine metrics/transition bookkeeping.
// Runtime weather polling is handled by domain/services/WeatherRefreshScheduler.
export interface PlanWeatherScheduleDecision {
  shouldRefresh: boolean;
  nextRefreshAt?: number;
  intervalMinutes?: number;
}

export class PlanWeatherRefreshPlanner {
  private readonly resolver: WeatherPolicyResolver;
  private readonly nextRunMap: Map<string, number> = new Map<string, number>();

  constructor(resolver?: WeatherPolicyResolver) {
    this.resolver = resolver ?? new WeatherPolicyResolver();
  }

  public onStatusEntered(planId: string, status: PlanStatus, now: number = Date.now()): PlanWeatherScheduleDecision {
    const policy = this.resolver.resolveWeatherFetchPolicy(status);
    if (!policy.refreshIntervalMinutes || policy.refreshIntervalMinutes <= 0) {
      this.nextRunMap.delete(planId);
      return {
        shouldRefresh: policy.forceRefreshOnEnter,
        intervalMinutes: undefined
      };
    }

    const nextAt = now + policy.refreshIntervalMinutes * 60 * 1000;
    this.nextRunMap.set(planId, nextAt);
    return {
      shouldRefresh: policy.forceRefreshOnEnter,
      nextRefreshAt: nextAt,
      intervalMinutes: policy.refreshIntervalMinutes
    };
  }

  public evaluate(planId: string, status: PlanStatus, now: number = Date.now()): PlanWeatherScheduleDecision {
    const policy = this.resolver.resolveWeatherFetchPolicy(status);
    const interval = policy.refreshIntervalMinutes;
    if (!interval || interval <= 0) {
      this.nextRunMap.delete(planId);
      return {
        shouldRefresh: false
      };
    }

    const nextAt = this.nextRunMap.get(planId);
    if (!nextAt || now >= nextAt) {
      const newNext = now + interval * 60 * 1000;
      this.nextRunMap.set(planId, newNext);
      return {
        shouldRefresh: true,
        nextRefreshAt: newNext,
        intervalMinutes: interval
      };
    }

    return {
      shouldRefresh: false,
      nextRefreshAt: nextAt,
      intervalMinutes: interval
    };
  }

  public clear(planId: string): void {
    this.nextRunMap.delete(planId);
  }
}
