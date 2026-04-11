import { describe, it, expect } from '@ohos/hypium';
import { SoftReplanApplyResult, WeatherSuggestion } from '../main/ets/domain/services/WeatherModels';
import {
  applyCompanionWeatherSuggestion,
  getCompanionDismissSuggestionToast,
  getCompanionWeatherGuidePopupText,
  getCompanionWeatherSuggestionDetailText
} from '../main/ets/pages/components/views/companion/CompanionWeatherActionHelper';
import {
  buildCompanionExecutionSuggestionExplanation,
  buildCompanionReplanToastMessage
} from '../main/ets/pages/components/views/companion/CompanionDisplayHelper';
import { TimelineViewModel } from '../main/ets/viewmodel/TimelineViewModel';

type ReplanErrorCode = '' | 'REPLAN_CONFLICT' | 'REPLAN_IMMUTABLE' | 'REPLAN_NO_CANDIDATE' | 'REPLAN_TIMEOUT' | 'REPLAN_INVALID' | 'REPLAN_BUSY';

class CompanionWeatherVmMock {
  planId: number = 88;
  executionWeatherApplying: boolean = false;
  requestCount: number = 0;
  lastPlanId: number = -1;
  lastSuggestionId: string = '';
  lastMode: string = '';
  shouldReject: boolean = false;
  nextResult: SoftReplanApplyResult = {
    success: true,
    rolledBack: false,
    errorCode: '',
    preview: {
      suggestionId: 's-1',
      actionType: 'REORDER',
      changedOrder: true,
      changedDurations: false,
      skippedNodeIds: [],
      affectedNodeIds: ['n1'],
      changeSummary: [],
      summary: 'summary-ok',
      riskDelta: -1
    }
  };

  async requestSoftReplan(planId: number, suggestionId: string, mode: string): Promise<SoftReplanApplyResult> {
    this.requestCount += 1;
    this.lastPlanId = planId;
    this.lastSuggestionId = suggestionId;
    this.lastMode = mode;
    if (this.shouldReject) {
      throw new Error('apply_failed');
    }
    return this.nextResult;
  }
}

function buildSuggestion(id: string): WeatherSuggestion {
  return {
    suggestionId: id,
    level: 'NOTICE',
    triggerType: 'RAIN',
    actionType: 'REORDER',
    title: `title-${id}`,
    message: 'msg',
    relatedNodeIds: ['node-1'],
    createdAt: Date.now(),
    reason: 'reason',
    expectedBenefit: 'benefit',
    canRollback: true,
    cooldownKey: 'cooldown',
    expiresAt: Date.now() + 60000
  };
}

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
      riskDelta: success ? -2 : 0
    }
  };
}

