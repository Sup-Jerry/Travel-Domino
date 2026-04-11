import { describe, expect, it } from '@ohos/hypium';
import { TimelineCompressionCoordinator } from '../main/ets/viewmodel/coordinators/TimelineCompressionCoordinator';
import {
  AdvanceAdjustApplyResult,
  AdvanceAdjustContext,
  AdvanceAdjustPreview,
  CompressionPlan,
  CompressionSelectionContext,
  ITimelineCompressionService
} from '../main/ets/domain/timeline/services/TimelineCompressionService';
import { EventEntity } from '../main/ets/model/entity/EventEntity';

class CompressionServiceSpy implements ITimelineCompressionService {
  callLog: string[] = [];
  lastTargetIndex: number = -1;
  lastForcedGap: number = -1;
  lastSelectedSize: number = 0;

  private buildPlan(status: 'NO_ACTION' | 'COMPRESS_CONFIRM' | 'OVERLOAD' | 'FAIL_TOO_SHORT', msg: string): CompressionPlan {
    return { status: status, msg: msg, affectedItems: [] };
  }

  async fixConflict(_item: EventEntity, _shiftMinutes: number): Promise<void> {
    this.callLog.push('fixConflict');
  }

  async smartFixConflict(_targetItem: EventEntity): Promise<void> {
    this.callLog.push('smartFixConflict');
  }

  calculateCompressionPlan(targetIndex: number, _newTimeStr: string, forcedGapMinutes?: number): CompressionPlan {
    this.callLog.push('calculateCompressionPlan');
    this.lastTargetIndex = targetIndex;
    this.lastForcedGap = Number(forcedGapMinutes ?? -1);
    return this.buildPlan('COMPRESS_CONFIRM', 'ok');
  }

  buildCompressionSelectionContext(targetIndex: number, _targetTime: string, _forcedGapMinutes?: number): CompressionSelectionContext | null {
    this.callLog.push('buildCompressionSelectionContext');
    this.lastTargetIndex = targetIndex;
    return null;
  }

  buildAdvanceAdjustContext(targetIndex: number): AdvanceAdjustContext | null {
    this.callLog.push('buildAdvanceAdjustContext');
    this.lastTargetIndex = targetIndex;
    return null;
  }

  previewAdvanceAdjust(targetIndex: number, selectedIds: Set<number>, _targetStartTime: string, _forcedGapMinutes?: number): AdvanceAdjustPreview {
    this.callLog.push('previewAdvanceAdjust');
    this.lastTargetIndex = targetIndex;
    this.lastSelectedSize = selectedIds.size;
    return {
      valid: true,
      message: 'preview',
      selectedCount: selectedIds.size,
      shiftMinutes: 10,
      requiredGapMinutes: 20,
      remainingGapMinutes: 10,
      firstNewStartTime: '09:00',
      lastNewEndTime: '10:00',
      items: []
    };
  }

  async applyAdvanceAdjust(
    targetIndex: number,
    selectedIds: Set<number>,
    _targetStartTime: string,
    _forcedGapMinutes?: number
  ): Promise<AdvanceAdjustApplyResult> {
    this.callLog.push('applyAdvanceAdjust');
    this.lastTargetIndex = targetIndex;
    this.lastSelectedSize = selectedIds.size;
    return {
      success: true,
      appliedCount: selectedIds.size,
      appliedShiftMinutes: 8,
      remainingGapMinutes: 0,
      message: 'applied'
    };
  }

  calculateCompressionPlanBySelection(
    targetIndex: number,
    _targetTime: string,
    selectedIds: Set<number>
  ): CompressionPlan {
    this.callLog.push('calculateCompressionPlanBySelection');
    this.lastTargetIndex = targetIndex;
    this.lastSelectedSize = selectedIds.size;
    return this.buildPlan('OVERLOAD', 'need_more');
  }

  applyCompressionPlan(_plan: CompressionPlan): void {
    this.callLog.push('applyCompressionPlan');
  }

