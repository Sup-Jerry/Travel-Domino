import { describe, it, expect } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { TimelineViewModel } from '../main/ets/viewmodel/TimelineViewModel';
import { SoftReplanApplyResult, WeatherSuggestion } from '../main/ets/domain/services/WeatherModels';
import {
  formatEventItemCommuteTime,
  resolveEventItemConflictGapMinutes
} from '../main/ets/pages/components/views/EventItemView';
import {
  isCompanionOverlayVisible,
  resolveCompanionBackLevel
} from '../main/ets/pages/components/views/CompanionView';
import {
  resolvePlanItemTimeText,
  shouldPlanItemShowCrossDayLabel
} from '../main/ets/pages/components/views/PlanItemView';
import {
  getBacklogBadgeText,
  shouldShowBacklogEmptyState
} from '../main/ets/pages/components/views/BacklogView';
import {
  handleCompanionFocusedReopen,
  handleCompanionFocusedSkip
} from '../main/ets/pages/components/views/companion/CompanionFocusActionHelper';
import {
  applyCompanionWeatherSuggestion,
  getCompanionDismissSuggestionToast,
  getCompanionWeatherGuidePopupText
} from '../main/ets/pages/components/views/companion/CompanionWeatherActionHelper';

function buildCompanionEventBK(id: number, state: 'PENDING' | 'ACTIVE' | 'SKIPPED'): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = `bk-event-${id}`;
  event.status = 1;
  event.completion_status = EventEntity.STATE_PENDING;
  event.actual_start_time = 0;
  event.actual_end_time = 0;
  if (state === 'ACTIVE') {
    event.actual_start_time = Date.now() - 1000;
  }
  if (state === 'SKIPPED') {
    event.completion_status = EventEntity.STATE_SKIPPED;
  }
  return event;
}

class CompanionWeatherVmBkMock {
  planId: number = 7;
  executionWeatherApplying: boolean = false;
  requestCount: number = 0;
  shouldReject: boolean = false;
  lastSuggestionId: string = '';
  nextResult: SoftReplanApplyResult = {
    success: true,
    rolledBack: false,
    errorCode: '',
    preview: {
      suggestionId: 'bk',
      actionType: 'REORDER',
      changedOrder: true,
      changedDurations: false,
      skippedNodeIds: [],
      affectedNodeIds: [],
      changeSummary: [],
      summary: 'ok',
      riskDelta: -1
    }
  };

  async requestSoftReplan(_planId: number, suggestionId: string, _mode: string): Promise<SoftReplanApplyResult> {
    this.requestCount += 1;
    this.lastSuggestionId = suggestionId;
    if (this.shouldReject) {
      throw new Error('bk_replan_error');
    }
    return this.nextResult;
  }
}

function buildWeatherSuggestionBK(id: string): WeatherSuggestion {
  return {
    suggestionId: id,
    level: 'NOTICE',
    triggerType: 'RAIN',
    actionType: 'REORDER',
    title: `title-${id}`,
    message: `message-${id}`,
    relatedNodeIds: ['node-1'],
    createdAt: Date.now(),
    reason: 'reason',
    expectedBenefit: 'benefit',
    canRollback: true,
    cooldownKey: `cooldown-${id}`,
    expiresAt: Date.now() + 60000
  };
}

