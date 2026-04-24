import { describe, expect, it } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { GapResolutionDialog } from '../main/ets/pages/components/dialogs/GapResolutionDialog';
import {
  buildMapPickerCoordinateFallbackAddress,
  formatMapPickerDistance,
  isMapPickerAddressResolving,
  isMapPickerCoordinateValid,
  resolveMapPickerCenterHint,
  resolveMapPickerSelectionAddress,
  resolveMapPickerStorageKey
} from '../main/ets/pages/MapPickerPage';
import { HistoryManager } from '../main/ets/domain/timeline/HistoryManager';
import { NotificationBridge } from '../main/ets/domain/statemachine/NotificationBridge';
import { PlanStatus, TransitionTriggerSource } from '../main/ets/domain/statemachine/PlanStatus';
import { WeatherReminderStore } from '../main/ets/common/utils/weather/WeatherReminderStore';
import { AppStorageKeys } from '../main/ets/common/constants/AppStorageKeys';
import { DateUtil } from '../main/ets/common/utils/DateUtil';
import { TimelineDatePolicy } from '../main/ets/domain/policy/TimelineDatePolicy';

interface GapPreviewGM {
  timeRange: string;
  addStr: string;
}

interface GapDialogPrivateGM {
  vm: GapVmMockGM;
  strategy: 'EQUAL' | 'SMART';
  selectedIds: Set<number>;
  currentGap: EventEntity | null;
  gapList: EventEntity[];
  candidates: EventEntity[];
  refreshGaps(): void;
  selectGap(item: EventEntity): void;
  getPreview(item: EventEntity): GapPreviewGM;
  safeShowToast(message: string, duration?: number): void;
}

class GapDistributionCoordinatorMockGM {
  public sortedGaps: EventEntity[] = [];
  public distributionCandidates: EventEntity[] = [];
  public previewMap: Map<number, number> = new Map<number, number>();

  getSortedGaps(): EventEntity[] {
    return this.sortedGaps;
  }

  getDistributionCandidates(_item: EventEntity): EventEntity[] {
    return this.distributionCandidates;
  }

  calculateDistributionPreview(
    _gap: EventEntity,
    _candidates: EventEntity[],
    _selectedIds: Set<number>,
    _strategy: 'EQUAL' | 'SMART'
  ): Map<number, number> {
    return this.previewMap;
  }
}

class GapVmMockGM {
  public distributionCoordinator: GapDistributionCoordinatorMockGM = new GapDistributionCoordinatorMockGM();
  public trigger: number = 45;

  getIdleGapTriggerMinutes(): number {
    return this.trigger;
  }
}

type GapDialogMethodGM<TResult, TArgs extends (Object | number | string | boolean | undefined)[]> =
  (this: GapDialogPrivateGM, ...args: TArgs) => TResult;

function getGapDialogMethodGM<TResult, TArgs extends (Object | number | string | boolean | undefined)[]>(name: string):
  GapDialogMethodGM<TResult, TArgs> {
  const prototype = Reflect.get(GapResolutionDialog as Object, 'prototype') as Object;
  return Reflect.get(prototype, name) as GapDialogMethodGM<TResult, TArgs>;
}

function invokeGapDialogMethodGM<TResult, TArgs extends (Object | number | string | boolean | undefined)[]>(
  host: GapDialogPrivateGM,
  method: GapDialogMethodGM<TResult, TArgs>,
  ...args: TArgs
): TResult {
  const bound = method.bind(host) as (...boundArgs: TArgs) => TResult;
  return bound(...args);
}

const gapRefreshGapsGM = getGapDialogMethodGM<void, []>('refreshGaps');
const gapSelectGapGM = getGapDialogMethodGM<void, [EventEntity]>('selectGap');
const gapGetPreviewGM = getGapDialogMethodGM<GapPreviewGM, [EventEntity]>('getPreview');
const gapSafeShowToastGM = getGapDialogMethodGM<void, [string, (number | undefined)]>('safeShowToast');

