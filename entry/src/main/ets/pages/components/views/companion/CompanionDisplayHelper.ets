import { EventEntity } from '../../../../model/entity/EventEntity';
import { SoftReplanApplyResult, WeatherSuggestion } from '../../../../domain/services/WeatherModels';
import { CompanionContext } from '../../../../viewmodel/TimelineViewModel';
import { CompanionEventState, CompanionPresentationHelper } from '../CompanionPresentationHelper';
import { ThemePalette } from '../../../../common/utils/ThemeCenter';

export type CompanionDisplayFilterState = 'ALL' | CompanionEventState;

export function getCompanionPlannedRange(event: EventEntity): string {
  return CompanionPresentationHelper.getPlannedRange(event);
}

export function getCompanionForecastStartText(event: EventEntity): string {
  return CompanionPresentationHelper.getForecastStartText(event);
}

export function getCompanionMainCardTimeText(event: EventEntity): string {
  return CompanionPresentationHelper.getMainCardTimeText(event);
}

export function getCompanionEventState(event: EventEntity): CompanionEventState {
  return CompanionPresentationHelper.getEventState(event);
}

export function getCompanionEventStateLabel(event: EventEntity): string {
  return CompanionPresentationHelper.getEventStateLabel(event);
}

export function getCompanionTimelineSupplement(event: EventEntity): string {
  return CompanionPresentationHelper.getTimelineSupplement(event);
}

export function getCompanionStateCoreColor(event: EventEntity, palette: ThemePalette): ResourceColor {
  const state = getCompanionEventState(event);
  if (state === 'ACTIVE') {
    return palette.success;
  }
  if (state === 'COMPLETED') {
    return palette.statusCompleted;
  }
  if (state === 'SKIPPED') {
    return palette.statusSkipped;
  }
  return palette.statusPending;
}

export function getCompanionStateTagBackgroundColor(event: EventEntity): ResourceColor {
  const state = getCompanionEventState(event);
  if (state === 'ACTIVE') {
    return '#E9F8F1';
  }
  if (state === 'COMPLETED') {
    return '#EAF7EE';
  }
  if (state === 'SKIPPED') {
    return '#FFF4E7';
  }
  return '#EAF2FF';
}

export function getCompanionRuntimeLabel(runtimeState: string): string {
  switch (runtimeState) {
    case 'READY':
      return '可开始';
    case 'ACTIVE':
      return '进行中';
    case 'PAUSED':
      return '已暂停';
    case 'GAP':
      return '空档中';
    default:
      return '空闲';
  }
}

export function getCompanionRuntimeDescription(context: CompanionContext, nowTs: number): string {
  if (context.runtimeState === 'PAUSED') {
    return '当前执行已暂停，可继续恢复；恢复后会重新计算后续安排。';
  }
  if (context.runtimeState === 'ACTIVE') {
    return '当前地点进行中。结束打卡后会自动重排后续行程。';
  }

  if (context.runtimeState === 'READY' && context.currentEvent) {
    const startTs = context.currentEvent.dynamic_start_time;
    if (startTs > 0 && startTs + 60000 < nowTs) {
      const overdue = Math.max(1, Math.round((nowTs - startTs) / 60000));
      return `已超出计划开始 ${overdue} 分钟，仍可立即开始。`;
    }
    return '当前任务可以立即开始。';
  }

  if (context.runtimeState === 'GAP' && context.nextEvent) {
    return `当前暂无可执行任务。下一站：${context.nextEvent.name}。`;
  }

  if (context.nextEvent) {
    return `下一站：${context.nextEvent.name}。`;
  }
  return '当前暂无进行中的任务。';
}

export function getCompanionWeatherScoreSummary(score: number): string {
  if (!Number.isFinite(score) || score < 0) {
    return '暂无评分';
  }
  if (score < 70) {
    return `评分 ${score} · 高风险`;
  }
  if (score < 85) {
    return `评分 ${score} · 中风险`;
  }
  return `评分 ${score} · 低风险`;
}

