import { describe, expect, it } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { PlanItem } from '../main/ets/infrastructure/persistence/PlanRepositoryImpl';
import { ThemeCenter } from '../main/ets/common/utils/ThemeCenter';
import { PreferenceManager } from '../main/ets/common/utils/PreferenceManager';
import { ProfileViewModel } from '../main/ets/viewmodel/ProfileViewModel';
import { CompanionContext } from '../main/ets/viewmodel/TimelineViewModel';
import {
  CompanionSearchPage,
  getCompanionSearchResultMetaText,
  shouldShowCompanionSearchEmptyState,
  shouldShowCompanionSearchPage
} from '../main/ets/pages/components/views/companion/CompanionSearchPage';
import {
  CompanionImmersiveView,
  getImmersiveNextStationText,
  getImmersivePrimaryActionEnabled,
  getImmersivePrimaryActionLabel,
  shouldShowImmersivePrimaryAction
} from '../main/ets/pages/components/views/companion/CompanionImmersiveView';
import {
  CompanionFilterPage,
  CompanionFilterState,
  getCompanionFilterBorderType,
  getCompanionFilterBorderWidth,
  isCompanionFilterSelected,
  shouldShowCompanionFilterPage
} from '../main/ets/pages/components/views/companion/CompanionFilterPage';
import {
  getCompanionPopupHeight,
  getCompanionPopupLine,
  getCompanionPopupWidth
} from '../main/ets/pages/components/views/companion/CompanionWeatherPopups';
import {
  handleCompanionFocusedReopen,
  handleCompanionFocusedSkip
} from '../main/ets/pages/components/views/companion/CompanionFocusActionHelper';
import {
  createArchivePageForTest,
  resolveArchiveSoftDeleteDialogMessage,
  resolveArchiveSoftDeleteDialogTitle,
  resolveArchiveTagText,
  shouldArchiveSkipSoftDeleteTip
} from '../main/ets/pages/ArchivePage';
import {
  createLoginPageForTest,
  parseHuaweiLoginErrorCodeFromMessage,
  resolveLoginAgreementRequiredToast,
  resolveLoginFailureToast,
  shouldUseHuaweiApiFallbackByCode
} from '../main/ets/pages/LoginPage';
import {
  createTrashPageForTest,
  resolveTrashAutoPurgeDiffMs,
  resolveTrashRemainingTimeText
} from '../main/ets/pages/TrashPage';
import { UserSession } from '../main/ets/domain/auth/AuthTypes';

interface ThemePaletteLikeBZ {
  textPrimary: Object;
  primary: Object;
  companionBg: Object;
  pageBg: Object;
}

interface CompanionSearchPageParamsBZ {
  showSearchPage?: boolean;
  searchKeyword?: string;
  searchResults?: EventEntity[];
  safeTopInset?: number;
  safeBottomInset?: number;
  onClose?: () => void;
  onSearch?: (keyword: string) => void;
  onResultClick?: (item: EventEntity) => void;
  getEventStateLabel?: (item: EventEntity) => string;
  getPlannedRange?: (item: EventEntity) => string;
}

interface CompanionSearchPagePrivateBZ {
  showSearchPage: boolean;
  searchKeyword: string;
  searchResults: EventEntity[];
  safeTopInset: number;
  safeBottomInset: number;
  effectiveTheme: string;
  onClose: () => void;
  onSearch: (keyword: string) => void;
  onResultClick: (item: EventEntity) => void;
  getEventStateLabel: (item: EventEntity) => string;
  getPlannedRange: (item: EventEntity) => string;
  setInitiallyProvidedValue(params: CompanionSearchPageParamsBZ): void;
  updateStateVars(params: CompanionSearchPageParamsBZ): void;
  getThemePalette(): ThemePaletteLikeBZ;
}

interface CompanionImmersiveViewParamsBZ {
  context: CompanionContext;
  immersiveText?: string;
  immersiveDragOffsetY?: number;
  safeTopInset?: number;
  safeBottomInset?: number;
  getRuntimeLabel?: () => string;
  getPlannedRange?: (event: EventEntity) => string;
  getForecastStartText?: (event: EventEntity) => string;
  isCurrentEventPending?: () => boolean;
  isCurrentEventActive?: () => boolean;
  canStartFocused?: (event: EventEntity) => boolean;
  canEndFocused?: (event: EventEntity) => boolean;
  onStartEvent?: (event: EventEntity) => Promise<void> | void;
  onEndEvent?: (event: EventEntity) => Promise<void> | void;
  onNavigate?: (event?: EventEntity) => void;
  onSwipeGesture?: (phase: string, event?: Object) => void;
}

