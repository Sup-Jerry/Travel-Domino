import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'NotificationGateway';

export class NotificationGateway {
  public static async updateScheduleNotification(title: string, content: string): Promise<void> {
    try {
      const module = await import('../../entryability/EntryAbility');
      await module.default.updateScheduleNotification(title, content);
    } catch (error) {
      hilog.warn(0x0000, TAG, `[NOTIFY][forward_failed] reason=${JSON.stringify(error)}`);
    }
  }
}
