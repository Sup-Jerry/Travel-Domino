import { describe, it, expect } from '@ohos/hypium';
import { ReminderFacade } from '../main/ets/viewmodel/internal/ReminderFacade';

export default function reminderFacadeTest() {
  describe('reminderFacadeTest', () => {
    it('updateScheduleNotification_should_use_test_dispatcher', 0, async (done: Function) => {
      let capturedTitle = '';
      let capturedContent = '';
      ReminderFacade.setDispatcherForTest(async (title: string, content: string): Promise<void> => {
        capturedTitle = title;
        capturedContent = content;
      });

      const facade = new ReminderFacade();
      await facade.updateScheduleNotification('当前地点', '下个地点');
      ReminderFacade.setDispatcherForTest(null);

      expect(capturedTitle).assertEqual('当前地点');
      expect(capturedContent).assertEqual('下个地点');
      done();
    });
  });
}
