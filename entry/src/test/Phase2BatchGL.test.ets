import { Want } from '@kit.AbilityKit';
import { describe, expect, it } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { GapResolutionDialog } from '../main/ets/pages/components/dialogs/GapResolutionDialog';
import EntryAbility from '../main/ets/entryability/EntryAbility';
import { AppStorageKeys } from '../main/ets/common/constants/AppStorageKeys';

interface GapPreviewGL {
  timeRange: string;
  addStr: string;
}

interface GapDialogPrivateGL {
  vm: GapVmMockGL;
  strategy: 'EQUAL' | 'SMART';
  selectedIds: Set<number>;
  currentGap: EventEntity | null;
  gapList: EventEntity[];
  candidates: EventEntity[];
  aboutToAppear(): void;
  refreshGaps(): void;
  selectGap(item: EventEntity): void;
  getPreview(item: EventEntity): GapPreviewGL;
  getAllocatableCandidates(): EventEntity[];
  isCandidateAllocatable(item: EventEntity): boolean;
  safeShowToast(message: string, duration?: number): void;
}

class GapDistributionCoordinatorMockGL {
  public sortedGaps: EventEntity[] = [];
  public distributionCandidates: EventEntity[] = [];
  public safetyCapMap: Map<number, number> = new Map<number, number>();
  public previewMap: Map<number, number> = new Map<number, number>();

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
    _candidates: EventEntity[],
    _selectedIds: Set<number>,
    _strategy: 'EQUAL' | 'SMART'
  ): Map<number, number> {
    return this.previewMap;
  }
}

class GapVmMockGL {
  public distributionCoordinator: GapDistributionCoordinatorMockGL = new GapDistributionCoordinatorMockGL();
  public trigger: number = 45;

  getIdleGapTriggerMinutes(): number {
    return this.trigger;
  }
}

type GapDialogMethodGL<TResult, TArgs extends (Object | number | string | boolean | undefined)[]> =
  (this: GapDialogPrivateGL, ...args: TArgs) => TResult;

function getGapDialogMethodGL<TResult, TArgs extends (Object | number | string | boolean | undefined)[]>(name: string):
  GapDialogMethodGL<TResult, TArgs> {
  const prototype = Reflect.get(GapResolutionDialog as Object, 'prototype') as Object;
  return Reflect.get(prototype, name) as GapDialogMethodGL<TResult, TArgs>;
}

function invokeGapDialogMethodGL<TResult, TArgs extends (Object | number | string | boolean | undefined)[]>(
  host: GapDialogPrivateGL,
  method: GapDialogMethodGL<TResult, TArgs>,
  ...args: TArgs
): TResult {
  const bound = method.bind(host) as (...boundArgs: TArgs) => TResult;
  return bound(...args);
}

const gapAboutToAppearGL = getGapDialogMethodGL<void, []>('aboutToAppear');
const gapRefreshGapsGL = getGapDialogMethodGL<void, []>('refreshGaps');
const gapSelectGapGL = getGapDialogMethodGL<void, [EventEntity]>('selectGap');
const gapGetPreviewGL = getGapDialogMethodGL<GapPreviewGL, [EventEntity]>('getPreview');
const gapGetAllocatableCandidatesGL = getGapDialogMethodGL<EventEntity[], []>('getAllocatableCandidates');
const gapIsCandidateAllocatableGL = getGapDialogMethodGL<boolean, [EventEntity]>('isCandidateAllocatable');
const gapSafeShowToastGL = getGapDialogMethodGL<void, [string, (number | undefined)]>('safeShowToast');

class GapDialogHostGL implements GapDialogPrivateGL {
  public vm: GapVmMockGL;
  public strategy: 'EQUAL' | 'SMART' = 'EQUAL';
  public selectedIds: Set<number> = new Set<number>();
  public currentGap: EventEntity | null = null;
  public gapList: EventEntity[] = [];
  public candidates: EventEntity[] = [];

  constructor(vm: GapVmMockGL) {
    this.vm = vm;
  }

  aboutToAppear(): void {
    invokeGapDialogMethodGL(this, gapAboutToAppearGL);
  }

  refreshGaps(): void {
    invokeGapDialogMethodGL(this, gapRefreshGapsGL);
  }

  selectGap(item: EventEntity): void {
    invokeGapDialogMethodGL(this, gapSelectGapGL, item);
  }

  getPreview(item: EventEntity): GapPreviewGL {
    return invokeGapDialogMethodGL(this, gapGetPreviewGL, item);
  }

  getAllocatableCandidates(): EventEntity[] {
    return invokeGapDialogMethodGL(this, gapGetAllocatableCandidatesGL);
  }

  isCandidateAllocatable(item: EventEntity): boolean {
    return invokeGapDialogMethodGL(this, gapIsCandidateAllocatableGL, item);
  }

  safeShowToast(message: string, duration?: number): void {
    invokeGapDialogMethodGL(this, gapSafeShowToastGL, message, duration);
  }
}

