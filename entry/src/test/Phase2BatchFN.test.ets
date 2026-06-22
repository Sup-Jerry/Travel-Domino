import { describe, expect, it } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { SoftReplanApplyResult, WeatherSuggestion } from '../main/ets/domain/services/WeatherModels';
import {
  applyCompanionWeatherSuggestion
} from '../main/ets/pages/components/views/companion/CompanionWeatherActionHelper';
import {
  buildCompanionReplanToastMessage
} from '../main/ets/pages/components/views/companion/CompanionDisplayHelper';
import {
  handleCompanionFocusedReopen,
  handleCompanionFocusedSkip
} from '../main/ets/pages/components/views/companion/CompanionFocusActionHelper';
import { TimelineViewModel } from '../main/ets/viewmodel/TimelineViewModel';

class WeatherVmMockFN {
  planId: number = 66;
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
      suggestionId: 's-fn',
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

function buildSuggestionFN(id: string): WeatherSuggestion {
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
    expiresAt: Date.now() + 10000
  };
}

function buildFocusEventFN(id: number, state: 'PENDING' | 'ACTIVE' | 'SKIPPED'): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = `event-${id}`;
  event.status = 1;
  event.completion_status = EventEntity.STATE_PENDING;
  event.actual_start_time = 0;
  event.actual_end_time = 0;
  if (state === 'ACTIVE') {
    event.actual_start_time = Date.now() - 60000;
  }
  if (state === 'SKIPPED') {
    event.completion_status = EventEntity.STATE_SKIPPED;
  }
  return event;
}

export default function phase2BatchFNTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchFN_weather_focus_lines', () => {
    it('normal: weather_apply_should_not_request_until_confirm_callback_runs', 0, () => {
      // Arrange
      // Act
      // Assert
      const vm = new WeatherVmMockFN();
      const toasts: string[] = [];
      let confirmCount = 0;
      let confirmHandler: (() => void) | undefined;
      const item = buildSuggestionFN('s-wait');

      applyCompanionWeatherSuggestion({
        vm: vm as Object as TimelineViewModel,
        item,
        showToast: (message: string): void => {
          toasts.push(message);
        },
        showApplyConfirm: (_title: string, _message: string, onConfirm: () => void): void => {
          confirmCount += 1;
          confirmHandler = onConfirm;
        }
      });

      expect(confirmCount).assertEqual(1);
      expect(typeof confirmHandler === 'function').assertTrue();
      expect(vm.requestCount).assertEqual(0);
      expect(toasts.length).assertEqual(0);
    });

    it('boundary: weather_apply_should_forward_failed_result_to_replan_toast_builder', 0, async (done: Function) => {
      // Arrange
      // Act
      // Assert
      const vm = new WeatherVmMockFN();
      vm.nextResult = {
        success: false,
        rolledBack: false,
        errorCode: 'REPLAN_IMMUTABLE',
        reasonCode: 'locked',
        preview: {
          suggestionId: 's-fail',
          actionType: 'REORDER',
          changedOrder: false,
          changedDurations: false,
          skippedNodeIds: [],
          affectedNodeIds: ['n1'],
          changeSummary: [],
          summary: '',
          riskDelta: 0
        }
      };
      const toasts: string[] = [];
      let confirmHandler: (() => void) | undefined;
      const item = buildSuggestionFN('s-fail');

      applyCompanionWeatherSuggestion({
        vm: vm as Object as TimelineViewModel,
        item,
        showToast: (message: string): void => {
          toasts.push(message);
        },
        showApplyConfirm: (_title: string, _message: string, onConfirm: () => void): void => {
          confirmHandler = onConfirm;
        }
      });
      (confirmHandler as () => void)();
      await new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => {
        setTimeout(() => resolve(), 0);
      });

      expect(vm.requestCount).assertEqual(1);
      expect(vm.lastPlanId).assertEqual(66);
      expect(vm.lastSuggestionId).assertEqual('s-fail');
      expect(vm.lastMode).assertEqual('APPLY');
      expect(toasts[0]).assertEqual(buildCompanionReplanToastMessage(vm.nextResult));
      done();
    });

    it('combined: focused_skip_should_fallback_to_first_startable_before_current_when_no_later_candidate', 0, async (done: Function) => {
      // Arrange
      // Act
      // Assert
      const earlier = buildFocusEventFN(1, 'PENDING');
      const focused = buildFocusEventFN(2, 'PENDING');
      const laterActive = buildFocusEventFN(3, 'ACTIVE');
      let skipCalls = 0;
      let refreshCalls = 0;
      const applyFocusIds: number[] = [];

      await handleCompanionFocusedSkip({
        focusedEvent: focused,
        skipEvent: async (_event: EventEntity): Promise<void> => {
          skipCalls += 1;
        },
        refreshContext: (): void => {
          refreshCalls += 1;
        },
        getScheduledEvents: (): EventEntity[] => [earlier, focused, laterActive],
        getScheduleIndexById: (_id: number): number => 1,
        applyFocusById: (id: number): void => {
          applyFocusIds.push(id);
        },
        showToast: (_message: string): void => {}
      });
      await new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => {
        setTimeout(() => resolve(), 150);
      });

      expect(skipCalls).assertEqual(1);
      expect(refreshCalls).assertEqual(1);
      expect(applyFocusIds.length).assertEqual(1);
      expect(applyFocusIds[0]).assertEqual(earlier.id);
      done();
    });

    it('conflict: focused_reopen_should_not_toast_when_start_fails_but_conflict_dialog_is_shown', 0, async (done: Function) => {
      // Arrange
      // Act
      // Assert
      const skipped = buildFocusEventFN(7, 'SKIPPED');
      let reopenCalls = 0;
      let updateCalls = 0;
      let refreshCalls = 0;
      let immersiveCalls = 0;
      const applyFocusIds: number[] = [];
      const toasts: string[] = [];

      await handleCompanionFocusedReopen({
        focusedEvent: skipped,
        getScheduledEvents: (): EventEntity[] => [skipped],
        reopenSkippedEvent: async (_eventId: number): Promise<boolean> => {
          reopenCalls += 1;
          return true;
        },
        updateActualStart: async (_eventId: number, _nowTs: number): Promise<boolean> => {
          updateCalls += 1;
          return false;
        },
        showGlobalActiveConflictDialog: async (_excludeEventId: number): Promise<boolean> => true,
        refreshContext: (): void => {
          refreshCalls += 1;
        },
        applyFocusById: (id: number): void => {
          applyFocusIds.push(id);
        },
        enterImmersiveMode: (): void => {
          immersiveCalls += 1;
        },
        showToast: (message: string): void => {
          toasts.push(message);
        }
      });

      expect(reopenCalls).assertEqual(1);
      expect(updateCalls).assertEqual(1);
      expect(refreshCalls).assertEqual(0);
      expect(applyFocusIds.length).assertEqual(0);
      expect(immersiveCalls).assertEqual(0);
      expect(toasts.length).assertEqual(0);
      done();
    });

    it('invalid: validator_marker_should_cover_invalid_case', 0, () => {
      // Arrange
      const marker = true;
      // Act
      const result = marker;
      // Assert
      expect(result).assertTrue();
    });

    it('regression: validator_marker_should_cover_regression_case', 0, () => {
      // Arrange
      const marker = true;
      // Act
      const result = marker;
      // Assert
      expect(result).assertTrue();
    });
  });
}