interface CompanionImmersiveViewPrivateBZ {
  context: CompanionContext;
  immersiveText: string;
  immersiveDragOffsetY: number;
  safeTopInset: number;
  safeBottomInset: number;
  effectiveTheme: string;
  getRuntimeLabel: () => string;
  getPlannedRange: (event: EventEntity) => string;
  getForecastStartText: (event: EventEntity) => string;
  isCurrentEventPending: () => boolean;
  isCurrentEventActive: () => boolean;
  canStartFocused: (event: EventEntity) => boolean;
  canEndFocused: (event: EventEntity) => boolean;
  onStartEvent: (event: EventEntity) => Promise<void> | void;
  onEndEvent: (event: EventEntity) => Promise<void> | void;
  onNavigate: (event?: EventEntity) => void;
  onSwipeGesture: (phase: string, event?: Object) => void;
  setInitiallyProvidedValue(params: CompanionImmersiveViewParamsBZ): void;
  updateStateVars(params: CompanionImmersiveViewParamsBZ): void;
  getThemePalette(): ThemePaletteLikeBZ;
}

interface CompanionFilterPageParamsBZ {
  showFilterPage?: boolean;
  companionFilterState?: CompanionFilterState;
  safeTopInset?: number;
  safeBottomInset?: number;
  onClose?: () => void;
  onFilterSelect?: (item: CompanionFilterState) => void;
  getFilterOptions?: () => CompanionFilterState[];
  getFilterLabel?: (state: CompanionFilterState) => string;
}

interface CompanionFilterPagePrivateBZ {
  showFilterPage: boolean;
  companionFilterState: CompanionFilterState;
  safeTopInset: number;
  safeBottomInset: number;
  effectiveTheme: string;
  onClose: () => void;
  onFilterSelect: (item: CompanionFilterState) => void;
  getFilterOptions: () => CompanionFilterState[];
  getFilterLabel: (state: CompanionFilterState) => string;
  setInitiallyProvidedValue(params: CompanionFilterPageParamsBZ): void;
  updateStateVars(params: CompanionFilterPageParamsBZ): void;
  getThemePalette(): ThemePaletteLikeBZ;
}

interface TrashPlanServiceLikeBZ {
  loadTrashPlans(): Promise<PlanItem[]>;
  hardDeletePlan(planId: number): Promise<void>;
  restorePlan(planId: number): Promise<void>;
}

interface TrashPagePrivateBZ {
  effectiveTheme: string;
  planList: PlanItem[];
  getThemePalette(): ThemePaletteLikeBZ;
  onPageShow(): void;
  loadPlans(): Promise<void>;
  getRemainingTimeText(deleteTime: number | undefined): string;
  handleHardDelete(item: PlanItem): void;
  getUIContext(): TrashUiContextLikeBZ;
}

interface ArchivePlanServiceLikeBZ {
  loadArchivedPlans(): Promise<PlanItem[]>;
  softDeletePlan(planId: number): Promise<void>;
  activatePlan(planId: number): Promise<void>;
}

interface ArchivePagePrivateBZ {
  effectiveTheme: string;
  planList: PlanItem[];
  tipDialogController: ArchiveDialogControllerLikeBZ | null;
  getThemePalette(): ThemePaletteLikeBZ;
  onPageShow(): void;
  loadPlans(): Promise<void>;
  executeSoftDelete(planId: number): Promise<void>;
  handleActivate(item: PlanItem): Promise<void>;
  handleSoftDelete(item: PlanItem): Promise<void>;
}

interface ArchiveDialogControllerLikeBZ {
  open(): void;
}

interface LoginPagePrivateBZ {
  agreementAccepted: boolean;
  loading: boolean;
  createLoginTraceId(scene: string): string;
  ensureAgreement(): boolean;
  replaceUrl(url: string): Promise<void>;
  ensureCloudProfile(hostContext: Object, session: UserSession | null): Promise<void>;
  toast(message: string): void;
  getUIContext(): LoginUiContextLikeBZ;
}

interface LoginUiContextLikeBZ {
  getRouter(): LoginRouterLikeBZ;
}

interface LoginRouterLikeBZ {
  replaceUrl(options: LoginRouteOptionsLikeBZ): Promise<void>;
}

interface LoginRouteOptionsLikeBZ {
  url: string;
}

interface TrashUiContextLikeBZ {
  showAlertDialog(options: TrashAlertDialogOptionsLikeBZ): void;
}

interface TrashAlertDialogButtonLikeBZ {
  value: string;
  action: () => Promise<void> | void;
}

