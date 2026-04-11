import { describe, it, expect } from '@ohos/hypium';
import { SoftReplanApplyResult } from '../main/ets/domain/services/WeatherModels';
import { buildCompanionReplanToastMessage } from '../main/ets/pages/components/views/companion/CompanionDisplayHelper';

type ReplanErrorCode = '' | 'REPLAN_CONFLICT' | 'REPLAN_IMMUTABLE' | 'REPLAN_NO_CANDIDATE' | 'REPLAN_TIMEOUT' | 'REPLAN_INVALID' | 'REPLAN_BUSY';

function buildResult(success: boolean, errorCode: ReplanErrorCode, rolledBack: boolean, summary: string): SoftReplanApplyResult {
  return {
    success: success,
    rolledBack: rolledBack,
    errorCode: errorCode,
    reasonCode: '',
    preview: {
      suggestionId: 's-1',
      actionType: 'REORDER',
      changedOrder: success,
      changedDurations: false,
      skippedNodeIds: [],
      affectedNodeIds: ['n1'],
      changeSummary: [],
      summary: summary,
      riskDelta: success ? -1 : 0
    }
  };
}

export default function companionDisplayHelperErrorCodesTest() {
  describe('unit_test_case_generator_autofill_CompanionDisplayHelperErrorCodes', () => {
    it('normal: busy_error_should_map_to_non_empty_stable_message', 0, () => {
      // Arrange
      const withReason = buildResult(false, 'REPLAN_BUSY', false, '');
      withReason.reasonCode = 'any';
      const noReason = buildResult(false, 'REPLAN_BUSY', false, '');

      // Act
      const withReasonText = buildCompanionReplanToastMessage(withReason);
      const noReasonText = buildCompanionReplanToastMessage(noReason);

      // Assert
      expect(withReasonText.length > 0).assertTrue();
      expect(noReasonText.length > 0).assertTrue();
      expect(withReasonText).assertEqual(noReasonText);
    });

    it('boundary: immutable_error_should_not_depend_on_preview_summary', 0, () => {
      // Arrange
      const withSummary = buildResult(false, 'REPLAN_IMMUTABLE', false, 'should-not-use');
      const withoutSummary = buildResult(false, 'REPLAN_IMMUTABLE', false, '');

      // Act
      const withSummaryText = buildCompanionReplanToastMessage(withSummary);
      const withoutSummaryText = buildCompanionReplanToastMessage(withoutSummary);

      // Assert
      expect(withSummaryText.length > 0).assertTrue();
      expect(withSummaryText).assertEqual(withoutSummaryText);
    });

    it('invalid: timeout_error_should_map_to_specific_message_instead_of_generic_fallback', 0, () => {
      // Arrange
      const timeoutResult = buildResult(false, 'REPLAN_TIMEOUT', false, '');
      const genericResult = buildResult(false, 'REPLAN_NO_CANDIDATE', false, '');

      // Act
      const timeoutText = buildCompanionReplanToastMessage(timeoutResult);
      const genericText = buildCompanionReplanToastMessage(genericResult);

      // Assert
      expect(timeoutText.length > 0).assertTrue();
      expect(genericText.length > 0).assertTrue();
      expect(timeoutText === genericText).assertFalse();
    });

    it('conflict: conflict_error_should_differentiate_rolled_back_and_not_rolled_back', 0, () => {
      // Arrange
      const rolledBack = buildResult(false, 'REPLAN_CONFLICT', true, '');
      const notRolledBack = buildResult(false, 'REPLAN_CONFLICT', false, '');

      // Act
      const rolledBackText = buildCompanionReplanToastMessage(rolledBack);
      const notRolledBackText = buildCompanionReplanToastMessage(notRolledBack);

      // Assert
      expect(rolledBackText.length > 0).assertTrue();
      expect(notRolledBackText.length > 0).assertTrue();
      expect(rolledBackText === notRolledBackText).assertFalse();
    });

    it('regression: invalid_error_should_differentiate_reason_code_variants', 0, () => {
      // Arrange
      const statusBlocked = buildResult(false, 'REPLAN_INVALID', false, '');
      statusBlocked.reasonCode = 'status_blocked';
      const suggestionMissing = buildResult(false, 'REPLAN_INVALID', false, '');
      suggestionMissing.reasonCode = 'suggestion_missing';
      const genericInvalid = buildResult(false, 'REPLAN_INVALID', false, '');
      genericInvalid.reasonCode = '';

      // Act
      const statusBlockedText = buildCompanionReplanToastMessage(statusBlocked);
      const suggestionMissingText = buildCompanionReplanToastMessage(suggestionMissing);
      const genericInvalidText = buildCompanionReplanToastMessage(genericInvalid);

      // Assert
      expect(statusBlockedText.length > 0).assertTrue();
      expect(suggestionMissingText.length > 0).assertTrue();
      expect(genericInvalidText.length > 0).assertTrue();
      expect(statusBlockedText === suggestionMissingText).assertFalse();
      expect(statusBlockedText === genericInvalidText).assertFalse();
      expect(suggestionMissingText === genericInvalidText).assertFalse();
    });

    it('combined: success_summary_and_unknown_error_should_follow_success_and_fallback_paths', 0, () => {
      // Arrange
      const successWithSummary = buildResult(true, '', false, 'summary-ok');
      const unknownError = buildResult(false, 'REPLAN_NO_CANDIDATE', false, '');

      // Act
      const successText = buildCompanionReplanToastMessage(successWithSummary);
      const unknownErrorText = buildCompanionReplanToastMessage(unknownError);

      // Assert
      expect(successText).assertEqual('summary-ok');
      expect(unknownErrorText.length > 0).assertTrue();
      expect(successText === unknownErrorText).assertFalse();
    });
  });
}
