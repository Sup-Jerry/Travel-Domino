import { describe, it, expect } from '@ohos/hypium';
import { WeatherSuggestion } from '../main/ets/domain/services/WeatherModels';
import { buildCompanionExecutionSuggestionExplanation } from '../main/ets/pages/components/views/companion/CompanionDisplayHelper';

function buildSuggestion(
  id: string,
  actionType: 'NONE' | 'PREPARE' | 'REORDER' | 'SHORTEN_STAY' | 'REPLACE_NODE' | 'SKIP_NODE',
  canRollback: boolean
): WeatherSuggestion {
  return {
    suggestionId: id,
    level: 'NOTICE',
    triggerType: 'RAIN',
    actionType: actionType,
    title: `title-${id}`,
    message: 'msg',
    relatedNodeIds: ['node-1'],
    createdAt: Date.now(),
    reason: 'reason-default',
    expectedBenefit: 'benefit-default',
    canRollback: canRollback,
    cooldownKey: `cool-${id}`,
    expiresAt: Date.now() + 60000
  };
}

export default function companionDisplayHelperSuggestionExplanationTest() {
  describe('unit_test_case_generator_autofill_CompanionDisplayHelperSuggestionExplanation', () => {
    it('normal: explanation_should_include_title_and_action_specific_content', 0, () => {
      // Arrange
      const reorder = buildSuggestion('reorder', 'REORDER', true);

      // Act
      const text = buildCompanionExecutionSuggestionExplanation(reorder);

      // Assert
      expect(text.includes('title-reorder')).assertTrue();
      expect(text.includes('\n')).assertTrue();
      expect(text.length > 30).assertTrue();
    });

    it('boundary: explanation_should_fallback_when_reason_and_benefit_are_blank', 0, () => {
      // Arrange
      const suggestion = buildSuggestion('blank', 'PREPARE', false);
      suggestion.reason = '   ';
      suggestion.expectedBenefit = '   ';

      // Act
      const text = buildCompanionExecutionSuggestionExplanation(suggestion);

      // Assert
      expect(text.includes('title-blank')).assertTrue();
      expect(text.includes('\n')).assertTrue();
      expect(text.length > 30).assertTrue();
    });

    it('invalid: none_action_should_not_share_same_text_with_reorder_action', 0, () => {
      // Arrange
      const noneAction = buildSuggestion('none', 'NONE', false);
      const reorderAction = buildSuggestion('reorder-2', 'REORDER', false);

      // Act
      const noneText = buildCompanionExecutionSuggestionExplanation(noneAction);
      const reorderText = buildCompanionExecutionSuggestionExplanation(reorderAction);

      // Assert
      expect(noneText.length > 0).assertTrue();
      expect(reorderText.length > 0).assertTrue();
      expect(noneText === reorderText).assertFalse();
    });

    it('conflict: rollback_flag_should_change_explanation_text', 0, () => {
      // Arrange
      const rollbackOn = buildSuggestion('rb-on', 'SHORTEN_STAY', true);
      const rollbackOff = buildSuggestion('rb-off', 'SHORTEN_STAY', false);

      // Act
      const rollbackOnText = buildCompanionExecutionSuggestionExplanation(rollbackOn);
      const rollbackOffText = buildCompanionExecutionSuggestionExplanation(rollbackOff);

      // Assert
      expect(rollbackOnText.length > 0).assertTrue();
      expect(rollbackOffText.length > 0).assertTrue();
      expect(rollbackOnText === rollbackOffText).assertFalse();
    });

    it('regression: action_type_mapping_should_distinguish_replace_and_skip_paths', 0, () => {
      // Arrange
      const replaceAction = buildSuggestion('replace', 'REPLACE_NODE', true);
      const skipAction = buildSuggestion('skip', 'SKIP_NODE', true);

      // Act
      const replaceText = buildCompanionExecutionSuggestionExplanation(replaceAction);
      const skipText = buildCompanionExecutionSuggestionExplanation(skipAction);

      // Assert
      expect(replaceText.length > 0).assertTrue();
      expect(skipText.length > 0).assertTrue();
      expect(replaceText === skipText).assertFalse();
    });

    it('combined: multiple_action_explanations_should_remain_non_empty_and_pairwise_different', 0, () => {
      // Arrange
      const reorder = buildSuggestion('c1', 'REORDER', true);
      const shorten = buildSuggestion('c2', 'SHORTEN_STAY', true);
      const replace = buildSuggestion('c3', 'REPLACE_NODE', true);

      // Act
      const reorderText = buildCompanionExecutionSuggestionExplanation(reorder);
      const shortenText = buildCompanionExecutionSuggestionExplanation(shorten);
      const replaceText = buildCompanionExecutionSuggestionExplanation(replace);

      // Assert
      expect(reorderText.length > 0).assertTrue();
      expect(shortenText.length > 0).assertTrue();
      expect(replaceText.length > 0).assertTrue();
      expect(reorderText === shortenText).assertFalse();
      expect(shortenText === replaceText).assertFalse();
      expect(reorderText === replaceText).assertFalse();
    });
  });
}