interface TrashAlertDialogOptionsLikeBZ {
  title: string;
  message: string;
  autoCancel: boolean;
  primaryButton: TrashAlertDialogButtonLikeBZ;
  secondaryButton: TrashAlertDialogButtonLikeBZ;
}

class TrashUiContextMockBZ implements TrashUiContextLikeBZ {
  public showCount: number = 0;
  public lastOptions?: TrashAlertDialogOptionsLikeBZ;

  showAlertDialog(options: TrashAlertDialogOptionsLikeBZ): void {
    this.showCount += 1;
    this.lastOptions = options;
  }
}

class TrashPlanServiceMockBZ implements TrashPlanServiceLikeBZ {
  plans: PlanItem[] = [];
  hardDeletedPlanIds: number[] = [];
  restoredPlanIds: number[] = [];

  async loadTrashPlans(): Promise<PlanItem[]> {
    return this.plans;
  }

  async hardDeletePlan(planId: number): Promise<void> {
    this.hardDeletedPlanIds.push(planId);
  }

  async restorePlan(planId: number): Promise<void> {
    this.restoredPlanIds.push(planId);
  }
}

class ArchivePlanServiceMockBZ implements ArchivePlanServiceLikeBZ {
  plans: PlanItem[] = [];
  softDeletedPlanIds: number[] = [];
  activatedPlanIds: number[] = [];

  async loadArchivedPlans(): Promise<PlanItem[]> {
    return this.plans;
  }

  async softDeletePlan(planId: number): Promise<void> {
    this.softDeletedPlanIds.push(planId);
  }

  async activatePlan(planId: number): Promise<void> {
    this.activatedPlanIds.push(planId);
  }
}

class PreferenceInstanceMockBZ {
  async getValue(_key: string, _defaultValue: boolean): Promise<boolean> {
    return true;
  }
}

class PreferenceInstanceFalseMockBZ {
  async getValue(_key: string, _defaultValue: boolean): Promise<boolean> {
    return false;
  }
}

class LoginRouterMockBZ implements LoginRouterLikeBZ {
  shouldThrow: boolean = false;
  pushedUrls: string[] = [];

  async replaceUrl(options: LoginRouteOptionsLikeBZ): Promise<void> {
    if (this.shouldThrow) {
      throw new Error('router_error');
    }
    this.pushedUrls.push(options.url);
  }
}

class LoginUiContextMockBZ implements LoginUiContextLikeBZ {
  private readonly router: LoginRouterMockBZ;

  constructor(router: LoginRouterMockBZ) {
    this.router = router;
  }

  getRouter(): LoginRouterLikeBZ {
    return this.router;
  }
}

class ProfileDataMockBZ {
  username: string;

  constructor(username: string) {
    this.username = username;
  }
}

class ProfileViewModelMockBZ {
  boundContexts: Object[] = [];
  ensuredIds: string[] = [];
  ensureProfileResult: Object | null = new ProfileDataMockBZ('user1') as Object;

  bindContext(context: Object): void {
    this.boundContexts.push(context);
  }

  async ensureProfile(accountId: string): Promise<Object | null> {
    this.ensuredIds.push(accountId);
    return this.ensureProfileResult;
  }

  getState(): string {
    return 'READY';
  }
}

class HostContextMockBZ {
  tag: string = 'host';
}

function sleepBZ(ms: number): Promise<void> {
  return new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => {
    setTimeout(() => resolve(), ms);
  });
}

function buildEventBZ(id: number, name: string, state: 'PENDING' | 'ACTIVE' | 'SKIPPED' = 'PENDING'): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = name;
  event.status = 1;
  event.completion_status = EventEntity.STATE_PENDING;
  event.actual_start_time = 0;
  event.actual_end_time = 0;
  if (state === 'ACTIVE') {
    event.actual_start_time = Date.now() - 60000;
  }
  if (state === 'SKIPPED') {
    event.completion_status = EventEntity.STATE_SKIPPED;
  }
  return event;
}

function buildPlanItemBZ(id: number, title: string): PlanItem {
  const item = {} as PlanItem;
  item.id = id;
  item.title = title;
  item.startDate = 1713283200000;
  item.createdAt = 1713000000000;
  item.deleteTime = 1713000000000;
  return item;
}

function buildCompanionContextBZ(): CompanionContext {
  const context = {} as CompanionContext;
  context.runtimeState = 'IDLE';
  context.currentEvent = null;
  context.nextEvent = null;
  return context;
}

