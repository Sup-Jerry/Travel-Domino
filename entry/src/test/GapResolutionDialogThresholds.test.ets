import { describe, it, expect } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import {
  GapResolutionDialog,
  hasPositiveAllocationValues,
  resolveGapTierColor,
  resolveGapTierLabel
} from '../main/ets/pages/components/dialogs/GapResolutionDialog';

interface GapPreviewTest {
  timeRange: string;
  addStr: string;
}

interface GapResolutionDialogPrivateTest {
  controller: GapDialogControllerMockTest;
  vm: GapVmMockTest;
  strategy: 'EQUAL' | 'SMART';
  selectedIds: Set<number>;
  currentGap: EventEntity | null;
  gapList: EventEntity[];
  candidates: EventEntity[];
  aboutToAppear(): void;
  refreshGaps(): void;
  selectGap(item: EventEntity): void;
  getPreview(item: EventEntity): GapPreviewTest;
  getTierColor(min: number): string;
  getTierLabel(min: number): string;
  hasPositiveAllocation(distributionMap: Map<number, number>): boolean;
  getAllocatableCandidates(): EventEntity[];
  isCandidateAllocatable(item: EventEntity): boolean;
}

class GapDialogControllerMockTest {
  closeCount: number = 0;

  close(): void {
    this.closeCount += 1;
  }
}

class GapDistributionCoordinatorMockTest {
  sortedGaps: EventEntity[] = [];
  distributionCandidates: EventEntity[] = [];
  safetyCapMap: Map<number, number> = new Map<number, number>();
  previewMap: Map<number, number> = new Map<number, number>();
  risk: boolean = false;
  appliedMaps: Map<number, number>[] = [];

  getSortedGaps(): EventEntity[] {
    return this.sortedGaps;
  }

  getDistributionCandidates(_item: EventEntity): EventEntity[] {
    return this.distributionCandidates;
  }

  getSafetyCap(item: EventEntity, _gap: EventEntity): number {
    return this.safetyCapMap.get(item.id) ?? 0;
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
      result.set(candidate.id, selectedIds.has(candidate.id) ? (this.safetyCapMap.get(candidate.id) ?? 0) : 0);
    });
    return result;
  }

  checkDistributionRisk(_gap: EventEntity, _map: Map<number, number>): boolean {
    return this.risk;
  }

  async applyDistribution(map: Map<number, number>): Promise<void> {
    this.appliedMaps.push(map);
  }
}

class GapVmMockTest {
  distributionCoordinator: GapDistributionCoordinatorMockTest = new GapDistributionCoordinatorMockTest();
  trigger: number = 45;

  getIdleGapTriggerMinutes(): number {
    return this.trigger;
  }
}