export default function phase2BatchBKTest() {
  describe('phase2BatchBKTest', () => {
    it('normal: event_plan_backlog_and_overlay_helpers_should_keep_expected_outputs', 0, () => {
      // Arrange
      const conflictMsg = '剩余冲突 35 分钟';

      // Act
      const commute = formatEventItemCommuteTime(61);
      const gap = resolveEventItemConflictGapMinutes(0, conflictMsg);
      const overlayVisible = isCompanionOverlayVisible(false, false, true);
      const backLevel = resolveCompanionBackLevel(false, false, true, 'immersive');
      const crossDay = shouldPlanItemShowCrossDayLabel('05-01 09:20');
      const timeText = resolvePlanItemTimeText('09:20');
      const badgeText = getBacklogBadgeText(4);

      // Assert
      expect(commute).assertEqual('1h 1m');
      expect(gap).assertEqual(35);
      expect(overlayVisible).assertTrue();
      expect(backLevel).assertEqual('overlay');
      expect(crossDay).assertTrue();
      expect(timeText).assertEqual('09:20');
      expect(badgeText).assertEqual('4');
    });

    it('boundary: event_plan_backlog_and_overlay_helpers_should_handle_edge_inputs', 0, () => {
      // Arrange
      const malformedConflictMsg = '';

      // Act
      const negativeCommute = formatEventItemCommuteTime(-5);
      const gap = resolveEventItemConflictGapMinutes(0, malformedConflictMsg);
      const overlayVisible = isCompanionOverlayVisible(false, false, false);
      const backLevel = resolveCompanionBackLevel(false, false, false, 'control');
      const crossDay = shouldPlanItemShowCrossDayLabel('');
      const timeText = resolvePlanItemTimeText('');
      const emptyExpanded = shouldShowBacklogEmptyState(true, 0);

      // Assert
      expect(negativeCommute).assertEqual('-5m');
      expect(gap).assertEqual(0);
      expect(overlayVisible).assertFalse();
      expect(backLevel).assertEqual('control');
      expect(crossDay).assertFalse();
      expect(timeText).assertEqual('--:--');
      expect(emptyExpanded).assertTrue();
    });

    it('invalid: companion_focus_skip_should_noop_when_focused_event_is_null', 0, async (done: Function) => {
      // Arrange
      let skipCalls = 0;
      let refreshCalls = 0;
      const focusIds: number[] = [];

      // Act
      await handleCompanionFocusedSkip({
        focusedEvent: null,
        skipEvent: async (_event: EventEntity): Promise<void> => {
          skipCalls += 1;
        },
        refreshContext: (): void => {
          refreshCalls += 1;
        },
        getScheduledEvents: (): EventEntity[] => [],
        getScheduleIndexById: (_id: number): number => -1,
        applyFocusById: (id: number): void => {
          focusIds.push(id);
        },
        showToast: (_message: string): void => {}
      });
      await new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => {
        setTimeout(() => resolve(), 160);
      });

      // Assert
      expect(skipCalls).assertEqual(0);
      expect(refreshCalls).assertEqual(0);
      expect(focusIds.length).assertEqual(0);
      done();
    });

    it('conflict: companion_focus_skip_should_pick_next_startable_after_current_index', 0, async (done: Function) => {
      // Arrange
      const focused = buildCompanionEventBK(1, 'PENDING');
      const active = buildCompanionEventBK(2, 'ACTIVE');
      const nextStartable = buildCompanionEventBK(3, 'PENDING');
      let skipCalls = 0;
      const focusIds: number[] = [];

      // Act
      await handleCompanionFocusedSkip({
        focusedEvent: focused,
        skipEvent: async (_event: EventEntity): Promise<void> => {
          skipCalls += 1;
        },
        refreshContext: (): void => {},
        getScheduledEvents: (): EventEntity[] => [focused, active, nextStartable],
        getScheduleIndexById: (_id: number): number => 0,
        applyFocusById: (id: number): void => {
          focusIds.push(id);
        },
        showToast: (_message: string): void => {}
      });
      await new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => {
        setTimeout(() => resolve(), 160);
      });

      // Assert
      expect(skipCalls).assertEqual(1);
      expect(focusIds.length).assertEqual(1);
      expect(focusIds[0]).assertEqual(3);
      done();
    });

    it('invalid: companion_focus_reopen_should_noop_when_focused_event_is_null', 0, async (done: Function) => {
      // Arrange
      let reopenCalls = 0;
      let updateCalls = 0;
      const toasts: string[] = [];

      // Act
      await handleCompanionFocusedReopen({
        focusedEvent: null,
        getScheduledEvents: (): EventEntity[] => [],
        reopenSkippedEvent: async (_eventId: number): Promise<boolean> => {
          reopenCalls += 1;
          return true;
        },
        updateActualStart: async (_eventId: number, _nowTs: number): Promise<boolean> => {
          updateCalls += 1;
          return true;
        },
        showGlobalActiveConflictDialog: async (_excludeEventId: number): Promise<boolean> => false,
        refreshContext: (): void => {},
        applyFocusById: (_id: number): void => {},
        enterImmersiveMode: (): void => {},
        showToast: (message: string): void => {
          toasts.push(message);
        }
      });

      // Assert
      expect(reopenCalls).assertEqual(0);
      expect(updateCalls).assertEqual(0);
      expect(toasts.length).assertEqual(0);
      done();
    });

    it('boundary: companion_focus_reopen_should_show_failure_toast_when_reopen_fails', 0, async (done: Function) => {
      // Arrange
      const focused = buildCompanionEventBK(10, 'SKIPPED');
      const toasts: string[] = [];

      // Act
      await handleCompanionFocusedReopen({
        focusedEvent: focused,
        getScheduledEvents: (): EventEntity[] => [focused],
        reopenSkippedEvent: async (_eventId: number): Promise<boolean> => false,
        updateActualStart: async (_eventId: number, _nowTs: number): Promise<boolean> => true,
        showGlobalActiveConflictDialog: async (_excludeEventId: number): Promise<boolean> => false,
        refreshContext: (): void => {},
        applyFocusById: (_id: number): void => {},
        enterImmersiveMode: (): void => {},
        showToast: (message: string): void => {
          toasts.push(message);
        }
      });

      // Assert
      expect(toasts.length).assertEqual(1);
      expect(toasts[0]).assertEqual('重新开始失败');
      done();
    });

    it('boundary: companion_focus_reopen_should_not_show_fallback_toast_when_conflict_dialog_shown', 0, async (done: Function) => {
      // Arrange
      const focused = buildCompanionEventBK(11, 'SKIPPED');
      const toasts: string[] = [];
      let conflictDialogCalls = 0;

      // Act
      await handleCompanionFocusedReopen({
        focusedEvent: focused,
        getScheduledEvents: (): EventEntity[] => [focused],
        reopenSkippedEvent: async (_eventId: number): Promise<boolean> => true,
        updateActualStart: async (_eventId: number, _nowTs: number): Promise<boolean> => false,
        showGlobalActiveConflictDialog: async (_excludeEventId: number): Promise<boolean> => {
          conflictDialogCalls += 1;
          return true;
        },
        refreshContext: (): void => {},
        applyFocusById: (_id: number): void => {},
        enterImmersiveMode: (): void => {},
        showToast: (message: string): void => {
          toasts.push(message);
        }
      });

      // Assert
      expect(conflictDialogCalls).assertEqual(1);
      expect(toasts.length).assertEqual(0);
      done();
    });

    it('normal: companion_weather_apply_should_execute_confirm_callback_and_call_vm', 0, async (done: Function) => {
      // Arrange
      const vm = new CompanionWeatherVmBkMock();
      const item = buildWeatherSuggestionBK('bk-normal');
      let confirm: (() => void) | undefined;

      // Act
      applyCompanionWeatherSuggestion({
        vm: vm as Object as TimelineViewModel,
        item: item,
        showToast: (_message: string): void => {},
        showApplyConfirm: (_title: string, _message: string, onConfirm: () => void): void => {
          confirm = onConfirm;
        }
      });
      if (confirm) {
        confirm();
      }
      await new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => {
        setTimeout(() => resolve(), 0);
      });

      // Assert
      expect(vm.requestCount).assertEqual(1);
      expect(vm.lastSuggestionId).assertEqual('bk-normal');
      done();
    });

    it('invalid: companion_weather_apply_should_show_exception_toast_when_vm_rejects', 0, async (done: Function) => {
      // Arrange
      const vm = new CompanionWeatherVmBkMock();
      vm.shouldReject = true;
      const item = buildWeatherSuggestionBK('bk-reject');
      const toasts: string[] = [];
      let confirm: (() => void) | undefined;

      // Act
      applyCompanionWeatherSuggestion({
        vm: vm as Object as TimelineViewModel,
        item: item,
        showToast: (message: string): void => {
          toasts.push(message);
        },
        showApplyConfirm: (_title: string, _message: string, onConfirm: () => void): void => {
          confirm = onConfirm;
        }
      });
      if (confirm) {
        confirm();
      }
      await new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => {
        setTimeout(() => resolve(), 0);
      });

      // Assert
      expect(vm.requestCount).assertEqual(1);
      expect(toasts.length).assertEqual(1);
      expect(toasts[0]).assertEqual('可选建议应用失败：执行异常');
      done();
    });

    it('regression: companion_weather_guide_and_dismiss_text_should_remain_stable', 0, () => {
      // Arrange
      // Act
      const guideText = getCompanionWeatherGuidePopupText();
      const laterToast = getCompanionDismissSuggestionToast('later');
      const ignoreToast = getCompanionDismissSuggestionToast('ignore');

      // Assert
      expect(guideText.includes('调整建议（用途）')).assertTrue();
      expect(guideText.includes('仅作为建议，不会自动改行程。')).assertTrue();
      expect(laterToast).assertEqual('已暂不处理该建议');
      expect(ignoreToast).assertEqual('已忽略该可选建议');
    });

    it('combined: companion_weather_focus_and_view_helpers_should_follow_independent_rules', 0, async (done: Function) => {
      // Arrange
      const vm = new CompanionWeatherVmBkMock();
      const item = buildWeatherSuggestionBK('bk-combined');
      const toasts: string[] = [];
      let confirm: (() => void) | undefined;
      const focused = buildCompanionEventBK(22, 'SKIPPED');
      let reopenRefreshCount = 0;

      // Act
      applyCompanionWeatherSuggestion({
        vm: vm as Object as TimelineViewModel,
        item: item,
        showToast: (message: string): void => {
          toasts.push(message);
        },
        showApplyConfirm: (_title: string, _message: string, onConfirm: () => void): void => {
          confirm = onConfirm;
        }
      });
      if (confirm) {
        confirm();
      }
      await handleCompanionFocusedReopen({
        focusedEvent: focused,
        getScheduledEvents: (): EventEntity[] => [focused],
        reopenSkippedEvent: async (_eventId: number): Promise<boolean> => true,
        updateActualStart: async (_eventId: number, _nowTs: number): Promise<boolean> => true,
        showGlobalActiveConflictDialog: async (_excludeEventId: number): Promise<boolean> => false,
        refreshContext: (): void => {
          reopenRefreshCount += 1;
        },
        applyFocusById: (_id: number): void => {},
        enterImmersiveMode: (): void => {},
        showToast: (_message: string): void => {}
      });
      await new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => {
        setTimeout(() => resolve(), 0);
      });

      // Assert
      expect(vm.requestCount).assertEqual(1);
      expect(toasts.length > 0).assertTrue();
      expect(reopenRefreshCount).assertEqual(1);
      expect(resolveCompanionBackLevel(false, false, false, 'immersive')).assertEqual('immersive');
      done();
    });
  });
}
