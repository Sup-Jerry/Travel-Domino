import { EventEntity } from '../../model/entity/EventEntity';
import {
  AdvanceAdjustApplyResult as ServiceAdvanceAdjustApplyResult,
  AdvanceAdjustCandidate as ServiceAdvanceAdjustCandidate,
  AdvanceAdjustContext as ServiceAdvanceAdjustContext,
  AdvanceAdjustPreview as ServiceAdvanceAdjustPreview,
  AdvanceAdjustPreviewItem as ServiceAdvanceAdjustPreviewItem,
  CompressionMode as ServiceCompressionMode,
  CompressionPlan as ServiceCompressionPlan,
  CompressionSelectionCandidate as ServiceCompressionSelectionCandidate,
  CompressionSelectionContext as ServiceCompressionSelectionContext
} from '../../domain/timeline/services/TimelineCompressionService';
import { ExecutionSuggestionApplyResult as ServiceExecutionSuggestionApplyResult } from '../../domain/timeline/services/TimelineAiService';
import { StartConflictInfo as ServiceStartConflictInfo } from '../../domain/timeline/services/TimelineExecutionService';

export type CompressionPlan = ServiceCompressionPlan;
export type CompressionMode = ServiceCompressionMode;
export type CompressionSelectionCandidate = ServiceCompressionSelectionCandidate;
export type CompressionSelectionContext = ServiceCompressionSelectionContext;
export type AdvanceAdjustCandidate = ServiceAdvanceAdjustCandidate;
export type AdvanceAdjustContext = ServiceAdvanceAdjustContext;
export type AdvanceAdjustPreviewItem = ServiceAdvanceAdjustPreviewItem;
export type AdvanceAdjustPreview = ServiceAdvanceAdjustPreview;
export type AdvanceAdjustApplyResult = ServiceAdvanceAdjustApplyResult;
export type ExecutionSuggestionApplyResult = ServiceExecutionSuggestionApplyResult;
export type StartConflictInfo = ServiceStartConflictInfo;

export interface PlanDateShiftPreview {
  hasRigidConflict: boolean;
  conflictItemId: number;
  conflictItemName: string;
  gapMinutes: number;
  conflictMsg: string;
}

export type HistoryTimelineFilter = 'all' | 'completed' | 'skipped' | 'abnormal';
export type HistoryTimelineActionType = 'ARRIVE' | 'LEAVE' | 'SKIP' | 'ACTIVE';

export interface HistoryTimelineItem {
  id: number;
  eventId: number;
  placeName: string;
  actionType: HistoryTimelineActionType;
  plannedStart: number;
  actualStart: number;
  actualEnd: number;
  stayMinutes: number;
  deviationMinutes: number;
  status: number;
  groupDateKey: string;
  address: string;
  note: string;
  displayTs: number;
  isAbnormal: boolean;
}

export interface HistoryTimelineSummary {
  planName: string;
  completedCount: number;
  skippedCount: number;
  activeCount: number;
}

export type CompanionRuntimeState = 'IDLE' | 'READY' | 'ACTIVE' | 'PAUSED' | 'GAP';

export interface ReflowHint {
  type: 'reflow' | 'shift' | 'next_changed';
  minutesDelta: number;
  message: string;
  updatedAt: number;
}

export interface CompanionActions {
  canStart: boolean;
  canPause: boolean;
  canResume: boolean;
  canEnd: boolean;
  canSkip: boolean;
  canNavigate: boolean;
  canViewDetail: boolean;
}

export interface CompanionContext {
  runtimeState: CompanionRuntimeState;
  currentEvent: EventEntity | null;
  nextEvent: EventEntity | null;
  hint: ReflowHint | null;
  actions: CompanionActions;
}

export interface SolverCalculatedItem {
  isConflict?: boolean;
  conflictMsg?: string;
  computedStartTime?: string;
  preTravelMinutes?: number;
  hasGap?: boolean;
  gapMinutes?: number;
  naturalStartTime?: string;
  transitWarning?: boolean;
  dynamicDayOffset?: number;
  dayOffset?: number;
  dynamicStartTime?: number;
  dynamicEndTime?: number;
}

export interface ApplyResultFlags {
  changed: boolean;
  dayOffsetChanged: boolean;
}
