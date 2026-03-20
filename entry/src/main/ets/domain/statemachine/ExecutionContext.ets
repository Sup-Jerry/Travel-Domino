import { PlanStatus, TransitionTriggerSource } from './PlanStatus';

export interface PlanTransitionEvent {
  planId: string;
  fromStatus: PlanStatus;
  toStatus: PlanStatus;
  triggerSource: TransitionTriggerSource;
  triggerReason: string;
  timestamp: number;
  payload?: Record<string, Object>;
}

export interface AutoTransitionStats {
  readyAttempt: number;
  readySuccess: number;
  readyFail: number;
  inProgressAttempt: number;
  inProgressSuccess: number;
  inProgressFail: number;
  jitterBlocked: number;
}

export interface ExecutionContext {
  planId: string;
  status: PlanStatus;
  plannedStartTime: number;
  plannedEndTime: number;
  actualStartTime?: number;
  actualEndTime?: number;
  currentNodeId?: string;
  nextNodeId?: string;
  completedNodeIds: string[];
  skippedNodeIds: string[];
  lastKnownLatitude?: number;
  lastKnownLongitude?: number;
  lastKnownSpeed?: number;
  lastKnownAccuracy?: number;
  lastLocationUpdateTime?: number;
  lastTransitionAt?: number;
  distanceToFirstNodeMeters?: number;
  autoTransitionStats?: AutoTransitionStats;
  isAutoStarted: boolean;
  isPaused: boolean;
  lastTransitionReason?: string;
  weatherSnapshotVersion?: string;
  updatedAt: number;
}

export interface StateEvaluationInput {
  planId: string;
  currentStatus: PlanStatus;
  now: number;
  firstNodeStartTime?: number;
  firstNodeLat?: number;
  firstNodeLng?: number;
  lastKnownLat?: number;
  lastKnownLng?: number;
  currentSpeed?: number;
  currentAccuracy?: number;
  motionDistanceMeters?: number;
  lastTransitionAt?: number;
  locationPermissionGranted: boolean;
  userClickedStart: boolean;
  userClickedPause: boolean;
  userClickedResume: boolean;
  userClickedCancel: boolean;
  hasReachedFirstNode: boolean;
  motionDetected: boolean;
  allNodesCompleted: boolean;
  isPlanExpired: boolean;
}

export interface EvaluateStatusResult {
  currentStatus: PlanStatus;
  suggestedStatus: PlanStatus;
  shouldTransition: boolean;
  triggerSource?: TransitionTriggerSource;
  triggerReason?: string;
}

export interface TransitionCommand {
  planId: string;
  expectedFromStatus?: PlanStatus;
  targetStatus: PlanStatus;
  triggerSource: TransitionTriggerSource;
  triggerReason: string;
  payload?: Record<string, Object>;
}

export interface TransitionResult {
  success: boolean;
  planId: string;
  fromStatus: PlanStatus;
  toStatus: PlanStatus;
  event?: PlanTransitionEvent;
  errorCode?: string;
  errorMessage?: string;
}

export interface GetPlanStatusResult {
  planId: string;
  status: PlanStatus;
  lastTransitionTime?: number;
  lastTransitionReason?: string;
  isAutoStarted: boolean;
}

export interface UpdateExecutionContextCommand {
  planId: string;
  currentNodeId?: string;
  nextNodeId?: string;
  completedNodeIds?: string[];
  skippedNodeIds?: string[];
  lastKnownLatitude?: number;
  lastKnownLongitude?: number;
  lastKnownSpeed?: number;
  lastKnownAccuracy?: number;
  distanceToFirstNodeMeters?: number;
  weatherSnapshotVersion?: string;
  updatedAt: number;
}

export interface PlanStageViewModel {
  planId: string;
  status: PlanStatus;
  stageLabel: string;
  canStart: boolean;
  canPause: boolean;
  canResume: boolean;
  canCancel: boolean;
  canReplan: boolean;
  weatherMode: 'PLAN_LOCATION' | 'CURRENT_AND_PLAN' | 'CURRENT_PRIORITY' | 'DISABLED';
  statusHint?: string;
}

export function createDefaultExecutionContext(
  planId: string,
  now: number,
  plannedStartTime: number = now,
  plannedEndTime: number = now
): ExecutionContext {
  return {
    planId: planId,
    status: PlanStatus.DRAFT,
    plannedStartTime: plannedStartTime,
    plannedEndTime: plannedEndTime,
    completedNodeIds: [],
    skippedNodeIds: [],
    autoTransitionStats: {
      readyAttempt: 0,
      readySuccess: 0,
      readyFail: 0,
      inProgressAttempt: 0,
      inProgressSuccess: 0,
      inProgressFail: 0,
      jitterBlocked: 0
    },
    isAutoStarted: false,
    isPaused: false,
    updatedAt: now
  };
}

