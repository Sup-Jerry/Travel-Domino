import { describe, it, expect } from '@ohos/hypium';
import {
  DateConflictDialog,
  getDateConflictDescription,
  shouldShowDateConflictPlanStartOption
} from '../main/ets/pages/components/dialogs/DateConflictDialog';

interface DateConflictDialogPrivateTest {
  conflictDateStr: string;
  planStartDateStr: string;
  planStartDate: number;
  initialRender(): void;
}

export default function dateConflictDialogHelperTest() {
  describe('unit_test_case_generator_autofill_DateConflictDialogHelper', () => {
    it('normal: date_conflict_description_should_include_both_dates', 0, () => {
      // Arrange
      const conflictDate = '05-01';
      const planStart = '05-05';
      // Act
      const text = getDateConflictDescription(conflictDate, planStart);
      // Assert
      expect(text.indexOf('05-01') >= 0).assertTrue();
      expect(text.indexOf('05-05') >= 0).assertTrue();
    });

    it('boundary: date_conflict_plan_start_option_should_show_for_zero_timestamp', 0, () => {
      // Arrange
      const planStartDate = 0;
      // Act
      const show = shouldShowDateConflictPlanStartOption(planStartDate);
      // Assert
      expect(show).assertTrue();
    });

    it('invalid: date_conflict_plan_start_option_should_hide_for_negative_timestamp', 0, () => {
      // Arrange
      const planStartDate = -1;
      // Act
      const show = shouldShowDateConflictPlanStartOption(planStartDate);
      // Assert
      expect(show).assertFalse();
    });

    it('conflict: date_conflict_description_should_change_when_conflict_date_changes', 0, () => {
      // Arrange
      const planStart = '05-05';
      // Act
      const textA = getDateConflictDescription('05-01', planStart);
      const textB = getDateConflictDescription('05-02', planStart);
      // Assert
      expect(textA === textB).assertFalse();
    });

    it('regression: td-20260412-date-conflict-description-format-should-stay', 0, () => {
      // Arrange
      const conflictDate = 'A';
      const planStart = 'B';
      // Act
      const text = getDateConflictDescription(conflictDate, planStart);
      // Assert
      expect(text.indexOf('conflictDate=') === 0).assertTrue();
      expect(text.indexOf(';planStart=') > 0).assertTrue();
    });

    it('combined: date_conflict_option_and_description_should_be_independent', 0, () => {
      // Arrange
      const planStartDate = -2;
      // Act
      const show = shouldShowDateConflictPlanStartOption(planStartDate);
      const text = getDateConflictDescription('x', 'y');
      // Assert
      expect(show).assertFalse();
      expect(text.indexOf('x') >= 0).assertTrue();
    });

    it('normal: date_conflict_dialog_initial_render_should_support_conflict_options_layout', 0, () => {
      // Arrange
      const page = new DateConflictDialog(undefined, {} as LocalStorage) as Object as DateConflictDialogPrivateTest;
      let threw = false;

      // Act
      page.conflictDateStr = '05月01日';
      page.planStartDateStr = '05月05日';
      page.planStartDate = new Date(2026, 4, 5).getTime();
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
    });
  });
}
