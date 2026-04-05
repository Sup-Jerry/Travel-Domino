import { EventEntity } from '../../model/entity/EventEntity';
import { TimelineExecutionState } from '../../domain/policy/TimelineExecutionState';
import { CompanionContext, ReflowHint } from '../types/TimelineTypes';

interface CompanionPlanStageView {
  canPause: boolean;
  canResume: boolean;
}

interface CompanionPlanStateMachine {
  getPlanStageViewModel(planId: string): CompanionPlanStageView;
}

export interface ITimelineCompanionHost {
  planId: number;
  latestReflowHint: ReflowHint | null;
  planStateMachine: CompanionPlanStateMachine;
  getOrderedScheduleEvents(): EventEntity[];
  getNextExecutableEvent(afterId: number, schedule?: EventEntity[]): EventEntity | null;
}

export class TimelineCompanionManager {
  private host: ITimelineCompanionHost;

  constructor(host: ITimelineCompanionHost) {
    this.host = host;
  }

  public getCompanionContext(nowTs: number = Date.now()): CompanionContext {
    const schedule = this.host.getOrderedScheduleEvents();
    if (schedule.length === 0) {
      return {
        runtimeState: 'IDLE',
        currentEvent: null,
        nextEvent: null,
        hint: this.host.latestReflowHint,
        actions: {
          canStart: false,
          canPause: false,
          canResume: false,
          canEnd: false,
          canSkip: false,
          canNavigate: false,
          canViewDetail: false
        }
      };
    }

    let active: EventEntity | null = null;
    let pending: EventEntity | null = null;
    for (let i = 0; i < schedule.length; i++) {
      const event = schedule[i];
      if (!active && TimelineExecutionState.isActive(event)) {
        active = event;
      }
      if (!pending && TimelineExecutionState.isStartable(event)) {
        pending = event;
      }
      if (active && pending) {
        break;
      }
    }

    if (active) {
      const stage = this.host.planStateMachine.getPlanStageViewModel(`${this.host.planId}`);
      const next = this.host.getNextExecutableEvent(active.id, schedule);
      if (stage.canResume && !stage.canPause) {
        return {
          runtimeState: 'PAUSED',
          currentEvent: active,
          nextEvent: next,
          hint: this.host.latestReflowHint,
          actions: {
            canStart: false,
            canPause: false,
            canResume: true,
            canEnd: true,
            canSkip: true,
            canNavigate: true,
            canViewDetail: true
          }
        };
      }
      return {
        runtimeState: 'ACTIVE',
        currentEvent: active,
        nextEvent: next,
        hint: this.host.latestReflowHint,
        actions: {
          canStart: false,
          canPause: stage.canPause,
          canResume: stage.canResume,
          canEnd: true,
          canSkip: true,
          canNavigate: true,
          canViewDetail: true
        }
      };
    }

    if (!pending) {
      return {
        runtimeState: 'IDLE',
        currentEvent: null,
        nextEvent: null,
        hint: this.host.latestReflowHint,
        actions: {
          canStart: false,
          canPause: false,
          canResume: false,
          canEnd: false,
          canSkip: false,
          canNavigate: false,
          canViewDetail: false
        }
      };
    }

    const hasDynamicStart = pending.dynamic_start_time > 0;
    const next = this.host.getNextExecutableEvent(pending.id, schedule);
    let runtimeHint = this.host.latestReflowHint;
    if (!runtimeHint && hasDynamicStart) {
      const deltaMinutes = Math.round((pending.dynamic_start_time - nowTs) / 60000);
      runtimeHint = {
        type: 'reflow',
        minutesDelta: deltaMinutes,
        message: deltaMinutes > 0
          ? `距计划开始约 ${Math.max(1, deltaMinutes)} 分钟，可手动提前开始`
          : `已超过计划开始 ${Math.max(1, Math.abs(deltaMinutes))} 分钟，可直接开始`,
        updatedAt: nowTs
      };
    }

    return {
      runtimeState: 'READY',
      currentEvent: pending,
      nextEvent: next,
      hint: runtimeHint,
      actions: {
        canStart: true,
        canPause: false,
        canResume: false,
        canEnd: false,
        canSkip: true,
        canNavigate: true,
        canViewDetail: true
      }
    };
  }

  public getRealActiveEvent(schedule?: EventEntity[]): EventEntity | null {
    const now = Date.now();
    const source = schedule ?? this.host.getOrderedScheduleEvents();
    let pending: EventEntity | null = null;
    for (let i = 0; i < source.length; i++) {
      const event = source[i];
      if (TimelineExecutionState.isActive(event)) {
        return event;
      }
      if (!pending && TimelineExecutionState.isStartable(event) && event.dynamic_end_time > now) {
        pending = event;
      }
    }
    return pending;
  }
}
