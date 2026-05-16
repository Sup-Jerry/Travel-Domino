import { describe, it, expect } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import {
  GapResolutionDialog,
  hasPositiveAllocationValues,
  resolveGapTierColor,
  resolveGapTierLabel
} from '../main/ets/pages/components/dialogs/GapResolutionDialog';

interface GapPreviewHelper {
  timeRange: string;
  addStr: string;
}

interface GapDialogHostHelper {
  vm: GapVmMockHelper;
  strategy: 'EQUAL' | 'SMART';
  selectedIds: Set<number>;
  currentGap: EventEntity | null;
  gapList: EventEntity[];
  candidates: EventEntity[];
  refreshGaps(): void;
  selectGap(item: EventEntity): void;
  getPreview(item: EventEntity): GapPreviewHelper;
  getAllocatableCandidates(): EventEntity[];
  isCandidateAllocatable(item: EventEntity): boolean;
}

type GapDialogArgHelper = Object | string | number | boolean | undefined;
type GapDialogMethodHelper<TArgs extends GapDialogArgHelper[], TResult> = (this: GapDialogHostImplHelper, ...args: TArgs) => TResult;

class GapDistributionCoordinatorMockHelper {
  sortedGaps: EventEntity[] = [];
  candidatesByGapId: Map<number, EventEntity[]> = new Map<number, EventEntity[]>();
  safetyCaps: Map<number, number> = new Map<number, number>();
  previewMap: Map<number, number> = new Map<number, number>();

  getSortedGaps(): EventEntity[] {
    return this.sortedGaps;
  }

  getDistributionCandidates(item: EventEntity): EventEntity[] {
    return this.candidatesByGapId.get(item.id) ?? [];
  }

  getSafetyCap(item: EventEntity, _gap: EventEntity): number {
    return this.safetyCaps.get(item.id) ?? 0;
  }

  calculateDistributionPreview(
    _gap: EventEntity,
    candidates: EventEntity[],
    selectedIds: Set<number>,
    _strategy: 'EQUAL' | 'SMART'
  ): Map<number, number> {
    if (this.previewMap.size > 0) {
      return this.previewMap;
    }
    const result = new Map<number, number>();
    candidates.forEach((candidate: EventEntity) => {
      result.set(candidate.id, selectedIds.has(candidate.id) ? (this.safetyCaps.get(candidate.id) ?? 0) : 0);
    });
    return result;
  }
}

class GapVmMockHelper {
  distributionCoordinator: GapDistributionCoordinatorMockHelper = new GapDistributionCoordinatorMockHelper();
  trigger: number = 30;

  getIdleGapTriggerMinutes(): number {
    return this.trigger;
  }
}

class GapDialogHostImplHelper implements GapDialogHostHelper {
  vm: GapVmMockHelper;
  strategy: 'EQUAL' | 'SMART' = 'EQUAL';
  selectedIds: Set<number> = new Set<number>();
  currentGap: EventEntity | null = null;
  gapList: EventEntity[] = [];
  candidates: EventEntity[] = [];

  constructor(vm: GapVmMockHelper) {
    this.vm = vm;
  }

  refreshGaps(): void {
    invokeGapDialogMethodHelper(gapRefreshGapsHelper, this);
  }

  selectGap(item: EventEntity): void {
    invokeGapDialogMethodHelper(gapSelectGapHelper, this, item);
  }

  getPreview(item: EventEntity): GapPreviewHelper {
    return invokeGapDialogMethodHelper(gapGetPreviewHelper, this, item);
  }

  getAllocatableCandidates(): EventEntity[] {
    return invokeGapDialogMethodHelper(gapGetAllocatableCandidatesHelper, this);
  }

  isCandidateAllocatable(item: EventEntity): boolean {
    return invokeGapDialogMethodHelper(gapIsCandidateAllocatableHelper, this, item);
  }

}

