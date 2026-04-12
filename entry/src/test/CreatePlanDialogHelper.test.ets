import { describe, it, expect } from '@ohos/hypium';
import {
  canCreatePlanWithTitle,
  formatCreatePlanDateText
} from '../main/ets/pages/components/dialogs/CreatePlanDialog';

export default function createPlanDialogHelperTest() {
  describe('unit_test_case_generator_autofill_CreatePlanDialogHelper', () => {
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
  });
}
