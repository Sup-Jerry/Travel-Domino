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
  aboutToAppear(): void;
  refreshGaps(): void;
  selectGap(item: EventEntity): void;
  getPreview(item: EventEntity): GapPreviewHelper;
  getTierColor(min: number): string;
  getTierLabel(min: number): string;
  hasPositiveAllocation(distributionMap: Map<number, number>): boolean;
  getAllocatableCandidates(): EventEntity[];
  isCandidateAllocatable(item: EventEntity): boolean;
  safeShowToast(message: string, duration?: number): void;
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

  aboutToAppear(): void {
    invokeGapDialogMethodHelper(gapAboutToAppearHelper, this);
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

  getTierColor(min: number): string {
    return invokeGapDialogMethodHelper(gapGetTierColorHelper, this, min);
  }

  getTierLabel(min: number): string {
    return invokeGapDialogMethodHelper(gapGetTierLabelHelper, this, min);
  }

  hasPositiveAllocation(distributionMap: Map<number, number>): boolean {
    return invokeGapDialogMethodHelper(gapHasPositiveAllocationHelper, this, distributionMap);
  }

  getAllocatableCandidates(): EventEntity[] {
    return invokeGapDialogMethodHelper(gapGetAllocatableCandidatesHelper, this);
  }

  isCandidateAllocatable(item: EventEntity): boolean {
    return invokeGapDialogMethodHelper(gapIsCandidateAllocatableHelper, this, item);
  }

  safeShowToast(message: string, duration?: number): void {
    return invokeGapDialogMethodHelper(gapSafeShowToastHelper, this, message, duration);
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
const gapAboutToAppearHelper = getGapDialogMethodHelper<[], void>('aboutToAppear');
const gapSelectGapHelper = getGapDialogMethodHelper<[EventEntity], void>('selectGap');
const gapGetPreviewHelper = getGapDialogMethodHelper<[EventEntity], GapPreviewHelper>('getPreview');
const gapGetTierColorHelper = getGapDialogMethodHelper<[number], string>('getTierColor');
const gapGetTierLabelHelper = getGapDialogMethodHelper<[number], string>('getTierLabel');
const gapHasPositiveAllocationHelper = getGapDialogMethodHelper<[Map<number, number>], boolean>('hasPositiveAllocation');
const gapGetAllocatableCandidatesHelper = getGapDialogMethodHelper<[], EventEntity[]>('getAllocatableCandidates');
const gapIsCandidateAllocatableHelper = getGapDialogMethodHelper<[EventEntity], boolean>('isCandidateAllocatable');
const gapSafeShowToastHelper = getGapDialogMethodHelper<[string, (number | undefined)], void>('safeShowToast');

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

    it('boundary: gap_resolution_about_to_appear_should_delegate_refresh_for_single_gap', 0, () => {
      // Arrange
      const vm = new GapVmMockHelper();
      const dialog = createDialogHelper(vm);
      const gap = buildGapEventHelper(401, 'single-gap', 55, '2026-05-16 13:00');
      const candidate = buildGapEventHelper(402, 'tea-stop', 0, '2026-05-16 13:30', 25);
      vm.distributionCoordinator.sortedGaps = [gap];
      vm.distributionCoordinator.candidatesByGapId.set(gap.id, [candidate]);

      // Act
      dialog.aboutToAppear();

      // Assert
      expect(dialog.gapList.length).assertEqual(1);
      expect(dialog.currentGap?.id ?? -1).assertEqual(gap.id);
      expect(dialog.candidates.length).assertEqual(1);
    });

    it('combined: gap_resolution_private_helpers_should_follow_trigger_and_positive_distribution_map', 0, () => {
      // Arrange
      const vm = new GapVmMockHelper();
      vm.trigger = 45;
      const dialog = createDialogHelper(vm);
      const positiveMap = new Map<number, number>();
      positiveMap.set(1, 0);
      positiveMap.set(2, 12);
      const emptyMap = new Map<number, number>();

      // Act
      const goldColor = dialog.getTierColor(150);
      const greenColor = dialog.getTierColor(45);
      const goldLabel = dialog.getTierLabel(150);
      const greenLabel = dialog.getTierLabel(45);
      const positive = dialog.hasPositiveAllocation(positiveMap);
      const empty = dialog.hasPositiveAllocation(emptyMap);

      // Assert
      expect(goldColor).assertEqual('#FFB800');
      expect(greenColor).assertEqual('#4CAF50');
      expect(goldLabel).assertEqual('\u9EC4\u91D1\u91CD\u6392');
      expect(greenLabel).assertEqual('\u6548\u7387\u8865\u5168');
      expect(positive).assertTrue();
      expect(empty).assertFalse();
    });

    it('combined: gap_resolution_preview_should_support_manual_preview_map_and_strategy_switch', 0, () => {
      // Arrange
      const vm = new GapVmMockHelper();
      const dialog = createDialogHelper(vm);
      const gap = buildGapEventHelper(501, 'museum-gap', 95, '2026-05-16 15:00');
      const candidate = buildGapEventHelper(502, 'gallery', 0, '2026-05-16 15:10', 40);
      const overflowCandidate = buildGapEventHelper(503, 'park', 0, '2026-05-16 16:00', 20);
      vm.distributionCoordinator.candidatesByGapId.set(gap.id, [candidate]);
      vm.distributionCoordinator.safetyCaps.set(candidate.id, 20);
      vm.distributionCoordinator.safetyCaps.set(overflowCandidate.id, 0);
      vm.distributionCoordinator.previewMap.set(candidate.id, 20);
      vm.distributionCoordinator.previewMap.set(overflowCandidate.id, 0);
      dialog.strategy = 'SMART';
      dialog.selectGap(gap);
      dialog.candidates.push(overflowCandidate);
      dialog.selectedIds = new Set<number>([candidate.id]);

      // Act
      const preview = dialog.getPreview(candidate);
      const allocatableCandidates = dialog.getAllocatableCandidates();

      // Assert
      expect(preview.timeRange).assertEqual('15:10-15:50 \u2192 16:10');
      expect(preview.addStr).assertEqual('(+20m)');
      expect(allocatableCandidates.length).assertEqual(1);
      expect(dialog.strategy).assertEqual('SMART');
      expect(dialog.selectedIds.has(candidate.id)).assertTrue();
    });

    it('boundary: gap_resolution_select_gap_should_replace_previous_gap_and_clear_stale_selection', 0, () => {
      // Arrange
      const vm = new GapVmMockHelper();
      const dialog = createDialogHelper(vm);
      const oldGap = buildGapEventHelper(601, 'old-gap', 40, '2026-05-16 09:00');
      const newGap = buildGapEventHelper(602, 'new-gap', 120, '2026-05-16 14:00');
      const candidateA = buildGapEventHelper(603, 'aquarium', 0, '2026-05-16 14:30', 35);
      const candidateB = buildGapEventHelper(604, 'library', 0, '2026-05-16 15:30', 25);
      vm.distributionCoordinator.candidatesByGapId.set(oldGap.id, [candidateA]);
      vm.distributionCoordinator.candidatesByGapId.set(newGap.id, [candidateB]);
      dialog.selectGap(oldGap);
      dialog.selectedIds = new Set<number>([candidateA.id]);

      // Act
      dialog.selectGap(newGap);

      // Assert
      expect(dialog.currentGap?.id ?? -1).assertEqual(newGap.id);
      expect(dialog.candidates.length).assertEqual(1);
      expect(dialog.candidates[0].id).assertEqual(candidateB.id);
      expect(dialog.selectedIds.size).assertEqual(0);
    });

    it('regression: td-20260516-gap-resolution-tier-thresholds-should-keep-gold-blue-green-split', 0, () => {
      // Arrange
      const trigger = 30;

      // Act
      const goldColor = resolveGapTierColor(150, trigger);
      const blueColor = resolveGapTierColor(149, trigger);
      const greenLabel = resolveGapTierLabel(30, trigger);
      const emptyLabel = resolveGapTierLabel(29, trigger);

      // Assert
      expect(goldColor).assertEqual('#FFB800');
      expect(blueColor).assertEqual('#007DFF');
      expect(greenLabel).assertEqual('\u6548\u7387\u8865\u5168');
      expect(emptyLabel).assertEqual('');
    });

    it('boundary: gap_resolution_refresh_should_clear_stale_current_gap_when_gap_list_is_empty', 0, () => {
      // Arrange
      const vm = new GapVmMockHelper();
      const dialog = createDialogHelper(vm);
      dialog.currentGap = buildGapEventHelper(701, 'stale-gap', 35, '2026-05-16 08:00');
      dialog.candidates = [buildGapEventHelper(702, 'stale-candidate', 0, '2026-05-16 08:30', 20)];
      dialog.selectedIds = new Set<number>([702]);
      vm.distributionCoordinator.sortedGaps = [];

      // Act
      dialog.refreshGaps();

      // Assert
      expect(dialog.gapList.length).assertEqual(0);
      expect(dialog.currentGap === null).assertTrue();
      expect(dialog.candidates.length).assertEqual(1);
      expect(dialog.selectedIds.size).assertEqual(1);
    });

    it('combined: gap_resolution_private_helpers_should_keep_blank_tier_and_zero_allocations_consistent', 0, () => {
      // Arrange
      const vm = new GapVmMockHelper();
      vm.trigger = 45;
      const dialog = createDialogHelper(vm);
      const zeroMap = new Map<number, number>();
      zeroMap.set(1, 0);
      zeroMap.set(2, 0);

      // Act
      const blankColor = dialog.getTierColor(44);
      const blankLabel = dialog.getTierLabel(44);
      const zeroAllocations = dialog.hasPositiveAllocation(zeroMap);

      // Assert
      expect(blankColor).assertEqual('');
      expect(blankLabel).assertEqual('');
      expect(zeroAllocations).assertFalse();
    });

    it('boundary: gap_resolution_about_to_appear_should_clear_current_gap_when_multiple_gaps_exist', 0, () => {
      // Arrange
      const vm = new GapVmMockHelper();
      const dialog = createDialogHelper(vm);
      const firstGap = buildGapEventHelper(801, 'first-gap', 35, '2026-05-16 08:00');
      const secondGap = buildGapEventHelper(802, 'second-gap', 65, '2026-05-16 10:00');
      dialog.currentGap = firstGap;
      vm.distributionCoordinator.sortedGaps = [firstGap, secondGap];

      // Act
      dialog.aboutToAppear();

      // Assert
      expect(dialog.gapList.length).assertEqual(2);
      expect(dialog.currentGap === null).assertTrue();
    });

    it('combined: gap_resolution_preview_should_keep_empty_add_str_when_selected_item_has_zero_allocation', 0, () => {
      // Arrange
      const vm = new GapVmMockHelper();
      const dialog = createDialogHelper(vm);
      const gap = buildGapEventHelper(803, 'preview-gap', 55, '2026-05-16 09:00');
      const candidate = buildGapEventHelper(804, 'zero-add-item', 0, '2026-05-16 09:30', 30);
      vm.distributionCoordinator.candidatesByGapId.set(gap.id, [candidate]);
      vm.distributionCoordinator.safetyCaps.set(candidate.id, 0);
      dialog.selectGap(gap);
      dialog.selectedIds = new Set<number>([candidate.id]);

      // Act
      const preview = dialog.getPreview(candidate);

      // Assert
      expect(preview.timeRange).assertEqual('09:30-10:00 \u2192 10:00');
      expect(preview.addStr).assertEqual('');
    });

    it('invalid: gap_resolution_preview_should_fallback_to_zero_clock_when_computed_time_has_no_clock_segment', 0, () => {
      // Arrange
      const vm = new GapVmMockHelper();
      const dialog = createDialogHelper(vm);
      const gap = buildGapEventHelper(805, 'fallback-gap', 40, '2026-05-16 09:00');
      const candidate = buildGapEventHelper(806, 'clockless-item', 0, 'clockless', 25);
      vm.distributionCoordinator.candidatesByGapId.set(gap.id, [candidate]);
      dialog.selectGap(gap);

      // Act
      const preview = dialog.getPreview(candidate);

      // Assert
      expect(preview.timeRange).assertEqual('clockless---:-- \u2192 --:--');
      expect(preview.addStr).assertEqual('');
    });

    it('combined: gap_resolution_allocatable_candidates_should_keep_all_positive_safety_cap_items', 0, () => {
      // Arrange
      const vm = new GapVmMockHelper();
      const dialog = createDialogHelper(vm);
      const gap = buildGapEventHelper(807, 'alloc-gap', 70, '2026-05-16 13:00');
      const candidateA = buildGapEventHelper(808, 'alloc-a', 0, '2026-05-16 13:10', 20);
      const candidateB = buildGapEventHelper(809, 'alloc-b', 0, '2026-05-16 13:40', 30);
      vm.distributionCoordinator.candidatesByGapId.set(gap.id, [candidateA, candidateB]);
      vm.distributionCoordinator.safetyCaps.set(candidateA.id, 5);
      vm.distributionCoordinator.safetyCaps.set(candidateB.id, 8);
      dialog.selectGap(gap);

      // Act
      const allocatableCandidates = dialog.getAllocatableCandidates();

      // Assert
      expect(allocatableCandidates.length).assertEqual(2);
      expect(dialog.isCandidateAllocatable(candidateA)).assertTrue();
      expect(dialog.isCandidateAllocatable(candidateB)).assertTrue();
    });

    it('boundary: gap_resolution_preview_should_keep_existing_clock_text_when_computed_time_has_only_clock', 0, () => {
      // Arrange
      const vm = new GapVmMockHelper();
      const dialog = createDialogHelper(vm);
      const gap = buildGapEventHelper(810, 'clock-gap', 45, '2026-05-16 14:00');
      const candidate = buildGapEventHelper(811, 'clock-only-item', 0, '14:20', 15);
      vm.distributionCoordinator.candidatesByGapId.set(gap.id, [candidate]);
      dialog.selectGap(gap);

      // Act
      const preview = dialog.getPreview(candidate);

      // Assert
      expect(preview.timeRange).assertEqual('14:20-14:35 \u2192 14:35');
      expect(preview.addStr).assertEqual('');
    });

    it('combined: gap_resolution_allocatable_candidates_should_be_empty_when_positive_caps_exist_on_other_gap_only', 0, () => {
      // Arrange
      const vm = new GapVmMockHelper();
      const dialog = createDialogHelper(vm);
      const currentGap = buildGapEventHelper(812, 'current-gap', 50, '2026-05-16 15:00');
      const candidate = buildGapEventHelper(813, 'foreign-cap-item', 0, '2026-05-16 15:10', 20);
      vm.distributionCoordinator.candidatesByGapId.set(currentGap.id, [candidate]);
      dialog.selectGap(currentGap);

      // Act
      const allocatableCandidates = dialog.getAllocatableCandidates();

      // Assert
      expect(allocatableCandidates.length).assertEqual(0);
      expect(dialog.isCandidateAllocatable(candidate)).assertFalse();
    });

    it('combined: gap_resolution_safe_toast_should_accept_plain_and_timed_messages_without_throwing', 0, () => {
      // Arrange
      const vm = new GapVmMockHelper();
      const dialog = createDialogHelper(vm);
      let plainThrew = false;
      let timedThrew = false;

      // Act
      try {
        dialog.safeShowToast('gap_toast_plain');
      } catch (_error) {
        plainThrew = true;
      }
      try {
        dialog.safeShowToast('gap_toast_timed', 1800);
      } catch (_error) {
        timedThrew = true;
      }

      // Assert
      expect(plainThrew).assertFalse();
      expect(timedThrew).assertFalse();
    });
  });
}
