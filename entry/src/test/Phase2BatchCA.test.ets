import { describe, expect, it } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import {
  canCopyPlanShareCompressedText,
  clampPlanShareEvents,
  PlanShareDialog,
  resolvePlanShareSaveQuality
} from '../main/ets/pages/components/dialogs/PlanShareDialog';
import { ShareEventItem } from '../main/ets/domain/services/PlanShareImageService';
import {
  GapResolutionDialog,
  hasPositiveAllocationValues,
  resolveGapTierColor,
  resolveGapTierLabel
} from '../main/ets/pages/components/dialogs/GapResolutionDialog';

interface ShareDialogHostCA {
  events: ShareEventItem[];
  compressedJson: string;
  shareImage: Object | null;
  toastMessages: string[];
  writeQualities: number[];
  failWriteTimes: number;
  safeShowToast(message: string): void;
  getRenderableEvents(): ShareEventItem[];
  writeImageWithRetry(uri: string): Promise<void>;
  writeImageToUri(uri: string, quality: number): Promise<void>;
  copyShareTextToClipboard(): Promise<boolean>;
  requestAlbumPermission(): Promise<boolean>;
}

interface GapPreviewCA {
  timeRange: string;
  addStr: string;
}

interface GapDialogHostCA {
  vm: GapVmMockCA;
  strategy: 'EQUAL' | 'SMART';
  selectedIds: Set<number>;
  currentGap: EventEntity | null;
  gapList: EventEntity[];
  candidates: EventEntity[];
  refreshGaps(): void;
  selectGap(item: EventEntity): void;
  getPreview(item: EventEntity): GapPreviewCA;
  hasPositiveAllocation(map: Map<number, number>): boolean;
  getAllocatableCandidates(): EventEntity[];
  isCandidateAllocatable(item: EventEntity): boolean;
  getTierColor(min: number): string;
  getTierLabel(min: number): string;
}

class ShareDialogHostImplCA implements ShareDialogHostCA {
  events: ShareEventItem[] = [];
  compressedJson: string = '';
  shareImage: Object | null = new SharePixelMapMockCA();
  toastMessages: string[] = [];
  writeQualities: number[] = [];
  failWriteTimes: number = 0;

  safeShowToast(message: string): void {
    this.toastMessages.push(message);
  }

  getRenderableEvents(): ShareEventItem[] {
    return invokeShareMethodCA(shareGetRenderableEventsCA, this);
  }

  async writeImageWithRetry(uri: string): Promise<void> {
    await invokeShareMethodCA(shareWriteImageWithRetryCA, this, uri);
  }

  async writeImageToUri(_uri: string, quality: number): Promise<void> {
    this.writeQualities.push(quality);
    if (this.failWriteTimes > 0) {
      this.failWriteTimes -= 1;
      throw new Error('write_failed');
    }
  }

  async copyShareTextToClipboard(): Promise<boolean> {
    return invokeShareMethodCA(shareCopyShareTextToClipboardCA, this);
  }

  async requestAlbumPermission(): Promise<boolean> {
    return invokeShareMethodCA(shareRequestAlbumPermissionCA, this);
  }
}

class SharePixelMapMockCA {
}

class GapDistributionCoordinatorMockCA {
  sortedGaps: EventEntity[] = [];
  distributionCandidates: EventEntity[] = [];
  safetyCapMap: Map<number, number> = new Map<number, number>();
  previewMap: Map<number, number> = new Map<number, number>();

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
}

class GapVmMockCA {
  distributionCoordinator: GapDistributionCoordinatorMockCA = new GapDistributionCoordinatorMockCA();
  trigger: number = 30;

  getIdleGapTriggerMinutes(): number {
    return this.trigger;
  }
}

class GapDialogHostImplCA implements GapDialogHostCA {
  vm: GapVmMockCA;
  strategy: 'EQUAL' | 'SMART' = 'EQUAL';
  selectedIds: Set<number> = new Set<number>();
  currentGap: EventEntity | null = null;
  gapList: EventEntity[] = [];
  candidates: EventEntity[] = [];

