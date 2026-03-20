import { AppStorageKeys } from '../../common/constants/AppStorageKeys';

export type MetricCounterKey =
  'auto_transition_attempt_ready' |
  'auto_transition_success_ready' |
  'auto_transition_fail_ready' |
  'auto_transition_attempt_in_progress' |
  'auto_transition_success_in_progress' |
  'auto_transition_fail_in_progress' |
  'transition_jitter_blocked' |
  'recovery_attempt' |
  'recovery_success' |
  'recovery_fail';

export interface PlanStateMetricsSnapshot {
  dayKey: string;
  planId: string;
  counters: Record<string, number>;
  reasons: Record<string, number>;
  updatedAt: number;
}

interface MetricsEntry {
  key: string;
  snapshot: PlanStateMetricsSnapshot;
}

export class PlanStateMetricsStore {
  private static instance: PlanStateMetricsStore | null = null;

  public static getInstance(): PlanStateMetricsStore {
    if (!PlanStateMetricsStore.instance) {
      PlanStateMetricsStore.instance = new PlanStateMetricsStore();
    }
    return PlanStateMetricsStore.instance;
  }

  public static buildDayKey(ts: number = Date.now()): string {
    const date = new Date(ts);
    const y = date.getFullYear();
    const m = `${date.getMonth() + 1}`.padStart(2, '0');
    const d = `${date.getDate()}`.padStart(2, '0');
    return `${y}-${m}-${d}`;
  }

  public bump(planId: string, dayKey: string, key: MetricCounterKey, reasonCode?: string, now: number = Date.now()): void {
    if (!planId || !dayKey) {
      return;
    }
    const snapshot = this.getSnapshot(planId, dayKey);
    const next = this.cloneSnapshot(snapshot, dayKey, planId, now);
    next.counters[key] = (next.counters[key] ?? 0) + 1;
    if (reasonCode && reasonCode.trim().length > 0) {
      const reason = reasonCode.trim();
      next.reasons[reason] = (next.reasons[reason] ?? 0) + 1;
    }
    next.updatedAt = now;
    this.writeSnapshot(next);
  }

  public getSnapshot(planId: string, dayKey: string): PlanStateMetricsSnapshot {
    const key = this.composeKey(planId, dayKey);
    const entries = this.readAllEntries();
    for (let i = 0; i < entries.length; i++) {
      if (entries[i].key === key) {
        return entries[i].snapshot;
      }
    }
    const emptyCounters: Record<string, number> = {};
    const emptyReasons: Record<string, number> = {};
    return {
      dayKey: dayKey,
      planId: planId,
      counters: emptyCounters,
      reasons: emptyReasons,
      updatedAt: Date.now()
    };
  }

  private writeSnapshot(snapshot: PlanStateMetricsSnapshot): void {
    const key = this.composeKey(snapshot.planId, snapshot.dayKey);
    const entries = this.readAllEntries();
    let replaced = false;
    for (let i = 0; i < entries.length; i++) {
      if (entries[i].key === key) {
        entries[i].snapshot = snapshot;
        replaced = true;
        break;
      }
    }
    if (!replaced) {
      const entry: MetricsEntry = { key: key, snapshot: snapshot };
      entries.push(entry);
    }
    AppStorage.setOrCreate(AppStorageKeys.PLAN_STATE_METRICS, JSON.stringify(entries));
  }

  private cloneSnapshot(source: PlanStateMetricsSnapshot, dayKey: string, planId: string, now: number): PlanStateMetricsSnapshot {
    const counters: Record<string, number> = {};
    const reasons: Record<string, number> = {};

    const sourceCounters = source.counters;
    Object.keys(sourceCounters).forEach((counterKey: string) => {
      counters[counterKey] = sourceCounters[counterKey];
    });

    const sourceReasons = source.reasons;
    Object.keys(sourceReasons).forEach((reasonKey: string) => {
      reasons[reasonKey] = sourceReasons[reasonKey];
    });

    return {
      dayKey: dayKey,
      planId: planId,
      counters: counters,
      reasons: reasons,
      updatedAt: now
    };
  }

  private composeKey(planId: string, dayKey: string): string {
    return `${dayKey}#${planId}`;
  }

  private readAllEntries(): MetricsEntry[] {
    const raw = AppStorage.get<string>(AppStorageKeys.PLAN_STATE_METRICS);
    if (!raw || raw.trim().length === 0) {
      return [];
    }
    try {
      return JSON.parse(raw) as MetricsEntry[];
    } catch (_error) {
      return [];
    }
  }
}