class GapDialogHostGM implements GapDialogPrivateGM {
  public vm: GapVmMockGM;
  public strategy: 'EQUAL' | 'SMART' = 'SMART';
  public selectedIds: Set<number> = new Set<number>();
  public currentGap: EventEntity | null = null;
  public gapList: EventEntity[] = [];
  public candidates: EventEntity[] = [];

  constructor(vm: GapVmMockGM) {
    this.vm = vm;
  }

  refreshGaps(): void {
    invokeGapDialogMethodGM(this, gapRefreshGapsGM);
  }

  selectGap(item: EventEntity): void {
    invokeGapDialogMethodGM(this, gapSelectGapGM, item);
  }

  getPreview(item: EventEntity): GapPreviewGM {
    return invokeGapDialogMethodGM(this, gapGetPreviewGM, item);
  }

  safeShowToast(message: string, duration?: number): void {
    invokeGapDialogMethodGM(this, gapSafeShowToastGM, message, duration);
  }
}

function buildGapEventGM(id: number, name: string, gapMinutes: number, computedTime: string, duration: number = 60): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = name;
  event.gap_minutes = gapMinutes;
  event.computed_time = computedTime;
  event.duration = duration;
  event.status = 1;
  event.fixed_start_time = computedTime.split(' ').pop() || computedTime;
  return event;
}

function createHistoryEventGM(id: number, status: number, completionStatus: number): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = `history_gm_${id}`;
  event.status = status;
  event.completion_status = completionStatus;
  return event;
}

function resetReminderStorageGM(planIdNum: number): void {
  AppStorage.setOrCreate(AppStorageKeys.WEATHER_REMINDER_SEQ, 0);
  AppStorage.setOrCreate(AppStorageKeys.WEATHER_REMINDER_PAYLOAD, '');
  AppStorage.setOrCreate(`${AppStorageKeys.WEATHER_REMINDER_PAYLOAD}_${planIdNum}`, '');
  AppStorage.setOrCreate(`WeatherInProgressShown_${planIdNum}`, 0);
}

