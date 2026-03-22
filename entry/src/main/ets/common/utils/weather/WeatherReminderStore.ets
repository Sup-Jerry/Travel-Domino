import { AppStorageKeys } from '../../constants/AppStorageKeys';
import { WeatherSuggestion } from '../../../domain/services/WeatherModels';

export interface WeatherStrategyAdjustment {
  density?: -1 | 0 | 1;
  pace?: -1 | 0 | 1;
  energy?: -1 | 0 | 1;
}

export interface WeatherReminderPayload {
  seq: number;
  planId: number;
  level: 'INFO' | 'NOTICE' | 'WARNING';
  title: string;
  message: string;
  relatedNodeIds: string[];
  suggestionId?: string;
  actionType?: string;
  reason?: string;
  expectedBenefit?: string;
  affectedNodes?: string[];
  suggestedDurationMin?: number;
  strategyHint?: string;
  strategyAdjustment?: WeatherStrategyAdjustment;
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

  public static fromSuggestion(
    planId: number,
    suggestion: WeatherSuggestion,
    strategyHint?: string,
    strategyAdjustment?: WeatherStrategyAdjustment
  ): WeatherReminderPayload {
    let resolvedHint: string | undefined = strategyHint;
    let resolvedAdjustment: WeatherStrategyAdjustment | undefined = strategyAdjustment;
    if (!resolvedHint && !resolvedAdjustment) {
      if (suggestion.triggerType === 'RAIN') {
        resolvedHint = '明日有雨，建议降低行程密度。';
        resolvedAdjustment = { density: -1 };
      } else if (suggestion.triggerType === 'HEAT') {
        resolvedHint = '持续高温，建议降低节奏并减少体力消耗。';
        resolvedAdjustment = { pace: -1, energy: -1 };
      }
    }
    return {
      seq: WeatherReminderStore.nextSeq(),
      planId: planId,
      level: suggestion.level,
      title: suggestion.title,
      message: suggestion.message,
      relatedNodeIds: suggestion.relatedNodeIds,
      suggestionId: suggestion.suggestionId,
      actionType: suggestion.actionType,
      reason: suggestion.reason,
      expectedBenefit: suggestion.expectedBenefit,
      affectedNodes: suggestion.affectedNodes,
      suggestedDurationMin: suggestion.suggestedDurationMin ?? suggestion.actionPayload?.suggestedStayMinutes,
      strategyHint: resolvedHint,
      strategyAdjustment: resolvedAdjustment,
      createdAt: suggestion.createdAt
    };
  }
}
