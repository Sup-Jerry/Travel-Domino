import { describe, it, expect } from '@ohos/hypium';
import { TimelineViewModel } from '../main/ets/viewmodel/TimelineViewModel';
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

class CompanionWeatherVmConfirmMock {
  planId: number = 99;
  executionWeatherApplying: boolean = false;
  requestCount: number = 0;
  lastPlanId: number = -1;
  lastSuggestionId: string = '';
  lastMode: string = '';
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
      summary: 'ok',
      riskDelta: -1
    }
  };

  async requestSoftReplan(planId: number, suggestionId: string, mode: string): Promise<SoftReplanApplyResult> {
    this.requestCount += 1;
    this.lastPlanId = planId;
    this.lastSuggestionId = suggestionId;
    this.lastMode = mode;
    return this.nextResult;
  }
}

function buildSuggestion(id: string, actionType: 'REORDER' | 'SHORTEN_STAY'): WeatherSuggestion {
  return {
    suggestionId: id,
    level: 'NOTICE',
    triggerType: 'RAIN',
    actionType: actionType,
    title: `title-${id}`,
    message: 'msg',
    relatedNodeIds: ['node-1'],
    createdAt: Date.now(),
    reason: 'reason',
    expectedBenefit: 'benefit',
    canRollback: true,
    cooldownKey: `cool-${id}`,
    expiresAt: Date.now() + 60000
  };
}

export default function companionWeatherActionHelperConfirmTest() {
  describe('unit_test_case_generator_autofill_CompanionWeatherActionHelperConfirm', () => {
    it('normal: apply_should_emit_confirm_message_with_suggestion_title_and_action_type', 0, () => {
      // Arrange
      const vm = new CompanionWeatherVmConfirmMock();
      const item = buildSuggestion('normal', 'REORDER');
      let confirmTitle = '';
      let confirmMessage = '';

      // Act
      applyCompanionWeatherSuggestion({
        vm: vm as Object as TimelineViewModel,
        item: item,
        showToast: (_message: string): void => {},
        showApplyConfirm: (title: string, message: string, _onConfirm: () => void): void => {
          confirmTitle = title;
          confirmMessage = message;
        }
      });

      // Assert
      expect(confirmTitle.length > 0).assertTrue();
      expect(confirmMessage.includes(item.title)).assertTrue();
      expect(confirmMessage.includes(item.actionType)).assertTrue();
    });

    it('boundary: apply_should_not_request_replan_before_user_confirms', 0, () => {
      // Arrange
      const vm = new CompanionWeatherVmConfirmMock();
      const item = buildSuggestion('boundary', 'REORDER');

      // Act
      applyCompanionWeatherSuggestion({
        vm: vm as Object as TimelineViewModel,
        item: item,
        showToast: (_message: string): void => {},
        showApplyConfirm: (_title: string, _message: string, _onConfirm: () => void): void => {}
      });

      // Assert
      expect(vm.requestCount).assertEqual(0);
    });

    it('invalid: apply_should_map_failure_result_to_replan_toast_message_after_confirm', 0, async (done: Function) => {
      // Arrange
      const vm = new CompanionWeatherVmConfirmMock();
      vm.nextResult = {
        success: false,
        rolledBack: false,
        errorCode: 'REPLAN_INVALID',
        reasonCode: 'status_blocked',
        preview: {
          suggestionId: 's-1',
          actionType: 'REORDER',
          changedOrder: false,
          changedDurations: false,
          skippedNodeIds: [],
          affectedNodeIds: [],
          changeSummary: [],
          summary: '',
          riskDelta: 0
        }
      };
      const item = buildSuggestion('invalid', 'REORDER');
      const toasts: string[] = [];
      let onConfirm: (() => void) | undefined;

      // Act
      applyCompanionWeatherSuggestion({
        vm: vm as Object as TimelineViewModel,
        item: item,
        showToast: (message: string): void => {
          toasts.push(message);
        },
        showApplyConfirm: (_title: string, _message: string, confirm: () => void): void => {
          onConfirm = confirm;
        }
      });
      if (onConfirm) {
        onConfirm();
      }
      await new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => {
        setTimeout(() => resolve(), 0);
      });

      // Assert
      expect(toasts.length).assertEqual(1);
      expect(toasts[0]).assertEqual(buildCompanionReplanToastMessage(vm.nextResult));
      done();
    });

    it('conflict: apply_should_block_confirm_when_execution_is_busy', 0, () => {
      // Arrange
      const vm = new CompanionWeatherVmConfirmMock();
      vm.executionWeatherApplying = true;
      const item = buildSuggestion('conflict', 'REORDER');
      let confirmCount = 0;
      const toasts: string[] = [];

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

    it('regression: confirmed_apply_should_keep_plan_id_suggestion_id_and_mode_consistent', 0, async (done: Function) => {
      // Arrange
      const vm = new CompanionWeatherVmConfirmMock();
      const item = buildSuggestion('regression', 'SHORTEN_STAY');
      let onConfirm: (() => void) | undefined;

      // Act
      applyCompanionWeatherSuggestion({
        vm: vm as Object as TimelineViewModel,
        item: item,
        showToast: (_message: string): void => {},
        showApplyConfirm: (_title: string, _message: string, confirm: () => void): void => {
          onConfirm = confirm;
        }
      });
      if (onConfirm) {
        onConfirm();
      }
      await new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => {
        setTimeout(() => resolve(), 0);
      });

      // Assert
      expect(vm.requestCount).assertEqual(1);
      expect(vm.lastPlanId).assertEqual(99);
      expect(vm.lastSuggestionId).assertEqual(item.suggestionId);
      expect(vm.lastMode).assertEqual('APPLY');
      done();
    });

    it('combined: guide_detail_and_dismiss_texts_should_remain_non_empty_and_delegated', 0, () => {
      // Arrange
      const item = buildSuggestion('combined', 'REORDER');

      // Act
      const guideText = getCompanionWeatherGuidePopupText();
      const detailText = getCompanionWeatherSuggestionDetailText(item);
      const expectedDetailText = buildCompanionExecutionSuggestionExplanation(item);
      const laterToast = getCompanionDismissSuggestionToast('later');
      const ignoreToast = getCompanionDismissSuggestionToast('ignore');

      // Assert
      expect(guideText.length > 20).assertTrue();
      expect(detailText).assertEqual(expectedDetailText);
      expect(laterToast.length > 0).assertTrue();
      expect(ignoreToast.length > 0).assertTrue();
      expect(laterToast === ignoreToast).assertFalse();
    });
  });
}
