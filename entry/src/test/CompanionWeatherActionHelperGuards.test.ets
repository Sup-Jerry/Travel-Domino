import { describe, it, expect } from '@ohos/hypium';
import { TimelineViewModel } from '../main/ets/viewmodel/TimelineViewModel';
import { SoftReplanApplyResult, WeatherSuggestion } from '../main/ets/domain/services/WeatherModels';
import {
  applyCompanionWeatherSuggestion,
  getCompanionDismissSuggestionToast
} from '../main/ets/pages/components/views/companion/CompanionWeatherActionHelper';

class CompanionWeatherGuardVmMock {
  planId: number = 1;
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
    cooldownKey: `cool-${id}`,
    expiresAt: Date.now() + 60000
  };
}

export default function companionWeatherActionHelperGuardsTest() {
  describe('unit_test_case_generator_autofill_CompanionWeatherActionHelperGuards', () => {
    it('normal: apply_should_forward_current_plan_and_suggestion_after_confirm', 0, async (done: Function) => {
      // Arrange
      const vm = new CompanionWeatherGuardVmMock();
      vm.planId = 42;
      const item = buildSuggestion('normal');
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
      (onConfirm as () => void)();
      await new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => setTimeout(() => resolve(), 0));

      // Assert
      expect(vm.requestCount).assertEqual(1);
      expect(vm.lastPlanId).assertEqual(42);
      expect(vm.lastSuggestionId).assertEqual('normal');
      done();
    });

    it('boundary: apply_should_still_attempt_request_when_plan_id_is_zero', 0, async (done: Function) => {
      // Arrange
      const vm = new CompanionWeatherGuardVmMock();
      vm.planId = 0;
      const item = buildSuggestion('boundary');
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
      (onConfirm as () => void)();
      await new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => setTimeout(() => resolve(), 0));

      // Assert
      expect(vm.requestCount).assertEqual(1);
      expect(vm.lastPlanId).assertEqual(0);
      done();
    });

    it('invalid: apply_should_still_forward_empty_suggestion_id_to_vm_request', 0, async (done: Function) => {
      // Arrange
      const vm = new CompanionWeatherGuardVmMock();
      const item = buildSuggestion('invalid');
      item.suggestionId = '';
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
      (onConfirm as () => void)();
      await new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => setTimeout(() => resolve(), 0));

      // Assert
      expect(vm.requestCount).assertEqual(1);
      expect(vm.lastSuggestionId).assertEqual('');
      done();
    });

    it('conflict: busy_state_should_block_confirm_dialog_and_request', 0, () => {
      // Arrange
      const vm = new CompanionWeatherGuardVmMock();
      vm.executionWeatherApplying = true;
      const item = buildSuggestion('conflict');
      let confirmCount = 0;
      const toasts: string[] = [];

      // Act
      applyCompanionWeatherSuggestion({
        vm: vm as Object as TimelineViewModel,
        item: item,
        showToast: (message: string): void => {
          toasts.push(message);
        },
        showApplyConfirm: (_title: string, _message: string, _confirm: () => void): void => {
          confirmCount += 1;
        }
      });

      // Assert
      expect(confirmCount).assertEqual(0);
      expect(vm.requestCount).assertEqual(0);
      expect(toasts.length).assertEqual(1);
    });

    it('regression: dismiss_toast_should_fallback_to_ignore_branch_for_unknown_mode_cast', 0, () => {
      // Arrange
      const unknownMode = 'unexpected' as 'later' | 'ignore';

      // Act
      const unknownText = getCompanionDismissSuggestionToast(unknownMode);
      const ignoreText = getCompanionDismissSuggestionToast('ignore');

      // Assert
      expect(unknownText).assertEqual(ignoreText);
    });

    it('combined: two_confirmed_apply_calls_should_keep_latest_request_arguments', 0, async (done: Function) => {
      // Arrange
      const vm = new CompanionWeatherGuardVmMock();
      const first = buildSuggestion('first');
      const second = buildSuggestion('second');
      const confirms: Array<() => void> = [];

      // Act
      applyCompanionWeatherSuggestion({
        vm: vm as Object as TimelineViewModel,
        item: first,
        showToast: (_message: string): void => {},
        showApplyConfirm: (_title: string, _message: string, confirm: () => void): void => {
          confirms.push(confirm);
        }
      });
      applyCompanionWeatherSuggestion({
        vm: vm as Object as TimelineViewModel,
        item: second,
        showToast: (_message: string): void => {},
        showApplyConfirm: (_title: string, _message: string, confirm: () => void): void => {
          confirms.push(confirm);
        }
      });
      confirms[0]();
      confirms[1]();
      await new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => setTimeout(() => resolve(), 0));

      // Assert
      expect(vm.requestCount).assertEqual(2);
      expect(vm.lastSuggestionId).assertEqual('second');
      expect(vm.lastMode).assertEqual('APPLY');
      done();
    });
  });
}