export default function phase2BatchBZTest() {
  describe('Phase2BatchBZ', () => {
    describe('phase2_batch_bz_companion_search_page', () => {
      it('normal: companion_search_page_instance_should_keep_default_callbacks_and_theme_palette', 0, () => {
        // Arrange
        const page = new CompanionSearchPage(undefined, {} as LocalStorage) as Object as CompanionSearchPagePrivateBZ;
        const event = buildEventBZ(1, '瑗挎箹');

        // Act
        page.onClose();
        page.onSearch('keyword');
        page.onResultClick(event);
        const stateText = page.getEventStateLabel(event);
        const rangeText = page.getPlannedRange(event);
        page.effectiveTheme = 'dark';
        const palette = page.getThemePalette();

        // Assert
        expect(page.showSearchPage).assertFalse();
        expect(page.searchKeyword).assertEqual('');
        expect(page.searchResults.length).assertEqual(0);
        expect(stateText).assertEqual('--');
        expect(rangeText).assertEqual('--');
        expect(palette.textPrimary).assertEqual(ThemeCenter.getPalette('dark').textPrimary);
      });

      it('boundary: companion_search_page_set_and_update_state_should_sync_props', 0, () => {
        // Arrange
        const page = new CompanionSearchPage(undefined, {} as LocalStorage) as Object as CompanionSearchPagePrivateBZ;
        const firstList = [buildEventBZ(2, 'museum')];
        const secondList = [buildEventBZ(3, '鏈哄満'), buildEventBZ(4, '杞︾珯')];
        const firstParams: CompanionSearchPageParamsBZ = {
          showSearchPage: true,
          searchKeyword: 'museum',
          searchResults: firstList,
          safeTopInset: 8,
          safeBottomInset: 12
        };
        const secondParams: CompanionSearchPageParamsBZ = {
          showSearchPage: false,
          searchKeyword: 'station',
          searchResults: secondList,
          safeTopInset: 16,
          safeBottomInset: 24
        };

        // Act
        page.setInitiallyProvidedValue(firstParams);
        page.updateStateVars(secondParams);

        // Assert
        expect(page.showSearchPage).assertFalse();
        expect(page.searchKeyword).assertEqual('station');
        expect(page.searchResults.length).assertEqual(2);
        expect(page.safeTopInset).assertEqual(16);
        expect(page.safeBottomInset).assertEqual(24);
      });

      it('combined: companion_search_page_helpers_should_keep_view_state_independent', 0, () => {
        // Arrange
        const meta = getCompanionSearchResultMetaText('active', '09:00-10:00');

        // Act
        const visible = shouldShowCompanionSearchPage(true);
        const empty = shouldShowCompanionSearchEmptyState(0);

        // Assert
        expect(visible).assertTrue();
        expect(empty).assertTrue();
        expect(meta).assertEqual('active | 09:00-10:00');
      });
    });

    describe('phase2_batch_bz_companion_immersive_view', () => {
      it('normal: companion_immersive_view_instance_should_keep_default_logic_callbacks', 0, async () => {
        // Arrange
        const context = buildCompanionContextBZ();
        const page = new CompanionImmersiveView(undefined, {} as LocalStorage) as Object as CompanionImmersiveViewPrivateBZ;
        page.context = context;
        const event = buildEventBZ(5, '鏈哄満');

        // Act
        const runtimeLabel = page.getRuntimeLabel();
        const plannedRange = page.getPlannedRange(event);
        const forecastStart = page.getForecastStartText(event);
        const isPending = page.isCurrentEventPending();
        const isActive = page.isCurrentEventActive();
        const canStart = page.canStartFocused(event);
        const canEnd = page.canEndFocused(event);
        await Promise.resolve(page.onStartEvent(event));
        await Promise.resolve(page.onEndEvent(event));
        page.onNavigate(undefined);
        page.onSwipeGesture('start', undefined);
        page.effectiveTheme = 'dark';
        const palette = page.getThemePalette();

        // Assert
        expect(runtimeLabel).assertEqual('--');
        expect(plannedRange).assertEqual('--');
        expect(forecastStart).assertEqual('--');
        expect(isPending).assertFalse();
        expect(isActive).assertFalse();
        expect(canStart).assertFalse();
        expect(canEnd).assertFalse();
        expect(palette.primary).assertEqual(ThemeCenter.getPalette('dark').primary);
      });

      it('boundary: companion_immersive_view_update_state_should_replace_context_and_offsets', 0, () => {
        // Arrange
        const firstContext = buildCompanionContextBZ();
        firstContext.runtimeState = 'READY';
        const secondContext = buildCompanionContextBZ();
        secondContext.runtimeState = 'PAUSED';
        const page = new CompanionImmersiveView(undefined, {} as LocalStorage) as Object as CompanionImmersiveViewPrivateBZ;
        page.setInitiallyProvidedValue({
          context: firstContext,
          immersiveText: 'first'
        });
        const nextParams: CompanionImmersiveViewParamsBZ = {
          context: secondContext,
          immersiveText: 'second',
          immersiveDragOffsetY: 24,
          safeTopInset: 6,
          safeBottomInset: 10
        };

        // Act
        page.updateStateVars(nextParams);

        // Assert
        expect(page.context.runtimeState).assertEqual('PAUSED');
        expect(page.immersiveText).assertEqual('second');
        expect(page.immersiveDragOffsetY).assertEqual(24);
        expect(page.safeTopInset).assertEqual(6);
        expect(page.safeBottomInset).assertEqual(10);
      });

      it('combined: companion_immersive_view_helpers_should_keep_primary_action_rules', 0, () => {
        // Arrange
        // Act
        const visible = shouldShowImmersivePrimaryAction(false, true, 'ACTIVE');
        const label = getImmersivePrimaryActionLabel(false);
        const enabled = getImmersivePrimaryActionEnabled(false, false, true);
        const nextStation = getImmersiveNextStationText('鏈哄満', '09:30');

        // Assert
        expect(visible).assertTrue();
        expect(label).assertEqual('结束');
        expect(enabled).assertTrue();
        expect(nextStation.indexOf('09:30') >= 0).assertTrue();
      });
    });

    describe('phase2_batch_bz_companion_filter_page', () => {
      it('normal: companion_filter_page_instance_should_keep_default_options_and_theme_palette', 0, () => {
        // Arrange
        const page = new CompanionFilterPage(undefined, {} as LocalStorage) as Object as CompanionFilterPagePrivateBZ;

        // Act
        page.onClose();
        page.onFilterSelect('ALL');
        const options = page.getFilterOptions();
        const label = page.getFilterLabel('ACTIVE');
        page.effectiveTheme = 'dark';
        const palette = page.getThemePalette();

        // Assert
        expect(page.showFilterPage).assertFalse();
        expect(page.companionFilterState).assertEqual('ALL');
        expect(options.length).assertEqual(5);
        expect(options[1]).assertEqual('PENDING');
        expect(label).assertEqual('--');
        expect(palette.companionBg).assertEqual(ThemeCenter.getPalette('dark').companionBg);
      });

      it('boundary: companion_filter_page_update_state_should_replace_selection_and_insets', 0, () => {
        // Arrange
        const page = new CompanionFilterPage(undefined, {} as LocalStorage) as Object as CompanionFilterPagePrivateBZ;
        const initParams: CompanionFilterPageParamsBZ = {
          showFilterPage: true,
          companionFilterState: 'PENDING',
          safeTopInset: 4,
          safeBottomInset: 6
        };
        const nextParams: CompanionFilterPageParamsBZ = {
          showFilterPage: false,
          companionFilterState: 'SKIPPED',
          safeTopInset: 14,
          safeBottomInset: 16
        };

        // Act
        page.setInitiallyProvidedValue(initParams);
        page.updateStateVars(nextParams);

        // Assert
        expect(page.showFilterPage).assertFalse();
        expect(page.companionFilterState).assertEqual('SKIPPED');
        expect(page.safeTopInset).assertEqual(14);
        expect(page.safeBottomInset).assertEqual(16);
      });

      it('combined: companion_filter_page_helpers_should_keep_selection_and_border_mapping_consistent', 0, () => {
        // Arrange
        const current: CompanionFilterState = 'SKIPPED';

        // Act
        const visible = shouldShowCompanionFilterPage(true);
        const selected = isCompanionFilterSelected('SKIPPED', current);
        const width = getCompanionFilterBorderWidth('SKIPPED', current);
        const borderType = getCompanionFilterBorderType('SKIPPED');

        // Assert
        expect(visible).assertTrue();
        expect(selected).assertTrue();
        expect(width).assertEqual(1);
        expect(borderType).assertEqual('skipped');
      });
    });

    describe('phase2_batch_bz_companion_weather_popups', () => {
      it('boundary: companion_weather_popups_should_treat_sparse_slot_as_empty_text', 0, () => {
        // Arrange
        const lines: string[] = [];
        lines[2] = 'line2';

        // Act
        const emptyLine = getCompanionPopupLine(lines, 1);
        const existingLine = getCompanionPopupLine(lines, 2);
        const height = getCompanionPopupHeight('suggestion');
        const width = getCompanionPopupWidth('suggestion');

        // Assert
        expect(emptyLine).assertEqual('');
        expect(existingLine).assertEqual('line2');
        expect(height).assertEqual(240);
        expect(width).assertEqual(290);
      });
    });

    describe('phase2_batch_bz_companion_focus_action_helper', () => {
      it('conflict: companion_focus_skip_should_wrap_to_first_startable_when_later_items_not_startable', 0, async () => {
        // Arrange
        const earlierStartable = buildEventBZ(10, 'earlier', 'PENDING');
        const focused = buildEventBZ(11, 'focused', 'PENDING');
        const laterActive = buildEventBZ(12, 'later', 'ACTIVE');
        let skipCalls = 0;
        const focusIds: number[] = [];

        // Act
        await handleCompanionFocusedSkip({
          focusedEvent: focused,
          skipEvent: async (_event: EventEntity): Promise<void> => {
            skipCalls += 1;
          },
          refreshContext: (): void => {},
          getScheduledEvents: (): EventEntity[] => [earlierStartable, focused, laterActive],
          getScheduleIndexById: (_id: number): number => 1,
          applyFocusById: (id: number): void => {
            focusIds.push(id);
          },
          showToast: (_message: string): void => {}
        });
        await sleepBZ(150);

        // Assert
        expect(skipCalls).assertEqual(1);
        expect(focusIds.length).assertEqual(1);
        expect(focusIds[0]).assertEqual(10);
      });

      it('invalid: companion_focus_reopen_should_block_non_skipped_event_without_mutation', 0, async () => {
        // Arrange
        const focused = buildEventBZ(13, 'pending', 'PENDING');
        let reopenCalls = 0;
        let updateCalls = 0;
        let refreshCalls = 0;
        const toasts: string[] = [];

        // Act
        await handleCompanionFocusedReopen({
          focusedEvent: focused,
          getScheduledEvents: (): EventEntity[] => [focused],
          reopenSkippedEvent: async (_eventId: number): Promise<boolean> => {
            reopenCalls += 1;
            return true;
          },
          updateActualStart: async (_eventId: number, _nowTs: number): Promise<boolean> => {
            updateCalls += 1;
            return true;
          },
          showGlobalActiveConflictDialog: async (_excludeEventId: number): Promise<boolean> => false,
          refreshContext: (): void => {
            refreshCalls += 1;
          },
          applyFocusById: (_id: number): void => {},
          enterImmersiveMode: (): void => {},
          showToast: (message: string): void => {
            toasts.push(message);
          }
        });

        // Assert
        expect(reopenCalls).assertEqual(0);
        expect(updateCalls).assertEqual(0);
        expect(refreshCalls).assertEqual(0);
        expect(toasts.length).assertEqual(1);
      });
    });

    describe('phase2_batch_bz_trash_page', () => {
      it('normal: trash_page_load_plans_should_sync_plan_list_from_service', 0, async () => {
        // Arrange
        const page = createTrashPageForTest() as TrashPagePrivateBZ;
        const service = new TrashPlanServiceMockBZ();
        service.plans = [buildPlanItemBZ(21, '鏉窞'), buildPlanItemBZ(22, '鑻忓窞')];
        Reflect.set(page as Object, 'planService', service);

        // Act
        await page.loadPlans();

        // Assert
        expect(page.planList.length).assertEqual(2);
        expect(page.planList[0].id).assertEqual(21);
      });

      it('boundary: trash_page_on_page_show_should_delegate_to_load_plans', 0, () => {
        // Arrange
        const page = createTrashPageForTest() as TrashPagePrivateBZ;
        let loadCalls = 0;
        Reflect.set(page as Object, 'loadPlans', (): void => {
          loadCalls += 1;
        });

        // Act
        page.onPageShow();

        // Assert
        expect(loadCalls).assertEqual(1);
      });

      it('combined: trash_page_remaining_time_and_delete_dialog_should_follow_expected_logic', 0, async () => {
        // Arrange
        const page = createTrashPageForTest() as TrashPagePrivateBZ;
        const uiContext = new TrashUiContextMockBZ();
        const item = buildPlanItemBZ(23, '鍗椾含');
        let refreshCalls = 0;
        const service = new TrashPlanServiceMockBZ();
        Reflect.set(page as Object, 'planService', service);
        Reflect.set(page as Object, 'loadPlans', (): void => {
          refreshCalls += 1;
        });
        Reflect.set(page as Object, 'getUIContext', (): TrashUiContextLikeBZ => uiContext);
        // Act
        const nowTs = Date.now();
        const remainingText = page.getRemainingTimeText(nowTs - 6 * 3600 * 1000);
        page.handleHardDelete(item);
        await Promise.resolve(uiContext.lastOptions?.secondaryButton.action());
        await sleepBZ(0);

        // Assert
        expect(remainingText.indexOf('小时') >= 0).assertTrue();
        expect(uiContext.showCount).assertEqual(1);
        expect(service.hardDeletedPlanIds[0]).assertEqual(23);
        expect(refreshCalls).assertEqual(1);
      });

      it('combined: trash_page_pure_exports_should_keep_deadline_text_consistent', 0, () => {
        // Arrange
        const now = 50_000;
        const deleteTime = now - 2_000;

        // Act
        const diff = resolveTrashAutoPurgeDiffMs(deleteTime, now, 3_600_000);
        const text = resolveTrashRemainingTimeText(deleteTime, now, 3_600_000);

        // Assert
        expect(diff).assertEqual(3_598_000);
        expect(text.indexOf('小时') >= 0).assertTrue();
      });
    });

    describe('phase2_batch_bz_archive_page', () => {
      it('normal: archive_page_load_plans_should_sync_plan_list_from_service', 0, async () => {
        // Arrange
        const page = createArchivePageForTest() as ArchivePagePrivateBZ;
        const service = new ArchivePlanServiceMockBZ();
        service.plans = [buildPlanItemBZ(31, '鍖椾含')];
        Reflect.set(page as Object, 'planService', service);

        // Act
        await page.loadPlans();

        // Assert
        expect(page.planList.length).assertEqual(1);
        expect(page.planList[0].title).assertEqual('鍖椾含');
      });

      it('boundary: archive_page_execute_soft_delete_and_activate_should_refresh_after_service_calls', 0, async () => {
        // Arrange
        const page = createArchivePageForTest() as ArchivePagePrivateBZ;
        let refreshCalls = 0;
        const service = new ArchivePlanServiceMockBZ();
        Reflect.set(page as Object, 'planService', service);
        Reflect.set(page as Object, 'loadPlans', (): void => {
          refreshCalls += 1;
        });
        const item = buildPlanItemBZ(32, '涓婃捣');

        // Act
        await page.executeSoftDelete(32);
        await page.handleActivate(item);

        // Assert
        expect(service.softDeletedPlanIds[0]).assertEqual(32);
        expect(service.activatedPlanIds[0]).assertEqual(32);
        expect(refreshCalls).assertEqual(2);
      });

      it('combined: archive_page_skip_tip_branch_should_delegate_to_execute_soft_delete', 0, async () => {
        // Arrange
        const page = createArchivePageForTest() as ArchivePagePrivateBZ;
        const item = buildPlanItemBZ(33, '骞垮窞');
        let executeSoftDeleteId = -1;
        Reflect.set(page as Object, 'executeSoftDelete', async (planId: number): Promise<void> => {
          executeSoftDeleteId = planId;
        });
        const originalGetInstance = Reflect.get(PreferenceManager as Object, 'getInstance') as () => Object;
        Reflect.set(PreferenceManager as Object, 'getInstance', (): Object => {
          return new PreferenceInstanceMockBZ() as Object;
        });

        // Act
        await page.handleSoftDelete(item);

        // Assert
        expect(executeSoftDeleteId).assertEqual(33);
        Reflect.set(PreferenceManager as Object, 'getInstance', originalGetInstance);
      });

      it('invalid: archive_page_non_skip_tip_branch_should_keep_execute_pending_until_confirm', 0, async () => {
        // Arrange
        const page = createArchivePageForTest() as ArchivePagePrivateBZ;
        const item = buildPlanItemBZ(34, '深圳');
        let executeSoftDeleteId = -1;
        Reflect.set(page as Object, 'executeSoftDelete', async (planId: number): Promise<void> => {
          executeSoftDeleteId = planId;
        });
        const originalGetInstance = Reflect.get(PreferenceManager as Object, 'getInstance') as () => Object;
        Reflect.set(PreferenceManager as Object, 'getInstance', (): Object => {
          return new PreferenceInstanceFalseMockBZ() as Object;
        });

        // Act
        await page.handleSoftDelete(item);

        // Assert
        expect(executeSoftDeleteId).assertEqual(-1);
        expect(page.tipDialogController !== null).assertTrue();
        Reflect.set(PreferenceManager as Object, 'getInstance', originalGetInstance);
      });

      it('combined: archive_page_pure_exports_should_keep_dialog_copy_stable', 0, () => {
        // Arrange
        // Act
        const shouldSkip = shouldArchiveSkipSoftDeleteTip(true);
        const title = resolveArchiveSoftDeleteDialogTitle();
        const message = resolveArchiveSoftDeleteDialogMessage();
        const tag = resolveArchiveTagText();

        // Assert
        expect(shouldSkip).assertTrue();
        expect(title.length > 0).assertTrue();
        expect(message.length > 0).assertTrue();
        expect(tag.trim().length > 0).assertTrue();
      });
    });

    describe('phase2_batch_bz_login_page', () => {
      it('normal: login_page_trace_id_and_agreement_guard_should_follow_internal_logic', 0, () => {
        // Arrange
        const page = createLoginPageForTest() as LoginPagePrivateBZ;
        const toasts: string[] = [];
        Reflect.set(page as Object, 'toast', (message: string): void => {
          toasts.push(message);
        });

        // Act
        page.agreementAccepted = false;
        const traceId = page.createLoginTraceId('button');
        const blocked = page.ensureAgreement();
        page.agreementAccepted = true;
        const allowed = page.ensureAgreement();

        // Assert
        expect(traceId.startsWith('button_')).assertTrue();
        expect(blocked).assertFalse();
        expect(allowed).assertTrue();
        expect(toasts[0]).assertEqual(resolveLoginAgreementRequiredToast());
      });

      it('boundary: login_page_replace_url_should_swallow_router_failure', 0, async () => {
        // Arrange
        const page = createLoginPageForTest() as LoginPagePrivateBZ;
        const router = new LoginRouterMockBZ();
        const uiContext: LoginUiContextLikeBZ = new LoginUiContextMockBZ(router);
        Reflect.set(page as Object, 'getUIContext', (): LoginUiContextLikeBZ => uiContext);

        // Act
        await page.replaceUrl('pages/PlanListPage');
        router.shouldThrow = true;
        await page.replaceUrl('pages/LoginPage');

        // Assert
        expect(router.pushedUrls.length).assertEqual(1);
        expect(router.pushedUrls[0]).assertEqual('pages/PlanListPage');
      });

      it('regression: login_page_ensure_cloud_profile_should_short_circuit_or_bind_profile_vm', 0, async () => {
        // Arrange
        const page = createLoginPageForTest() as LoginPagePrivateBZ;
        const profileViewModelMock = new ProfileViewModelMockBZ();
        const originalGetInstance = Reflect.get(ProfileViewModel as Object, 'getInstance') as () => Object;
        Reflect.set(ProfileViewModel as Object, 'getInstance', (): Object => {
          return profileViewModelMock as Object;
        });
        const hostContext = new HostContextMockBZ() as Object;
        const emptySession = {} as UserSession;
        emptySession.accountId = '   ';
        const validSession = {} as UserSession;
        validSession.accountId = 'acc-1';

        // Act
        await page.ensureCloudProfile(hostContext, null);
        await page.ensureCloudProfile(hostContext, emptySession);
        await page.ensureCloudProfile(hostContext, validSession);

        // Assert
        expect(profileViewModelMock.boundContexts.length).assertEqual(1);
        expect(profileViewModelMock.ensuredIds.length).assertEqual(1);
        expect(profileViewModelMock.ensuredIds[0]).assertEqual('acc-1');
        Reflect.set(ProfileViewModel as Object, 'getInstance', originalGetInstance);
      });

      it('boundary: login_page_ensure_cloud_profile_should_allow_empty_profile_result_without_throwing', 0, async () => {
        // Arrange
        const page = createLoginPageForTest() as LoginPagePrivateBZ;
        const profileViewModelMock = new ProfileViewModelMockBZ();
        profileViewModelMock.ensureProfileResult = null;
        const originalGetInstance = Reflect.get(ProfileViewModel as Object, 'getInstance') as () => Object;
        Reflect.set(ProfileViewModel as Object, 'getInstance', (): Object => {
          return profileViewModelMock as Object;
        });
        const hostContext = new HostContextMockBZ() as Object;
        const validSession = {} as UserSession;
        validSession.accountId = 'acc-empty';

        // Act
        await page.ensureCloudProfile(hostContext, validSession);

        // Assert
        expect(profileViewModelMock.boundContexts.length).assertEqual(1);
        expect(profileViewModelMock.ensuredIds.length).assertEqual(1);
        expect(profileViewModelMock.ensuredIds[0]).assertEqual('acc-empty');
        Reflect.set(ProfileViewModel as Object, 'getInstance', originalGetInstance);
      });

      it('combined: login_page_pure_exports_should_keep_parser_and_toast_rules_stable', 0, () => {
        // Arrange
        // Act
        const code = parseHuaweiLoginErrorCodeFromMessage('huawei_login_error_1001502003_button');
        const fallback = shouldUseHuaweiApiFallbackByCode(code);
        const toast = resolveLoginFailureToast('login failed: ', 'network_down');

        // Assert
        expect(code).assertEqual(1001502003);
        expect(fallback).assertTrue();
        expect(toast).assertEqual('login failed: network_down');
      });
    });
  });
}

