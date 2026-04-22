import { describe, expect, it } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { GapResolutionDialog } from '../main/ets/pages/components/dialogs/GapResolutionDialog';

interface GapPreviewCB {
  timeRange: string;
  addStr: string;
}

interface GapResolutionDialogPrivateCB {
  controller: GapDialogControllerMockCB;
  vm: GapVmMockCB;
  strategy: 'EQUAL' | 'SMART';
  selectedIds: Set<number>;
  currentGap: EventEntity | null;
  gapList: EventEntity[];
  candidates: EventEntity[];
  aboutToAppear(): void;
  refreshGaps(): void;
  selectGap(item: EventEntity): void;
  getPreview(item: EventEntity): GapPreviewCB;
  getTierColor(min: number): string;
  getTierLabel(min: number): string;
  hasPositiveAllocation(distributionMap: Map<number, number>): boolean;
  getAllocatableCandidates(): EventEntity[];
  isCandidateAllocatable(item: EventEntity): boolean;
  safeShowToast(message: string, duration?: number): void;
}

class GapDialogControllerMockCB {
  public closeCount: number = 0;

  close(): void {
    this.closeCount += 1;
  }
}

class GapDistributionCoordinatorMockCB {
  public sortedGaps: EventEntity[] = [];
  public distributionCandidates: EventEntity[] = [];
  public safetyCapMap: Map<number, number> = new Map<number, number>();
  public previewMap: Map<number, number> = new Map<number, number>();
  public risk: boolean = false;
  public appliedMaps: Map<number, number>[] = [];

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

class GapVmMockCB {
  public distributionCoordinator: GapDistributionCoordinatorMockCB = new GapDistributionCoordinatorMockCB();
  public trigger: number = 45;

  getIdleGapTriggerMinutes(): number {
    return this.trigger;
  }
}

function buildGapEventCB(
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
  event.fixed_start_time = computedTime.split(' ').pop() || computedTime;
  return event;
}

type GapDialogMethodCB<TResult, TArgs extends (Object | number | string | boolean | undefined)[]> =
  (this: GapResolutionDialogPrivateCB, ...args: TArgs) => TResult;

function getGapDialogMethodCB<TResult, TArgs extends (Object | number | string | boolean | undefined)[]>(
  name: string
): GapDialogMethodCB<TResult, TArgs> {
  const prototype = Reflect.get(GapResolutionDialog as Object, 'prototype') as Object;
  return Reflect.get(prototype, name) as GapDialogMethodCB<TResult, TArgs>;
}

function invokeGapDialogMethodCB<TResult, TArgs extends (Object | number | string | boolean | undefined)[]>(
  host: GapResolutionDialogPrivateCB,
  method: GapDialogMethodCB<TResult, TArgs>,
  ...args: TArgs
): TResult {
  const bound = method.bind(host) as (...boundArgs: TArgs) => TResult;
  return bound(...args);
}

const gapAboutToAppearCB = getGapDialogMethodCB<void, []>('aboutToAppear');
const gapRefreshGapsCB = getGapDialogMethodCB<void, []>('refreshGaps');
const gapSelectGapCB = getGapDialogMethodCB<void, [EventEntity]>('selectGap');
const gapGetPreviewCB = getGapDialogMethodCB<GapPreviewCB, [EventEntity]>('getPreview');
const gapGetTierColorCB = getGapDialogMethodCB<string, [number]>('getTierColor');
const gapGetTierLabelCB = getGapDialogMethodCB<string, [number]>('getTierLabel');
const gapHasPositiveAllocationCB = getGapDialogMethodCB<boolean, [Map<number, number>]>('hasPositiveAllocation');
const gapGetAllocatableCandidatesCB = getGapDialogMethodCB<EventEntity[], []>('getAllocatableCandidates');
const gapIsCandidateAllocatableCB = getGapDialogMethodCB<boolean, [EventEntity]>('isCandidateAllocatable');
const gapSafeShowToastCB = getGapDialogMethodCB<void, [string, (number | undefined)]>('safeShowToast');

class GapDialogHostCB implements GapResolutionDialogPrivateCB {
  public controller: GapDialogControllerMockCB = new GapDialogControllerMockCB();
  public vm: GapVmMockCB;
  public strategy: 'EQUAL' | 'SMART' = 'EQUAL';
  public selectedIds: Set<number> = new Set<number>();
  public currentGap: EventEntity | null = null;
  public gapList: EventEntity[] = [];
  public candidates: EventEntity[] = [];

  constructor(vm: GapVmMockCB) {
    this.vm = vm;
  }

  aboutToAppear(): void {
    invokeGapDialogMethodCB(this, gapAboutToAppearCB);
  }

  refreshGaps(): void {
    invokeGapDialogMethodCB(this, gapRefreshGapsCB);
  }

  selectGap(item: EventEntity): void {
    invokeGapDialogMethodCB(this, gapSelectGapCB, item);
  }

  getPreview(item: EventEntity): GapPreviewCB {
    return invokeGapDialogMethodCB(this, gapGetPreviewCB, item);
  }

  getTierColor(min: number): string {
    return invokeGapDialogMethodCB(this, gapGetTierColorCB, min);
  }

  getTierLabel(min: number): string {
    return invokeGapDialogMethodCB(this, gapGetTierLabelCB, min);
  }

  hasPositiveAllocation(distributionMap: Map<number, number>): boolean {
    return invokeGapDialogMethodCB(this, gapHasPositiveAllocationCB, distributionMap);
  }

  getAllocatableCandidates(): EventEntity[] {
    return invokeGapDialogMethodCB(this, gapGetAllocatableCandidatesCB);
  }

