import { describe, expect, it } from '@ohos/hypium';
import {
  getAiLoadingTextByStrategy,
  normalizeAiStrategyMode,
  shouldKeepCurrentModeOnRegenerate,
  shouldUseAiInitialPrompt
} from '../main/ets/pages/components/dialogs/AiInputDialog';
import {
  canConflictCompressConfirm,
  resolveConflictCompressPreviewNewDuration,
  resolveConflictCompressPreviewReduced,
  resolveConflictCompressRemainingGap,
  shouldShowConflictCompressOverload
} from '../main/ets/pages/components/dialogs/ConflictCompressDialog';
import {
  getPlanSettingsActions,
  isPlanSettingsActionSupported,
  isWeatherPreferenceLevelValid
} from '../main/ets/pages/components/dialogs/PlanSettingsDialog';
import {
  canStartPlanJsonImport,
  normalizePlanJsonImportInput
} from '../main/ets/pages/components/dialogs/PlanJsonImportDialog';
import { canCopyPlanJsonText } from '../main/ets/pages/components/dialogs/PlanJsonExportDialog';

export default function phase2BatchGITest() {
  describe('unit_test_case_generator_autofill_Phase2BatchGI_dialog_export_import_strategy_branches', () => {
    it('combined: ai_input_should_cover_negative_custom_mode_loading_text_and_prompt_guard', 0, () => {
      expect(normalizeAiStrategyMode(-1)).assertEqual(-1);
      expect(normalizeAiStrategyMode(0)).assertEqual(0);
      expect(getAiLoadingTextByStrategy(-1)).assertEqual('正在生成行程（预计30-50秒）');
      expect(getAiLoadingTextByStrategy(0)).assertEqual('正在生成行程（预计30-50秒）');
      expect(shouldUseAiInitialPrompt('\ntrip\n')).assertTrue();
      expect(shouldKeepCurrentModeOnRegenerate(-1, false, true)).assertFalse();
      expect(shouldKeepCurrentModeOnRegenerate(-1, true, false)).assertFalse();
      expect(shouldKeepCurrentModeOnRegenerate(1, false, false)).assertFalse();
    });

    it('combined: conflict_compress_should_cover_non_positive_overload_and_preview_fallback_matrix', 0, () => {
      expect(canConflictCompressConfirm(-1)).assertFalse();
      expect(shouldShowConflictCompressOverload('OVERLOAD', -5)).assertFalse();
      expect(shouldShowConflictCompressOverload('COMPRESS_CONFIRM', 8)).assertFalse();
      expect(resolveConflictCompressPreviewNewDuration([{ index: 1, newVal: 35 }, { index: 1, newVal: 25 }], 1, 50)).assertEqual(35);
      expect(resolveConflictCompressPreviewNewDuration([{ index: 2, newVal: 18 }], 1, 50)).assertEqual(50);
      expect(resolveConflictCompressPreviewReduced(30, 30)).assertEqual(0);
      expect(resolveConflictCompressRemainingGap(undefined)).assertEqual(0);
    });

    it('combined: plan_settings_should_cover_decimal_negative_and_known_action_set', 0, () => {
      const actions = getPlanSettingsActions();
      expect(actions[0]).assertEqual('rename');
      expect(actions[3]).assertEqual('weather_preference');
      expect(isPlanSettingsActionSupported('rename')).assertTrue();
      expect(isPlanSettingsActionSupported('')).assertFalse();
      expect(isWeatherPreferenceLevelValid(0)).assertTrue();
      expect(isWeatherPreferenceLevelValid(2)).assertTrue();
      expect(isWeatherPreferenceLevelValid(-1)).assertFalse();
      expect(isWeatherPreferenceLevelValid(1.5)).assertFalse();
    });

    it('combined: plan_json_import_should_cover_trimmed_newline_and_whitespace_only_cases', 0, () => {
      expect(normalizePlanJsonImportInput('\n  {\"a\":1}\t')).assertEqual('{\"a\":1}');
      expect(normalizePlanJsonImportInput('\n\t')).assertEqual('');
      expect(canStartPlanJsonImport('\n\t')).assertFalse();
      expect(canStartPlanJsonImport('\n  []  ')).assertTrue();
    });

    it('combined: plan_json_export_should_keep_length_based_copy_guard_for_whitespace_text', 0, () => {
      expect(canCopyPlanJsonText('')).assertFalse();
      expect(canCopyPlanJsonText(' ')).assertTrue();
      expect(canCopyPlanJsonText('\n')).assertTrue();
      expect(canCopyPlanJsonText('{}')).assertTrue();
    });
  });
}
