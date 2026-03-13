import { ArrivalReminderPayload } from '../ArrivalReminderEngine';

export class ArrivalReminderStore {
  public static readonly ARRIVAL_REMINDER_SEQ_KEY = 'ArrivalReminderSeq';
  public static readonly ARRIVAL_REMINDER_PAYLOAD_KEY = 'ArrivalReminderPayload';
  private static readonly ARRIVAL_REMINDER_SEQ_PREFIX = 'ArrivalReminderSeq_';
  private static readonly ARRIVAL_REMINDER_PAYLOAD_PREFIX = 'ArrivalReminderPayload_';

  public static buildScopedSeqKey(planId: number): string {
    return `${ArrivalReminderStore.ARRIVAL_REMINDER_SEQ_PREFIX}${planId}`;
  }

  public static buildScopedPayloadKey(planId: number): string {
    return `${ArrivalReminderStore.ARRIVAL_REMINDER_PAYLOAD_PREFIX}${planId}`;
  }

  public static ensureDefaults(): void {
    AppStorage.setOrCreate(ArrivalReminderStore.ARRIVAL_REMINDER_SEQ_KEY, 0);
    AppStorage.setOrCreate(ArrivalReminderStore.ARRIVAL_REMINDER_PAYLOAD_KEY, '');
  }

  public static readPayload(planId?: number): ArrivalReminderPayload | null {
    let raw = '';
    if (planId !== undefined && planId > 0) {
      raw = AppStorage.get<string>(ArrivalReminderStore.buildScopedPayloadKey(planId)) ?? '';
    }
    if (!raw || raw.length <= 0) {
      raw = AppStorage.get<string>(ArrivalReminderStore.ARRIVAL_REMINDER_PAYLOAD_KEY) ?? '';
    }
    if (!raw || raw.length <= 0) {
      return null;
    }
    try {
      return JSON.parse(raw) as ArrivalReminderPayload;
    } catch (_error) {
      ArrivalReminderStore.clearPayload();
      return null;
    }
  }

  public static writePayload(payload: ArrivalReminderPayload): void {
    AppStorage.setOrCreate(ArrivalReminderStore.ARRIVAL_REMINDER_PAYLOAD_KEY, JSON.stringify(payload));
    AppStorage.setOrCreate(ArrivalReminderStore.ARRIVAL_REMINDER_SEQ_KEY, payload.seq);
    if (payload.planId > 0) {
      AppStorage.setOrCreate(ArrivalReminderStore.buildScopedPayloadKey(payload.planId), JSON.stringify(payload));
      AppStorage.setOrCreate(ArrivalReminderStore.buildScopedSeqKey(payload.planId), payload.seq);
    }
  }

  public static nextSeq(): number {
    const currentSeq = AppStorage.get<number>(ArrivalReminderStore.ARRIVAL_REMINDER_SEQ_KEY) ?? 0;
    return currentSeq + 1;
  }

  public static clearPayload(planId?: number): void {
    AppStorage.setOrCreate(ArrivalReminderStore.ARRIVAL_REMINDER_PAYLOAD_KEY, '');
    if (planId !== undefined && planId > 0) {
      AppStorage.setOrCreate(ArrivalReminderStore.buildScopedPayloadKey(planId), '');
    }
  }

  public static clearPayloadIfEventMatches(eventId: number): void {
    const payload = ArrivalReminderStore.readPayload();
    if (!payload || payload.eventId !== eventId) {
      return;
    }
    ArrivalReminderStore.clearPayload(payload.planId);
  }
}
