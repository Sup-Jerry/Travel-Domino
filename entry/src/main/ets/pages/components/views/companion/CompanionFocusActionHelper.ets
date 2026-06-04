import { EventEntity } from '../../../../model/entity/EventEntity';
import { TimelineExecutionState } from '../../../../domain/policy/TimelineExecutionState';
import { getCompanionEventState, hasCompanionOtherActiveEvent } from './CompanionDisplayHelper';

type CompanionEventAction = (event: EventEntity) => Promise<void>;
type CompanionVoidCallback = () => void;
type CompanionEventListGetter = () => EventEntity[];
type CompanionIndexGetter = (id: number) => number;
type CompanionIdAction = (id: number) => void;
type CompanionToastCallback = (message: string) => void;
type CompanionReopenAction = (eventId: number) => Promise<boolean>;
type CompanionActualStartAction = (eventId: number, nowTs: number) => Promise<boolean>;
type CompanionActiveConflictDialog = (excludeEventId: number) => Promise<boolean>;

interface CompanionHandleFocusedSkipParams {
  focusedEvent: EventEntity | null;
  skipEvent: CompanionEventAction;
  refreshContext: CompanionVoidCallback;
  getScheduledEvents: CompanionEventListGetter;
  getScheduleIndexById: CompanionIndexGetter;
  applyFocusById: CompanionIdAction;
  showToast: CompanionToastCallback;
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
  getScheduledEvents: CompanionEventListGetter;
  reopenSkippedEvent: CompanionReopenAction;
  updateActualStart: CompanionActualStartAction;
  showGlobalActiveConflictDialog: CompanionActiveConflictDialog;
  refreshContext: CompanionVoidCallback;
  applyFocusById: CompanionIdAction;
  enterImmersiveMode: CompanionVoidCallback;
  showToast: CompanionToastCallback;
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