function buildGapEventForTest(
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

function getGapDialogMethodForTest<T>(name: string): T {
  const prototype = Reflect.get(GapResolutionDialog as Object, 'prototype') as Object;
  return Reflect.get(prototype, name) as T;
}

function invokeGapDialogMethodForTest<THost, TResult, TArgs extends (Object | number | string | boolean)[]>(
  method: (this: THost, ...args: TArgs) => TResult,
  host: THost,
  ...args: TArgs
): TResult {
  const bound = method.bind(host) as (...boundArgs: TArgs) => TResult;
  return bound(...args);
}

const gapAboutToAppearTest = getGapDialogMethodForTest<(this: GapDialogHostTest) => void>('aboutToAppear');
const gapRefreshGapsTest = getGapDialogMethodForTest<(this: GapDialogHostTest) => void>('refreshGaps');
const gapSelectGapTest = getGapDialogMethodForTest<(this: GapDialogHostTest, item: EventEntity) => void>('selectGap');
const gapGetPreviewTest = getGapDialogMethodForTest<(this: GapDialogHostTest, item: EventEntity) => GapPreviewTest>('getPreview');
const gapGetTierColorTest = getGapDialogMethodForTest<(this: GapDialogHostTest, min: number) => string>('getTierColor');
const gapGetTierLabelTest = getGapDialogMethodForTest<(this: GapDialogHostTest, min: number) => string>('getTierLabel');
const gapHasPositiveAllocationTest = getGapDialogMethodForTest<
  (this: GapDialogHostTest, distributionMap: Map<number, number>) => boolean
>('hasPositiveAllocation');
const gapGetAllocatableCandidatesTest = getGapDialogMethodForTest<(this: GapDialogHostTest) => EventEntity[]>(
  'getAllocatableCandidates'
);
const gapIsCandidateAllocatableTest = getGapDialogMethodForTest<(this: GapDialogHostTest, item: EventEntity) => boolean>(
  'isCandidateAllocatable'
);

class GapDialogHostTest implements GapResolutionDialogPrivateTest {
  controller: GapDialogControllerMockTest = new GapDialogControllerMockTest();
  vm: GapVmMockTest;
  strategy: 'EQUAL' | 'SMART' = 'EQUAL';
  selectedIds: Set<number> = new Set<number>();
  currentGap: EventEntity | null = null;
  gapList: EventEntity[] = [];
  candidates: EventEntity[] = [];

  constructor(vm: GapVmMockTest) {
    this.vm = vm;
  }

  aboutToAppear(): void {
    invokeGapDialogMethodForTest(gapAboutToAppearTest, this);
  }

  refreshGaps(): void {
    invokeGapDialogMethodForTest(gapRefreshGapsTest, this);
  }

  selectGap(item: EventEntity): void {
    invokeGapDialogMethodForTest(gapSelectGapTest, this, item);
  }

  getPreview(item: EventEntity): GapPreviewTest {
    return invokeGapDialogMethodForTest(gapGetPreviewTest, this, item);
  }

  getTierColor(min: number): string {
    return invokeGapDialogMethodForTest(gapGetTierColorTest, this, min);
  }

  getTierLabel(min: number): string {
    return invokeGapDialogMethodForTest(gapGetTierLabelTest, this, min);
  }

  hasPositiveAllocation(distributionMap: Map<number, number>): boolean {
    return invokeGapDialogMethodForTest(gapHasPositiveAllocationTest, this, distributionMap);
  }

  getAllocatableCandidates(): EventEntity[] {
    return invokeGapDialogMethodForTest(gapGetAllocatableCandidatesTest, this);
  }

  isCandidateAllocatable(item: EventEntity): boolean {
    return invokeGapDialogMethodForTest(gapIsCandidateAllocatableTest, this, item);
  }
}

function createGapDialogForTest(vm: GapVmMockTest): GapResolutionDialogPrivateTest {
  return new GapDialogHostTest(vm);
}

export default function gapResolutionDialogThresholdsTest() {
  describe('unit_test_case_generator_autofill_GapResolutionDialogThresholds', () => {
    it('normal: gap_threshold_should_return_gold_tier_at_150_and_above', 0, () => {
      // Arrange
      const trigger = 30;

      // Act
      const color = resolveGapTierColor(150, trigger);
      const label = resolveGapTierLabel(180, trigger);

      // Assert
      expect(color).assertEqual('#FFB800');
      expect(label).assertEqual('\u9EC4\u91D1\u91CD\u6392');
    });

    it('boundary: gap_threshold_should_switch_from_green_to_blue_at_90', 0, () => {
      // Arrange
      const trigger = 30;

      // Act
      const before = resolveGapTierColor(89, trigger);
      const at = resolveGapTierColor(90, trigger);

      // Assert
      expect(before).assertEqual('#4CAF50');
      expect(at).assertEqual('#007DFF');
    });

    it('invalid: gap_threshold_should_return_empty_when_trigger_is_not_met', 0, () => {
      // Arrange
      const trigger = 45;

      // Act
      const color = resolveGapTierColor(44, trigger);
      const label = resolveGapTierLabel(44, trigger);

      // Assert
      expect(color).assertEqual('');
      expect(label).assertEqual('');
    });

    it('conflict: gap_label_should_prioritize_blue_tier_over_trigger_label', 0, () => {
      // Arrange
      const trigger = 20;

      // Act
      const label = resolveGapTierLabel(120, trigger);

      // Assert
      expect(label).assertEqual('\u4F53\u9A8C\u5347\u7EA7');
    });

    it('regression: td-20260412-gap-positive-allocation-should-ignore-zero-and-negative', 0, () => {
      // Arrange
      const values = [0, -3, 0, -1];

      // Act
      const hasPositive = hasPositiveAllocationValues(values);

      // Assert
      expect(hasPositive).assertFalse();
    });

    it('combined: gap_threshold_and_positive_allocation_should_align_for_trigger_edge', 0, () => {
      // Arrange
      const trigger = 60;
      const values = [0, 5, 0];

      // Act
      const color = resolveGapTierColor(60, trigger);
      const label = resolveGapTierLabel(60, trigger);
      const hasPositive = hasPositiveAllocationValues(values);

      // Assert
      expect(color).assertEqual('#4CAF50');
      expect(label).assertEqual('\u6548\u7387\u8865\u5168');
      expect(hasPositive).assertTrue();
    });

    it('normal: gap_dialog_should_auto_select_single_gap_and_build_preview', 0, () => {
      // Arrange
      const vm = new GapVmMockTest();
      const dialog = createGapDialogForTest(vm);
      const gap = buildGapEventForTest(100, '午后空闲', 75, '2026-04-10 10:00');
      const candidate = buildGapEventForTest(1, '博物馆', 0, '2026-04-10 11:00', 45);
      vm.distributionCoordinator.sortedGaps = [gap];
      vm.distributionCoordinator.distributionCandidates = [candidate];
      vm.distributionCoordinator.safetyCapMap = new Map<number, number>([[1, 15]]);
      dialog.selectedIds = new Set<number>([1]);

      // Act
      dialog.aboutToAppear();
      dialog.selectedIds = new Set<number>([1]);
      const preview = dialog.getPreview(candidate);

      // Assert
      expect(dialog.currentGap?.id ?? -1).assertEqual(100);
      expect(dialog.candidates.length).assertEqual(1);
      expect(preview.timeRange).assertEqual('11:00-11:45 \u2192 12:00');
      expect(preview.addStr).assertEqual('(+15m)');
    });

    it('boundary: gap_dialog_should_keep_list_mode_for_multiple_gaps_and_render', 0, () => {
      // Arrange
      const vm = new GapVmMockTest();
      const dialog = createGapDialogForTest(vm);
      const gapA = buildGapEventForTest(100, '早餐后空闲', 45, '2026-04-10 09:00');
      const gapB = buildGapEventForTest(101, '晚间空闲', 160, '2026-04-10 18:00');
      vm.distributionCoordinator.sortedGaps = [gapA, gapB];

      // Act
      dialog.refreshGaps();

      // Assert
      expect(dialog.currentGap === null).assertTrue();
      expect(dialog.gapList.length).assertEqual(2);
      expect(dialog.getTierColor(160)).assertEqual('#FFB800');
      expect(dialog.getTierLabel(45)).assertEqual('\u6548\u7387\u8865\u5168');
    });

    it('invalid: gap_dialog_should_return_empty_allocatable_without_current_gap', 0, () => {
      // Arrange
      const vm = new GapVmMockTest();
      const dialog = createGapDialogForTest(vm);
      const candidate = buildGapEventForTest(1, '咖啡店', 0, '2026-04-10 12:00');
      dialog.candidates = [candidate];

      // Act
      const allocatableCandidates = dialog.getAllocatableCandidates();
      const allocatable = dialog.isCandidateAllocatable(candidate);
      const preview = dialog.getPreview(candidate);

      // Assert
      expect(allocatableCandidates.length).assertEqual(0);
      expect(allocatable).assertFalse();
      expect(preview.addStr).assertEqual('');
    });

    it('combined: gap_dialog_detail_render_should_cover_risk_and_candidate_states', 0, () => {
      // Arrange
      const vm = new GapVmMockTest();
      const dialog = createGapDialogForTest(vm);
      const gap = buildGapEventForTest(100, '午餐前空闲', 95, '2026-04-10 11:30');
      const aiCandidate = buildGapEventForTest(1, '艺术街区', 0, '2026-04-10 09:00', 30);
      const lockedCandidate = buildGapEventForTest(2, '预约展馆', 0, '2026-04-10 10:00', 40);
      aiCandidate.source = 1;
      aiCandidate.priority = 1;
      lockedCandidate.lock_status = 1;
      dialog.gapList = [gap, buildGapEventForTest(101, '晚间空闲', 60, '2026-04-10 18:00')];
      dialog.currentGap = gap;
      dialog.candidates = [aiCandidate, lockedCandidate];
      dialog.selectedIds = new Set<number>([1, 2]);
      dialog.strategy = 'SMART';
      vm.distributionCoordinator.safetyCapMap = new Map<number, number>([[1, 20], [2, 0]]);
      vm.distributionCoordinator.risk = true;

      // Act
      const allocatableCandidates = dialog.getAllocatableCandidates();
      const hasPositive = dialog.hasPositiveAllocation(
        vm.distributionCoordinator.calculateDistributionPreview(gap, dialog.candidates, dialog.selectedIds, dialog.strategy)
      );

      // Assert
      expect(allocatableCandidates.length).assertEqual(1);
      expect(dialog.isCandidateAllocatable(aiCandidate)).assertTrue();
      expect(dialog.isCandidateAllocatable(lockedCandidate)).assertFalse();
      expect(hasPositive).assertTrue();
    });
  });
}

