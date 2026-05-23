import { describe, it, expect } from '@ohos/hypium';
import { ReminderFacade } from '../main/ets/viewmodel/internal/ReminderFacade';

export default function reminderFacadeTest() {
  describe('reminderFacadeTest', () => {
    it('normal: updateScheduleNotification_should_use_test_dispatcher', 0, async (done: Function) => {
      // Arrange
      let capturedTitle = '';
      let capturedContent = '';
      ReminderFacade.setDispatcherForTest(async (title: string, content: string): Promise<void> => {
        capturedTitle = title;
        capturedContent = content;
      });
      const facade = new ReminderFacade();

      // Act
      await facade.updateScheduleNotification('褰撳墠鍦扮偣', '涓嬩釜鍦扮偣');
      ReminderFacade.setDispatcherForTest(null);

      // Assert
      expect(capturedTitle).assertEqual('褰撳墠鍦扮偣');
      expect(capturedContent).assertEqual('涓嬩釜鍦扮偣');
      done();
    });
  });

  describe('unit_test_case_generator_autofill_ReminderFacade', () => {
    it('boundary: updateScheduleNotification_should_forward_optional_args_to_dispatcher', 0, async (done: Function) => {
      // Arrange
      let capturedPlanId = -1;
      let capturedEventId = -1;
      let capturedForceCompanionMode = false;
      ReminderFacade.setDispatcherForTest(
        async (_title: string, _content: string, targetPlanId?: number, targetEventId?: number, forceCompanionMode?: boolean): Promise<void> => {
          capturedPlanId = targetPlanId ?? -1;
          capturedEventId = targetEventId ?? -1;
          capturedForceCompanionMode = forceCompanionMode === true;
        }
      );
      const facade = new ReminderFacade();

      // Act
      await facade.updateScheduleNotification('title_b', 'content_b', 77, 88, true);
      ReminderFacade.setDispatcherForTest(null);

      // Assert
      expect(capturedPlanId).assertEqual(77);
      expect(capturedEventId).assertEqual(88);
      expect(capturedForceCompanionMode).assertTrue();
      done();
    });

    it('invalid: updateScheduleNotification_should_allow_empty_text_payloads', 0, async (done: Function) => {
      // Arrange
      let capturedTitle = 'unset';
      let capturedContent = 'unset';
      ReminderFacade.setDispatcherForTest(async (title: string, content: string): Promise<void> => {
        capturedTitle = title;
        capturedContent = content;
      });
      const facade = new ReminderFacade();

      // Act
      await facade.updateScheduleNotification('', '');
      ReminderFacade.setDispatcherForTest(null);

      // Assert
      expect(capturedTitle).assertEqual('');
      expect(capturedContent).assertEqual('');
      done();
    });

    it('conflict: updateScheduleNotification_should_use_latest_dispatcher_when_dispatcher_replaced', 0, async (done: Function) => {
      // Arrange
      let firstCalls = 0;
      let secondCalls = 0;
      ReminderFacade.setDispatcherForTest(async (): Promise<void> => {
        firstCalls += 1;
      });
      ReminderFacade.setDispatcherForTest(async (): Promise<void> => {
        secondCalls += 1;
      });
      const facade = new ReminderFacade();

      // Act
      await facade.updateScheduleNotification('title_c', 'content_c');
      ReminderFacade.setDispatcherForTest(null);

      // Assert
      expect(firstCalls).assertEqual(0);
      expect(secondCalls).assertEqual(1);
      done();
    });

    it('regression: dispatcher_reset_should_not_leak_previous_capture_between_calls', 0, async (done: Function) => {
      // Arrange
      let firstTitle = '';
      let secondTitle = '';
      ReminderFacade.setDispatcherForTest(async (title: string): Promise<void> => {
        firstTitle = title;
      });
      const facade = new ReminderFacade();

      // Act
      await facade.updateScheduleNotification('first_title', 'first_content');
      ReminderFacade.setDispatcherForTest(async (title: string): Promise<void> => {
        secondTitle = title;
      });
      await facade.updateScheduleNotification('second_title', 'second_content');
      ReminderFacade.setDispatcherForTest(null);

      // Assert
      expect(firstTitle).assertEqual('first_title');
      expect(secondTitle).assertEqual('second_title');
      done();
    });

    it('combined: dispatcher_matrix_should_preserve_text_and_optional_params_across_multiple_calls', 0, async (done: Function) => {
      // Arrange
      const records: string[] = [];
      ReminderFacade.setDispatcherForTest(
        async (title: string, content: string, targetPlanId?: number, targetEventId?: number, forceCompanionMode?: boolean): Promise<void> => {
          records.push(`${title}|${content}|${targetPlanId ?? 0}|${targetEventId ?? 0}|${forceCompanionMode === true}`);
        }
      );
      const facade = new ReminderFacade();

      // Act
      await facade.updateScheduleNotification('one', 'first');
      await facade.updateScheduleNotification('two', 'second', 9, 10, false);
      ReminderFacade.setDispatcherForTest(null);

      // Assert
      expect(records.length).assertEqual(2);
      expect(records[0]).assertEqual('one|first|0|0|false');
      expect(records[1]).assertEqual('two|second|9|10|false');
      done();
    });
  });
}
