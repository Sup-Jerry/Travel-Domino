import { EventEntity } from '../../model/entity/EventEntity';

export interface WeatherSuggestionContext {
  collabLabel: string;
  planningHint: string;
  collabSummary: string;
  strategyHint: string;
}

export class IndexHelpers {
  private static pad2(value: number): string {
    return String(value).padStart(2, '0');
  }

  static splitLines(text: string): string[] {
    return text.split('\n');
  }

  static buildWeatherSuggestionText(context: WeatherSuggestionContext): string {
    const labelPart = context.collabLabel ? `· ${context.collabLabel}` : '';
    const summaryPart = context.collabSummary ? `（${context.collabSummary}）` : '';
    const strategyPart = context.strategyHint ? `；策略联动：${context.strategyHint}` : '';
    return `天气建议（可选） ⓘ ${labelPart}：${context.planningHint}${summaryPart}${strategyPart}`;
  }

  static resolveBacklogSuggestedTime(events: EventEntity[]): string {
    const scheduleItems = events
      .filter((event: EventEntity) => event.status === 1)
      .sort((a: EventEntity, b: EventEntity) => a.sort_order - b.sort_order);

    if (scheduleItems.length === 0) {
      return '09:00';
    }

    const lastItem = scheduleItems[scheduleItems.length - 1];
    if (lastItem.computed_time) {
      const timeStr = lastItem.computed_time.includes(' ')
        ? lastItem.computed_time.split(' ').pop()
        : lastItem.computed_time;
      if (timeStr) {
        const parts = timeStr.split(':');
        const hour = Number(parts[0]);
        const minute = Number(parts[1]);
        const endMinutes = hour * 60 + minute + (lastItem.duration || 60);
        return `${IndexHelpers.pad2(Math.floor(endMinutes / 60))}:${IndexHelpers.pad2(endMinutes % 60)}`;
      }
    }

    if (lastItem.dynamic_end_time > 0) {
      const endDate = new Date(lastItem.dynamic_end_time);
      return `${IndexHelpers.pad2(endDate.getHours())}:${IndexHelpers.pad2(endDate.getMinutes())}`;
    }

    return '09:00';
  }
}
