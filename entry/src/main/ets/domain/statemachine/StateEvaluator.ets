import { EvaluateStatusResult, StateEvaluationInput } from './ExecutionContext';
import { PlanStatus, TransitionTriggerSource } from './PlanStatus';

interface TransitionMeta {
  triggerSource: TransitionTriggerSource;
  triggerReason: string;
}

export class StateEvaluator {
  private readonly readyWindowMinutes: number;
  private readonly motionLeadMinutes: number;
  private readonly minReadyStayMs: number;
  private readonly minPauseStayMs: number;

  constructor(
    readyWindowMinutes: number = 30,
    motionLeadMinutes: number = 15,
    minReadyStayMs: number = 2 * 60 * 1000,
    minPauseStayMs: number = 20 * 1000
  ) {
    this.readyWindowMinutes = readyWindowMinutes;
    this.motionLeadMinutes = motionLeadMinutes;
    this.minReadyStayMs = minReadyStayMs;
    this.minPauseStayMs = minPauseStayMs;
  }

  public evaluateNextStatus(input: StateEvaluationInput): EvaluateStatusResult {
    const next = this.computeStatus(input);
    if (next === input.currentStatus) {
      return {
        currentStatus: input.currentStatus,
        suggestedStatus: next,
        shouldTransition: false
      };
    }

    const transitionMeta = this.resolveTransitionMeta(input, next);
    return {
      currentStatus: input.currentStatus,
      suggestedStatus: next,
      shouldTransition: true,
      triggerSource: transitionMeta.triggerSource,
      triggerReason: transitionMeta.triggerReason
    };
  }

  public shouldEnterReady(input: StateEvaluationInput): boolean {
    if (input.hasReachedFirstNode) {
      return true;
    }
    if (!input.firstNodeStartTime || input.firstNodeStartTime <= 0) {
      return false;
    }
    const windowStart = input.firstNodeStartTime - this.readyWindowMinutes * 60 * 1000;
    return input.now >= windowStart && input.now < input.firstNodeStartTime;
  }

  public shouldEnterInProgress(input: StateEvaluationInput): boolean {
    if (input.userClickedStart || input.hasReachedFirstNode) {
      return true;
    }

    if (input.firstNodeStartTime && input.firstNodeStartTime > 0) {
      if (input.now >= input.firstNodeStartTime) {
        return true;
      }

      const motionWindowStart = input.firstNodeStartTime - this.motionLeadMinutes * 60 * 1000;
      if (input.motionDetected && input.now >= motionWindowStart) {
        return true;
      }
    }

    return false;
  }

  public shouldBlockReadyLeave(now: number, lastTransitionAt?: number): boolean {
    if (!lastTransitionAt || lastTransitionAt <= 0) {
      return false;
    }
    return now - lastTransitionAt < this.minReadyStayMs;
  }

  public shouldBlockPauseLeave(now: number, lastTransitionAt?: number): boolean {
    if (!lastTransitionAt || lastTransitionAt <= 0) {
      return false;
    }
    return now - lastTransitionAt < this.minPauseStayMs;
  }

  private computeStatus(input: StateEvaluationInput): PlanStatus {
    if (input.userClickedCancel) {
      return PlanStatus.CANCELLED;
    }
    if (input.allNodesCompleted) {
      return PlanStatus.COMPLETED;
    }
    if (input.isPlanExpired && input.currentStatus !== PlanStatus.IN_PROGRESS && input.currentStatus !== PlanStatus.PAUSED) {
      return PlanStatus.EXPIRED;
    }

    if (input.currentStatus === PlanStatus.IN_PROGRESS && input.userClickedPause) {
      return PlanStatus.PAUSED;
    }
    if (input.currentStatus === PlanStatus.PAUSED) {
      if (!input.userClickedResume) {
        return PlanStatus.PAUSED;
      }
      return this.shouldBlockPauseLeave(input.now, input.lastTransitionAt)
        ? PlanStatus.PAUSED
        : PlanStatus.IN_PROGRESS;
    }

    if ((input.currentStatus === PlanStatus.DRAFT || input.currentStatus === PlanStatus.CONFIRMED) && this.shouldEnterReady(input)) {
      return PlanStatus.READY;
    }

    if (input.currentStatus === PlanStatus.READY) {
      if (this.shouldBlockReadyLeave(input.now, input.lastTransitionAt)) {
        return PlanStatus.READY;
      }
      if (this.shouldEnterInProgress(input)) {
        return PlanStatus.IN_PROGRESS;
      }
      return PlanStatus.READY;
    }

    if (input.currentStatus === PlanStatus.CONFIRMED && this.shouldEnterInProgress(input)) {
      return PlanStatus.IN_PROGRESS;
    }

    return input.currentStatus;
  }

  private resolveTransitionMeta(input: StateEvaluationInput, next: PlanStatus): TransitionMeta {
    if (next === PlanStatus.CANCELLED) {
      return this.meta(TransitionTriggerSource.USER_ACTION, 'cancel_by_user');
    }
    if (next === PlanStatus.COMPLETED) {
      return this.meta(TransitionTriggerSource.TASK_COMPLETION, 'all_nodes_completed');
    }
    if (next === PlanStatus.EXPIRED) {
      return this.meta(TransitionTriggerSource.PLAN_TIMEOUT, 'plan_expired');
    }
    if (next === PlanStatus.PAUSED) {
      return this.meta(TransitionTriggerSource.USER_ACTION, 'pause_by_user');
    }
    if (next === PlanStatus.IN_PROGRESS && input.userClickedResume) {
      return this.meta(TransitionTriggerSource.USER_ACTION, 'resume_by_user');
    }
    if (next === PlanStatus.READY && this.shouldEnterReady(input)) {
      if (input.hasReachedFirstNode) {
        return this.meta(TransitionTriggerSource.LOCATION_PROXIMITY, 'arrived_first_node_window');
      }
      return this.meta(TransitionTriggerSource.TIME_WINDOW, 'enter_ready_window');
    }
    if (next === PlanStatus.IN_PROGRESS && this.shouldEnterInProgress(input)) {
      if (input.userClickedStart) {
        return this.meta(TransitionTriggerSource.USER_ACTION, 'start_by_user');
      }
      if (input.hasReachedFirstNode) {
        return this.meta(TransitionTriggerSource.LOCATION_PROXIMITY, 'arrived_first_node');
      }
      if (input.motionDetected) {
        return this.meta(TransitionTriggerSource.MOTION_DETECTED, 'motion_detected_near_start');
      }
      return this.meta(TransitionTriggerSource.TIME_WINDOW, 'reach_first_node_start_time');
    }

    return this.meta(TransitionTriggerSource.MANUAL_OVERRIDE, 'state_adjustment');
  }

  private meta(triggerSource: TransitionTriggerSource, triggerReason: string): TransitionMeta {
    return {
      triggerSource: triggerSource,
      triggerReason: triggerReason
    };
  }
}
