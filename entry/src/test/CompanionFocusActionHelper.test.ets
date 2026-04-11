import { describe, it, expect } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import {
  handleCompanionFocusedReopen,
  handleCompanionFocusedSkip
} from '../main/ets/pages/components/views/companion/CompanionFocusActionHelper';

interface FocusSkipParamsMock {
  focusedEvent: EventEntity | null;
  schedule: EventEntity[];
  skipCalls: number;
  refreshCalls: number;
  applyFocusIds: number[];
  toasts: string[];
}

interface FocusReopenParamsMock {
  focusedEvent: EventEntity | null;
  schedule: EventEntity[];
  reopenResult: boolean;
  updateStartResult: boolean;
  conflictDialogResult: boolean;
  reopenCalls: number;
  updateCalls: number;
  refreshCalls: number;
  applyFocusIds: number[];
  immersiveCalls: number;
  toasts: string[];
}

function buildEvent(id: number, state: 'PENDING' | 'ACTIVE' | 'SKIPPED'): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = `event-${id}`;
  event.status = 1;
  event.completion_status = EventEntity.STATE_PENDING;
  event.actual_start_time = 0;
  event.actual_end_time = 0;
  if (state === 'ACTIVE') {
    event.actual_start_time = Date.now() - 120000;
  }
  if (state === 'SKIPPED') {
    event.completion_status = EventEntity.STATE_SKIPPED;
  }
  return event;
}

function createSkipMock(focused: EventEntity | null, schedule: EventEntity[]): FocusSkipParamsMock {
  return {
    focusedEvent: focused,
    schedule: schedule,
    skipCalls: 0,
    refreshCalls: 0,
    applyFocusIds: [],
    toasts: []
  };
}

function createReopenMock(focused: EventEntity | null, schedule: EventEntity[]): FocusReopenParamsMock {
  return {
    focusedEvent: focused,
    schedule: schedule,
    reopenResult: true,
    updateStartResult: true,
    conflictDialogResult: false,
    reopenCalls: 0,
    updateCalls: 0,
    refreshCalls: 0,
    applyFocusIds: [],
    immersiveCalls: 0,
    toasts: []
  };
}