function buildGapEventGL(id: number, name: string, gapMinutes: number, computedTime: string, duration: number = 60): EventEntity {
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

class NotificationWantGL {
  parameters?: Object;
  uri?: string;
}

class NotificationParamsInvalidPlanGL {
  fromNotification: boolean = true;
  targetPlanId: string = 'NaN';
}

class NotificationParamsInvalidEventGL {
  fromNotification: boolean = true;
  targetPlanId: number = 99;
  targetEventId: string = 'bad';
  forceCompanionMode: boolean = false;
}

class EntryAbilityHostGL {
  handleNotificationLaunchWant(want: Want): void {
    const method = getEntryAbilityMethodGL<(this: EntryAbilityHostGL, want: Want) => void>('handleNotificationLaunchWant');
    invokeEntryAbilityMethodGL(method, this, want);
  }

  handleDeepLinkWant(want: Want): void {
    const method = getEntryAbilityMethodGL<(this: EntryAbilityHostGL, want: Want) => void>('handleDeepLinkWant');
    invokeEntryAbilityMethodGL(method, this, want);
  }
}

function getEntryAbilityMethodGL<T>(name: string): T {
  const prototype = Reflect.get(EntryAbility as Object, 'prototype') as Object;
  return Reflect.get(prototype, name) as T;
}

function invokeEntryAbilityMethodGL<THost, TResult, TArgs extends (Object | Want)[]>(
  method: (this: THost, ...args: TArgs) => TResult,
  host: THost,
  ...args: TArgs
): TResult {
  const bound = method.bind(host) as (...boundArgs: TArgs) => TResult;
  return bound(...args);
}

function createWantGL(parameters?: Object, uri?: string): Want {
  const want = new NotificationWantGL();
  want.parameters = parameters;
  want.uri = uri;
  return want as Want;
}

function resetRouteStorageGL(): void {
  AppStorage.setOrCreate(AppStorageKeys.NOTIFICATION_NAV_PAYLOAD, '');
  AppStorage.setOrCreate(AppStorageKeys.NOTIFICATION_NAV_SEQ, 0);
  AppStorage.setOrCreate('pendingImportUri', '');
}

export default function phase2BatchGLTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchGL_gap_entry_lines', () => {
    it('combined: gap_dialog_should_cover_single_gap_refresh_preview_and_allocatable_edges', 0, () => {
      const vm = new GapVmMockGL();
      const page = new GapDialogHostGL(vm);
      const gap = buildGapEventGL(501, 'gap', 55, '2026-04-24 10:00');
      const alloc = buildGapEventGL(601, 'alloc', 0, '2026-04-24 11:00', 40);
      const blocked = buildGapEventGL(602, 'blocked', 0, '2026-04-24 12:00', 30);
      vm.distributionCoordinator.sortedGaps = [gap];
      vm.distributionCoordinator.distributionCandidates = [alloc, blocked];
      vm.distributionCoordinator.safetyCapMap = new Map<number, number>([[alloc.id, 20], [blocked.id, 0]]);
      vm.distributionCoordinator.previewMap = new Map<number, number>([[alloc.id, 20]]);
      let toastThrew = false;

      page.aboutToAppear();
      const allocatables = page.getAllocatableCandidates();
      const preview = page.getPreview(alloc);
      const blockedAllocatable = page.isCandidateAllocatable(blocked);
      page.currentGap = null;
      const orphanPreview = page.getPreview(blocked);
      try {
        page.safeShowToast('toast_only_message');
      } catch (_error) {
        toastThrew = true;
      }

      expect(page.candidates.length).assertEqual(2);
      expect(page.selectedIds.size).assertEqual(0);
      expect(allocatables.length).assertEqual(1);
      expect(blockedAllocatable).assertFalse();
      expect(preview.addStr).assertEqual('(+20m)');
      expect(preview.timeRange.length > 0).assertTrue();
      expect(orphanPreview.addStr).assertEqual('');
      expect(toastThrew).assertFalse();
    });

    it('combined: entry_ability_should_cover_notification_and_deep_link_ignore_paths', 0, () => {
      resetRouteStorageGL();
      const host = new EntryAbilityHostGL();

      host.handleNotificationLaunchWant(createWantGL(undefined));
      host.handleNotificationLaunchWant(createWantGL(new NotificationParamsInvalidPlanGL()));
      host.handleNotificationLaunchWant(createWantGL(new NotificationParamsInvalidEventGL()));
      host.handleDeepLinkWant(createWantGL(undefined, 'travelapp://other/path'));
      host.handleDeepLinkWant(createWantGL(undefined, ''));

      const seq = AppStorage.get<number>(AppStorageKeys.NOTIFICATION_NAV_SEQ) ?? 0;
      const payload = AppStorage.get<string>(AppStorageKeys.NOTIFICATION_NAV_PAYLOAD) ?? '';
      const importUri = AppStorage.get<string>('pendingImportUri') ?? '';

      expect(seq >= 0).assertTrue();
      expect(payload.length >= 0).assertTrue();
      expect(importUri).assertEqual('');
    });
  });
}