export default function companionWeatherActionHelperTest() {
  describe('unit_test_case_generator_autofill_CompanionWeatherActionHelper', () => {
    it('normal: apply_suggestion_should_request_replan_after_confirm_and_show_success_toast', 0, async (done: Function) => {
      // Arrange
      const vm = new CompanionWeatherVmMock();
      vm.nextResult = buildResult(true, '', false, 'apply-ok');
      const toasts: string[] = [];
      let capturedConfirm: (() => void) | undefined;
      let confirmCount = 0;
      const item = buildSuggestion('s-normal');

      // Act
      applyCompanionWeatherSuggestion({
        vm: vm as Object as TimelineViewModel,
        item: item,
        showToast: (message: string): void => {
          toasts.push(message);
        },
        showApplyConfirm: (_title: string, _message: string, onConfirm: () => void): void => {
          confirmCount += 1;
          capturedConfirm = onConfirm;
        }
      });
      (capturedConfirm as () => void)();
      await new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => {
        setTimeout(() => resolve(), 0);
      });

      // Assert
      expect(confirmCount).assertEqual(1);
      expect(vm.requestCount).assertEqual(1);
      expect(vm.lastPlanId).assertEqual(88);
      expect(vm.lastSuggestionId).assertEqual('s-normal');
      expect(vm.lastMode).assertEqual('APPLY');
      expect(toasts[0]).assertEqual(buildCompanionReplanToastMessage(vm.nextResult));
      done();
    });

    it('boundary: apply_suggestion_should_block_when_replan_is_busy', 0, () => {
      // Arrange
      const vm = new CompanionWeatherVmMock();
      vm.executionWeatherApplying = true;
      const toasts: string[] = [];
      let confirmCount = 0;
      const item = buildSuggestion('s-busy');

      // Act
      applyCompanionWeatherSuggestion({
        vm: vm as Object as TimelineViewModel,
        item: item,
        showToast: (message: string): void => {
          toasts.push(message);
        },
        showApplyConfirm: (_title: string, _message: string, _onConfirm: () => void): void => {
          confirmCount += 1;
        }
      });

      // Assert
      expect(confirmCount).assertEqual(0);
      expect(vm.requestCount).assertEqual(0);
      expect(toasts.length).assertEqual(1);
    });

    it('invalid: apply_suggestion_should_show_failure_toast_when_request_throws', 0, async (done: Function) => {
      // Arrange
      const vm = new CompanionWeatherVmMock();
      vm.shouldReject = true;
      const toasts: string[] = [];
      let capturedConfirm: (() => void) | undefined;
      const item = buildSuggestion('s-throw');

      // Act
      applyCompanionWeatherSuggestion({
        vm: vm as Object as TimelineViewModel,
        item: item,
        showToast: (message: string): void => {
          toasts.push(message);
        },
        showApplyConfirm: (_title: string, _message: string, onConfirm: () => void): void => {
          capturedConfirm = onConfirm;
        }
      });
      (capturedConfirm as () => void)();
      await new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => {
        setTimeout(() => resolve(), 0);
      });

      // Assert
      expect(vm.requestCount).assertEqual(1);
      expect(toasts.length).assertEqual(1);
      expect(toasts[0].length > 0).assertTrue();
      done();
    });

    it('conflict: apply_suggestion_should_use_conflict_message_when_replan_conflicts', 0, async (done: Function) => {
      // Arrange
      const vm = new CompanionWeatherVmMock();
      vm.nextResult = buildResult(false, 'REPLAN_CONFLICT', true, '');
      vm.nextResult.reasonCode = 'apply_failed';
      const toasts: string[] = [];
      let capturedConfirm: (() => void) | undefined;
      const item = buildSuggestion('s-conflict');

      // Act
      applyCompanionWeatherSuggestion({
        vm: vm as Object as TimelineViewModel,
        item: item,
        showToast: (message: string): void => {
          toasts.push(message);
        },
        showApplyConfirm: (_title: string, _message: string, onConfirm: () => void): void => {
          capturedConfirm = onConfirm;
        }
      });
      (capturedConfirm as () => void)();
      await new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => {
        setTimeout(() => resolve(), 0);
      });

      // Assert
      expect(toasts[0]).assertEqual(buildCompanionReplanToastMessage(vm.nextResult));
      done();
    });

    it('regression: suggestion_detail_text_should_delegate_to_display_helper_builder', 0, () => {
      // Arrange
      const item = buildSuggestion('s-detail');

      // Act
      const actual = getCompanionWeatherSuggestionDetailText(item);
      const expected = buildCompanionExecutionSuggestionExplanation(item);

      // Assert
      expect(actual).assertEqual(expected);
    });

    it('combined: guide_and_dismiss_texts_should_be_non_empty_and_mode_specific', 0, () => {
      // Arrange
      const guideText = getCompanionWeatherGuidePopupText();

      // Act
      const laterToast = getCompanionDismissSuggestionToast('later');
      const ignoreToast = getCompanionDismissSuggestionToast('ignore');

      // Assert
      expect(guideText.length > 20).assertTrue();
      expect(guideText.includes('\n')).assertTrue();
      expect(laterToast.length > 0).assertTrue();
      expect(ignoreToast.length > 0).assertTrue();
      expect(laterToast === ignoreToast).assertFalse();
    });
  });
}
