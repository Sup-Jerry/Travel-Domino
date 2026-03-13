import { NotificationGateway } from '../../common/utils/NotificationGateway';

type NotifyDispatcher = (title: string, content: string) => Promise<void>;

export class ReminderFacade {
  private static dispatcherForTest: NotifyDispatcher | null = null;

  public static setDispatcherForTest(dispatcher: NotifyDispatcher | null): void {
    ReminderFacade.dispatcherForTest = dispatcher;
  }

  public async updateScheduleNotification(title: string, content: string): Promise<void> {
    if (ReminderFacade.dispatcherForTest) {
      return ReminderFacade.dispatcherForTest(title, content);
    }
    return NotificationGateway.updateScheduleNotification(title, content);
  }
}
