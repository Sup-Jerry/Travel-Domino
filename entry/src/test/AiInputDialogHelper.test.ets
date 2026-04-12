import { describe, it, expect } from '@ohos/hypium';
import {
  getAiLoadingTextByStrategy,
  normalizeAiStrategyMode,
  shouldKeepCurrentModeOnRegenerate,
  shouldUseAiInitialPrompt
} from '../main/ets/pages/components/dialogs/AiInputDialog';

export default function aiInputDialogHelperTest() {
  describe('unit_test_case_generator_autofill_AiInputDialogHelper', () => {
    it('normal: ai_input_strategy_mode_should_keep_valid_builtin_mode', 0, () => {
      // Arrange
      const mode = 2;
      // Act
      const normalized = normalizeAiStrategyMode(mode);
      // Assert
      expect(normalized).assertEqual(2);
    });

    it('boundary: ai_input_prompt_should_reject_blank_text', 0, () => {
      // Arrange
      const prompt = '   ';
      // Act
      const shouldUse = shouldUseAiInitialPrompt(prompt);
      // Assert
      expect(shouldUse).assertFalse();
    });

    it('invalid: ai_input_strategy_mode_should_fallback_when_out_of_range', 0, () => {
      // Arrange
      const mode = 99;
      // Act
      const normalized = normalizeAiStrategyMode(mode);
      // Assert
      expect(normalized).assertEqual(0);
    });

    it('conflict: ai_input_keep_mode_should_require_untouched_custom_state', 0, () => {
      // Arrange
      const currentStrategyMode = -1;
      const strategyTouched = true;
      const useCustomStrategy = false;
      // Act
      const keep = shouldKeepCurrentModeOnRegenerate(currentStrategyMode, strategyTouched, useCustomStrategy);
      // Assert
      expect(keep).assertFalse();
    });

    it('regression: td-20260412-ai-input-loading-text-for-special-mode-should-stay-stable', 0, () => {
      // Arrange
      const strategy = 1;
      // Act
      const text = getAiLoadingTextByStrategy(strategy);
      // Assert
      expect(text).assertEqual('正在生成行程（预计30-60秒）');
    });

    it('combined: ai_input_custom_mode_should_keep_and_use_prompt_together', 0, () => {
      // Arrange
      const prompt = '帮我做三天西安亲子行程';
      // Act
      const shouldUsePrompt = shouldUseAiInitialPrompt(prompt);
      const keepMode = shouldKeepCurrentModeOnRegenerate(-1, false, false);
      // Assert
      expect(shouldUsePrompt).assertTrue();
      expect(keepMode).assertTrue();
    });
  });
}