export default function companionFocusActionHelperTest() {
  describe('unit_test_case_generator_autofill_CompanionFocusActionHelper', () => {
    it('normal: reopen_should_refresh_focus_and_enter_immersive_on_success', 0, async (done: Function) => {
      // Arrange
      const focused = buildEvent(1, 'SKIPPED');
      const mock = createReopenMock(focused, [focused]);

      // Act
      await handleCompanionFocusedReopen({
        focusedEvent: mock.focusedEvent,
        getScheduledEvents: () => mock.schedule,
        reopenSkippedEvent: async (_eventId: number): Promise<boolean> => {
          mock.reopenCalls += 1;
          return mock.reopenResult;
        },
        updateActualStart: async (_eventId: number, _nowTs: number): Promise<boolean> => {
          mock.updateCalls += 1;
          return mock.updateStartResult;
        },
        showGlobalActiveConflictDialog: async (_excludeEventId: number): Promise<boolean> => mock.conflictDialogResult,
        refreshContext: (): void => {
          mock.refreshCalls += 1;
        },
        applyFocusById: (id: number): void => {
          mock.applyFocusIds.push(id);
        },
        enterImmersiveMode: (): void => {
          mock.immersiveCalls += 1;
        },
        showToast: (message: string): void => {
          mock.toasts.push(message);
        }
      });

      // Assert
      expect(mock.reopenCalls).assertEqual(1);
      expect(mock.updateCalls).assertEqual(1);
      expect(mock.refreshCalls).assertEqual(1);
      expect(mock.applyFocusIds[0]).assertEqual(1);
      expect(mock.immersiveCalls).assertEqual(1);
      done();
    });

    it('boundary: skip_should_fallback_to_first_startable_when_current_index_is_missing', 0, async (done: Function) => {
      // Arrange
      const focused = buildEvent(2, 'PENDING');
      const nextStartable = buildEvent(3, 'PENDING');
      const mock = createSkipMock(focused, [nextStartable]);

      // Act
      await handleCompanionFocusedSkip({
        focusedEvent: mock.focusedEvent,
        skipEvent: async (_event: EventEntity): Promise<void> => {
          mock.skipCalls += 1;
        },
        refreshContext: (): void => {
          mock.refreshCalls += 1;
        },
        getScheduledEvents: () => mock.schedule,
        getScheduleIndexById: (_id: number): number => -1,
        applyFocusById: (id: number): void => {
          mock.applyFocusIds.push(id);
        },
        showToast: (message: string): void => {
          mock.toasts.push(message);
        }
      });
      await new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => {
        setTimeout(() => resolve(), 150);
      });

      // Assert
      expect(mock.skipCalls).assertEqual(1);
      expect(mock.refreshCalls).assertEqual(1);
      expect(mock.applyFocusIds[0]).assertEqual(3);
      done();
    });

    it('invalid: skip_should_show_toast_when_focused_event_is_not_pending', 0, async (done: Function) => {
      // Arrange
      const focused = buildEvent(4, 'ACTIVE');
      const mock = createSkipMock(focused, [focused]);

      // Act
      await handleCompanionFocusedSkip({
        focusedEvent: mock.focusedEvent,
        skipEvent: async (_event: EventEntity): Promise<void> => {
          mock.skipCalls += 1;
        },
        refreshContext: (): void => {
          mock.refreshCalls += 1;
        },
        getScheduledEvents: () => mock.schedule,
        getScheduleIndexById: (_id: number): number => 0,
        applyFocusById: (id: number): void => {
          mock.applyFocusIds.push(id);
        },
        showToast: (message: string): void => {
          mock.toasts.push(message);
        }
      });

      // Assert
      expect(mock.skipCalls).assertEqual(0);
      expect(mock.refreshCalls).assertEqual(0);
      expect(mock.toasts.length).assertEqual(1);
      done();
    });

    it('conflict: reopen_should_block_when_other_active_event_exists', 0, async (done: Function) => {
      // Arrange
      const focused = buildEvent(5, 'SKIPPED');
      const active = buildEvent(6, 'ACTIVE');
      const mock = createReopenMock(focused, [focused, active]);

      // Act
      await handleCompanionFocusedReopen({
        focusedEvent: mock.focusedEvent,
        getScheduledEvents: () => mock.schedule,
        reopenSkippedEvent: async (_eventId: number): Promise<boolean> => {
          mock.reopenCalls += 1;
          return mock.reopenResult;
        },
        updateActualStart: async (_eventId: number, _nowTs: number): Promise<boolean> => {
          mock.updateCalls += 1;
          return mock.updateStartResult;
        },
        showGlobalActiveConflictDialog: async (_excludeEventId: number): Promise<boolean> => mock.conflictDialogResult,
        refreshContext: (): void => {
          mock.refreshCalls += 1;
        },
        applyFocusById: (id: number): void => {
          mock.applyFocusIds.push(id);
        },
        enterImmersiveMode: (): void => {
          mock.immersiveCalls += 1;
        },
        showToast: (message: string): void => {
          mock.toasts.push(message);
        }
      });

      // Assert
      expect(mock.reopenCalls).assertEqual(0);
      expect(mock.updateCalls).assertEqual(0);
      expect(mock.toasts.length).assertEqual(1);
      done();
    });

    it('regression: reopen_should_show_failure_toast_when_start_fails_and_dialog_not_shown', 0, async (done: Function) => {
      // Arrange
      const focused = buildEvent(7, 'SKIPPED');
      const mock = createReopenMock(focused, [focused]);
      mock.updateStartResult = false;
      mock.conflictDialogResult = false;

      // Act
      await handleCompanionFocusedReopen({
        focusedEvent: mock.focusedEvent,
        getScheduledEvents: () => mock.schedule,
        reopenSkippedEvent: async (_eventId: number): Promise<boolean> => {
          mock.reopenCalls += 1;
          return mock.reopenResult;
        },
        updateActualStart: async (_eventId: number, _nowTs: number): Promise<boolean> => {
          mock.updateCalls += 1;
          return mock.updateStartResult;
        },
        showGlobalActiveConflictDialog: async (_excludeEventId: number): Promise<boolean> => mock.conflictDialogResult,
        refreshContext: (): void => {
          mock.refreshCalls += 1;
        },
        applyFocusById: (id: number): void => {
          mock.applyFocusIds.push(id);
        },
        enterImmersiveMode: (): void => {
          mock.immersiveCalls += 1;
        },
        showToast: (message: string): void => {
          mock.toasts.push(message);
        }
      });

      // Assert
      expect(mock.reopenCalls).assertEqual(1);
      expect(mock.updateCalls).assertEqual(1);
      expect(mock.refreshCalls).assertEqual(0);
      expect(mock.toasts.length).assertEqual(1);
      done();
    });

    it('combined: skip_should_not_apply_focus_when_no_startable_event_exists', 0, async (done: Function) => {
      // Arrange
      const focused = buildEvent(8, 'PENDING');
      const nonStartable = buildEvent(9, 'ACTIVE');
      const mock = createSkipMock(focused, [nonStartable]);

      // Act
      await handleCompanionFocusedSkip({
        focusedEvent: mock.focusedEvent,
        skipEvent: async (_event: EventEntity): Promise<void> => {
          mock.skipCalls += 1;
        },
        refreshContext: (): void => {
          mock.refreshCalls += 1;
        },
        getScheduledEvents: () => mock.schedule,
        getScheduleIndexById: (_id: number): number => 0,
        applyFocusById: (id: number): void => {
          mock.applyFocusIds.push(id);
        },
        showToast: (message: string): void => {
          mock.toasts.push(message);
        }
      });
      await new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => {
        setTimeout(() => resolve(), 150);
      });

      // Assert
      expect(mock.skipCalls).assertEqual(1);
      expect(mock.refreshCalls).assertEqual(1);
      expect(mock.applyFocusIds.length).assertEqual(0);
      done();
    });
  });
}