  constructor(vm: GapVmMockCA) {
    this.vm = vm;
  }

  refreshGaps(): void {
    invokeGapMethodCA(gapRefreshGapsCA, this);
  }

  selectGap(item: EventEntity): void {
    invokeGapMethodCA(gapSelectGapCA, this, item);
  }

  getPreview(item: EventEntity): GapPreviewCA {
    return invokeGapMethodCA(gapGetPreviewCA, this, item);
  }

  hasPositiveAllocation(map: Map<number, number>): boolean {
    return invokeGapMethodCA(gapHasPositiveAllocationCA, this, map);
  }

  getAllocatableCandidates(): EventEntity[] {
    return invokeGapMethodCA(gapGetAllocatableCandidatesCA, this);
  }

  isCandidateAllocatable(item: EventEntity): boolean {
    return invokeGapMethodCA(gapIsCandidateAllocatableCA, this, item);
  }

  getTierColor(min: number): string {
    return invokeGapMethodCA(gapGetTierColorCA, this, min);
  }

  getTierLabel(min: number): string {
    return invokeGapMethodCA(gapGetTierLabelCA, this, min);
  }
}

function getShareMethodCA<T>(name: string): T {
  const prototype = Reflect.get(PlanShareDialog as Object, 'prototype') as Object;
  return Reflect.get(prototype, name) as T;
}

function getGapMethodCA<T>(name: string): T {
  const prototype = Reflect.get(GapResolutionDialog as Object, 'prototype') as Object;
  return Reflect.get(prototype, name) as T;
}

function invokeShareMethodCA<THost, TResult, TArgs extends (Object | string | number | boolean)[]>(
  method: (this: THost, ...args: TArgs) => TResult,
  host: THost,
  ...args: TArgs
): TResult {
  const bound = method.bind(host) as (...boundArgs: TArgs) => TResult;
  return bound(...args);
}

function invokeGapMethodCA<THost, TResult, TArgs extends (Object | string | number | boolean)[]>(
  method: (this: THost, ...args: TArgs) => TResult,
  host: THost,
  ...args: TArgs
): TResult {
  const bound = method.bind(host) as (...boundArgs: TArgs) => TResult;
  return bound(...args);
}

const shareGetRenderableEventsCA = getShareMethodCA<(this: ShareDialogHostCA) => ShareEventItem[]>('getRenderableEvents');
const shareWriteImageWithRetryCA = getShareMethodCA<(this: ShareDialogHostCA, uri: string) => Promise<void>>(
  'writeImageWithRetry'
);
const shareCopyShareTextToClipboardCA = getShareMethodCA<(this: ShareDialogHostCA) => Promise<boolean>>(
  'copyShareTextToClipboard'
);
const shareRequestAlbumPermissionCA = getShareMethodCA<(this: ShareDialogHostCA) => Promise<boolean>>(
  'requestAlbumPermission'
);

const gapRefreshGapsCA = getGapMethodCA<(this: GapDialogHostCA) => void>('refreshGaps');
const gapSelectGapCA = getGapMethodCA<(this: GapDialogHostCA, item: EventEntity) => void>('selectGap');
const gapGetPreviewCA = getGapMethodCA<(this: GapDialogHostCA, item: EventEntity) => GapPreviewCA>('getPreview');
const gapHasPositiveAllocationCA = getGapMethodCA<(this: GapDialogHostCA, map: Map<number, number>) => boolean>(
  'hasPositiveAllocation'
);
const gapGetAllocatableCandidatesCA = getGapMethodCA<(this: GapDialogHostCA) => EventEntity[]>('getAllocatableCandidates');
const gapIsCandidateAllocatableCA = getGapMethodCA<(this: GapDialogHostCA, item: EventEntity) => boolean>(
  'isCandidateAllocatable'
);
const gapGetTierColorCA = getGapMethodCA<(this: GapDialogHostCA, min: number) => string>('getTierColor');
const gapGetTierLabelCA = getGapMethodCA<(this: GapDialogHostCA, min: number) => string>('getTierLabel');

