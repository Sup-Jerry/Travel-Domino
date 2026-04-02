import { EventEntity } from '../../../../model/entity/EventEntity';
import { TimelineExecutionState } from '../../../../domain/policy/TimelineExecutionState';
import { getCompanionEventState, hasCompanionOtherActiveEvent } from './CompanionDisplayHelper';

interface CompanionHandleFocusedSkipParams {
  focusedEvent: EventEntity | null;
  skipEvent: (event: EventEntity) => Promise<void>;
  refreshContext: () => void;
  getScheduledEvents: () => EventEntity[];
  getScheduleIndexById: (id: number) => number;
  applyFocusById: (id: number) => void;
  showToast: (message: string) => void;
}

export async function handleCompanionFocusedSkip(params: CompanionHandleFocusedSkipParams): Promise<void> {
  const focused = params.focusedEvent;
  if (!focused) {
    return;
  }
  if (getCompanionEventState(focused) !== 'PENDING') {
    params.showToast('仅“未开始”任务可跳过');
    return;
  }

  await params.skipEvent(focused);
  params.refreshContext();

  setTimeout(() => {
    const schedule = params.getScheduledEvents();
    const startIndex = params.getScheduleIndexById(focused.id);
    let nextId = -1;

    if (startIndex >= 0) {
      for (let i = startIndex + 1; i < schedule.length; i++) {
        if (TimelineExecutionState.isStartable(schedule[i])) {
          nextId = schedule[i].id;
          break;
        }
      }
    }

    if (nextId <= 0) {
      for (let i = 0; i < schedule.length; i++) {
        if (TimelineExecutionState.isStartable(schedule[i])) {
          nextId = schedule[i].id;
          break;
        }
      }
    }

    if (nextId > 0) {
      params.applyFocusById(nextId);
    }
  }, 120);
}

interface CompanionHandleFocusedReopenParams {
  focusedEvent: EventEntity | null;
  getScheduledEvents: () => EventEntity[];
  reopenSkippedEvent: (eventId: number) => Promise<boolean>;
  updateActualStart: (eventId: number, nowTs: number) => Promise<boolean>;
  showGlobalActiveConflictDialog: (excludeEventId: number) => Promise<boolean>;
  refreshContext: () => void;
  applyFocusById: (id: number) => void;
  enterImmersiveMode: () => void;
  showToast: (message: string) => void;
}

export async function handleCompanionFocusedReopen(params: CompanionHandleFocusedReopenParams): Promise<void> {
  const focused = params.focusedEvent;
  if (!focused) {
    return;
  }
  if (getCompanionEventState(focused) !== 'SKIPPED') {
    params.showToast('仅“已跳过”任务可重新开始');
    return;
  }
  if (hasCompanionOtherActiveEvent(params.getScheduledEvents(), focused.id)) {
    params.showToast('请先结束当前进行中的任务');
    return;
  }

  const reopened = await params.reopenSkippedEvent(focused.id);
  if (!reopened) {
    params.showToast('重新开始失败');
    return;
  }

  const started = await params.updateActualStart(focused.id, Date.now());
  if (!started) {
    const shown = await params.showGlobalActiveConflictDialog(focused.id);
    if (!shown) {
      params.showToast('开始打卡失败，请稍后重试');
    }
    return;
  }

  params.refreshContext();
  params.applyFocusById(focused.id);
  params.enterImmersiveMode();
}