function buildGapEventHelper(
  id: number,
  name: string,
  gapMinutes: number,
  computedTime: string,
  duration: number = 60
): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = name;
  event.gap_minutes = gapMinutes;
  event.computed_time = computedTime;
  event.duration = duration;
  event.status = 1;
  event.lock_status = 0;
  event.priority = 0;
  event.source = 0;
  return event;
}

function getGapDialogMethodHelper<TArgs extends GapDialogArgHelper[], TResult>(name: string): GapDialogMethodHelper<TArgs, TResult> {
  const prototype = Reflect.get(GapResolutionDialog as Object, 'prototype') as Object;
  return Reflect.get(prototype, name) as GapDialogMethodHelper<TArgs, TResult>;
}

function invokeGapDialogMethodHelper<TArgs extends GapDialogArgHelper[], TResult>(
  method: GapDialogMethodHelper<TArgs, TResult>,
  host: GapDialogHostImplHelper,
  ...args: TArgs
): TResult {
  const bound = method.bind(host) as (...boundArgs: TArgs) => TResult;
  return bound(...args);
}

const gapRefreshGapsHelper = getGapDialogMethodHelper<[], void>('refreshGaps');
const gapSelectGapHelper = getGapDialogMethodHelper<[EventEntity], void>('selectGap');
const gapGetPreviewHelper = getGapDialogMethodHelper<[EventEntity], GapPreviewHelper>('getPreview');
const gapGetAllocatableCandidatesHelper = getGapDialogMethodHelper<[], EventEntity[]>('getAllocatableCandidates');
const gapIsCandidateAllocatableHelper = getGapDialogMethodHelper<[EventEntity], boolean>('isCandidateAllocatable');

function createDialogHelper(vm: GapVmMockHelper): GapDialogHostHelper {
  return new GapDialogHostImplHelper(vm);
}

