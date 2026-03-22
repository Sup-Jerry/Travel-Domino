import { PlanTransitionEvent } from './ExecutionContext';

export type StateTransitionListener = (event: PlanTransitionEvent) => void;

export interface LocationChangeEvent {
  planId: string;
  latitude: number;
  longitude: number;
  distanceMeters: number;
  timestamp: number;
}

export type LocationChangeListener = (event: LocationChangeEvent) => void;

export class StateEventBus {
  private readonly listeners: Map<string, Set<StateTransitionListener>> = new Map<string, Set<StateTransitionListener>>();
  private readonly locationListeners: Map<string, Set<LocationChangeListener>> = new Map<string, Set<LocationChangeListener>>();

  public subscribe(planId: string, listener: StateTransitionListener): () => void {
    const key = this.normalizePlanId(planId);
    const set = this.listeners.get(key) ?? new Set<StateTransitionListener>();
    set.add(listener);
    this.listeners.set(key, set);

    return () => {
      const current = this.listeners.get(key);
      if (!current) {
        return;
      }
      current.delete(listener);
      if (current.size === 0) {
        this.listeners.delete(key);
      }
    };
  }

  public publish(event: PlanTransitionEvent): void {
    const specific = this.listeners.get(this.normalizePlanId(event.planId));
    if (specific) {
      specific.forEach((listener: StateTransitionListener) => listener(event));
    }
    const wildcard = this.listeners.get('*');
    if (wildcard) {
      wildcard.forEach((listener: StateTransitionListener) => listener(event));
    }
  }

  public subscribeLocationChange(planId: string, listener: LocationChangeListener): () => void {
    const key = this.normalizePlanId(planId);
    const set = this.locationListeners.get(key) ?? new Set<LocationChangeListener>();
    set.add(listener);
    this.locationListeners.set(key, set);

    return () => {
      const current = this.locationListeners.get(key);
      if (!current) {
        return;
      }
      current.delete(listener);
      if (current.size === 0) {
        this.locationListeners.delete(key);
      }
    };
  }

  public publishLocationChange(event: LocationChangeEvent): void {
    const specific = this.locationListeners.get(this.normalizePlanId(event.planId));
    if (specific) {
      specific.forEach((listener: LocationChangeListener) => listener(event));
    }
    const wildcard = this.locationListeners.get('*');
    if (wildcard) {
      wildcard.forEach((listener: LocationChangeListener) => listener(event));
    }
  }

  private normalizePlanId(planId: string): string {
    return planId && planId.trim().length > 0 ? planId.trim() : '*';
  }
}
