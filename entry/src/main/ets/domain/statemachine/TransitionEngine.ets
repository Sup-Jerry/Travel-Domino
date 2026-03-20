import { PlanTransitionEvent, TransitionCommand, TransitionResult } from './ExecutionContext';
import { PlanStatus } from './PlanStatus';

export class TransitionEngine {
  private readonly allowedTransitions: Map<PlanStatus, Set<PlanStatus>> = new Map<PlanStatus, Set<PlanStatus>>();

  constructor() {
    this.allowedTransitions.set(PlanStatus.DRAFT, new Set<PlanStatus>([PlanStatus.CONFIRMED, PlanStatus.CANCELLED]));
    this.allowedTransitions.set(PlanStatus.CONFIRMED, new Set<PlanStatus>([PlanStatus.READY, PlanStatus.IN_PROGRESS, PlanStatus.EXPIRED, PlanStatus.CANCELLED]));
    this.allowedTransitions.set(PlanStatus.READY, new Set<PlanStatus>([PlanStatus.IN_PROGRESS, PlanStatus.EXPIRED, PlanStatus.CANCELLED]));
    this.allowedTransitions.set(PlanStatus.IN_PROGRESS, new Set<PlanStatus>([PlanStatus.PAUSED, PlanStatus.COMPLETED, PlanStatus.CANCELLED]));
    this.allowedTransitions.set(PlanStatus.PAUSED, new Set<PlanStatus>([PlanStatus.IN_PROGRESS, PlanStatus.COMPLETED, PlanStatus.CANCELLED]));
    this.allowedTransitions.set(PlanStatus.COMPLETED, new Set<PlanStatus>());
    this.allowedTransitions.set(PlanStatus.CANCELLED, new Set<PlanStatus>());
    this.allowedTransitions.set(PlanStatus.EXPIRED, new Set<PlanStatus>());
  }

  public canTransition(fromStatus: PlanStatus, targetStatus: PlanStatus): boolean {
    if (fromStatus === targetStatus) {
      return true;
    }
    const set = this.allowedTransitions.get(fromStatus);
    if (!set) {
      return false;
    }
    return set.has(targetStatus);
  }

  public transitionPlanStatus(
    currentStatus: PlanStatus,
    command: TransitionCommand
  ): TransitionResult {
    if (currentStatus === command.targetStatus) {
      return {
        success: true,
        planId: command.planId,
        fromStatus: currentStatus,
        toStatus: command.targetStatus
      };
    }

    if (command.expectedFromStatus && command.expectedFromStatus !== currentStatus) {
      return {
        success: false,
        planId: command.planId,
        fromStatus: currentStatus,
        toStatus: command.targetStatus,
        errorCode: 'STATUS_CONFLICT',
        errorMessage: 'Current status does not match expectedFromStatus.'
      };
    }

    if (!this.canTransition(currentStatus, command.targetStatus)) {
      return {
        success: false,
        planId: command.planId,
        fromStatus: currentStatus,
        toStatus: command.targetStatus,
        errorCode: 'INVALID_TRANSITION',
        errorMessage: 'Transition is not allowed by transition table.'
      };
    }

    const now = Date.now();
    const event: PlanTransitionEvent = {
      planId: command.planId,
      fromStatus: currentStatus,
      toStatus: command.targetStatus,
      triggerSource: command.triggerSource,
      triggerReason: command.triggerReason,
      timestamp: now,
      payload: command.payload
    };

    return {
      success: true,
      planId: command.planId,
      fromStatus: currentStatus,
      toStatus: command.targetStatus,
      event: event
    };
  }
}