export default function gapResolutionDialogHelperTest() {
  describe('unit_test_case_generator_autofill_GapResolutionDialogHelper', () => {
    it('normal: gap_resolution_should_resolve_green_tier_label_and_color_at_trigger', 0, () => {
      // Arrange
      const min = 30;
      const trigger = 30;
      // Act
      const color = resolveGapTierColor(min, trigger);
      const label = resolveGapTierLabel(min, trigger);
      // Assert
      expect(color).assertEqual('#4CAF50');
      expect(label).assertEqual('\u6548\u7387\u8865\u5168');
    });

    it('boundary: gap_resolution_should_auto_select_single_gap_and_build_preview', 0, () => {
      // Arrange
      const vm = new GapVmMockHelper();
      const dialog = createDialogHelper(vm);
      const gap = buildGapEventHelper(100, 'afternoon-gap', 75, '2026-05-16 10:00');
      const candidate = buildGapEventHelper(1, 'museum', 0, '2026-05-16 11:00', 45);
      vm.distributionCoordinator.sortedGaps = [gap];
      vm.distributionCoordinator.candidatesByGapId.set(gap.id, [candidate]);
      vm.distributionCoordinator.safetyCaps.set(candidate.id, 15);
      dialog.selectedIds = new Set<number>([candidate.id]);
      // Act
      dialog.refreshGaps();
      dialog.selectedIds = new Set<number>([candidate.id]);
      const preview = dialog.getPreview(candidate);
      // Assert
      expect(dialog.currentGap?.id ?? -1).assertEqual(gap.id);
      expect(dialog.candidates.length).assertEqual(1);
      expect(dialog.selectedIds.has(candidate.id)).assertTrue();
      expect(preview.timeRange).assertEqual('11:00-11:45 \u2192 12:00');
      expect(preview.addStr).assertEqual('(+15m)');
    });

    it('invalid: gap_resolution_should_fallback_to_empty_preview_without_current_gap', 0, () => {
      // Arrange
      const vm = new GapVmMockHelper();
      const dialog = createDialogHelper(vm);
      const candidate = buildGapEventHelper(2, 'cafe', 0, '', 20);
      // Act
      const preview = dialog.getPreview(candidate);
      const allocatableCandidates = dialog.getAllocatableCandidates();
      const allocatable = dialog.isCandidateAllocatable(candidate);
      // Assert
      expect(preview.timeRange).assertEqual('00:00-00:20 \u2192 00:20');
      expect(preview.addStr).assertEqual('');
      expect(allocatableCandidates.length).assertEqual(0);
      expect(allocatable).assertFalse();
    });

    it('conflict: gap_resolution_should_filter_out_non_allocatable_candidates', 0, () => {
      // Arrange
      const vm = new GapVmMockHelper();
      const dialog = createDialogHelper(vm);
      const gap = buildGapEventHelper(200, 'pre-lunch-gap', 95, '2026-05-16 11:30');
      const positiveCandidate = buildGapEventHelper(3, 'art-zone', 0, '2026-05-16 09:00', 30);
      const blockedCandidate = buildGapEventHelper(4, 'locked-museum', 0, '2026-05-16 10:00', 40);
      vm.distributionCoordinator.candidatesByGapId.set(gap.id, [positiveCandidate, blockedCandidate]);
      vm.distributionCoordinator.safetyCaps.set(positiveCandidate.id, 20);
      vm.distributionCoordinator.safetyCaps.set(blockedCandidate.id, 0);
      dialog.selectGap(gap);
      // Act
      const allocatableCandidates = dialog.getAllocatableCandidates();
      const positiveAllocatable = dialog.isCandidateAllocatable(positiveCandidate);
      const blockedAllocatable = dialog.isCandidateAllocatable(blockedCandidate);
      // Assert
      expect(dialog.currentGap?.id ?? -1).assertEqual(gap.id);
      expect(dialog.selectedIds.size).assertEqual(0);
      expect(allocatableCandidates.length).assertEqual(1);
      expect(positiveAllocatable).assertTrue();
      expect(blockedAllocatable).assertFalse();
    });

    it('regression: td-20260516-gap-resolution-refresh-should-clear-stale-current-gap-for-multiple-gaps', 0, () => {
      // Arrange
      const vm = new GapVmMockHelper();
      const dialog = createDialogHelper(vm);
      const gapA = buildGapEventHelper(300, 'breakfast-gap', 45, '2026-05-16 09:00');
      const gapB = buildGapEventHelper(301, 'evening-gap', 160, '2026-05-16 18:00');
      dialog.currentGap = gapA;
      vm.distributionCoordinator.sortedGaps = [gapA, gapB];
      // Act
      dialog.refreshGaps();
      // Assert
      expect(dialog.currentGap === null).assertTrue();
      expect(dialog.gapList.length).assertEqual(2);
    });

    it('combined: gap_resolution_should_align_blue_tier_and_positive_allocation', 0, () => {
      // Arrange
      const min = 90;
      const trigger = 30;
      const values = [0, 10, 0];
      // Act
      const color = resolveGapTierColor(min, trigger);
      const label = resolveGapTierLabel(min, trigger);
      const hasPositive = hasPositiveAllocationValues(values);
      // Assert
      expect(color).assertEqual('#007DFF');
      expect(label).assertEqual('\u4F53\u9A8C\u5347\u7EA7');
      expect(hasPositive).assertTrue();
    });

    it('boundary: gap_resolution_should_return_empty_tier_below_trigger', 0, () => {
      // Arrange
      const min = 29;
      const trigger = 30;
      // Act
      const color = resolveGapTierColor(min, trigger);
      const label = resolveGapTierLabel(min, trigger);
      // Assert
      expect(color).assertEqual('');
      expect(label).assertEqual('');
    });

    it('invalid: gap_resolution_positive_allocation_should_reject_empty_and_non_positive_values', 0, () => {
      // Arrange
      const emptyValues: number[] = [];
      const nonPositiveValues = [0, -1, 0];
      // Act
      const emptyResult = hasPositiveAllocationValues(emptyValues);
      const nonPositiveResult = hasPositiveAllocationValues(nonPositiveValues);
      // Assert
      expect(emptyResult).assertFalse();
      expect(nonPositiveResult).assertFalse();
    });
  });
}
