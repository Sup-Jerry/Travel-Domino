import { EventEntity } from '../../model/entity/EventEntity';
import { ExecutionContext } from './ExecutionContext';
import { PlanStatus } from './PlanStatus';

export enum WeatherTargetType {
  CURRENT_LOCATION = 'CURRENT_LOCATION',
  FIRST_NODE = 'FIRST_NODE',
  UPCOMING_NODES = 'UPCOMING_NODES',
  ALL_PLAN_NODES = 'ALL_PLAN_NODES'
}

export interface WeatherFetchPolicy {
  targets: WeatherTargetType[];
  refreshIntervalMinutes?: number;
  forceRefreshOnEnter: boolean;
  allowCache: boolean;
}

export interface WeatherTarget {
  type: WeatherTargetType;
  latitude?: number;
  longitude?: number;
  nodeId?: string;
  planId: string;
  forecastTime?: number;
}

export interface WeatherRefreshResult {
  success: boolean;
  requestedTargets: WeatherTarget[];
  snapshotVersion?: string;
  degraded: boolean;
  errorMessage?: string;
}

export class WeatherPolicyResolver {
  public resolveWeatherFetchPolicy(status: PlanStatus): WeatherFetchPolicy {
    if (status === PlanStatus.DRAFT) {
      return {
        targets: [WeatherTargetType.ALL_PLAN_NODES],
        forceRefreshOnEnter: true,
        allowCache: true
      };
    }
    if (status === PlanStatus.CONFIRMED) {
      return {
        targets: [WeatherTargetType.ALL_PLAN_NODES],
        refreshIntervalMinutes: 120,
        forceRefreshOnEnter: true,
        allowCache: true
      };
    }
    if (status === PlanStatus.READY) {
      return {
        targets: [WeatherTargetType.CURRENT_LOCATION, WeatherTargetType.FIRST_NODE, WeatherTargetType.UPCOMING_NODES],
        refreshIntervalMinutes: 15,
        forceRefreshOnEnter: true,
        allowCache: true
      };
    }
    if (status === PlanStatus.IN_PROGRESS) {
      return {
        targets: [WeatherTargetType.CURRENT_LOCATION, WeatherTargetType.UPCOMING_NODES],
        refreshIntervalMinutes: 20,
        forceRefreshOnEnter: true,
        allowCache: true
      };
    }
    if (status === PlanStatus.PAUSED) {
      return {
        targets: [WeatherTargetType.CURRENT_LOCATION, WeatherTargetType.UPCOMING_NODES],
        refreshIntervalMinutes: 30,
        forceRefreshOnEnter: false,
        allowCache: true
      };
    }
    return {
      targets: [],
      forceRefreshOnEnter: false,
      allowCache: true
    };
  }

  public buildWeatherTargets(
    planId: string,
    status: PlanStatus,
    events: EventEntity[],
    context?: ExecutionContext
  ): WeatherTarget[] {
    const policy = this.resolveWeatherFetchPolicy(status);
    if (policy.targets.length === 0) {
      return [];
    }

    const activeEvents = (events || []).filter((item: EventEntity) => item.status === 1 && this.hasGeo(item.latitude, item.longitude));
    const sorted = activeEvents.sort((a: EventEntity, b: EventEntity) => {
      const aTime = a.dynamic_start_time > 0 ? a.dynamic_start_time : Number.MAX_SAFE_INTEGER;
      const bTime = b.dynamic_start_time > 0 ? b.dynamic_start_time : Number.MAX_SAFE_INTEGER;
      return aTime - bTime;
    });
    const pending = sorted.filter((item: EventEntity) => item.completion_status === EventEntity.STATE_PENDING);
    const first = pending.length > 0 ? pending[0] : undefined;
    const upcoming = pending.slice(0, 3);

    const targets: WeatherTarget[] = [];
    policy.targets.forEach((type: WeatherTargetType) => {
      if (type === WeatherTargetType.ALL_PLAN_NODES) {
        sorted.forEach((event: EventEntity) => {
          targets.push({
            type: WeatherTargetType.ALL_PLAN_NODES,
            latitude: event.latitude,
            longitude: event.longitude,
            nodeId: `${event.id}`,
            planId: planId,
            forecastTime: event.dynamic_start_time > 0 ? event.dynamic_start_time : undefined
          });
        });
      }
      if (type === WeatherTargetType.FIRST_NODE && first) {
        targets.push({
          type: WeatherTargetType.FIRST_NODE,
          latitude: first.latitude,
          longitude: first.longitude,
          nodeId: `${first.id}`,
          planId: planId,
          forecastTime: first.dynamic_start_time > 0 ? first.dynamic_start_time : undefined
        });
      }
      if (type === WeatherTargetType.UPCOMING_NODES) {
        upcoming.forEach((event: EventEntity) => {
          targets.push({
            type: WeatherTargetType.UPCOMING_NODES,
            latitude: event.latitude,
            longitude: event.longitude,
            nodeId: `${event.id}`,
            planId: planId,
            forecastTime: event.dynamic_start_time > 0 ? event.dynamic_start_time : undefined
          });
        });
      }
      if (type === WeatherTargetType.CURRENT_LOCATION && context && this.hasGeo(context.lastKnownLatitude, context.lastKnownLongitude)) {
        targets.push({
          type: WeatherTargetType.CURRENT_LOCATION,
          latitude: context.lastKnownLatitude,
          longitude: context.lastKnownLongitude,
          planId: planId,
          forecastTime: Date.now()
        });
      }
    });

    const dedup: Map<string, WeatherTarget> = new Map<string, WeatherTarget>();
    targets.forEach((target: WeatherTarget) => {
      const key = `${target.type}_${target.nodeId ?? ''}_${target.latitude ?? 0}_${target.longitude ?? 0}`;
      if (!dedup.has(key)) {
        dedup.set(key, target);
      }
    });
    return Array.from(dedup.values());
  }

  private hasGeo(lat?: number, lng?: number): boolean {
    return lat !== undefined && lng !== undefined && Number.isFinite(lat) && Number.isFinite(lng) && !(lat === 0 && lng === 0);
  }
}
