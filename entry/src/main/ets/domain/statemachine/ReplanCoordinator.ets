import { ExecutionContext } from './ExecutionContext';
import { PlanStatus } from './PlanStatus';
import { ReplanChangeSummaryItem } from '../services/WeatherModels';

export interface ReplanResult {
  success: boolean;
  planId: string;
  changed: boolean;
  changeSummary?: ReplanChangeSummaryItem[];
  newPlanVersion?: string;
  errorCode?: string;
  reasonCode?: string;
  affectedNodeIds?: string[];
  startFromEventId?: number;
  preserveCompletedNodes?: boolean;
}

export interface SoftReplanCommand {
  planId: string;
  reason: string;
  currentNodeId?: string;
  preserveCompletedNodes: boolean;
  preserveStartedWindow: boolean;
  useWeatherConstraint: boolean;
}

export interface FullReplanCommand {
  planId: string;
  reason: string;
  triggeredBy: string;
  useWeatherConstraint: boolean;
}

export class ReplanCoordinator {
  public onStateEntered(_status: PlanStatus, _context: ExecutionContext): void {
    // Keep extension point for future scheduler/inference integration.
  }

  public requestSoftReplan(command: SoftReplanCommand, context: ExecutionContext): ReplanResult {
    if (!this.canSoftReplanStatus(context.status)) {
      return {
        success: false,
        planId: command.planId,
        changed: false,
        errorCode: 'REPLAN_INVALID',
        reasonCode: 'status_blocked'
      };
    }

    const completed = context.completedNodeIds ?? [];
    const currentNodeId = command.currentNodeId && command.currentNodeId.trim().length > 0
      ? command.currentNodeId.trim()
      : context.currentNodeId;

    const summary: ReplanChangeSummaryItem[] = [{
      type: 'NO_OP',
      nodeId: currentNodeId ?? '',
      before: `reason=${command.reason}`,
      after: `completed=${completed.length};preserve=${command.preserveCompletedNodes};weather=${command.useWeatherConstraint}`
    }];

    return {
      success: true,
      planId: command.planId,
      changed: true,
      reasonCode: 'weather_soft_replan',
      affectedNodeIds: [],
      startFromEventId: this.toEventId(currentNodeId),
      preserveCompletedNodes: command.preserveCompletedNodes,
      changeSummary: summary,
      newPlanVersion: `soft_${Date.now()}`
    };
  }

  public requestFullReplan(command: FullReplanCommand, status: PlanStatus): ReplanResult {
    if (status !== PlanStatus.DRAFT && status !== PlanStatus.CONFIRMED) {
      return {
        success: false,
        planId: command.planId,
        changed: false,
        errorCode: 'REPLAN_INVALID',
        reasonCode: 'status_blocked'
      };
    }

    return {
      success: true,
      planId: command.planId,
      changed: true,
      reasonCode: 'full_replan',
      changeSummary: [{
        type: 'NO_OP',
        nodeId: '',
        before: `reason=${command.reason}`,
        after: `triggered_by=${command.triggeredBy};weather=${command.useWeatherConstraint}`
      }],
      newPlanVersion: `full_${Date.now()}`
    };
  }

  private canSoftReplanStatus(status: PlanStatus): boolean {
    return status === PlanStatus.READY || status === PlanStatus.IN_PROGRESS || status === PlanStatus.PAUSED;
  }

  private toEventId(nodeId?: string): number {
    if (!nodeId) {
      return 0;
    }
    const id = Number(nodeId);
    if (!Number.isFinite(id) || id <= 0) {
      return 0;
    }
    return Math.floor(id);
  }
}
