import { describe, it, expect } from '@ohos/hypium';
import { SoftReplanApplyResult } from '../main/ets/domain/services/WeatherModels';
import { buildCompanionReplanToastMessage } from '../main/ets/pages/components/views/companion/CompanionDisplayHelper';

type ReplanErrorCode = '' | 'REPLAN_CONFLICT' | 'REPLAN_IMMUTABLE' | 'REPLAN_NO_CANDIDATE' | 'REPLAN_TIMEOUT' | 'REPLAN_INVALID' | 'REPLAN_BUSY';

function buildResult(success: boolean, errorCode: ReplanErrorCode, summary: string): SoftReplanApplyResult {
  return {
    success: success,
    rolledBack: errorCode === 'REPLAN_CONFLICT',
    errorCode: errorCode,
    reasonCode: '',
    preview: {
      suggestionId: 's-1',
      actionType: 'REORDER',
      changedOrder: success,
      changedDurations: false,
      skippedNodeIds: [],
      affectedNodeIds: [],
      changeSummary: [],
      summary: summary,
      riskDelta: success ? -1 : 0
    }
  };
}

export default function companionDisplayHelperToastFallbackTest() {
  describe('unit_test_case_generator_autofill_CompanionDisplayHelperToastFallback', () => {
    it('normal: success_toast_should_return_preview_summary_when_summary_is_non_empty', 0, () => {
      // Arrange
      const result = buildResult(true, '', 'summary-ok');

      // Act
      const message = buildCompanionReplanToastMessage(result);

      // Assert
      expect(message).assertEqual('summary-ok');
    });

    it('boundary: success_toast_should_fallback_when_summary_is_whitespace_only', 0, () => {
      // Arrange
      const result = buildResult(true, '', '   ');

      // Act
      const message = buildCompanionReplanToastMessage(result);

      // Assert
      expect(message.length > 0).assertTrue();
      expect(message === '   ').assertFalse();
    });

    it('invalid: invalid_error_with_empty_reason_should_use_generic_invalid_path', 0, () => {
      // Arrange
      const result = buildResult(false, 'REPLAN_INVALID', '');
      result.reasonCode = '';

      // Act
      const message = buildCompanionReplanToastMessage(result);

      // Assert
      expect(message.length > 0).assertTrue();
    });

    it('conflict: apply_failed_reason_should_take_priority_in_conflict_branch', 0, () => {
      // Arrange
      const applyFailed = buildResult(false, 'REPLAN_CONFLICT', '');
      applyFailed.reasonCode = 'apply_failed';
      applyFailed.rolledBack = false;
      const plainConflict = buildResult(false, 'REPLAN_CONFLICT', '');
      plainConflict.reasonCode = '';
      plainConflict.rolledBack = false;

      // Act
      const applyFailedMessage = buildCompanionReplanToastMessage(applyFailed);
      const plainConflictMessage = buildCompanionReplanToastMessage(plainConflict);

      // Assert
      expect(applyFailedMessage.length > 0).assertTrue();
      expect(plainConflictMessage.length > 0).assertTrue();
      expect(applyFailedMessage === plainConflictMessage).assertFalse();
    });

    it('regression: no_candidate_error_should_fallback_to_generic_failure_message', 0, () => {
      // Arrange
      const result = buildResult(false, 'REPLAN_NO_CANDIDATE', '');
      const timeout = buildResult(false, 'REPLAN_TIMEOUT', '');

      // Act
      const genericMessage = buildCompanionReplanToastMessage(result);
      const timeoutMessage = buildCompanionReplanToastMessage(timeout);

      // Assert
      expect(genericMessage.length > 0).assertTrue();
      expect(timeoutMessage.length > 0).assertTrue();
      expect(genericMessage === timeoutMessage).assertFalse();
    });

    it('combined: busy_immutable_and_timeout_should_produce_three_distinct_messages', 0, () => {
      // Arrange
      const busy = buildResult(false, 'REPLAN_BUSY', '');
      const immutable = buildResult(false, 'REPLAN_IMMUTABLE', '');
      const timeout = buildResult(false, 'REPLAN_TIMEOUT', '');

      // Act
      const busyMessage = buildCompanionReplanToastMessage(busy);
      const immutableMessage = buildCompanionReplanToastMessage(immutable);
      const timeoutMessage = buildCompanionReplanToastMessage(timeout);

      // Assert
      expect(busyMessage.length > 0).assertTrue();
      expect(immutableMessage.length > 0).assertTrue();
      expect(timeoutMessage.length > 0).assertTrue();
      expect(busyMessage === immutableMessage).assertFalse();
      expect(busyMessage === timeoutMessage).assertFalse();
      expect(immutableMessage === timeoutMessage).assertFalse();
    });
  });
}
