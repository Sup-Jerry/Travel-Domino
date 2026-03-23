import { WeatherReminderStore } from '../../common/utils/weather/WeatherReminderStore';
import { PlanTransitionEvent } from './ExecutionContext';
import { PlanStatus } from './PlanStatus';

export class NotificationBridge {
  private static readonly IN_PROGRESS_SHOWN_KEY_PREFIX = 'WeatherInProgressShown_';

  private hasInProgressShown(planIdNum: number): boolean {
    const key = `${NotificationBridge.IN_PROGRESS_SHOWN_KEY_PREFIX}${planIdNum}`;
    return (AppStorage.get<number>(key) ?? 0) === 1;
  }

  private markInProgressShown(planIdNum: number): void {
    const key = `${NotificationBridge.IN_PROGRESS_SHOWN_KEY_PREFIX}${planIdNum}`;
    AppStorage.setOrCreate(key, 1);
  }

  private clearInProgressShown(planIdNum: number): void {
    const key = `${NotificationBridge.IN_PROGRESS_SHOWN_KEY_PREFIX}${planIdNum}`;
    AppStorage.setOrCreate(key, 0);
  }

  public handlePlanTransitionNotification(event: PlanTransitionEvent): void {
    const planIdNum = Number(event.planId);
    if (!Number.isFinite(planIdNum) || planIdNum <= 0) {
      return;
    }

    if (event.toStatus === PlanStatus.READY) {
      WeatherReminderStore.writePayload({
        seq: WeatherReminderStore.nextSeq(),
        planId: planIdNum,
        level: 'NOTICE',
        title: '行程即将开始',
        message: '已进入执行预备状态，请查看首站天气与出发建议。',
        relatedNodeIds: [],
        suggestionId: 'state_ready',
        actionType: 'PREPARE',
        createdAt: event.timestamp
      });
      return;
    }

    if (event.toStatus === PlanStatus.IN_PROGRESS) {
      if (event.triggerReason === 'resume_by_user' || this.hasInProgressShown(planIdNum)) {
        return;
      }
      this.markInProgressShown(planIdNum);
      WeatherReminderStore.writePayload({
        seq: WeatherReminderStore.nextSeq(),
        planId: planIdNum,
        level: 'NOTICE',
        title: '行程已开始',
        message: '系统已切换到执行模式，将优先关注你当前位置天气。',
        relatedNodeIds: [],
        suggestionId: 'state_in_progress',
        actionType: 'NONE',
        createdAt: event.timestamp
      });
      return;
    }

    if (event.toStatus === PlanStatus.PAUSED) {
      WeatherReminderStore.writePayload({
        seq: WeatherReminderStore.nextSeq(),
        planId: planIdNum,
        level: 'INFO',
        title: '行程已暂停',
        message: '执行提醒已暂停，可在恢复后继续。',
        relatedNodeIds: [],
        suggestionId: 'state_paused',
        actionType: 'NONE',
        createdAt: event.timestamp
      });
      return;
    }

    if (event.toStatus === PlanStatus.COMPLETED || event.toStatus === PlanStatus.CANCELLED || event.toStatus === PlanStatus.EXPIRED) {
      WeatherReminderStore.clearPayload(planIdNum);
      this.clearInProgressShown(planIdNum);
    }
  }
}
