import { PlanTransitionEvent } from './ExecutionContext';

export type StateTransitionListener = (event: PlanTransitionEvent) => void;

export class StateEventBus {
  private readonly listeners: Map<string, Set<StateTransitionListener>> = new Map<string, Set<StateTransitionListener>>();

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

  private normalizePlanId(planId: string): string {
    return planId && planId.trim().length > 0 ? planId.trim() : '*';
  }
}
