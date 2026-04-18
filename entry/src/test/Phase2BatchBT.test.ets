import { describe, expect, it } from '@ohos/hypium';
import { AppConfig } from '../main/ets/common/utils/AppConfig';
import { DEFAULT_WEATHER_USER_PREFERENCE, WeatherUserPreference } from '../main/ets/domain/services/WeatherModels';
import {
  ComposableStrategy,
  DensityLevel,
  EnergyLevel,
  PaceLevel,
  PreferenceType
} from '../main/ets/domain/strategy/TravelStrategyDimensions';
import { UserProfileService } from '../main/ets/domain/strategy/UserProfileService';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { AddItemDialog } from '../main/ets/pages/components/dialogs/AddItemDialog';
import { AiInputDialog } from '../main/ets/pages/components/dialogs/AiInputDialog';
import { ConflictCompressDialog } from '../main/ets/pages/components/dialogs/ConflictCompressDialog';
import { GapResolutionDialog } from '../main/ets/pages/components/dialogs/GapResolutionDialog';
import { PlanSettingsDialog } from '../main/ets/pages/components/dialogs/PlanSettingsDialog';

function sleepBT(ms: number): Promise<void> {
  return new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => {
    setTimeout(() => resolve(), ms);
  });
}

function getDialogMethodBT<T>(dialogCtor: Object, name: string): T {
  const prototype = Reflect.get(dialogCtor, 'prototype') as Object;
  return Reflect.get(prototype, name) as T;
}

function invokeDialogMethodBT<THost, TResult, TArgs extends (Object | number | string | boolean)[]>(
  method: (this: THost, ...args: TArgs) => TResult,
  host: THost,
  ...args: TArgs
): TResult {
  const bound = method.bind(host) as (...boundArgs: TArgs) => TResult;
  return bound(...args);
}

function buildStrategyBT(
  density: DensityLevel = DensityLevel.MEDIUM,
  pace: PaceLevel = PaceLevel.BALANCED,
  preference: PreferenceType = PreferenceType.BALANCED,
  energy: EnergyLevel = EnergyLevel.MEDIUM
): ComposableStrategy {
  return {
    density: density,
    pace: pace,
    preference: preference,
    energy: energy
  };
}

function buildEventBT(id: number, name: string, computedTime: string, duration: number = 60): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = name;
  event.computed_time = computedTime;
  event.duration = duration;
  event.gap_minutes = 0;
  event.priority = 0;
  event.lock_status = 0;
  event.source = 0;
  event.fixed_start_time = computedTime.split(' ').pop() || computedTime;
  return event;
}

class UserProfileServiceHooksBT {
  private readonly originHint: Object;
  private readonly originRecommended: Object;

  constructor() {
    this.originHint = Reflect.get(UserProfileService, 'getRecommendationHint') as Object;
    this.originRecommended = Reflect.get(UserProfileService, 'getRecommendedStrategy') as Object;
  }

  setHint(fn: () => Promise<string>): void {
    Reflect.set(UserProfileService, 'getRecommendationHint', fn);
  }

  setRecommended(fn: () => Promise<ComposableStrategy | null>): void {
    Reflect.set(UserProfileService, 'getRecommendedStrategy', fn);
  }

  restore(): void {
    Reflect.set(UserProfileService, 'getRecommendationHint', this.originHint);
    Reflect.set(UserProfileService, 'getRecommendedStrategy', this.originRecommended);
  }
}

class AppConfigHooksBT {
  private readonly amapSdkApiKey: Object;

  constructor() {
    this.amapSdkApiKey = Reflect.get(AppConfig as Object, 'AMAP_SDK_API_KEY') as Object;
  }

  setAmapSdkApiKey(value: Object): void {
    Reflect.set(AppConfig as Object, 'AMAP_SDK_API_KEY', value);
  }

  restore(): void {
    Reflect.set(AppConfig as Object, 'AMAP_SDK_API_KEY', this.amapSdkApiKey);
  }
}

class GapDistributionCoordinatorMockBT {
  sortedGaps: EventEntity[] = [];
  distributionCandidates: EventEntity[] = [];
  previewMap: Map<number, number> = new Map<number, number>();
  safetyCapMap: Map<number, number> = new Map<number, number>();

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

  getSafetyCap(item: EventEntity, _gap: EventEntity): number {
    return this.safetyCapMap.get(item.id) ?? 0;
  }
}

class GapVmMockBT {
  distributionCoordinator: GapDistributionCoordinatorMockBT = new GapDistributionCoordinatorMockBT();
  idleGapTriggerMinutes: number = 45;

