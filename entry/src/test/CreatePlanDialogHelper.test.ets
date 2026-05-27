import { describe, it, expect } from '@ohos/hypium';
import {
  canCreatePlanWithTitle,
  CreatePlanDialog,
  formatCreatePlanDateText
} from '../main/ets/pages/components/dialogs/CreatePlanDialog';

class DialogControllerMockCreatePlan {
  closed: boolean = false;

  close(): void {
    this.closed = true;
  }
}

interface CreatePlanDialogPrivateTest {
  controller?: DialogControllerMockCreatePlan;
  title: string;
  selectedDate: Date;
  effectiveTheme: string;
  initialRender(): void;
  confirmCreatePlan(): Promise<void>;
  setController(controller: DialogControllerMockCreatePlan): void;
  onCreatePlan: (title: string, startDate: number) => Promise<number>;
  onPlanCreated: (planId: number, title: string) => void;
}

export default function createPlanDialogHelperTest() {
  describe('unit_test_case_generator_autofill_CreatePlanDialogHelper', () => {
    it('combined: create_plan_dialog_set_controller_should_replace_controller_reference', 0, () => {
      // Arrange
      const page = new CreatePlanDialog(undefined, {} as LocalStorage) as Object as CreatePlanDialogPrivateTest;
      const first = new DialogControllerMockCreatePlan();
      const second = new DialogControllerMockCreatePlan();
      page.controller = first;

      // Act
      page.setController(second);

      // Assert
      expect(page.controller === second).assertTrue();
    });

    it('normal: create_plan_should_allow_non_empty_title', 0, () => {
      // Arrange
      const title = '东京攻略';
      // Act
      const canCreate = canCreatePlanWithTitle(title);
      // Assert
      expect(canCreate).assertTrue();
    });

    it('boundary: create_plan_should_reject_whitespace_only_title', 0, () => {
      // Arrange
      const title = '   ';
      // Act
      const canCreate = canCreatePlanWithTitle(title);
      // Assert
      expect(canCreate).assertFalse();
    });

    it('invalid: create_plan_should_reject_empty_title', 0, () => {
      // Arrange
      const title = '';
      // Act
      const canCreate = canCreatePlanWithTitle(title);
      // Assert
      expect(canCreate).assertFalse();
    });

    it('conflict: create_plan_date_text_should_use_month_plus_one_display', 0, () => {
      // Arrange
      const date = new Date(2026, 0, 2);
      // Act
      const dateText = formatCreatePlanDateText(date);
      // Assert
      expect(dateText).assertEqual('2026/1/2');
    });

    it('regression: td-20260412-create-plan-date-format-should-stay-year-month-day', 0, () => {
      // Arrange
      const date = new Date(2026, 11, 31);
      // Act
      const dateText = formatCreatePlanDateText(date);
      // Assert
      expect(dateText).assertEqual('2026/12/31');
    });

    it('combined: create_plan_title_and_date_helpers_should_work_together', 0, () => {
      // Arrange
      const title = '西安两日游';
      const date = new Date(2026, 3, 12);
      // Act
      const canCreate = canCreatePlanWithTitle(title);
      const dateText = formatCreatePlanDateText(date);
      // Assert
      expect(canCreate).assertTrue();
      expect(dateText.length > 0).assertTrue();
    });

    it('normal: create_plan_dialog_initial_render_should_support_title_and_date_branch', 0, () => {
      // Arrange
      const page = new CreatePlanDialog(undefined, {} as LocalStorage) as Object as CreatePlanDialogPrivateTest;
      let threw = false;

      // Act
      page.title = 'xian trip';
      page.selectedDate = new Date(2026, 3, 12);
      page.effectiveTheme = 'dark';
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
    });

    it('boundary: create_plan_should_allow_title_after_trimming_outer_spaces', 0, () => {
      // Arrange
      const title = '  上海周末  ';
      // Act
      const canCreate = canCreatePlanWithTitle(title);
      // Assert
      expect(canCreate).assertTrue();
    });

    it('boundary: create_plan_date_text_should_format_leap_day_without_zero_padding', 0, () => {
      // Arrange
      const date = new Date(2028, 1, 29);
      // Act
      const dateText = formatCreatePlanDateText(date);
      // Assert
      expect(dateText).assertEqual('2028/2/29');
    });

    it('normal: create_plan_dialog_set_controller_should_replace_controller_reference', 0, () => {
      // Arrange
      const page = new CreatePlanDialog(undefined, {} as LocalStorage) as Object as CreatePlanDialogPrivateTest;
      const first = new DialogControllerMockCreatePlan();
      const second = new DialogControllerMockCreatePlan();
      page.controller = first;

      // Act
      page.setController(second);

      // Assert
      expect(page.controller === second).assertTrue();
    });

    it('combined: create_plan_dialog_initial_render_should_support_light_theme_with_empty_title_matrix', 0, () => {
      // Arrange
      const page = new CreatePlanDialog(undefined, {} as LocalStorage) as Object as CreatePlanDialogPrivateTest;
      let threw = false;

      // Act
      page.title = '';
      page.selectedDate = new Date(2027, 8, 9);
      page.effectiveTheme = 'light';
      try {
        page.initialRender();
        page.title = 'beijing trip';
        page.selectedDate = new Date(2027, 10, 11);
        page.effectiveTheme = 'dark';
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
    });

    it('boundary: create_plan_dialog_confirm_should_skip_when_title_invalid', 0, async () => {
      // Arrange
      const page = new CreatePlanDialog(undefined, {} as LocalStorage) as Object as CreatePlanDialogPrivateTest;
      const controller = new DialogControllerMockCreatePlan();
      let createCalls = 0;
      page.controller = controller;
      page.title = '   ';
      page.onCreatePlan = async (): Promise<number> => {
        createCalls += 1;
        return 1;
      };

      // Act
      await page.confirmCreatePlan();

      // Assert
      expect(createCalls).assertEqual(0);
      expect(controller.closed).assertFalse();
    });

    it('boundary: create_plan_dialog_confirm_should_keep_dialog_open_when_create_fails', 0, async () => {
      // Arrange
      const page = new CreatePlanDialog(undefined, {} as LocalStorage) as Object as CreatePlanDialogPrivateTest;
      const controller = new DialogControllerMockCreatePlan();
      let notified = 0;
      page.controller = controller;
      page.title = 'hangzhou trip';
      page.selectedDate = new Date(2026, 4, 1);
      page.onCreatePlan = async (): Promise<number> => 0;
      page.onPlanCreated = (): void => {
        notified += 1;
      };

      // Act
      await page.confirmCreatePlan();

      // Assert
      expect(notified).assertEqual(0);
      expect(controller.closed).assertFalse();
    });

    it('normal: create_plan_dialog_confirm_should_notify_and_close_when_create_succeeds', 0, async () => {
      // Arrange
      const page = new CreatePlanDialog(undefined, {} as LocalStorage) as Object as CreatePlanDialogPrivateTest;
      const controller = new DialogControllerMockCreatePlan();
      let createdPlanId = -1;
      let createdTitle = '';
      let passedStartDate = 0;
      page.controller = controller;
      page.title = 'nanjing trip';
      page.selectedDate = new Date(2026, 6, 3);
      page.onCreatePlan = async (_title: string, startDate: number): Promise<number> => {
        passedStartDate = startDate;
        return 42;
      };
      page.onPlanCreated = (planId: number, title: string): void => {
        createdPlanId = planId;
        createdTitle = title;
      };

      // Act
      await page.confirmCreatePlan();

      // Assert
      expect(passedStartDate).assertEqual(page.selectedDate.getTime());
      expect(createdPlanId).assertEqual(42);
      expect(createdTitle).assertEqual('nanjing trip');
      expect(controller.closed).assertTrue();
    });
  });
}