export function buildCompanionExecutionSuggestionExplanation(item: WeatherSuggestion): string {
  const reason = item.reason && item.reason.trim().length > 0 ? item.reason : '系统根据天气风险自动生成。';
  const benefit = item.expectedBenefit && item.expectedBenefit.trim().length > 0 ? item.expectedBenefit : '用于降低执行中断风险。';
  const rollback = item.canRollback ? '可回滚' : '不可回滚';
  const actionTypeText = item.actionType === 'REORDER'
    ? '重排行程顺序'
    : (item.actionType === 'SHORTEN_STAY'
      ? '缩短停留时长'
      : (item.actionType === 'REPLACE_NODE'
        ? '替换为更稳妥节点'
        : (item.actionType === 'SKIP_NODE'
          ? '跳过当前高风险节点'
          : '提示类建议')));
  return `建议：${item.title}\n动作类型：${actionTypeText}\n原因：${reason}\n收益：${benefit}\n回滚：${rollback}\n按钮说明：可选应用=立即尝试按建议调整；稍后=本次先不处理但后续仍可再看；忽略=移除该建议，不会自动执行。`;
}

export function buildCompanionReplanToastMessage(result: SoftReplanApplyResult): string {
  if (result.success) {
    const summary = result.preview?.summary && result.preview.summary.trim().length > 0
      ? result.preview.summary
      : '已按可选建议调整行程';
    return summary;
  }
  if (result.errorCode === 'REPLAN_INVALID') {
    if (result.reasonCode === 'status_blocked') {
      return '当前计划状态不可调整（如已过期/已完成）';
    }
    if (result.reasonCode === 'suggestion_missing') {
      return '建议已失效，请先刷新天气后重试';
    }
    return '参数或状态不满足应用条件';
  }
  if (result.errorCode === 'REPLAN_BUSY') {
    return '系统正在处理上一条建议，请稍后再试';
  }
  if (result.errorCode === 'REPLAN_IMMUTABLE') {
    return '命中已完成或锁定节点保护，未执行调整';
  }
  if (result.errorCode === 'REPLAN_TIMEOUT') {
    return '调整超时，已自动回滚';
  }
  if (result.errorCode === 'REPLAN_CONFLICT') {
    if (result.reasonCode === 'apply_failed') {
      return '建议未命中可调整节点，已回滚';
    }
    return result.rolledBack ? '执行冲突，已回滚未改动行程' : '执行冲突，未应用建议';
  }
  return '可选建议应用失败，请稍后重试';
}

export function matchesCompanionFilter(event: EventEntity, state: CompanionDisplayFilterState): boolean {
  if (state === 'ALL') {
    return true;
  }
  return getCompanionEventState(event) === state;
}

export function getCompanionFilterLabel(state: CompanionDisplayFilterState): string {
  if (state === 'ALL') {
    return '全部';
  }
  if (state === 'PENDING') {
    return '未开始';
  }
  if (state === 'ACTIVE') {
    return '进行中';
  }
  if (state === 'COMPLETED') {
    return '已完成';
  }
  return '已跳过';
}

export function getCompanionFilterOptions(): CompanionDisplayFilterState[] {
  return ['ALL', 'PENDING', 'ACTIVE', 'COMPLETED', 'SKIPPED'];
}

export function hasCompanionOtherActiveEvent(schedule: EventEntity[], excludeEventId: number): boolean {
  return schedule.some((item: EventEntity) =>
    item.id !== excludeEventId && getCompanionEventState(item) === 'ACTIVE'
  );
}

export function canCompanionStartFocused(event: EventEntity, schedule: EventEntity[]): boolean {
  if (getCompanionEventState(event) !== 'PENDING') {
    return false;
  }
  return !hasCompanionOtherActiveEvent(schedule, event.id);
}

export function canCompanionEndFocused(event: EventEntity, context: CompanionContext): boolean {
  if (getCompanionEventState(event) !== 'ACTIVE') {
    return false;
  }
  if (!context.actions.canEnd) {
    return false;
  }
  if (!context.currentEvent) {
    return false;
  }
  return context.currentEvent.id === event.id;
}

export function isCompanionCurrentEventPending(context: CompanionContext): boolean {
  return !!context.currentEvent && getCompanionEventState(context.currentEvent) === 'PENDING';
}

export function isCompanionCurrentEventActive(context: CompanionContext): boolean {
  return !!context.currentEvent && getCompanionEventState(context.currentEvent) === 'ACTIVE';
}
