import { NotificationGateway } from '../../infrastructure/adapters/NotificationGateway';

type NotifyDispatcher = (
  title: string,
  content: string,
  targetPlanId?: number,
  targetEventId?: number,
  forceCompanionMode?: boolean
) => Promise<void>;

export class ReminderFacade {
  private static dispatcherForTest: NotifyDispatcher | null = null;

  public static setDispatcherForTest(dispatcher: NotifyDispatcher | null): void {
    ReminderFacade.dispatcherForTest = dispatcher;
  }

  public async updateScheduleNotification(
    title: string,
    content: string,
    targetPlanId?: number,
    targetEventId?: number,
    forceCompanionMode?: boolean
  ): Promise<void> {
    if (ReminderFacade.dispatcherForTest) {
      return ReminderFacade.dispatcherForTest(title, content, targetPlanId, targetEventId, forceCompanionMode);
    }
    return NotificationGateway.updateScheduleNotification(
      title,
      content,
      targetPlanId,
      targetEventId,
      forceCompanionMode
    );
  }
}