  getIdleGapTriggerMinutes(): number {
    return this.idleGapTriggerMinutes;
  }
}

interface GapPreviewBT {
  timeRange: string;
  addStr: string;
}

const gapRefreshGapsBT = getDialogMethodBT<(this: GapDialogHostBT) => void>(GapResolutionDialog as Object, 'refreshGaps');
const gapSelectGapBT = getDialogMethodBT<(this: GapDialogHostBT, item: EventEntity) => void>(GapResolutionDialog as Object, 'selectGap');
const gapGetPreviewBT = getDialogMethodBT<(this: GapDialogHostBT, item: EventEntity) => GapPreviewBT>(
  GapResolutionDialog as Object,
  'getPreview'
);
const gapGetTierColorBT = getDialogMethodBT<(this: GapDialogHostBT, min: number) => string>(GapResolutionDialog as Object, 'getTierColor');
const gapGetTierLabelBT = getDialogMethodBT<(this: GapDialogHostBT, min: number) => string>(GapResolutionDialog as Object, 'getTierLabel');
const gapHasPositiveAllocationBT = getDialogMethodBT<(this: GapDialogHostBT, distributionMap: Map<number, number>) => boolean>(
  GapResolutionDialog as Object,
  'hasPositiveAllocation'
);
const gapGetAllocatableCandidatesBT = getDialogMethodBT<(this: GapDialogHostBT) => EventEntity[]>(
  GapResolutionDialog as Object,
  'getAllocatableCandidates'
);
const gapIsCandidateAllocatableBT = getDialogMethodBT<(this: GapDialogHostBT, item: EventEntity) => boolean>(
  GapResolutionDialog as Object,
  'isCandidateAllocatable'
);

class GapDialogHostBT {
  vm: GapVmMockBT = new GapVmMockBT();
  strategy: 'EQUAL' | 'SMART' = 'EQUAL';
  selectedIds: Set<number> = new Set<number>();
  currentGap: EventEntity | null = null;
  gapList: EventEntity[] = [];
  candidates: EventEntity[] = [];

  refreshGaps(): void {
    invokeDialogMethodBT(gapRefreshGapsBT, this);
  }

  selectGap(item: EventEntity): void {
    invokeDialogMethodBT(gapSelectGapBT, this, item);
  }

  getPreview(item: EventEntity): GapPreviewBT {
    return invokeDialogMethodBT(gapGetPreviewBT, this, item);
  }

  getTierColor(min: number): string {
    return invokeDialogMethodBT(gapGetTierColorBT, this, min);
  }

  getTierLabel(min: number): string {
    return invokeDialogMethodBT(gapGetTierLabelBT, this, min);
  }

  hasPositiveAllocation(distributionMap: Map<number, number>): boolean {
    return invokeDialogMethodBT(gapHasPositiveAllocationBT, this, distributionMap);
  }

  getAllocatableCandidates(): EventEntity[] {
    return invokeDialogMethodBT(gapGetAllocatableCandidatesBT, this);
  }

  isCandidateAllocatable(item: EventEntity): boolean {
    return invokeDialogMethodBT(gapIsCandidateAllocatableBT, this, item);
  }
}

const aiAboutToAppearBT = getDialogMethodBT<(this: AiInputDialogHostBT) => void>(AiInputDialog as Object, 'aboutToAppear');
const aiLoadRecommendationBT = getDialogMethodBT<(this: AiInputDialogHostBT) => Promise<void>>(AiInputDialog as Object, 'loadRecommendation');
const aiGetLoadingTextBT = getDialogMethodBT<(this: AiInputDialogHostBT) => string>(AiInputDialog as Object, 'getLoadingText');

class AiInputDialogHostBT {
  strategyTouched: boolean = true;
  currentStrategyMode: number = 0;
  initialSelectedStrategyMode: number = 0;
  initialPrompt: string = '';
  forceUseInitialSelection: boolean = false;
  selectedStrategy: number = 0;
  useCustomStrategy: boolean = false;
  inputText: string = '';
  recommendHint: string = '';
  recommendedStrategy: ComposableStrategy | null = null;
  initialCustomStrategy?: ComposableStrategy;
  customStrategy: ComposableStrategy = buildStrategyBT();

  aboutToAppear(): void {
    invokeDialogMethodBT(aiAboutToAppearBT, this);
  }

  async loadRecommendation(): Promise<void> {
    await invokeDialogMethodBT(aiLoadRecommendationBT, this);
  }

