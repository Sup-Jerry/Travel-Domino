import { AppStorageKeys } from '../../constants/AppStorageKeys';
import { WeatherSuggestion } from '../../../domain/services/WeatherModels';

export interface WeatherReminderPayload {
  seq: number;
  planId: number;
  level: 'INFO' | 'NOTICE' | 'WARNING';
  title: string;
  message: string;
  relatedNodeIds: string[];
  suggestionId?: string;
  actionType?: string;
  createdAt: number;
}

export class WeatherReminderStore {
  private static readonly WEATHER_REMINDER_PAYLOAD_PREFIX = 'WeatherReminderPayload_';

  public static nextSeq(): number {
    const prev = AppStorage.get<number>(AppStorageKeys.WEATHER_REMINDER_SEQ) || 0;
    const next = prev + 1;
    AppStorage.setOrCreate(AppStorageKeys.WEATHER_REMINDER_SEQ, next);
    return next;
  }

  public static readPayload(planId?: number): WeatherReminderPayload | null {
    const keys: string[] = [];
    if (planId && planId > 0) {
      keys.push(`${WeatherReminderStore.WEATHER_REMINDER_PAYLOAD_PREFIX}${planId}`);
    }
    keys.push(AppStorageKeys.WEATHER_REMINDER_PAYLOAD);

    for (let i = 0; i < keys.length; i++) {
      const raw = AppStorage.get<string>(keys[i]);
      if (!raw || raw.trim().length === 0) {
        continue;
      }
      try {
        return JSON.parse(raw) as WeatherReminderPayload;
      } catch (_error) {
      }
    }
    return null;
  }

  public static writePayload(payload: WeatherReminderPayload): void {
    const serialized = JSON.stringify(payload);
    AppStorage.setOrCreate(AppStorageKeys.WEATHER_REMINDER_PAYLOAD, serialized);
    AppStorage.setOrCreate(`${WeatherReminderStore.WEATHER_REMINDER_PAYLOAD_PREFIX}${payload.planId}`, serialized);
    AppStorage.setOrCreate(AppStorageKeys.WEATHER_REMINDER_SEQ, payload.seq);
  }

  public static clearPayload(planId?: number): void {
    AppStorage.setOrCreate(AppStorageKeys.WEATHER_REMINDER_PAYLOAD, '');
    if (planId && planId > 0) {
      AppStorage.setOrCreate(`${WeatherReminderStore.WEATHER_REMINDER_PAYLOAD_PREFIX}${planId}`, '');
    }
  }

  public static fromSuggestion(planId: number, suggestion: WeatherSuggestion): WeatherReminderPayload {
    return {
      seq: WeatherReminderStore.nextSeq(),
      planId: planId,
      level: suggestion.level,
      title: suggestion.title,
      message: suggestion.message,
      relatedNodeIds: suggestion.relatedNodeIds,
      suggestionId: suggestion.suggestionId,
      actionType: suggestion.actionType,
      createdAt: suggestion.createdAt
    };
  }
}
