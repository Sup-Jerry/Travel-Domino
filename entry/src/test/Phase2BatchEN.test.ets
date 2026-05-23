import { describe, expect, it } from '@ohos/hypium';
import {
  canCreatePlanWithTitle,
  CreatePlanDialog,
  formatCreatePlanDateText
} from '../main/ets/pages/components/dialogs/CreatePlanDialog';

interface CreatePlanDialogPrivateEN {
  title: string;
  selectedDate: Date;
  effectiveTheme: string;
  initialRender(): void;
}

export default function phase2BatchENTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchEN_create_plan_dialog_extra', () => {
    it('normal: create_plan_should_allow_title_with_inner_spaces_after_trim', 0, () => {
      // Arrange
      const title = '  Tokyo Weekend Plan  ';

      // Act
      const canCreate = canCreatePlanWithTitle(title);

      // Assert
      expect(canCreate).assertTrue();
    });

    it('boundary: create_plan_date_should_format_single_digit_month_and_day_without_padding', 0, () => {
      // Arrange
      const date = new Date(2026, 2, 4);

      // Act
      const text = formatCreatePlanDateText(date);

      // Assert
      expect(text).assertEqual('2026/3/4');
    });

    it('invalid: create_plan_should_reject_line_break_only_title', 0, () => {
      // Arrange
      const title = '\n\t ';

      // Act
      const canCreate = canCreatePlanWithTitle(title);

      // Assert
      expect(canCreate).assertFalse();
    });

    it('conflict: create_plan_date_text_should_distinguish_adjacent_months', 0, () => {
      // Arrange
      const april = new Date(2026, 3, 30);
      const may = new Date(2026, 4, 1);

      // Act
      const aprilText = formatCreatePlanDateText(april);
      const mayText = formatCreatePlanDateText(may);

      // Assert
      expect(aprilText).assertEqual('2026/4/30');
      expect(mayText).assertEqual('2026/5/1');
      expect(aprilText === mayText).assertFalse();
    });

    it('regression: create_plan_should_allow_non_latin_non_empty_titles', 0, () => {
      // Arrange
      const title = '西安两日游';

      // Act
      const canCreate = canCreatePlanWithTitle(title);

      // Assert
      expect(canCreate).assertTrue();
    });

    it('combined: create_plan_dialog_should_render_light_and_dark_with_changed_date', 0, () => {
      // Arrange
      const page = new CreatePlanDialog(undefined, {} as LocalStorage) as Object as CreatePlanDialogPrivateEN;
      let threw = false;

      // Act
      page.title = 'Kyoto Trip';
      page.selectedDate = new Date(2026, 5, 6);
      page.effectiveTheme = 'light';
      try {
        page.initialRender();
        page.title = 'Osaka Trip';
        page.selectedDate = new Date(2026, 9, 10);
        page.effectiveTheme = 'dark';
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
      expect(page.title).assertEqual('Osaka Trip');
      expect(formatCreatePlanDateText(page.selectedDate)).assertEqual('2026/10/10');
    });
  });
}