  getLoadingText(): string {
    return invokeDialogMethodBT(aiGetLoadingTextBT, this);
  }
}

const addAboutToAppearBT = getDialogMethodBT<(this: AddItemDialogHostBT) => void>(AddItemDialog as Object, 'aboutToAppear');
const addCalculateDurationBT = getDialogMethodBT<(this: AddItemDialogHostBT) => void>(AddItemDialog as Object, 'calculateDuration');
const addRecalculateEndTimeBT = getDialogMethodBT<(this: AddItemDialogHostBT) => void>(AddItemDialog as Object, 'recalculateEndTime');
const addFormatTimeBT = getDialogMethodBT<(this: AddItemDialogHostBT, date: Date) => string>(AddItemDialog as Object, 'formatTime');
const addApplyTimeStringBT = getDialogMethodBT<(this: AddItemDialogHostBT, target: Date, timeText: string) => Date>(
  AddItemDialog as Object,
  'applyTimeString'
);
const addIsValidCoordinateBT = getDialogMethodBT<(this: AddItemDialogHostBT, lat: number, lng: number) => boolean>(
  AddItemDialog as Object,
  'isValidCoordinate'
);
const addScopedStorageKeyBT = getDialogMethodBT<(this: AddItemDialogHostBT, base: string) => string>(AddItemDialog as Object, 'scopedStorageKey');
const addCanUseMapPickerBT = getDialogMethodBT<(this: AddItemDialogHostBT) => boolean>(AddItemDialog as Object, 'canUseMapPicker');

class AddItemDialogHostBT {
  globalDefaultDuration: number = 60;
  showTip: boolean = false;
  initName: string = '';
  initNote: string = '';
  initDuration: number = 0;
  initIsSchedule: boolean = false;
  initFixedTime: string = '';
  initSuggestedTime: string = '';
  initIsAnchor: boolean = false;
  initDayOffset: number = 0;
  initPreTravel: number = -1;
  initPriority: number = 0;
  storageScopePlanId: number = 0;
  planStartDate: number = new Date(2026, 3, 10, 8, 0, 0, 0).getTime();
  initLat: number = 0;
  initLng: number = 0;
  name: string = '';
  note: string = '';
  duration: number = 60;
  isSchedule: boolean = false;
  isAnchor: boolean = false;
  preTravel: number = 0;
  startTime: Date = new Date(2026, 3, 10, 8, 0, 0, 0);
  endTime: Date = new Date(2026, 3, 10, 9, 0, 0, 0);
  isMustVisit: boolean = false;
  latitude: number = 0;
  longitude: number = 0;
  isGeocoding: boolean = false;
  mode: number = 1;
  effectiveTheme: string = 'light';

  aboutToAppear(): void {
    invokeDialogMethodBT(addAboutToAppearBT, this);
  }

  calculateDuration(): void {
    invokeDialogMethodBT(addCalculateDurationBT, this);
  }

  recalculateEndTime(): void {
    invokeDialogMethodBT(addRecalculateEndTimeBT, this);
  }

  formatTime(date: Date): string {
    return invokeDialogMethodBT(addFormatTimeBT, this, date);
  }

  applyTimeString(target: Date, timeText: string): Date {
    return invokeDialogMethodBT(addApplyTimeStringBT, this, target, timeText);
  }

  isValidCoordinate(lat: number, lng: number): boolean {
    return invokeDialogMethodBT(addIsValidCoordinateBT, this, lat, lng);
  }

  scopedStorageKey(base: string): string {
    return invokeDialogMethodBT(addScopedStorageKeyBT, this, base);
  }

  canUseMapPicker(): boolean {
    return invokeDialogMethodBT(addCanUseMapPickerBT, this);
  }
}

interface CompressionAffectedItemBT {
  index: number;
  newVal: number;
}

interface CompressionCandidateBT {
  id: number;
  index: number;
  name: string;
  oldVal: number;
  selectable: boolean;
  isRigid: boolean;
  disabledReason?: string;
}

interface CompressionContextBT {
  neededGapMinutes: number;
  candidates: CompressionCandidateBT[];
}

interface CompressionPlanBT {
  status: string;
  msg?: string;
  capacityMinutes?: number;
  remainingGapMinutes?: number;
  suggestedTime?: string;
  affectedItems: CompressionAffectedItemBT[];
}

class CompressionCoordinatorMockBT {
  context: CompressionContextBT | null = null;
  plan: CompressionPlanBT = {
    status: 'NO_ACTION',
    capacityMinutes: 0,
    remainingGapMinutes: 0,
    affectedItems: []
  };
  lastSelectedIds: number[] = [];

