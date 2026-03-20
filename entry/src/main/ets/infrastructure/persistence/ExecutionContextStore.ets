import { AppStorageKeys } from '../../common/constants/AppStorageKeys';
import { ExecutionContext, PlanTransitionEvent } from '../../domain/statemachine/ExecutionContext';

interface ContextEntry {
  planId: string;
  context: ExecutionContext;
}

interface TransitionEntry {
  planId: string;
  events: PlanTransitionEvent[];
}

export class ExecutionContextStore {
  private static instance: ExecutionContextStore | null = null;

  public static getInstance(): ExecutionContextStore {
    if (!ExecutionContextStore.instance) {
      ExecutionContextStore.instance = new ExecutionContextStore();
    }
    return ExecutionContextStore.instance;
  }

  public readContext(planId: string): ExecutionContext | null {
    const entries = this.readAllContextEntries();
    for (let i = 0; i < entries.length; i++) {
      if (entries[i].planId === planId) {
        return entries[i].context;
      }
    }
    return null;
  }

  public writeContext(context: ExecutionContext): void {
    const entries = this.readAllContextEntries();
    let replaced = false;
    for (let i = 0; i < entries.length; i++) {
      if (entries[i].planId === context.planId) {
        entries[i] = {
          planId: context.planId,
          context: context
        };
        replaced = true;
        break;
      }
    }
    if (!replaced) {
      entries.push({
        planId: context.planId,
        context: context
      });
    }
    AppStorage.setOrCreate(AppStorageKeys.PLAN_EXECUTION_CONTEXT, JSON.stringify(entries));
  }

  public clearContext(planId: string): void {
    const entries = this.readAllContextEntries();
    const next: ContextEntry[] = [];
    for (let i = 0; i < entries.length; i++) {
      if (entries[i].planId !== planId) {
        next.push(entries[i]);
      }
    }
    AppStorage.setOrCreate(AppStorageKeys.PLAN_EXECUTION_CONTEXT, JSON.stringify(next));
  }

  public appendTransition(event: PlanTransitionEvent): void {
    const entries = this.readAllTransitionEntries();
    let target: TransitionEntry | null = null;
    for (let i = 0; i < entries.length; i++) {
      if (entries[i].planId === event.planId) {
        target = entries[i];
        break;
      }
    }

    if (!target) {
      target = {
        planId: event.planId,
        events: []
      };
      entries.push(target);
    }

    target.events.push(event);
    if (target.events.length > 30) {
      target.events.splice(0, target.events.length - 30);
    }

    AppStorage.setOrCreate(AppStorageKeys.PLAN_TRANSITION_LOG, JSON.stringify(entries));
  }

  public readTransitions(planId: string): PlanTransitionEvent[] {
    const entries = this.readAllTransitionEntries();
    for (let i = 0; i < entries.length; i++) {
      if (entries[i].planId === planId) {
        return entries[i].events;
      }
    }
    return [];
  }

  public readLatestTransition(planId: string): PlanTransitionEvent | null {
    const list = this.readTransitions(planId);
    if (list.length === 0) {
      return null;
    }
    return list[list.length - 1];
  }

  private readAllContextEntries(): ContextEntry[] {
    const raw = AppStorage.get<string>(AppStorageKeys.PLAN_EXECUTION_CONTEXT);
    if (!raw || raw.trim().length === 0) {
      return [];
    }
    try {
      return JSON.parse(raw) as ContextEntry[];
    } catch (_error) {
      return [];
    }
  }

  private readAllTransitionEntries(): TransitionEntry[] {
    const raw = AppStorage.get<string>(AppStorageKeys.PLAN_TRANSITION_LOG);
    if (!raw || raw.trim().length === 0) {
      return [];
    }
    try {
      return JSON.parse(raw) as TransitionEntry[];
    } catch (_error) {
      return [];
    }
  }
}