function buildShareEventCA(index: number): ShareEventItem {
  return {
    name: `event-${index}`,
    dayOffset: 0,
    startTime: '09:00',
    endTime: '10:00',
    duration: 60,
    icon: 'pin',
    location: 'loc',
    category: 'visit'
  };
}

function buildShareEventsCA(count: number): ShareEventItem[] {
  const events: ShareEventItem[] = [];
  for (let i = 0; i < count; i++) {
    events.push(buildShareEventCA(i));
  }
  return events;
}

function buildEventCA(id: number, name: string, computedTime: string, duration: number = 60): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = name;
  event.computed_time = computedTime;
  event.duration = duration;
  event.gap_minutes = 0;
  event.status = 1;
  event.lock_status = 0;
  event.priority = 0;
  event.source = 0;
  return event;
}

export default function phase2BatchCATest() {
  describe('unit_test_case_generator_autofill_Phase2BatchCA', () => {
    it('normal: plan_share_should_keep_renderable_events_when_below_limit', 0, () => {
      // Arrange
      const host = new ShareDialogHostImplCA();
      host.events = buildShareEventsCA(3);

      // Act
      const renderable = host.getRenderableEvents();

      // Assert
      expect(renderable.length).assertEqual(3);
      expect(host.toastMessages.length).assertEqual(0);
    });

    it('boundary: plan_share_should_trim_renderable_events_at_limit_and_toast_once', 0, () => {
      // Arrange
      const host = new ShareDialogHostImplCA();
      host.events = buildShareEventsCA(51);

      // Act
      const renderable = host.getRenderableEvents();

      // Assert
      expect(renderable.length).assertEqual(50);
      expect(host.toastMessages.length).assertEqual(1);
    });

    it('invalid: plan_share_copy_should_return_false_for_empty_compressed_text', 0, async () => {
      // Arrange
      const host = new ShareDialogHostImplCA();
      host.compressedJson = '';

      // Act
      const copied = await host.copyShareTextToClipboard();

      // Assert
      expect(copied).assertFalse();
      expect(canCopyPlanShareCompressedText(host.compressedJson)).assertFalse();
    });

    it('conflict: plan_share_write_retry_should_fallback_to_second_quality_after_first_failure', 0, async () => {
      // Arrange
      const host = new ShareDialogHostImplCA();
      host.failWriteTimes = 1;

      // Act
      await host.writeImageWithRetry('cache/share.jpg');

      // Assert
      expect(host.writeQualities.length).assertEqual(2);
      expect(host.writeQualities[0]).assertEqual(95);
      expect(host.writeQualities[1]).assertEqual(80);
    });

    it('regression: td-20260422-plan_share_retry_should_throw_last_error_after_all_attempts_fail', 0, async () => {
      // Arrange
      const host = new ShareDialogHostImplCA();
      host.failWriteTimes = 2;
      let failed = false;

      // Act
      try {
        await host.writeImageWithRetry('cache/share.jpg');
      } catch (_error) {
        failed = true;
      }

      // Assert
      expect(failed).assertTrue();
      expect(host.writeQualities.length).assertEqual(2);
      expect(resolvePlanShareSaveQuality(2)).assertEqual(80);
    });

    it('combined: gap_resolution_should_preview_allocations_and_filter_allocatable_candidates', 0, () => {
      // Arrange
      const vm = new GapVmMockCA();
      const gap = buildEventCA(1, 'gap', '2026-04-22 10:00');
      const first = buildEventCA(2, 'museum', '2026-04-22 09:00');
      const second = buildEventCA(3, 'lunch', '2026-04-22 11:00');
      vm.distributionCoordinator.sortedGaps = [gap];
      vm.distributionCoordinator.distributionCandidates = [first, second];
      vm.distributionCoordinator.safetyCapMap.set(first.id, 15);
      vm.distributionCoordinator.safetyCapMap.set(second.id, 0);
      const dialog = new GapDialogHostImplCA(vm);

      // Act
      dialog.refreshGaps();
      dialog.selectedIds.add(first.id);
      const preview = dialog.getPreview(first);
      const allocatable = dialog.getAllocatableCandidates();

      // Assert
      expect(dialog.currentGap?.id).assertEqual(gap.id);
      expect(preview.timeRange).assertEqual('09:00-10:00 \u2192 10:15');
      expect(preview.addStr).assertEqual('(+15m)');
      expect(allocatable.length).assertEqual(1);
      expect(dialog.isCandidateAllocatable(second)).assertFalse();
    });

    it('boundary: gap_resolution_should_keep_list_mode_when_multiple_gaps_exist', 0, () => {
      // Arrange
      const vm = new GapVmMockCA();
      vm.distributionCoordinator.sortedGaps = [
        buildEventCA(1, 'first gap', '2026-04-22 10:00'),
        buildEventCA(2, 'second gap', '2026-04-22 12:00')
      ];
      const dialog = new GapDialogHostImplCA(vm);

      // Act
      dialog.refreshGaps();

      // Assert
      expect(dialog.gapList.length).assertEqual(2);
      expect(dialog.currentGap === null).assertTrue();
    });

    it('normal: gap_resolution_should_use_vm_trigger_for_private_tier_helpers', 0, () => {
      // Arrange
      const vm = new GapVmMockCA();
      vm.trigger = 45;
      const dialog = new GapDialogHostImplCA(vm);

      // Act
      const below = dialog.getTierColor(44);
      const label = dialog.getTierLabel(45);

      // Assert
      expect(below).assertEqual('');
      expect(label).assertEqual('效率补全');
    });

    it('invalid: gap_resolution_should_report_no_positive_allocation_for_empty_map', 0, () => {
      // Arrange
      const dialog = new GapDialogHostImplCA(new GapVmMockCA());
      const emptyMap = new Map<number, number>();

      // Act
      const positive = dialog.hasPositiveAllocation(emptyMap);

      // Assert
      expect(positive).assertFalse();
      expect(hasPositiveAllocationValues([])).assertFalse();
    });

    it('regression: td-20260422-gap_resolution_tier_boundaries_should_match_public_helpers', 0, () => {
      // Arrange
      const trigger = 30;

      // Act
      const gold = resolveGapTierColor(150, trigger);
      const blue = resolveGapTierColor(90, trigger);
      const green = resolveGapTierColor(30, trigger);
      const low = resolveGapTierLabel(29, trigger);

      // Assert
      expect(gold).assertEqual('#FFB800');
      expect(blue).assertEqual('#007DFF');
      expect(green).assertEqual('#4CAF50');
      expect(low).assertEqual('');
    });

    it('combined: plan_share_clamp_and_gap_preview_should_keep_boundary_contracts_together', 0, () => {
      // Arrange
      const eventsCount = 0;
      const vm = new GapVmMockCA();
      const gap = buildEventCA(1, 'gap', '2026-04-22 10:00');
      const item = buildEventCA(2, 'short stop', '2026-04-22 09:30', 30);
      vm.distributionCoordinator.sortedGaps = [gap];
      vm.distributionCoordinator.distributionCandidates = [item];
      vm.distributionCoordinator.previewMap.set(item.id, 0);
      const dialog = new GapDialogHostImplCA(vm);

      // Act
      dialog.refreshGaps();
      const preview = dialog.getPreview(item);
      const clamped = clampPlanShareEvents(eventsCount);

      // Assert
      expect(clamped).assertEqual(0);
      expect(preview.timeRange).assertEqual('09:30-10:00 \u2192 10:00');
      expect(preview.addStr).assertEqual('');
    });
  });
}