  buildCompressionSelectionContext(_index: number, _targetTime: string, _forcedGapMinutes: number): CompressionContextBT | null {
    return this.context;
  }

  calculateCompressionPlanBySelection(
    _index: number,
    _targetTime: string,
    selectedIds: Set<number>,
    _mode: 'RATIO' | 'EQUAL',
    _forcedGapMinutes: number
  ): CompressionPlanBT {
    this.lastSelectedIds = Array.from(selectedIds).sort((a, b) => a - b);
    return this.plan;
  }
}

class ConflictVmMockBT {
  compressionCoordinator: CompressionCoordinatorMockBT = new CompressionCoordinatorMockBT();
}

const conflictAboutToAppearBT = getDialogMethodBT<(this: ConflictCompressDialogHostBT) => void>(ConflictCompressDialog as Object, 'aboutToAppear');
const conflictRefreshPreviewBT = getDialogMethodBT<(this: ConflictCompressDialogHostBT) => void>(ConflictCompressDialog as Object, 'refreshPreview');
const conflictGetSelectableCandidatesBT = getDialogMethodBT<(this: ConflictCompressDialogHostBT) => CompressionCandidateBT[]>(
  ConflictCompressDialog as Object,
  'getSelectableCandidates'
);
const conflictIsAllSelectedBT = getDialogMethodBT<(this: ConflictCompressDialogHostBT) => boolean>(ConflictCompressDialog as Object, 'isAllSelected');
const conflictToggleSelectAllBT = getDialogMethodBT<(this: ConflictCompressDialogHostBT, next: boolean) => void>(
  ConflictCompressDialog as Object,
  'toggleSelectAll'
);
const conflictToggleOneBT = getDialogMethodBT<(
  this: ConflictCompressDialogHostBT,
  candidate: CompressionCandidateBT,
  checked: boolean
) => void>(ConflictCompressDialog as Object, 'toggleOne');
const conflictGetPreviewNewDurationBT = getDialogMethodBT<(this: ConflictCompressDialogHostBT, candidate: CompressionCandidateBT) => number>(
  ConflictCompressDialog as Object,
  'getPreviewNewDuration'
);
const conflictGetPreviewReducedBT = getDialogMethodBT<(this: ConflictCompressDialogHostBT, candidate: CompressionCandidateBT) => number>(
  ConflictCompressDialog as Object,
  'getPreviewReduced'
);
const conflictGetRemainingGapBT = getDialogMethodBT<(this: ConflictCompressDialogHostBT) => number>(
  ConflictCompressDialog as Object,
  'getRemainingGap'
);

class ConflictCompressDialogHostBT {
  vm: ConflictVmMockBT = new ConflictVmMockBT();
  targetIndex: number = 0;
  targetTime: string = '09:00';
  targetName: string = 'target';
  initialMode: 'RATIO' | 'EQUAL' = 'RATIO';
  initialSelectedIds: number[] = [];
  forcedGapMinutes: number = 0;
  mode: 'RATIO' | 'EQUAL' = 'RATIO';
  context: CompressionContextBT | null = null;
  selectedIds: Set<number> = new Set<number>();
  previewPlan: CompressionPlanBT | null = null;

  aboutToAppear(): void {
    invokeDialogMethodBT(conflictAboutToAppearBT, this);
  }

  refreshPreview(): void {
    invokeDialogMethodBT(conflictRefreshPreviewBT, this);
  }

  getSelectableCandidates(): CompressionCandidateBT[] {
    return invokeDialogMethodBT(conflictGetSelectableCandidatesBT, this);
  }

  isAllSelected(): boolean {
    return invokeDialogMethodBT(conflictIsAllSelectedBT, this);
  }

  toggleSelectAll(next: boolean): void {
    invokeDialogMethodBT(conflictToggleSelectAllBT, this, next);
  }

  toggleOne(candidate: CompressionCandidateBT, checked: boolean): void {
    invokeDialogMethodBT(conflictToggleOneBT, this, candidate, checked);
  }

  getPreviewNewDuration(candidate: CompressionCandidateBT): number {
    return invokeDialogMethodBT(conflictGetPreviewNewDurationBT, this, candidate);
  }

  getPreviewReduced(candidate: CompressionCandidateBT): number {
    return invokeDialogMethodBT(conflictGetPreviewReducedBT, this, candidate);
  }

  getRemainingGap(): number {
    return invokeDialogMethodBT(conflictGetRemainingGapBT, this);
  }
}

