import { describe, expect, it } from '@ohos/hypium';
import { TimelineCompanionManager, ITimelineCompanionHost } from '../main/ets/viewmodel/managers/TimelineCompanionManager';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { ReflowHint } from '../main/ets/viewmodel/types/TimelineTypes';

class StageViewModel {
  canPause: boolean = false;
  canResume: boolean = false;
}

class FakePlanStateMachine {
  stage: StageViewModel = new StageViewModel();

  getPlanStageViewModel(_planId: string): StageViewModel {
    return this.stage;
  }
}

class CompanionHost implements ITimelineCompanionHost {
  planId: number = 1;
  latestReflowHint: ReflowHint | null = null;
  planStateMachine: FakePlanStateMachine = new FakePlanStateMachine();
  private schedule: EventEntity[] = [];
  private nextMap: Map<number, EventEntity> = new Map<number, EventEntity>();

  setSchedule(schedule: EventEntity[]): void {
    this.schedule = schedule;
  }

  setNext(afterId: number, next: EventEntity): void {
    this.nextMap.set(afterId, next);
  }

  getOrderedScheduleEvents(): EventEntity[] {
    return this.schedule;
  }

  getNextExecutableEvent(afterId: number, _schedule?: EventEntity[]): EventEntity | null {
    return this.nextMap.get(afterId) || null;
  }
}

function createScheduledEvent(id: number, name: string): EventEntity {
  const event = new EventEntity(name, 1);
  event.id = id;
  event.status = 1;
  event.completion_status = EventEntity.STATE_PENDING;
  event.actual_start_time = 0;
  event.actual_end_time = 0;
  event.dynamic_start_time = 0;
  event.dynamic_end_time = 0;
  return event;
}

export default function timelineCompanionManagerTest() {
  describe('timelineCompanionManagerTest', () => {
    it('normal: get_companion_context_should_return_active_state_when_active_event_exists', 0, () => {
      // Arrange
      const active = createScheduledEvent(1, 'active');
      active.actual_start_time = Date.now();
      const next = createScheduledEvent(2, 'next');
      const host = new CompanionHost();
      host.setSchedule([active, next]);
      host.setNext(1, next);
      host.planStateMachine.stage.canPause = true;
      host.planStateMachine.stage.canResume = false;
      const manager = new TimelineCompanionManager(host);
      // Act
      const context = manager.getCompanionContext();
      // Assert
      expect(context.runtimeState).assertEqual('ACTIVE');
      expect(context.currentEvent?.id || 0).assertEqual(1);
      expect(context.nextEvent?.id || 0).assertEqual(2);
      expect(context.actions.canPause).assertTrue();
    });

    it('boundary: get_companion_context_should_generate_ready_hint_when_no_latest_hint', 0, () => {
      // Arrange
      const pending = createScheduledEvent(3, 'pending');
      const nowTs = Date.now();
      pending.dynamic_start_time = nowTs + 20 * 60 * 1000;
      const host = new CompanionHost();
      host.setSchedule([pending]);
      const manager = new TimelineCompanionManager(host);
      // Act
      const context = manager.getCompanionContext(nowTs);
      // Assert
      expect(context.runtimeState).assertEqual('READY');
      expect(context.hint !== null).assertTrue();
      expect((context.hint?.message || '').includes('距计划开始')).assertTrue();
    });

    it('invalid: get_companion_context_should_return_idle_when_schedule_empty', 0, () => {
      // Arrange
      const host = new CompanionHost();
      host.setSchedule([]);
      const manager = new TimelineCompanionManager(host);
      // Act
      const context = manager.getCompanionContext();
      // Assert
      expect(context.runtimeState).assertEqual('IDLE');
      expect(context.actions.canStart).assertFalse();
      expect(context.currentEvent === null).assertTrue();
    });

    it('conflict: get_companion_context_should_mark_paused_when_resume_enabled_but_pause_disabled', 0, () => {
      // Arrange
      const active = createScheduledEvent(4, 'active');
      active.actual_start_time = Date.now();
      const host = new CompanionHost();
      host.setSchedule([active]);
      host.planStateMachine.stage.canPause = false;
      host.planStateMachine.stage.canResume = true;
      const manager = new TimelineCompanionManager(host);
      // Act
      const context = manager.getCompanionContext();
      // Assert
      expect(context.runtimeState).assertEqual('PAUSED');
      expect(context.actions.canResume).assertTrue();
      expect(context.actions.canPause).assertFalse();
    });

    it('regression: td-20260411-c4-get-real-active-event-should-fallback-to-pending-before-end-time', 0, () => {
      // Arrange
      const pending = createScheduledEvent(5, 'pending');
      pending.dynamic_end_time = Date.now() + 60 * 1000;
      const host = new CompanionHost();
      host.setSchedule([pending]);
      const manager = new TimelineCompanionManager(host);
      // Act
      const active = manager.getRealActiveEvent();
      // Assert
      expect(active !== null).assertTrue();
      expect(active?.id || 0).assertEqual(5);
    });

    it('combined: ready_context_should_keep_latest_hint_and_next_event_together', 0, () => {
      // Arrange
      const pending = createScheduledEvent(6, 'pending');
      const next = createScheduledEvent(7, 'next');
      const hint: ReflowHint = {
        type: 'next_changed',
        minutesDelta: 0,
        message: '下一站改为 next',
        updatedAt: Date.now()
      };
      const host = new CompanionHost();
      host.latestReflowHint = hint;
      host.setSchedule([pending, next]);
      host.setNext(6, next);
      const manager = new TimelineCompanionManager(host);
      // Act
      const context = manager.getCompanionContext();
      // Assert
      expect(context.runtimeState).assertEqual('READY');
      expect(context.hint?.message || '').assertEqual('下一站改为 next');
      expect(context.nextEvent?.id || 0).assertEqual(7);
      expect(context.actions.canStart).assertTrue();
    });
  });
}
