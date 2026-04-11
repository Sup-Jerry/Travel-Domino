import { describe, it, expect } from '@ohos/hypium';
import { WeatherSuggestion } from '../main/ets/domain/services/WeatherModels';
import { buildCompanionExecutionSuggestionExplanation } from '../main/ets/pages/components/views/companion/CompanionDisplayHelper';

type ActionType = 'NONE' | 'PREPARE' | 'REORDER' | 'SHORTEN_STAY' | 'REPLACE_NODE' | 'SKIP_NODE';

function buildSuggestion(id: string, actionType: ActionType, canRollback: boolean): WeatherSuggestion {
  return {
    suggestionId: id,
    level: 'NOTICE',
    triggerType: 'RAIN',
    actionType: actionType,
    title: `title-${id}`,
    message: 'msg',
    relatedNodeIds: ['node-1'],
    createdAt: Date.now(),
    reason: `reason-${id}`,
    expectedBenefit: `benefit-${id}`,
    canRollback: canRollback,
    cooldownKey: `cool-${id}`,
    expiresAt: Date.now() + 60000
  };
}

export default function companionDisplayHelperSuggestionActionsTest() {
  describe('unit_test_case_generator_autofill_CompanionDisplayHelperSuggestionActions', () => {
    it('normal: explanation_should_differ_between_reorder_and_shorten_stay_actions', 0, () => {
      // Arrange
      const reorder = buildSuggestion('reorder', 'REORDER', true);
      const shorten = buildSuggestion('shorten', 'SHORTEN_STAY', true);

      // Act
      const reorderText = buildCompanionExecutionSuggestionExplanation(reorder);
      const shortenText = buildCompanionExecutionSuggestionExplanation(shorten);

      // Assert
      expect(reorderText.includes(reorder.title)).assertTrue();
      expect(shortenText.includes(shorten.title)).assertTrue();
      expect(reorderText === shortenText).assertFalse();
    });

    it('boundary: explanation_should_differ_between_replace_node_and_skip_node_actions', 0, () => {
      // Arrange
      const replace = buildSuggestion('replace', 'REPLACE_NODE', true);
      const skip = buildSuggestion('skip', 'SKIP_NODE', true);

      // Act
      const replaceText = buildCompanionExecutionSuggestionExplanation(replace);
      const skipText = buildCompanionExecutionSuggestionExplanation(skip);

      // Assert
      expect(replaceText.includes(replace.title)).assertTrue();
      expect(skipText.includes(skip.title)).assertTrue();
      expect(replaceText === skipText).assertFalse();
    });

    it('invalid: explanation_should_fallback_when_reason_and_benefit_are_empty', 0, () => {
      // Arrange
      const item = buildSuggestion('invalid', 'NONE', false);
      item.reason = '';
      item.expectedBenefit = '';

      // Act
      const text = buildCompanionExecutionSuggestionExplanation(item);

      // Assert
      expect(text.includes(item.title)).assertTrue();
      expect(text.length > 20).assertTrue();
      expect(text.includes('\n')).assertTrue();
    });

    it('conflict: explanation_should_reflect_rollback_capability_difference', 0, () => {
      // Arrange
      const rollback = buildSuggestion('rb-yes', 'REORDER', true);
      const noRollback = buildSuggestion('rb-no', 'REORDER', false);

      // Act
      const rollbackText = buildCompanionExecutionSuggestionExplanation(rollback);
      const noRollbackText = buildCompanionExecutionSuggestionExplanation(noRollback);

      // Assert
      expect(rollbackText.includes(rollback.title)).assertTrue();
      expect(noRollbackText.includes(noRollback.title)).assertTrue();
      expect(rollbackText === noRollbackText).assertFalse();
    });

    it('regression: prepare_and_none_actions_should_keep_default_action_mapping_behavior', 0, () => {
      // Arrange
      const prepare = buildSuggestion('prepare', 'PREPARE', true);
      const none = buildSuggestion('none', 'NONE', true);

      // Act
      const prepareText = buildCompanionExecutionSuggestionExplanation(prepare);
      const noneText = buildCompanionExecutionSuggestionExplanation(none);

      // Assert
      expect(prepareText.includes(prepare.title)).assertTrue();
      expect(noneText.includes(none.title)).assertTrue();
      expect(prepareText.length > 20).assertTrue();
      expect(noneText.length > 20).assertTrue();
    });

    it('combined: explanation_matrix_should_keep_each_action_output_non_empty_and_title_bound', 0, () => {
      // Arrange
      const actions: ActionType[] = ['NONE', 'PREPARE', 'REORDER', 'SHORTEN_STAY', 'REPLACE_NODE', 'SKIP_NODE'];
      const suggestions = actions.map((action: ActionType, index: number) => buildSuggestion(`matrix-${index}`, action, index % 2 === 0));

      // Act
      const outputs = suggestions.map((item: WeatherSuggestion) => buildCompanionExecutionSuggestionExplanation(item));

      // Assert
      expect(outputs.length).assertEqual(6);
      expect(outputs.every((text: string) => text.length > 20)).assertTrue();
      expect(outputs.every((text: string, index: number) => text.includes(suggestions[index].title))).assertTrue();
    });
  });
}
