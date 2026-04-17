import { describe, expect, it } from '@ohos/hypium';
import {
  hasPositiveAllocationValues,
  resolveGapTierColor,
  resolveGapTierLabel
} from '../main/ets/pages/components/dialogs/GapResolutionDialog';
import {
  getAiLoadingTextByStrategy,
  normalizeAiStrategyMode,
  shouldKeepCurrentModeOnRegenerate,
  shouldUseAiInitialPrompt
} from '../main/ets/pages/components/dialogs/AiInputDialog';
import {
  getConflictSelectionGapPrompt,
  shouldUseConflictAdvanceAdjust
} from '../main/ets/pages/components/dialogs/ConflictSelectionDialog';
import {
  canConflictCompressConfirm,
  ConflictCompressAffectedItem,
  resolveConflictCompressPreviewNewDuration,
  resolveConflictCompressPreviewReduced,
  resolveConflictCompressRemainingGap,
  shouldShowConflictCompressOverload
} from '../main/ets/pages/components/dialogs/ConflictCompressDialog';
import {
  isAddItemCoordinateValid,
  isAddItemMapPickerEnabled,
  resolveAddItemDuration,
  resolveAddItemMode,
  resolveAddItemScopedStorageKey
} from '../main/ets/pages/components/dialogs/AddItemDialog';

class ConflictCompressAffectedItemAY implements ConflictCompressAffectedItem {
  index: number = 0;
  newVal: number = 0;
}

function buildAffectedItemAY(index: number, newVal: number): ConflictCompressAffectedItem {
  const item = new ConflictCompressAffectedItemAY();
  item.index = index;
  item.newVal = newVal;
  return item;
}

