import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'NotificationGateway';

export class NotificationGateway {
  public static async updateScheduleNotification(
    title: string,
    content: string,
    targetPlanId?: number,
    targetEventId?: number,
    forceCompanionMode?: boolean
  ): Promise<void> {
    try {
      const module = await import('../../entryability/EntryAbility');
      await module.default.updateScheduleNotification(title, content, targetPlanId, targetEventId, forceCompanionMode);
    } catch (error) {
      hilog.warn(0x0000, TAG, `[NOTIFY][forward_failed] reason=${JSON.stringify(error)}`);
    }
  }
}
