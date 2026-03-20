export enum PlanStatus {
  DRAFT = 'DRAFT',
  CONFIRMED = 'CONFIRMED',
  READY = 'READY',
  IN_PROGRESS = 'IN_PROGRESS',
  PAUSED = 'PAUSED',
  COMPLETED = 'COMPLETED',
  CANCELLED = 'CANCELLED',
  EXPIRED = 'EXPIRED'
}

export enum TransitionTriggerSource {
  USER_ACTION = 'USER_ACTION',
  TIME_WINDOW = 'TIME_WINDOW',
  LOCATION_PROXIMITY = 'LOCATION_PROXIMITY',
  MOTION_DETECTED = 'MOTION_DETECTED',
  SYSTEM_RECOVERY = 'SYSTEM_RECOVERY',
  PLAN_TIMEOUT = 'PLAN_TIMEOUT',
  TASK_COMPLETION = 'TASK_COMPLETION',
  MANUAL_OVERRIDE = 'MANUAL_OVERRIDE'
}

export function isTerminalPlanStatus(status: PlanStatus): boolean {
  return status === PlanStatus.COMPLETED ||
    status === PlanStatus.CANCELLED ||
    status === PlanStatus.EXPIRED;
}

export function canAutoTransition(status: PlanStatus): boolean {
  return !isTerminalPlanStatus(status);
}