  calculateDelayPlan(targetIndex: number): CompressionPlan {
    this.callLog.push('calculateDelayPlan');
    this.lastTargetIndex = targetIndex;
    return this.buildPlan('COMPRESS_CONFIRM', 'delay');
  }

  calculateForceCompressPlan(targetIndex: number, _newTimeStr: string): CompressionPlan {
    this.callLog.push('calculateForceCompressPlan');
    this.lastTargetIndex = targetIndex;
    return this.buildPlan('FAIL_TOO_SHORT', 'too_short');
  }

  calculateNaturalArrival(targetIndex: number): number {
    this.callLog.push('calculateNaturalArrival');
    this.lastTargetIndex = targetIndex;
    return 615;
  }
}

export default function timelineCompressionCoordinatorTest() {
  describe('timelineCompressionCoordinatorTest', () => {
    it('normal: calculate_compression_plan_should_delegate_to_service', 0, () => {
      // Arrange
      const service = new CompressionServiceSpy();
      const coordinator = new TimelineCompressionCoordinator(service);
      // Act
      const plan = coordinator.calculateCompressionPlan(3, '10:00', 15);
      // Assert
      expect(plan.status).assertEqual('COMPRESS_CONFIRM');
      expect(service.lastTargetIndex).assertEqual(3);
      expect(service.lastForcedGap).assertEqual(15);
    });

    it('boundary: preview_advance_adjust_should_handle_empty_selection', 0, () => {
      // Arrange
      const service = new CompressionServiceSpy();
      const coordinator = new TimelineCompressionCoordinator(service);
      const selectedIds = new Set<number>();
      // Act
      const preview = coordinator.previewAdvanceAdjust(2, selectedIds, '09:30');
      // Assert
      expect(preview.valid).assertTrue();
      expect(preview.selectedCount).assertEqual(0);
      expect(service.lastSelectedSize).assertEqual(0);
    });

    it('invalid: build_compression_selection_context_should_return_null_when_service_returns_null', 0, () => {
      // Arrange
      const service = new CompressionServiceSpy();
      const coordinator = new TimelineCompressionCoordinator(service);
      // Act
      const context = coordinator.buildCompressionSelectionContext(1, '09:00');
      // Assert
      expect(context === null).assertTrue();
    });

    it('conflict: apply_compression_plan_should_forward_even_when_plan_overload', 0, () => {
      // Arrange
      const service = new CompressionServiceSpy();
      const coordinator = new TimelineCompressionCoordinator(service);
      const overloadPlan: CompressionPlan = { status: 'OVERLOAD', msg: 'need_more', affectedItems: [] };
      // Act
      coordinator.applyCompressionPlan(overloadPlan);
      // Assert
      expect(service.callLog.includes('applyCompressionPlan')).assertTrue();
    });

    it('regression: td-20260411-c4-smart-fix-conflict-should-await-service-call', 0, async (done: () => void) => {
      // Arrange
      const service = new CompressionServiceSpy();
      const coordinator = new TimelineCompressionCoordinator(service);
      const target = new EventEntity('target', 1);
      // Act
      await coordinator.smartFixConflict(target);
      // Assert
      expect(service.callLog.includes('smartFixConflict')).assertTrue();
      done();
    });

    it('combined: selection_plan_and_apply_should_keep_selected_size_consistent', 0, async (done: () => void) => {
      // Arrange
      const service = new CompressionServiceSpy();
      const coordinator = new TimelineCompressionCoordinator(service);
      const selected = new Set<number>([11, 12]);
      // Act
      const plan = coordinator.calculateCompressionPlanBySelection(4, '11:00', selected, 'RATIO', 20);
      const applyResult = await coordinator.applyAdvanceAdjust(4, selected, '10:30', 20);
      // Assert
      expect(plan.status).assertEqual('OVERLOAD');
      expect(applyResult.success).assertTrue();
      expect(applyResult.appliedCount).assertEqual(2);
      expect(service.lastSelectedSize).assertEqual(2);
      done();
    });
  });
}