export default function phase2BatchAYTest() {
  describe('phase2BatchAYTest', () => {
    it('normal: gap_resolution_tier_color_should_return_blue_for_upgrade_gap', 0, () => {
      // Arrange
      const min = 95;
      const trigger = 30;
      // Act
      const color = resolveGapTierColor(min, trigger);
      // Assert
      expect(color).assertEqual('#007DFF');
    });

    it('boundary: gap_resolution_tier_color_should_return_green_at_trigger', 0, () => {
      // Arrange
      const min = 30;
      const trigger = 30;
      // Act
      const color = resolveGapTierColor(min, trigger);
      // Assert
      expect(color).assertEqual('#4CAF50');
    });

    it('invalid: gap_resolution_tier_color_should_return_empty_below_trigger', 0, () => {
      // Arrange
      const min = -1;
      const trigger = 30;
      // Act
      const color = resolveGapTierColor(min, trigger);
      // Assert
      expect(color).assertEqual('');
    });

    it('normal: gap_resolution_tier_label_should_return_gold_for_long_gap', 0, () => {
      // Arrange
      const min = 180;
      const trigger = 30;
      // Act
      const label = resolveGapTierLabel(min, trigger);
      // Assert
      expect(label).assertEqual('黄金重排');
    });

    it('boundary: gap_resolution_tier_label_should_return_upgrade_at_ninety_minutes', 0, () => {
      // Arrange
      const min = 90;
      const trigger = 30;
      // Act
      const label = resolveGapTierLabel(min, trigger);
      // Assert
      expect(label).assertEqual('体验升级');
    });

    it('invalid: gap_resolution_tier_label_should_return_empty_for_negative_gap', 0, () => {
      // Arrange
      const min = -30;
      const trigger = 30;
      // Act
      const label = resolveGapTierLabel(min, trigger);
      // Assert
      expect(label).assertEqual('');
    });

    it('normal: gap_resolution_positive_allocation_should_detect_any_positive_value', 0, () => {
      // Arrange
      const values = [0, 15, -2];
      // Act
      const hasPositive = hasPositiveAllocationValues(values);
      // Assert
      expect(hasPositive).assertTrue();
    });

    it('boundary: gap_resolution_positive_allocation_should_return_false_for_empty_values', 0, () => {
      // Arrange
      const values: number[] = [];
      // Act
      const hasPositive = hasPositiveAllocationValues(values);
      // Assert
      expect(hasPositive).assertFalse();
    });

    it('invalid: gap_resolution_positive_allocation_should_reject_all_negative_values', 0, () => {
      // Arrange
      const values = [-1, -5, -9];
      // Act
      const hasPositive = hasPositiveAllocationValues(values);
      // Assert
      expect(hasPositive).assertFalse();
    });

    it('normal: ai_input_strategy_mode_should_keep_custom_mode_marker', 0, () => {
      // Arrange
      const mode = -1;
      // Act
      const normalized = normalizeAiStrategyMode(mode);
      // Assert
      expect(normalized).assertEqual(-1);
    });

    it('boundary: ai_input_strategy_mode_should_keep_default_mode_zero', 0, () => {
      // Arrange
      const mode = 0;
      // Act
      const normalized = normalizeAiStrategyMode(mode);
      // Assert
      expect(normalized).assertEqual(0);
    });

    it('invalid: ai_input_strategy_mode_should_fallback_for_nan', 0, () => {
      // Arrange
      const mode = Number.NaN;
      // Act
      const normalized = normalizeAiStrategyMode(mode);
      // Assert
      expect(normalized).assertEqual(0);
    });

    it('normal: ai_input_initial_prompt_should_accept_trimmed_text', 0, () => {
      // Arrange
      const prompt = '  帮我规划两天成都美食行程  ';
      // Act
      const shouldUse = shouldUseAiInitialPrompt(prompt);
      // Assert
      expect(shouldUse).assertTrue();
    });

    it('boundary: ai_input_initial_prompt_should_reject_empty_string', 0, () => {
      // Arrange
      const prompt = '';
      // Act
      const shouldUse = shouldUseAiInitialPrompt(prompt);
      // Assert
      expect(shouldUse).assertFalse();
    });

    it('invalid: ai_input_initial_prompt_should_reject_whitespace_only_text', 0, () => {
      // Arrange
      const prompt = '\n\t  ';
      // Act
      const shouldUse = shouldUseAiInitialPrompt(prompt);
      // Assert
      expect(shouldUse).assertFalse();
    });

    it('normal: ai_input_loading_text_should_use_special_mode_copy', 0, () => {
      // Arrange
      const strategy = 1;
      // Act
      const text = getAiLoadingTextByStrategy(strategy);
      // Assert
      expect(text).assertEqual('正在生成行程（预计30-60秒）');
    });

    it('boundary: ai_input_loading_text_should_use_leisure_copy', 0, () => {
      // Arrange
      const strategy = 2;
      // Act
      const text = getAiLoadingTextByStrategy(strategy);
      // Assert
      expect(text).assertEqual('正在生成行程（预计20-40秒）');
    });

    it('invalid: ai_input_loading_text_should_fallback_to_default_copy', 0, () => {
      // Arrange
      const strategy = 99;
      // Act
      const text = getAiLoadingTextByStrategy(strategy);
      // Assert
      expect(text).assertEqual('正在生成行程（预计30-50秒）');
    });

    it('normal: ai_input_keep_mode_should_return_true_for_untouched_custom_replan', 0, () => {
      // Arrange
      const currentStrategyMode = -1;
      const strategyTouched = false;
      const useCustomStrategy = false;
      // Act
      const keepCurrent = shouldKeepCurrentModeOnRegenerate(
        currentStrategyMode,
        strategyTouched,
        useCustomStrategy
      );
      // Assert
      expect(keepCurrent).assertTrue();
    });

    it('boundary: ai_input_keep_mode_should_return_false_when_strategy_was_touched', 0, () => {
      // Arrange
      const currentStrategyMode = -1;
      const strategyTouched = true;
      const useCustomStrategy = false;
      // Act
      const keepCurrent = shouldKeepCurrentModeOnRegenerate(
        currentStrategyMode,
        strategyTouched,
        useCustomStrategy
      );
      // Assert
      expect(keepCurrent).assertFalse();
    });

    it('invalid: ai_input_keep_mode_should_return_false_for_builtin_mode', 0, () => {
      // Arrange
      const currentStrategyMode = 0;
      const strategyTouched = false;
      const useCustomStrategy = false;
      // Act
      const keepCurrent = shouldKeepCurrentModeOnRegenerate(
        currentStrategyMode,
        strategyTouched,
        useCustomStrategy
      );
      // Assert
      expect(keepCurrent).assertFalse();
    });

    it('normal: conflict_selection_prompt_should_include_positive_gap', 0, () => {
      // Arrange
      const gapMinutes = 25;
      // Act
      const prompt = getConflictSelectionGapPrompt(gapMinutes);
      // Assert
      expect(prompt.indexOf('25') >= 0).assertTrue();
    });

    it('boundary: conflict_selection_prompt_should_include_zero_gap', 0, () => {
      // Arrange
      const gapMinutes = 0;
      // Act
      const prompt = getConflictSelectionGapPrompt(gapMinutes);
      // Assert
      expect(prompt.indexOf('0') >= 0).assertTrue();
    });

    it('invalid: conflict_selection_prompt_should_include_negative_gap', 0, () => {
      // Arrange
      const gapMinutes = -8;
      // Act
      const prompt = getConflictSelectionGapPrompt(gapMinutes);
      // Assert
      expect(prompt.indexOf('-8') >= 0).assertTrue();
    });

    it('normal: conflict_selection_advance_adjust_should_use_true_flag', 0, () => {
      // Arrange
      const hasAdvanceAdjust = true;
      // Act
      const useAdvance = shouldUseConflictAdvanceAdjust(hasAdvanceAdjust);
      // Assert
      expect(useAdvance).assertTrue();
    });

    it('boundary: conflict_selection_advance_adjust_should_return_false_for_false_flag', 0, () => {
      // Arrange
      const hasAdvanceAdjust = false;
      // Act
      const useAdvance = shouldUseConflictAdvanceAdjust(hasAdvanceAdjust);
      // Assert
      expect(useAdvance).assertFalse();
    });

    it('invalid: conflict_selection_advance_adjust_should_return_false_when_callback_missing', 0, () => {
      // Arrange
      const hasAdvanceAdjust = false;
      // Act
      const useAdvance = shouldUseConflictAdvanceAdjust(hasAdvanceAdjust);
      // Assert
      expect(useAdvance).assertFalse();
    });

    it('normal: conflict_compress_confirm_should_allow_positive_selection', 0, () => {
      // Arrange
      const selectedCount = 3;
      // Act
      const canConfirm = canConflictCompressConfirm(selectedCount);
      // Assert
      expect(canConfirm).assertTrue();
    });

    it('boundary: conflict_compress_confirm_should_reject_zero_selection', 0, () => {
      // Arrange
      const selectedCount = 0;
      // Act
      const canConfirm = canConflictCompressConfirm(selectedCount);
      // Assert
      expect(canConfirm).assertFalse();
    });

    it('invalid: conflict_compress_confirm_should_reject_negative_selection', 0, () => {
      // Arrange
      const selectedCount = -2;
      // Act
      const canConfirm = canConflictCompressConfirm(selectedCount);
      // Assert
      expect(canConfirm).assertFalse();
    });

    it('normal: conflict_compress_overload_should_show_when_status_and_gap_match', 0, () => {
      // Arrange
      const status = 'OVERLOAD';
      const remainingGapMinutes = 6;
      // Act
      const shouldShow = shouldShowConflictCompressOverload(status, remainingGapMinutes);
      // Assert
      expect(shouldShow).assertTrue();
    });

    it('boundary: conflict_compress_overload_should_hide_when_remaining_gap_zero', 0, () => {
      // Arrange
      const status = 'OVERLOAD';
      const remainingGapMinutes = 0;
      // Act
      const shouldShow = shouldShowConflictCompressOverload(status, remainingGapMinutes);
      // Assert
      expect(shouldShow).assertFalse();
    });

    it('invalid: conflict_compress_overload_should_hide_for_non_overload_status', 0, () => {
      // Arrange
      const status = 'READY';
      const remainingGapMinutes = 10;
      // Act
      const shouldShow = shouldShowConflictCompressOverload(status, remainingGapMinutes);
      // Assert
      expect(shouldShow).assertFalse();
    });

    it('normal: conflict_compress_preview_new_duration_should_use_matching_affected_item', 0, () => {
      // Arrange
      const affectedItems = [buildAffectedItemAY(2, 35)];
      const candidateIndex = 2;
      const candidateOldVal = 60;
      // Act
      const newDuration = resolveConflictCompressPreviewNewDuration(
        affectedItems,
        candidateIndex,
        candidateOldVal
      );
      // Assert
      expect(newDuration).assertEqual(35);
    });

    it('boundary: conflict_compress_preview_new_duration_should_fallback_to_old_value_when_not_found', 0, () => {
      // Arrange
      const affectedItems = [buildAffectedItemAY(2, 35)];
      const candidateIndex = 8;
      const candidateOldVal = 55;
      // Act
      const newDuration = resolveConflictCompressPreviewNewDuration(
        affectedItems,
        candidateIndex,
        candidateOldVal
      );
      // Assert
      expect(newDuration).assertEqual(55);
    });

    it('invalid: conflict_compress_preview_new_duration_should_use_first_match_when_duplicates_exist', 0, () => {
      // Arrange
      const affectedItems = [
        buildAffectedItemAY(4, 28),
        buildAffectedItemAY(4, 22)
      ];
      const candidateIndex = 4;
      const candidateOldVal = 50;
      // Act
      const newDuration = resolveConflictCompressPreviewNewDuration(
        affectedItems,
        candidateIndex,
        candidateOldVal
      );
      // Assert
      expect(newDuration).assertEqual(28);
    });

    it('normal: conflict_compress_preview_reduced_should_return_positive_delta', 0, () => {
      // Arrange
      const oldVal = 60;
      const newVal = 45;
      // Act
      const reduced = resolveConflictCompressPreviewReduced(oldVal, newVal);
      // Assert
      expect(reduced).assertEqual(15);
    });

    it('boundary: conflict_compress_preview_reduced_should_return_zero_when_duration_unchanged', 0, () => {
      // Arrange
      const oldVal = 30;
      const newVal = 30;
      // Act
      const reduced = resolveConflictCompressPreviewReduced(oldVal, newVal);
      // Assert
      expect(reduced).assertEqual(0);
    });

    it('invalid: conflict_compress_preview_reduced_should_support_negative_delta', 0, () => {
      // Arrange
      const oldVal = 20;
      const newVal = 32;
      // Act
      const reduced = resolveConflictCompressPreviewReduced(oldVal, newVal);
      // Assert
      expect(reduced).assertEqual(-12);
    });

    it('normal: conflict_compress_remaining_gap_should_keep_positive_value', 0, () => {
      // Arrange
      const remainingGapMinutes = 18;
      // Act
      const gap = resolveConflictCompressRemainingGap(remainingGapMinutes);
      // Assert
      expect(gap).assertEqual(18);
    });

    it('boundary: conflict_compress_remaining_gap_should_keep_zero', 0, () => {
      // Arrange
      const remainingGapMinutes = 0;
      // Act
      const gap = resolveConflictCompressRemainingGap(remainingGapMinutes);
      // Assert
      expect(gap).assertEqual(0);
    });

    it('invalid: conflict_compress_remaining_gap_should_fallback_to_zero_when_undefined', 0, () => {
      // Arrange
      const remainingGapMinutes = undefined;
      // Act
      const gap = resolveConflictCompressRemainingGap(remainingGapMinutes);
      // Assert
      expect(gap).assertEqual(0);
    });

    it('normal: add_item_mode_should_follow_existing_backlog_item', 0, () => {
      // Arrange
      const initName = '兵马俑';
      const initIsSchedule = false;
      // Act
      const mode = resolveAddItemMode(initName, initIsSchedule);
      // Assert
      expect(mode).assertEqual(0);
    });

    it('boundary: add_item_mode_should_follow_existing_schedule_item', 0, () => {
      // Arrange
      const initName = '大唐不夜城';
      const initIsSchedule = true;
      // Act
      const mode = resolveAddItemMode(initName, initIsSchedule);
      // Assert
      expect(mode).assertEqual(1);
    });

    it('invalid: add_item_mode_should_default_to_schedule_for_blank_name', 0, () => {
      // Arrange
      const initName = '   ';
      const initIsSchedule = false;
      // Act
      const mode = resolveAddItemMode(initName, initIsSchedule);
      // Assert
      expect(mode).assertEqual(1);
    });

    it('normal: add_item_duration_should_prefer_positive_initial_duration', 0, () => {
      // Arrange
      const initDuration = 90;
      const defaultDuration = 45;
      // Act
      const duration = resolveAddItemDuration(initDuration, defaultDuration);
      // Assert
      expect(duration).assertEqual(90);
    });

    it('boundary: add_item_duration_should_fallback_to_default_duration', 0, () => {
      // Arrange
      const initDuration = 0;
      const defaultDuration = 45;
      // Act
      const duration = resolveAddItemDuration(initDuration, defaultDuration);
      // Assert
      expect(duration).assertEqual(45);
    });

    it('invalid: add_item_duration_should_fallback_to_sixty_when_inputs_non_positive', 0, () => {
      // Arrange
      const initDuration = -10;
      const defaultDuration = 0;
      // Act
      const duration = resolveAddItemDuration(initDuration, defaultDuration);
      // Assert
      expect(duration).assertEqual(60);
    });

    it('normal: add_item_coordinate_should_accept_valid_inner_range', 0, () => {
      // Arrange
      const lat = 34.3416;
      const lng = 108.9398;
      // Act
      const valid = isAddItemCoordinateValid(lat, lng);
      // Assert
      expect(valid).assertTrue();
    });

    it('boundary: add_item_coordinate_should_accept_edge_world_coordinates', 0, () => {
      // Arrange
      const lat = 90;
      const lng = 180;
      // Act
      const valid = isAddItemCoordinateValid(lat, lng);
      // Assert
      expect(valid).assertTrue();
    });

    it('invalid: add_item_coordinate_should_reject_zero_pair', 0, () => {
      // Arrange
      const lat = 0;
      const lng = 0;
      // Act
      const valid = isAddItemCoordinateValid(lat, lng);
      // Assert
      expect(valid).assertFalse();
    });

    it('normal: add_item_scoped_key_should_append_positive_plan_id', 0, () => {
      // Arrange
      const base = 'tempDialogState';
      const storageScopePlanId = 12;
      // Act
      const key = resolveAddItemScopedStorageKey(base, storageScopePlanId);
      // Assert
      expect(key).assertEqual('tempDialogState_12');
    });

    it('boundary: add_item_scoped_key_should_keep_base_for_zero_scope', 0, () => {
      // Arrange
      const base = 'tempDialogState';
      const storageScopePlanId = 0;
      // Act
      const key = resolveAddItemScopedStorageKey(base, storageScopePlanId);
      // Assert
      expect(key).assertEqual('tempDialogState');
    });

    it('invalid: add_item_scoped_key_should_keep_base_for_negative_scope', 0, () => {
      // Arrange
      const base = 'tempDialogState';
      const storageScopePlanId = -3;
      // Act
      const key = resolveAddItemScopedStorageKey(base, storageScopePlanId);
      // Assert
      expect(key).assertEqual('tempDialogState');
    });

    it('normal: add_item_map_picker_should_enable_for_non_blank_key', 0, () => {
      // Arrange
      const apiKey = 'amap_key';
      // Act
      const enabled = isAddItemMapPickerEnabled(apiKey);
      // Assert
      expect(enabled).assertTrue();
    });

    it('boundary: add_item_map_picker_should_enable_after_trim', 0, () => {
      // Arrange
      const apiKey = '   amap_key   ';
      // Act
      const enabled = isAddItemMapPickerEnabled(apiKey);
      // Assert
      expect(enabled).assertTrue();
    });

    it('invalid: add_item_map_picker_should_disable_for_whitespace_only_key', 0, () => {
      // Arrange
      const apiKey = '   ';
      // Act
      const enabled = isAddItemMapPickerEnabled(apiKey);
      // Assert
      expect(enabled).assertFalse();
    });

    it('conflict: phase2_batch_ay_should_keep_gap_and_compress_threshold_rules_independent', 0, () => {
      // Arrange
      const tierColor = resolveGapTierColor(150, 30);
      const canConfirm = canConflictCompressConfirm(1);
      // Act
      const overload = shouldShowConflictCompressOverload('OVERLOAD', 5);
      // Assert
      expect(tierColor).assertEqual('#FFB800');
      expect(canConfirm).assertTrue();
      expect(overload).assertTrue();
    });

    it('regression: td-20260417-phase2-batch-ay_should_keep_custom_replan_and_sixty_minute_fallbacks', 0, () => {
      // Arrange
      const currentStrategyMode = -1;
      // Act
      const keepCurrent = shouldKeepCurrentModeOnRegenerate(currentStrategyMode, false, false);
      const duration = resolveAddItemDuration(0, 0);
      // Assert
      expect(keepCurrent).assertTrue();
      expect(duration).assertEqual(60);
    });

    it('combined: phase2_batch_ay_should_support_common_dialog_helper_paths_together', 0, () => {
      // Arrange
      const affectedItems = [buildAffectedItemAY(3, 40)];
      // Act
      const promptUsed = shouldUseAiInitialPrompt('西安两日游');
      const promptText = getConflictSelectionGapPrompt(12);
      const reduced = resolveConflictCompressPreviewReduced(
        70,
        resolveConflictCompressPreviewNewDuration(affectedItems, 3, 70)
      );
      const scopedKey = resolveAddItemScopedStorageKey('tempDialogState', 5);
      // Assert
      expect(promptUsed).assertTrue();
      expect(promptText.indexOf('12') >= 0).assertTrue();
      expect(reduced).assertEqual(30);
      expect(scopedKey).assertEqual('tempDialogState_5');
    });
  });
}
