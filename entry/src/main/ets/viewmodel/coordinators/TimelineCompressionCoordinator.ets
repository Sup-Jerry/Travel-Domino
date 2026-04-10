import { hilog } from '@kit.PerformanceAnalysisKit';
import { EventEntity } from '../../model/entity/EventEntity';
import {
  AdvanceAdjustApplyResult,
  AdvanceAdjustContext,
  AdvanceAdjustPreview,
  CompressionMode,
  CompressionPlan,
  CompressionSelectionContext,
  ITimelineCompressionService
} from '../../domain/timeline/services/TimelineCompressionService';

const TAG = 'TimelineViewModel';

export class TimelineCompressionCoordinator {
  private readonly compressionService: ITimelineCompressionService;

  constructor(compressionService: ITimelineCompressionService) {
    this.compressionService = compressionService;
  }

  public async smartFixConflict(targetItem: EventEntity): Promise<void> {
    await this.compressionService.smartFixConflict(targetItem);
  }

  public calculateCompressionPlan(targetIndex: number, newTimeStr: string, forcedGapMinutes?: number): CompressionPlan {
    hilog.info(
      0x0000,
      TAG,
      `[ACPT][COMPRESS][calculateCompressionPlan] targetIndex=${targetIndex}, newTime=${newTimeStr}, forcedGap=${forcedGapMinutes ?? -1}`
    );
    return this.compressionService.calculateCompressionPlan(targetIndex, newTimeStr, forcedGapMinutes);
  }

  public buildCompressionSelectionContext(
    targetIndex: number,
    targetTime: string,
    forcedGapMinutes?: number
  ): CompressionSelectionContext | null {
    hilog.info(
      0x0000,
      TAG,
      `[ACPT][COMPRESS][buildSelectionContext] targetIndex=${targetIndex}, targetTime=${targetTime}, forcedGap=${forcedGapMinutes ?? -1}`
    );
    return this.compressionService.buildCompressionSelectionContext(targetIndex, targetTime, forcedGapMinutes);
  }

  public buildAdvanceAdjustContext(targetIndex: number): AdvanceAdjustContext | null {
    return this.compressionService.buildAdvanceAdjustContext(targetIndex);
  }

  public previewAdvanceAdjust(
    targetIndex: number,
    selectedIds: Set<number>,
    targetStartTime: string,
    forcedGapMinutes?: number
  ): AdvanceAdjustPreview {
    hilog.info(
      0x0000,
      TAG,
      `[ACPT][COMPRESS][previewAdvanceAdjust] targetIndex=${targetIndex}, selected=${selectedIds.size}, targetStart=${targetStartTime}, forcedGap=${forcedGapMinutes ?? -1}`
    );
    return this.compressionService.previewAdvanceAdjust(targetIndex, selectedIds, targetStartTime, forcedGapMinutes);
  }

  public async applyAdvanceAdjust(
    targetIndex: number,
    selectedIds: Set<number>,
    targetStartTime: string,
    forcedGapMinutes?: number
  ): Promise<AdvanceAdjustApplyResult> {
    hilog.info(
      0x0000,
      TAG,
      `[ACPT][COMPRESS][applyAdvanceAdjust] targetIndex=${targetIndex}, selected=${selectedIds.size}, targetStart=${targetStartTime}, forcedGap=${forcedGapMinutes ?? -1}`
    );
    return this.compressionService.applyAdvanceAdjust(targetIndex, selectedIds, targetStartTime, forcedGapMinutes);
  }

  public calculateCompressionPlanBySelection(
    targetIndex: number,
    targetTime: string,
    selectedIds: Set<number>,
    mode: CompressionMode = 'RATIO',
    forcedGapMinutes?: number
  ): CompressionPlan {
    return this.compressionService.calculateCompressionPlanBySelection(targetIndex, targetTime, selectedIds, mode, forcedGapMinutes);
  }

  public applyCompressionPlan(plan: CompressionPlan): void {
    hilog.info(0x0000, TAG, `[ACPT][COMPRESS][applyCompressionPlan] status=${plan.status}, msg=${plan.msg}`);
    this.compressionService.applyCompressionPlan(plan);
  }

  public calculateDelayPlan(targetIndex: number): CompressionPlan {
    return this.compressionService.calculateDelayPlan(targetIndex);
  }

  public calculateForceCompressPlan(targetIndex: number, newTimeStr: string): CompressionPlan {
    return this.compressionService.calculateForceCompressPlan(targetIndex, newTimeStr);
  }

  public calculateNaturalArrival(targetIndex: number): number {
    return this.compressionService.calculateNaturalArrival(targetIndex);
  }
}