export default function phase2BatchGMTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchGM_gap_map_picker_lines', () => {
    it('combined: gap_dialog_should_cover_zero_single_multi_refresh_and_preview_edges', 0, () => {
      const vm = new GapVmMockGM();
      const page = new GapDialogHostGM(vm);
      const singleGap = buildGapEventGM(701, 'single', 50, '09:00');
      const multiGap = buildGapEventGM(702, 'multi', 80, '2026-04-24 12:00');
      const candidate = buildGapEventGM(801, 'candidate', 0, '10:20', 40);
      let toastThrew = false;

      vm.distributionCoordinator.sortedGaps = [];
      page.refreshGaps();
      expect(page.currentGap).assertNull();
      expect(page.gapList.length).assertEqual(0);

      vm.distributionCoordinator.sortedGaps = [singleGap];
      vm.distributionCoordinator.distributionCandidates = [candidate];
      vm.distributionCoordinator.previewMap = new Map<number, number>();
      page.refreshGaps();
      const emptyPreview = page.getPreview(candidate);

      vm.distributionCoordinator.sortedGaps = [singleGap, multiGap];
      page.refreshGaps();
      page.selectGap(multiGap);
      vm.distributionCoordinator.previewMap = new Map<number, number>([[candidate.id, 15]]);
      const positivePreview = page.getPreview(candidate);

      try {
        page.safeShowToast('toast_with_duration', 800);
      } catch (_error) {
        toastThrew = true;
      }

      expect(page.gapList.length).assertEqual(2);
      expect(page.currentGap?.id ?? -1).assertEqual(multiGap.id);
      expect(page.candidates.length).assertEqual(1);
      expect(emptyPreview.addStr).assertEqual('');
      expect(positivePreview.addStr).assertEqual('(+15m)');
      expect(positivePreview.timeRange.length > 0).assertTrue();
      expect(toastThrew).assertFalse();
    });

    it('combined: map_picker_helpers_should_cover_coordinate_distance_and_center_hint_edges', 0, () => {
      expect(isMapPickerCoordinateValid(30.12345, 120.54321)).assertTrue();
      expect(isMapPickerCoordinateValid(0, 0)).assertFalse();
      expect(isMapPickerCoordinateValid(91, 120)).assertFalse();
      expect(isMapPickerAddressResolving('')).assertTrue();
      expect(isMapPickerAddressResolving('resolving_placeholder')).assertFalse();
      expect(isMapPickerAddressResolving('Known address')).assertFalse();
      expect(buildMapPickerCoordinateFallbackAddress(31.2, 121.5).includes('31.20000')).assertTrue();
      expect(formatMapPickerDistance(undefined)).assertEqual('');
      expect(formatMapPickerDistance(1500)).assertEqual('1.5km');
      expect(formatMapPickerDistance(12.8)).assertEqual('12m');
      expect(resolveMapPickerCenterHint('geocode', 'museum').includes('museum')).assertTrue();
      expect(resolveMapPickerCenterHint('existing', '').length > 0).assertTrue();
      expect(resolveMapPickerCenterHint('current', '').length > 0).assertTrue();
      expect(resolveMapPickerSelectionAddress('', 31.2, 121.5))
        .assertEqual(buildMapPickerCoordinateFallbackAddress(31.2, 121.5));
      expect(resolveMapPickerSelectionAddress('actual address', 31.2, 121.5)).assertEqual('actual address');
      expect(resolveMapPickerStorageKey(0)).assertEqual('pickedLocationStr');
      expect(resolveMapPickerStorageKey(9)).assertEqual('pickedLocationStr_9');
    });

    it('combined: history_notification_and_date_policy_helpers_should_cover_small_function_edges', 0, () => {
      const completed = createHistoryEventGM(1, 1, EventEntity.STATE_COMPLETED);
      const skipped = createHistoryEventGM(2, 1, EventEntity.STATE_SKIPPED);
      const active = createHistoryEventGM(3, 1, EventEntity.STATE_PENDING);
      active.actual_start_time = 1000;
      const backlog = createHistoryEventGM(4, 0, EventEntity.STATE_COMPLETED);
      const summary = HistoryManager.generateSummary([completed, skipped, active, backlog], '   ', 88);

      const planIdNum = 508;
      const bridge = new NotificationBridge();
      resetReminderStorageGM(planIdNum);
      bridge.handlePlanTransitionNotification({
        planId: `${planIdNum}`,
        fromStatus: PlanStatus.READY,
        toStatus: PlanStatus.IN_PROGRESS,
        triggerSource: TransitionTriggerSource.TIME_WINDOW,
        triggerReason: 'auto_start',
        timestamp: 8801
      });
      bridge.handlePlanTransitionNotification({
        planId: `${planIdNum}`,
        fromStatus: PlanStatus.IN_PROGRESS,
        toStatus: PlanStatus.CANCELLED,
        triggerSource: TransitionTriggerSource.USER_ACTION,
        triggerReason: 'cancel_by_user',
        timestamp: 8802
      });
      const payload = WeatherReminderStore.readPayload(planIdNum);
      const shownFlag = AppStorage.get<number>(`WeatherInProgressShown_${planIdNum}`) ?? 1;

      const baseDate = new Date(2026, 0, 31, 23, 30, 0, 0);
      const header = DateUtil.getDateHeader(baseDate, 60);
      const targetTs = new Date('2026-03-15T15:20:00').getTime();
      const offset = TimelineDatePolicy.timestampToDayOffset(0, targetTs);

      expect(summary.planName.length > 0).assertTrue();
      expect(summary.planName.includes('#88')).assertTrue();
      expect(summary.completedCount).assertEqual(1);
      expect(summary.skippedCount).assertEqual(1);
      expect(summary.activeCount).assertEqual(1);
      expect(payload === null).assertTrue();
      expect(shownFlag).assertEqual(0);
      expect(header.length > 0).assertTrue();
      expect(header.includes('2026') || header.includes('2')).assertTrue();
      expect(offset).assertEqual(0);
    });
  });
}