const planSettingsAboutToAppearBT = getDialogMethodBT<(this: PlanSettingsDialogHostBT) => void>(PlanSettingsDialog as Object, 'aboutToAppear');

class PlanSettingsDialogHostBT {
  weatherUserPreference: WeatherUserPreference = {
    heatSensitivity: DEFAULT_WEATHER_USER_PREFERENCE.heatSensitivity,
    rainSensitivity: DEFAULT_WEATHER_USER_PREFERENCE.rainSensitivity,
    weatherRiskTolerance: DEFAULT_WEATHER_USER_PREFERENCE.weatherRiskTolerance
  };
  weatherPreference: WeatherUserPreference = {
    heatSensitivity: DEFAULT_WEATHER_USER_PREFERENCE.heatSensitivity,
    rainSensitivity: DEFAULT_WEATHER_USER_PREFERENCE.rainSensitivity,
    weatherRiskTolerance: DEFAULT_WEATHER_USER_PREFERENCE.weatherRiskTolerance
  };

  aboutToAppear(): void {
    invokeDialogMethodBT(planSettingsAboutToAppearBT, this);
  }
}

export default function phase2BatchBTTest() {
  describe('phase2BatchBT_gapResolutionDialog_logic', () => {
    it('normal: gap_refresh_should_auto_select_when_only_one_gap', 0, () => {
      // Arrange
      const host = new GapDialogHostBT();
      const gap = buildEventBT(100, 'gap', '2026-04-10 09:00', 45);
      host.vm.distributionCoordinator.sortedGaps = [gap];
      host.vm.distributionCoordinator.distributionCandidates = [buildEventBT(1, 'a', '2026-04-10 10:00', 60)];
      // Act
      host.refreshGaps();
      // Assert
      expect(host.currentGap?.id ?? -1).assertEqual(100);
      expect(host.gapList.length).assertEqual(1);
      expect(host.candidates.length).assertEqual(1);
    });

    it('boundary: gap_refresh_should_reset_current_when_multiple_gap', 0, () => {
      // Arrange
      const host = new GapDialogHostBT();
      const gapA = buildEventBT(100, 'gapA', '2026-04-10 09:00', 45);
      const gapB = buildEventBT(101, 'gapB', '2026-04-10 11:00', 30);
      host.currentGap = gapA;
      host.vm.distributionCoordinator.sortedGaps = [gapA, gapB];
      // Act
      host.refreshGaps();
      // Assert
      expect(host.currentGap === null).assertTrue();
      expect(host.gapList.length).assertEqual(2);
    });

    it('normal: gap_preview_should_use_distribution_map', 0, () => {
      // Arrange
      const host = new GapDialogHostBT();
      const gap = buildEventBT(100, 'gap', '2026-04-10 09:00', 45);
      const candidate = buildEventBT(1, 'spot', '2026-04-10 09:00', 60);
      host.currentGap = gap;
      host.candidates = [candidate];
      host.vm.distributionCoordinator.previewMap = new Map<number, number>([[1, 30]]);
      // Act
      const preview = host.getPreview(candidate);
      // Assert
      expect(preview.timeRange).assertEqual('09:00-10:00 → 10:30');
      expect(preview.addStr).assertEqual('(+30m)');
    });

    it('invalid: gap_candidate_allocatable_should_be_false_without_current_gap', 0, () => {
      // Arrange
      const host = new GapDialogHostBT();
      const candidate = buildEventBT(1, 'spot', '2026-04-10 09:00', 60);
      // Act
      const allocatable = host.isCandidateAllocatable(candidate);
      // Assert
      expect(allocatable).assertFalse();
    });

    it('regression: gap_allocatable_candidates_should_filter_by_safety_cap', 0, () => {
      // Arrange
      const host = new GapDialogHostBT();
      const gap = buildEventBT(100, 'gap', '2026-04-10 09:00', 45);
      const a = buildEventBT(1, 'a', '2026-04-10 10:00', 60);
      const b = buildEventBT(2, 'b', '2026-04-10 11:00', 60);
      host.currentGap = gap;
      host.candidates = [a, b];
      host.vm.distributionCoordinator.safetyCapMap = new Map<number, number>([[1, 20], [2, 0]]);
      // Act
      const candidates = host.getAllocatableCandidates();
      // Assert
      expect(candidates.length).assertEqual(1);
      expect(candidates[0].id).assertEqual(1);
    });

    it('combined: gap_tier_and_allocation_should_match_threshold_rules', 0, () => {
      // Arrange
      const host = new GapDialogHostBT();
      host.vm.idleGapTriggerMinutes = 45;
      const positiveMap = new Map<number, number>([[1, 0], [2, 10]]);
      const zeroMap = new Map<number, number>([[1, 0], [2, 0]]);
      // Act
      const color150 = host.getTierColor(150);
      const label90 = host.getTierLabel(90);
      const color45 = host.getTierColor(45);
      const hasPositive = host.hasPositiveAllocation(positiveMap);
      const hasZeroOnly = host.hasPositiveAllocation(zeroMap);
      // Assert
      expect(color150).assertEqual('#FFB800');
      expect(label90).assertEqual('体验升级');
      expect(color45).assertEqual('#4CAF50');
      expect(hasPositive).assertTrue();
      expect(hasZeroOnly).assertFalse();
    });
  });

  describe('phase2BatchBT_aiInputDialog_logic', () => {
    it('normal: ai_about_to_appear_should_apply_forced_custom_initial_selection', 0, async () => {
      // Arrange
      const hooks = new UserProfileServiceHooksBT();
      const host = new AiInputDialogHostBT();
      host.forceUseInitialSelection = true;
      host.initialSelectedStrategyMode = -1;
      host.initialPrompt = '  hello  ';
      host.initialCustomStrategy = buildStrategyBT(DensityLevel.LOW, PaceLevel.RELAXED, PreferenceType.CULTURE, EnergyLevel.LOW);
      hooks.setHint(async () => 'hint');
      hooks.setRecommended(async () => buildStrategyBT(DensityLevel.HIGH, PaceLevel.COMPACT, PreferenceType.FOOD, EnergyLevel.HIGH));
      // Act
      host.aboutToAppear();
      await sleepBT(0);
      // Assert
      expect(host.strategyTouched).assertFalse();
      expect(host.selectedStrategy).assertEqual(-1);
      expect(host.useCustomStrategy).assertTrue();
      expect(host.inputText).assertEqual('hello');
      expect(host.customStrategy.preference).assertEqual(PreferenceType.CULTURE);
      hooks.restore();
    });

    it('boundary: ai_about_to_appear_should_keep_default_when_modes_invalid', 0, async () => {
      // Arrange
      const hooks = new UserProfileServiceHooksBT();
      const host = new AiInputDialogHostBT();
      host.selectedStrategy = 0;
      host.currentStrategyMode = 9;
      host.initialSelectedStrategyMode = 7;
      hooks.setHint(async () => '');
      hooks.setRecommended(async () => null);
      // Act
      host.aboutToAppear();
      await sleepBT(0);
      // Assert
      expect(host.selectedStrategy).assertEqual(0);
      expect(host.useCustomStrategy).assertFalse();
      hooks.restore();
    });

    it('invalid: ai_load_recommendation_should_fallback_when_service_throw', 0, async () => {
      // Arrange
      const hooks = new UserProfileServiceHooksBT();
      const host = new AiInputDialogHostBT();
      hooks.setHint(async () => {
        throw new Error('x');
      });
      hooks.setRecommended(async () => {
        throw new Error('x');
      });
      // Act
      await host.loadRecommendation();
      // Assert
      expect(host.recommendHint).assertEqual('');
      expect(host.recommendedStrategy === null).assertTrue();
      hooks.restore();
    });

    it('regression: ai_loading_text_should_match_selected_strategy', 0, () => {
      // Arrange
      const host = new AiInputDialogHostBT();
      // Act
      host.selectedStrategy = 1;
      const text1 = host.getLoadingText();
      host.selectedStrategy = 2;
      const text2 = host.getLoadingText();
      host.selectedStrategy = 0;
      const text0 = host.getLoadingText();
      // Assert
      expect(text1).assertEqual('正在生成行程（预计30-60秒）');
      expect(text2).assertEqual('正在生成行程（预计20-40秒）');
      expect(text0).assertEqual('正在生成行程（预计30-50秒）');
    });
  });

  describe('phase2BatchBT_addItemDialog_logic', () => {
    it('normal: add_about_to_appear_should_init_mode_time_and_duration', 0, () => {
      // Arrange
      const host = new AddItemDialogHostBT();
      host.globalDefaultDuration = 80;
      host.initName = 'museum';
      host.initIsSchedule = true;
      host.initDuration = 120;
      host.initFixedTime = '10:20';
      host.initDayOffset = 1;
      host.initPriority = 1;
      host.initPreTravel = 15;
      host.initLat = 39.9;
      host.initLng = 116.3;
      host.planStartDate = new Date(2026, 3, 10, 8, 0, 0, 0).getTime();
      // Act
      host.aboutToAppear();
      // Assert
      expect(host.mode).assertEqual(1);
      expect(host.duration).assertEqual(120);
      expect(host.isMustVisit).assertTrue();
      expect(host.preTravel).assertEqual(15);
      expect(host.formatTime(host.startTime)).assertEqual('10:20');
      expect(host.formatTime(host.endTime)).assertEqual('12:20');
      expect(host.latitude).assertEqual(39.9);
      expect(host.longitude).assertEqual(116.3);
    });

    it('boundary: add_calculate_duration_should_ignore_non_positive_diff', 0, () => {
      // Arrange
      const host = new AddItemDialogHostBT();
      host.duration = 90;
      host.startTime = new Date(2026, 3, 10, 10, 0, 0, 0);
      host.endTime = new Date(2026, 3, 10, 9, 30, 0, 0);
      // Act
      host.calculateDuration();
      // Assert
      expect(host.duration).assertEqual(90);
    });

    it('invalid: add_apply_time_string_should_return_original_when_format_invalid', 0, () => {
      // Arrange
      const host = new AddItemDialogHostBT();
      const target = new Date(2026, 3, 10, 8, 5, 0, 0);
      // Act
      const invalidResult = host.applyTimeString(target, 'abc');
      const validResult = host.applyTimeString(target, '18:40');
      // Assert
      expect(invalidResult.getTime()).assertEqual(target.getTime());
      expect(host.formatTime(validResult)).assertEqual('18:40');
    });

    it('conflict: add_duration_and_endtime_should_stay_consistent_after_recalculate', 0, () => {
      // Arrange
      const host = new AddItemDialogHostBT();
      host.startTime = new Date(2026, 3, 10, 9, 0, 0, 0);
      host.duration = 75;
      // Act
      host.recalculateEndTime();
      host.calculateDuration();
      // Assert
      expect(host.formatTime(host.endTime)).assertEqual('10:15');
      expect(host.duration).assertEqual(75);
    });

    it('regression: add_map_picker_should_depend_on_app_config_key', 0, () => {
      // Arrange
      const hooks = new AppConfigHooksBT();
      const host = new AddItemDialogHostBT();
      hooks.setAmapSdkApiKey(' ');
      const disabled = host.canUseMapPicker();
      hooks.setAmapSdkApiKey('demo-key');
      const enabled = host.canUseMapPicker();
      // Act
      // Assert
      expect(disabled).assertFalse();
      expect(enabled).assertTrue();
      hooks.restore();
    });

    it('combined: add_scoped_key_and_coordinate_validation_should_follow_rules', 0, () => {
      // Arrange
      const host = new AddItemDialogHostBT();
      host.storageScopePlanId = 42;
      // Act
      const key = host.scopedStorageKey('tempDialogState');
      const validCoord = host.isValidCoordinate(39.9, 116.3);
      const invalidCoord = host.isValidCoordinate(0, 0);
      // Assert
      expect(key).assertEqual('tempDialogState_42');
      expect(validCoord).assertTrue();
      expect(invalidCoord).assertFalse();
    });
  });

  describe('phase2BatchBT_conflictCompressDialog_logic', () => {
    it('normal: conflict_about_to_appear_should_choose_valid_initial_selected_ids', 0, () => {
      // Arrange
      const host = new ConflictCompressDialogHostBT();
      host.initialSelectedIds = [2, 999];
      host.vm.compressionCoordinator.context = {
        neededGapMinutes: 30,
        candidates: [
          { id: 1, index: 0, name: 'a', oldVal: 60, selectable: true, isRigid: false },
          { id: 2, index: 1, name: 'b', oldVal: 50, selectable: true, isRigid: false },
          { id: 3, index: 2, name: 'c', oldVal: 40, selectable: false, isRigid: true }
        ]
      };
      host.vm.compressionCoordinator.plan = {
        status: 'OK',
        capacityMinutes: 40,
        remainingGapMinutes: 0,
        affectedItems: [{ index: 1, newVal: 35 }]
      };
      // Act
      host.aboutToAppear();
      // Assert
      expect(host.selectedIds.size).assertEqual(1);
      expect(host.selectedIds.has(2)).assertTrue();
      expect(host.previewPlan?.status ?? '').assertEqual('OK');
    });

    it('boundary: conflict_about_to_appear_should_fallback_to_all_selectable_when_context_invalid_selected', 0, () => {
      // Arrange
      const host = new ConflictCompressDialogHostBT();
      host.initialSelectedIds = [999];
      host.vm.compressionCoordinator.context = {
        neededGapMinutes: 20,
        candidates: [
          { id: 11, index: 0, name: 'a', oldVal: 60, selectable: true, isRigid: false },
          { id: 12, index: 1, name: 'b', oldVal: 50, selectable: true, isRigid: false }
        ]
      };
      // Act
      host.aboutToAppear();
      // Assert
      expect(host.selectedIds.size).assertEqual(2);
      expect(host.isAllSelected()).assertTrue();
    });

    it('invalid: conflict_about_to_appear_should_keep_preview_null_without_context', 0, () => {
      // Arrange
      const host = new ConflictCompressDialogHostBT();
      host.vm.compressionCoordinator.context = null;
      host.previewPlan = {
        status: 'OK',
        affectedItems: []
      };
      // Act
      host.aboutToAppear();
      // Assert
      expect(host.context === null).assertTrue();
      expect(host.previewPlan === null).assertTrue();
    });

    it('conflict: conflict_toggle_one_should_ignore_unselectable_candidate', 0, () => {
      // Arrange
      const host = new ConflictCompressDialogHostBT();
      host.vm.compressionCoordinator.context = {
        neededGapMinutes: 20,
        candidates: [
          { id: 11, index: 0, name: 'a', oldVal: 60, selectable: true, isRigid: false },
          { id: 12, index: 1, name: 'b', oldVal: 50, selectable: false, isRigid: true }
        ]
      };
      host.aboutToAppear();
      const beforeSize = host.selectedIds.size;
      const bad = host.vm.compressionCoordinator.context.candidates[1];
      // Act
      host.toggleOne(bad, true);
      // Assert
      expect(host.selectedIds.size).assertEqual(beforeSize);
      expect(host.selectedIds.has(12)).assertFalse();
    });

    it('regression: conflict_preview_methods_should_use_preview_plan_affected_items', 0, () => {
      // Arrange
      const host = new ConflictCompressDialogHostBT();
      host.previewPlan = {
        status: 'OVERLOAD',
        remainingGapMinutes: 15,
        affectedItems: [{ index: 5, newVal: 40 }]
      };
      const candidate: CompressionCandidateBT = {
        id: 99,
        index: 5,
        name: 'spot',
        oldVal: 70,
        selectable: true,
        isRigid: false
      };
      // Act
      const newDuration = host.getPreviewNewDuration(candidate);
      const reduced = host.getPreviewReduced(candidate);
      const remaining = host.getRemainingGap();
      // Assert
      expect(newDuration).assertEqual(40);
      expect(reduced).assertEqual(30);
      expect(remaining).assertEqual(15);
    });

    it('combined: conflict_select_all_and_refresh_preview_should_sync_selected_ids', 0, () => {
      // Arrange
      const host = new ConflictCompressDialogHostBT();
      host.vm.compressionCoordinator.context = {
        neededGapMinutes: 35,
        candidates: [
          { id: 21, index: 0, name: 'a', oldVal: 80, selectable: true, isRigid: false },
          { id: 22, index: 1, name: 'b', oldVal: 50, selectable: true, isRigid: false },
          { id: 23, index: 2, name: 'c', oldVal: 40, selectable: false, isRigid: true }
        ]
      };
      host.aboutToAppear();
      // Act
      host.toggleSelectAll(false);
      host.toggleSelectAll(true);
      host.refreshPreview();
      // Assert
      expect(host.selectedIds.size).assertEqual(2);
      expect(host.vm.compressionCoordinator.lastSelectedIds.join(',')).assertEqual('21,22');
    });
  });

  describe('phase2BatchBT_planSettingsDialog_logic', () => {
    it('normal: plan_settings_about_to_appear_should_copy_weather_preference', 0, () => {
      // Arrange
      const host = new PlanSettingsDialogHostBT();
      host.weatherUserPreference = {
        heatSensitivity: 2,
        rainSensitivity: 1,
        weatherRiskTolerance: 0
      };
      host.weatherPreference = {
        heatSensitivity: 0,
        rainSensitivity: 0,
        weatherRiskTolerance: 2
      };
      // Act
      host.aboutToAppear();
      // Assert
      expect(host.weatherPreference.heatSensitivity).assertEqual(2);
      expect(host.weatherPreference.rainSensitivity).assertEqual(1);
      expect(host.weatherPreference.weatherRiskTolerance).assertEqual(0);
      expect(host.weatherPreference === host.weatherUserPreference).assertFalse();
    });
  });
}