  isCandidateAllocatable(item: EventEntity): boolean {
    return invokeGapDialogMethodCB(this, gapIsCandidateAllocatableCB, item);
  }

  safeShowToast(message: string, duration?: number): void {
    return invokeGapDialogMethodCB(this, gapSafeShowToastCB, message, duration);
  }
}

export default function phase2BatchCBTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchCB', () => {
    it('normal: gap_dialog_initial_render_should_support_multiple_gap_list_mode', 0, () => {
      // Arrange
      const vm = new GapVmMockCB();
      const page = new GapDialogHostCB(vm);
      const gapA = buildGapEventCB(301, '上午空闲', 50, '2026-04-10 09:00');
      const gapB = buildGapEventCB(302, '午后空闲', 160, '2026-04-10 14:00');
      vm.distributionCoordinator.sortedGaps = [gapA, gapB];

      // Act
      page.aboutToAppear();

      // Assert
      expect(page.currentGap).assertNull();
      expect(page.gapList.length).assertEqual(2);
      expect(page.getTierColor(gapB.gap_minutes)).assertEqual('#FFB800');
    });

    it('boundary: gap_dialog_initial_render_should_support_detail_mode_without_candidates', 0, () => {
      // Arrange
      const vm = new GapVmMockCB();
      const page = new GapDialogHostCB(vm);
      const gap = buildGapEventCB(303, '午餐前空闲', 70, '2026-04-10 11:30');
      page.gapList = [gap, buildGapEventCB(304, '晚间空闲', 90, '2026-04-10 18:30')];
      page.currentGap = gap;
      page.candidates = [];

      // Act
      const allocatable = page.getAllocatableCandidates();

      // Assert
      expect(allocatable.length).assertEqual(0);
      expect(page.currentGap?.id ?? -1).assertEqual(gap.id);
    });

    it('invalid: gap_dialog_safe_toast_should_not_throw_in_test_runtime', 0, () => {
      // Arrange
      const vm = new GapVmMockCB();
      const page = new GapDialogHostCB(vm);
      let threw = false;

      // Act
      try {
        page.safeShowToast('toast_message', 1200);
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
    });

    it('conflict: gap_dialog_initial_render_should_support_locked_candidate_and_risk_warning', 0, () => {
      // Arrange
      const vm = new GapVmMockCB();
      const page = new GapDialogHostCB(vm);
      const gap = buildGapEventCB(305, '傍晚空闲', 95, '2026-04-10 17:00');
      const aiCandidate = buildGapEventCB(1, '艺术街区', 0, '2026-04-10 15:00', 30);
      const lockedCandidate = buildGapEventCB(2, '预约展馆', 0, '2026-04-10 16:00', 40);
      aiCandidate.source = 1;
      aiCandidate.priority = 1;
      lockedCandidate.lock_status = 1;
      page.gapList = [gap];
      page.currentGap = gap;
      page.candidates = [aiCandidate, lockedCandidate];
      page.selectedIds = new Set<number>([1, 2]);
      page.strategy = 'SMART';
      vm.distributionCoordinator.safetyCapMap = new Map<number, number>([[1, 20], [2, 0]]);
      vm.distributionCoordinator.risk = true;
      // Act

      // Assert
      expect(page.isCandidateAllocatable(aiCandidate)).assertTrue();
      expect(page.isCandidateAllocatable(lockedCandidate)).assertFalse();
      expect(page.getAllocatableCandidates().length).assertEqual(1);
    });

    it('regression: gap_dialog_preview_should_keep_time_text_when_computed_time_has_no_date_prefix', 0, () => {
      // Arrange
      const vm = new GapVmMockCB();
      const page = new GapDialogHostCB(vm);
      const gap = buildGapEventCB(306, '回归空闲', 65, '09:30');
      const candidate = buildGapEventCB(3, '书店', 0, '10:20', 40);
      page.currentGap = gap;
      page.candidates = [candidate];
      page.selectedIds = new Set<number>([candidate.id]);
      vm.distributionCoordinator.previewMap = new Map<number, number>([[candidate.id, 15]]);

      // Act
      const preview = page.getPreview(candidate);

      // Assert
      expect(preview.timeRange).assertEqual('10:20-11:00 → 11:15');
      expect(preview.addStr).assertEqual('(+15m)');
    });

    it('combined: gap_dialog_should_refresh_single_gap_select_candidates_and_render_detail', 0, () => {
      // Arrange
      const vm = new GapVmMockCB();
      const page = new GapDialogHostCB(vm);
      const gap = buildGapEventCB(307, '综合空闲', 120, '2026-04-10 13:00');
      const museum = buildGapEventCB(4, '博物馆', 0, '2026-04-10 13:20', 45);
      const cafe = buildGapEventCB(5, '咖啡馆', 0, '2026-04-10 14:10', 25);
      vm.distributionCoordinator.sortedGaps = [gap];
      vm.distributionCoordinator.distributionCandidates = [museum, cafe];
      vm.distributionCoordinator.safetyCapMap = new Map<number, number>([[museum.id, 25], [cafe.id, 10]]);
      vm.distributionCoordinator.previewMap = new Map<number, number>([[museum.id, 25], [cafe.id, 0]]);
      // Act
      page.refreshGaps();
      page.selectedIds = new Set<number>([museum.id]);
      const preview = page.getPreview(museum);

      // Assert
      expect(page.currentGap?.id ?? -1).assertEqual(gap.id);
      expect(page.candidates.length).assertEqual(2);
      expect(page.hasPositiveAllocation(vm.distributionCoordinator.previewMap)).assertTrue();
      expect(preview.addStr).assertEqual('(+25m)');
    });
  });
}
