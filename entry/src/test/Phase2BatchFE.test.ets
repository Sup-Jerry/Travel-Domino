import { describe, expect, it } from '@ohos/hypium';
import {
  canCopyPlanShareCompressedText,
  clampPlanShareEvents,
  resolvePlanShareSaveQuality
} from '../main/ets/pages/components/dialogs/PlanShareDialog';
import {
  DateFilterDialogAction,
  getDateFilterDialogActions,
  getDateFilterDialogOptions,
  isDateFilterDialogActionSupported
} from '../main/ets/pages/components/dialogs/DateFilterDialog';
import {
  getDateConflictDescription,
  shouldShowDateConflictPlanStartOption
} from '../main/ets/pages/components/dialogs/DateConflictDialog';
import {
  shouldPersistTipDialogChoice,
  toggleTipDialogChecked
} from '../main/ets/pages/components/dialogs/TipDialog';
import {
  getSuggestionApplyButtonLabel,
  getSuggestionBackButtonLabel,
  shouldShowSuggestionSummary
} from '../main/ets/pages/components/dialogs/SuggestionDialog';

export default function phase2BatchFETest() {
  describe('unit_test_case_generator_autofill_Phase2BatchFE_share_filter_tip_helpers', () => {
    it('normal: plan_share_helpers_should_clamp_event_count_and_quality', 0, () => {
      expect(clampPlanShareEvents(-1)).assertEqual(0);
      expect(clampPlanShareEvents(0)).assertEqual(0);
      expect(clampPlanShareEvents(12)).assertEqual(12);
      expect(clampPlanShareEvents(99)).assertEqual(50);
      expect(clampPlanShareEvents(8, 5)).assertEqual(5);
      expect(canCopyPlanShareCompressedText('')).assertFalse();
      expect(canCopyPlanShareCompressedText('{}')).assertTrue();
      expect(resolvePlanShareSaveQuality(0)).assertEqual(95);
      expect(resolvePlanShareSaveQuality(1)).assertEqual(80);
      expect(resolvePlanShareSaveQuality(2)).assertEqual(80);
    });

    it('boundary: date_filter_helpers_should_expose_supported_actions_in_option_order', 0, () => {
      const options = getDateFilterDialogOptions();
      const actions = getDateFilterDialogActions();

      expect(options.length).assertEqual(3);
      expect(actions.length).assertEqual(3);
      expect(actions[0]).assertEqual('show_all');
      expect(actions[1]).assertEqual('select_date');
      expect(actions[2]).assertEqual('select_range');
      expect(isDateFilterDialogActionSupported('show_all')).assertTrue();
      expect(isDateFilterDialogActionSupported('select_date')).assertTrue();
      expect(isDateFilterDialogActionSupported('select_range')).assertTrue();
      expect(isDateFilterDialogActionSupported('unknown')).assertFalse();
      expect(isDateFilterDialogActionSupported('')).assertFalse();
      expect(options[0].action).assertEqual(actions[0] as DateFilterDialogAction);
    });

    it('combined: date_conflict_helpers_should_build_description_and_plan_start_visibility', 0, () => {
      const description = getDateConflictDescription('04-20', '04-23');

      expect(description.indexOf('conflictDate=04-20') >= 0).assertTrue();
      expect(description.indexOf('planStart=04-23') >= 0).assertTrue();
      expect(shouldShowDateConflictPlanStartOption(0)).assertTrue();
      expect(shouldShowDateConflictPlanStartOption(1)).assertTrue();
      expect(shouldShowDateConflictPlanStartOption(-1)).assertFalse();
    });

    it('regression: tip_dialog_helpers_should_toggle_and_persist_only_checked_state', 0, () => {
      expect(toggleTipDialogChecked(false)).assertTrue();
      expect(toggleTipDialogChecked(true)).assertFalse();
      expect(shouldPersistTipDialogChoice(true)).assertTrue();
      expect(shouldPersistTipDialogChoice(false)).assertFalse();
    });

    it('invalid: suggestion_dialog_helpers_should_trim_summary_and_keep_button_labels', 0, () => {
      expect(shouldShowSuggestionSummary('')).assertFalse();
      expect(shouldShowSuggestionSummary('   ')).assertFalse();
      expect(shouldShowSuggestionSummary(' summary ')).assertTrue();
      expect(getSuggestionApplyButtonLabel().length > 0).assertTrue();
      expect(getSuggestionBackButtonLabel().length > 0).assertTrue();
    });
  });
}
