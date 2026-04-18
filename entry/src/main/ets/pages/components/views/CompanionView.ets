import { EventEntity } from '../../../model/entity/EventEntity';
import {
  CompanionContext,
  PlaceCheckinSummary,
  HistoryTimelineFilter,
  HistoryTimelineItem,
  HistoryTimelineSummary,
  TimelineViewModel
} from '../../../viewmodel/TimelineViewModel';
import { promptAction, window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ThemeCenter } from '../../../common/utils/ThemeCenter';
import { TimelineExecutionState } from '../../../domain/policy/TimelineExecutionState';
import { WeatherSuggestion } from '../../../domain/services/WeatherModels';
import { CompanionImmersiveView } from './companion/CompanionImmersiveView';
import { CompanionControlPage } from './companion/CompanionControlPage';
import { CompanionOverlayPages } from './companion/CompanionOverlayPages';
import { RecordCorrectionDialog } from '../dialogs/RecordCorrectionDialog';
import {
  CompanionDisplayFilterState,
  canCompanionEndFocused,
  canCompanionStartFocused,
  getCompanionEventState,
  getCompanionFilterLabel,
  getCompanionForecastStartText,
  hasCompanionOtherActiveEvent,
  getCompanionPlannedRange,
  getCompanionRuntimeLabel,
  isCompanionCurrentEventActive,
  isCompanionCurrentEventPending,
  matchesCompanionFilter
} from './companion/CompanionDisplayHelper';
import {
  CompanionInteractionMode,
  CompanionSubMode,
  getCompanionInteractiveEnabled,
  pickRandomCompanionImmersiveText
} from './companion/CompanionAnimationHelper';
import { getCompanionSwipeUpdate, shouldCompanionEnterControlMode } from './companion/CompanionSwipeHelper';
import {
  applyCompanionWeatherSuggestion,
  getCompanionDismissSuggestionToast,
  getCompanionWeatherGuidePopupText,
  getCompanionWeatherSuggestionDetailText
} from './companion/CompanionWeatherActionHelper';
import { handleCompanionFocusedReopen, handleCompanionFocusedSkip } from './companion/CompanionFocusActionHelper';
import {
  applyCompanionSystemBarVisible,
  createCompanionZeroInsets,
  resolveCompanionSafeAreaInsets
} from './companion/CompanionWindowHelper';
type FocusSource = 'tap' | 'scroll' | 'init';
type CompanionFilterState = CompanionDisplayFilterState;
type HistoryViewMode = 'timeline' | 'detail';

export function isCompanionOverlayVisible(showHistoryPage: boolean, showSearchPage: boolean, showFilterPage: boolean): boolean {
  return showHistoryPage || showSearchPage || showFilterPage;
}

export function resolveCompanionBackLevel(
  showHistoryPage: boolean,
  showSearchPage: boolean,
  showFilterPage: boolean,
  companionSubMode: CompanionSubMode
): string {
  if (isCompanionOverlayVisible(showHistoryPage, showSearchPage, showFilterPage)) {
    return 'overlay';
  }
  return companionSubMode === 'control' ? 'control' : 'immersive';
}

export function resolveCompanionBackAction(
  showHistoryPage: boolean,
  showSearchPage: boolean,
  showFilterPage: boolean,
  companionSubMode: CompanionSubMode
): 'close_overlay' | 'control_to_immersive' | 'exit' {
  if (isCompanionOverlayVisible(showHistoryPage, showSearchPage, showFilterPage)) {
    return 'close_overlay';
  }
  return companionSubMode === 'control' ? 'control_to_immersive' : 'exit';
}

export function resolveCompanionSearchResults(
  source: EventEntity[],
  keyword: string,
  searchTextById?: Map<number, string>
): EventEntity[] {
  const normalizedKeyword = keyword.trim().toLowerCase();
  if (normalizedKeyword.length === 0) {
    return source.slice(0, 20);
  }
  return source.filter((event: EventEntity) => {
    const fallbackText = `${event.name}|${event.address || ''}`.toLowerCase();
    const searchable = searchTextById ? (searchTextById.get(event.id) ?? fallbackText) : fallbackText;
    return searchable.includes(normalizedKeyword);
  });
}

export function resolveCompanionDefaultFocusId(
  schedule: EventEntity[],
  currentEventId: number,
  nextEventId: number
): number {
  if (schedule.length === 0) {
    return -1;
  }

  let activeId: number = -1;
  let pendingId: number = -1;
  for (let i = 0; i < schedule.length; i++) {
    const event = schedule[i];
    if (activeId <= 0 && TimelineExecutionState.isActive(event)) {
      activeId = event.id;
    }
    if (pendingId <= 0 && TimelineExecutionState.isStartable(event)) {
      pendingId = event.id;
    }
    if (activeId > 0 && pendingId > 0) {
      break;
    }
  }

  if (activeId > 0) {
    return activeId;
  }
  if (currentEventId > 0 && schedule.some((event: EventEntity) => event.id === currentEventId)) {
    return currentEventId;
  }
  if (nextEventId > 0 && schedule.some((event: EventEntity) => event.id === nextEventId)) {
    return nextEventId;
  }
  if (pendingId > 0) {
    return pendingId;
  }
  return schedule[0].id;
}

export function resolveCompanionVisibleFocusId(visibleEvents: EventEntity[], focusedEventId: number): number {
  if (visibleEvents.length === 0) {
    return -1;
  }
  if (visibleEvents.some((event: EventEntity) => event.id === focusedEventId)) {
    return focusedEventId;
  }
  return visibleEvents[0].id;
}

export function resolveCompanionVisibleFocusPosition(
  focusedEventId: number,
  visibleIndexById: Map<number, number>
): number {
  const index = visibleIndexById.get(focusedEventId);
  return index !== undefined ? index + 1 : 0;
}
@Component
export struct CompanionView {
  @Link vm: TimelineViewModel;
  @Link isShow: boolean;
  @StorageLink('EffectiveTheme') effectiveTheme: string = 'light';
  // region state
  @State context: CompanionContext = {
    runtimeState: 'IDLE',
    currentEvent: null,
    nextEvent: null,
    hint: null,
    actions: {
      canStart: false,
      canPause: false,
      canResume: false,
      canEnd: false,
      canSkip: false,
      canNavigate: false,
      canViewDetail: false
    }
  };
  @State companionSubMode: CompanionSubMode = 'immersive';
  @State interactionMode: CompanionInteractionMode = 'immersive';
  @State immersiveText: string = '';
  @State immersiveDragOffsetY: number = 0;
  @State showHistoryPage: boolean = false;
  @State historyTimelineSummary: HistoryTimelineSummary | null = null;
  @State historyTimelineItems: HistoryTimelineItem[] = [];
  @State historyTimelineFilter: HistoryTimelineFilter = 'all';
  @State selectedHistoryTimelineItem: HistoryTimelineItem | null = null;
  @State historySummary: PlaceCheckinSummary | null = null;
  @State historyViewMode: HistoryViewMode = 'timeline';
  @State selectedHistoryPlaceName: string = '';
  @State showSearchPage: boolean = false;
  @State showFilterPage: boolean = false;
  @State searchKeyword: string = '';
  @State searchResults: EventEntity[] = [];
  @State companionFilterState: CompanionFilterState = 'ALL';
  @State cachedScheduledEvents: EventEntity[] = [];
  @State cachedVisibleScheduledEvents: EventEntity[] = [];

  @State focusedEventId: number = -1;
  @State focusedIndex: number = -1;
  @State focusSource: FocusSource = 'init';
  @State tapPriorityUntilTs: number = 0;

  @State visibleStartIndex: number = 0;
  @State visibleEndIndex: number = 0;
  @State visibleCenterIndex: number = 0;

  @State cardDisplayEventId: number = -1;
  @State outgoingCardEventId: number = -1;
  @State incomingCardEventId: number = -1;
  @State isCardSwitching: boolean = false;
  @State cardSwitchProgress: number = 1;
  @State pendingFocusId: number = -1;

  @State swipeStartTs: number = 0;
  @State swipeLastTs: number = 0;
  @State swipePeakDistance: number = 0;
  @State safeTopInset: number = 0;
  @State safeBottomInset: number = 0;
  @State safeLeftInset: number = 0;
  @State safeRightInset: number = 0;
  @State weatherExpanded: boolean = false;
  @State showWeatherScorePopup: boolean = false;
  @State showWeatherHintPopup: boolean = false;
  @State showWeatherSuggestionPopup: boolean = false;
  @State weatherSuggestionPopupText: string = '';

  private timelineScroller: Scroller = new Scroller();
  private cachedScheduleVersion: number = -1;
  private cachedEventById: Map<number, EventEntity> = new Map<number, EventEntity>();
  private cachedIndexById: Map<number, number> = new Map<number, number>();
  private cachedVisibleIndexById: Map<number, number> = new Map<number, number>();
  private cachedSearchTextById: Map<number, string> = new Map<number, string>();
  private tapPriorityWindowMs: number = 220;
  private immersiveDistanceTrigger: number = 90;
  private immersiveVelocityTrigger: number = 0.65;
  private immersiveWindow?: window.Window;
  private realtimeWatchTimer: number = -1;
  private observedScheduleVersion: number = -1;
  private observedRuntimeState: string = '';
  private observedBackRequest: number = 0;
  private correctionDialogController: CustomDialogController | null = null;
  private onWindowAvoidAreaChange: (avoidOptions: window.AvoidAreaOptions) => void = (_avoidOptions) => {
    this.updateSafeAreaInsets();
  };
  private onWindowSizeChange: (windowSize: window.Size) => void = (_windowSize) => {
    this.updateSafeAreaInsets();
  };
  // endregion

  // region methods
  private safeShowToast(message: string): void {
    try {
      promptAction.openToast({ message: message });
    } catch (error) {
      hilog.warn(0x0000, 'CompanionView', `[TOAST_FAIL] reason=${JSON.stringify(error)}`);
    }
  }

  aboutToAppear() {
    this.focusedEventId = -1;
    this.focusedIndex = -1;
    this.cardDisplayEventId = -1;
    this.outgoingCardEventId = -1;
    this.incomingCardEventId = -1;
    this.pendingFocusId = -1;
    this.refreshContext();
    this.companionSubMode = 'immersive';
    this.interactionMode = 'immersive';
    this.showHistoryPage = false;
    this.historyViewMode = 'timeline';
    this.historyTimelineSummary = null;
    this.historyTimelineItems = [];
    this.historyTimelineFilter = 'all';
    this.selectedHistoryTimelineItem = null;
    this.historySummary = null;
    this.selectedHistoryPlaceName = '';
    this.showSearchPage = false;
    this.showFilterPage = false;
    this.weatherExpanded = false;
    this.showWeatherScorePopup = false;
    this.showWeatherHintPopup = false;
    this.showWeatherSuggestionPopup = false;
    this.weatherSuggestionPopupText = '';
    this.searchKeyword = '';
    this.searchResults = [];
    this.companionFilterState = 'ALL';
    this.immersiveDragOffsetY = 0;
    this.swipeStartTs = 0;
    this.swipeLastTs = 0;
    this.swipePeakDistance = 0;
    this.bindImmersiveWindowContext();
    this.immersiveText = pickRandomCompanionImmersiveText();
    this.ensureFocusReady();
    this.startRealtimeWatch();
  }

  aboutToDisappear() {
    this.stopRealtimeWatch();
    this.unbindImmersiveWindowContext();
    this.setSystemBarVisible(true);
  }

  private getThemePalette() {
    return ThemeCenter.getPalette(this.effectiveTheme);
  }

  private startRealtimeWatch(): void {
    this.observedScheduleVersion = this.vm.getScheduleVersion();
    this.observedRuntimeState = this.context.runtimeState;
    this.observedBackRequest = Number(AppStorage.get('COMPANION_BACK_REQUEST') as number) || 0;
    if (this.realtimeWatchTimer !== -1) {
      clearInterval(this.realtimeWatchTimer);
      this.realtimeWatchTimer = -1;
    }
    this.realtimeWatchTimer = setInterval(() => {
      const backLevel = resolveCompanionBackLevel(
        this.showHistoryPage,
        this.showSearchPage,
        this.showFilterPage,
        this.companionSubMode
      );
      AppStorage.setOrCreate('COMPANION_BACK_LEVEL', backLevel);
      const latestBackRequest = Number(AppStorage.get('COMPANION_BACK_REQUEST') as number) || 0;
      if (latestBackRequest !== this.observedBackRequest) {
        this.observedBackRequest = latestBackRequest;
        this.handleCompanionBackNavigation();
      }

      const nextVersion = this.vm.getScheduleVersion();
      const nextRuntime = this.vm.getCompanionContext().runtimeState;
      if (nextVersion !== this.observedScheduleVersion || nextRuntime !== this.observedRuntimeState) {
        hilog.info(
          0x0000,
          'CompanionView',
          `[COMPANION][card_state_refresh] version=${this.observedScheduleVersion}->${nextVersion}, runtime=${this.observedRuntimeState}->${nextRuntime}`
        );
        this.observedScheduleVersion = nextVersion;
        this.observedRuntimeState = nextRuntime;
        this.refreshContext();
      }
    }, 300);
  }

  private stopRealtimeWatch(): void {
    if (this.realtimeWatchTimer !== -1) {
      clearInterval(this.realtimeWatchTimer);
      this.realtimeWatchTimer = -1;
    }
    AppStorage.setOrCreate('COMPANION_BACK_LEVEL', 'none');
  }

  private bindImmersiveWindowContext(): void {
    window.getLastWindow(this.getUIContext().getHostContext()).then((mainWindow: window.Window) => {
      this.immersiveWindow = mainWindow;
      this.updateSafeAreaInsetsFromWindow(mainWindow);
      this.setSystemBarVisible(false);
      mainWindow.off('avoidAreaChange');
      mainWindow.off('windowSizeChange');
      mainWindow.on('avoidAreaChange', this.onWindowAvoidAreaChange);
      mainWindow.on('windowSizeChange', this.onWindowSizeChange);
    }).catch((_err: object) => {
      const zeroInsets = createCompanionZeroInsets();
      this.safeTopInset = zeroInsets.top;
      this.safeBottomInset = zeroInsets.bottom;
      this.safeLeftInset = zeroInsets.left;
      this.safeRightInset = zeroInsets.right;
    });
  }

  private unbindImmersiveWindowContext(): void {
    if (!this.immersiveWindow) {
      return;
    }
    this.immersiveWindow.off('avoidAreaChange');
    this.immersiveWindow.off('windowSizeChange');
    this.immersiveWindow = undefined;
  }

  private setSystemBarVisible(isVisible: boolean): void {
    if (this.immersiveWindow) {
      applyCompanionSystemBarVisible(this.immersiveWindow, isVisible);
      return;
    }
    window.getLastWindow(this.getUIContext().getHostContext()).then((mainWindow: window.Window) => {
      this.immersiveWindow = mainWindow;
      applyCompanionSystemBarVisible(mainWindow, isVisible);
    }).catch((_err: object) => {
      // Ignore if current UI context is already detached.
    });
  }

  private updateSafeAreaInsets(): void {
    if (this.immersiveWindow) {
      this.updateSafeAreaInsetsFromWindow(this.immersiveWindow);
      return;
    }
    window.getLastWindow(this.getUIContext().getHostContext()).then((mainWindow: window.Window) => {
      this.immersiveWindow = mainWindow;
      this.updateSafeAreaInsetsFromWindow(mainWindow);
    }).catch((_err: object) => {
      const zeroInsets = createCompanionZeroInsets();
      this.safeTopInset = zeroInsets.top;
      this.safeBottomInset = zeroInsets.bottom;
      this.safeLeftInset = zeroInsets.left;
      this.safeRightInset = zeroInsets.right;
    });
  }

  private updateSafeAreaInsetsFromWindow(mainWindow: window.Window): void {
    try {
      const safeInsets = resolveCompanionSafeAreaInsets(mainWindow, this.getUIContext());
      this.safeTopInset = safeInsets.top;
      this.safeBottomInset = safeInsets.bottom;
      this.safeLeftInset = safeInsets.left;
      this.safeRightInset = safeInsets.right;
    } catch (_err) {
      const zeroInsets = createCompanionZeroInsets();
      this.safeTopInset = zeroInsets.top;
      this.safeBottomInset = zeroInsets.bottom;
      this.safeLeftInset = zeroInsets.left;
      this.safeRightInset = zeroInsets.right;
    }
  }

  private refreshContext(): void {
    this.refreshScheduleCache();
    this.context = this.vm.getCompanionContext();
    this.ensureFocusReady();
    this.ensureFocusVisible();
  }

  private refreshScheduleCache(): void {
    this.cachedScheduleVersion = this.vm.getScheduleVersion();
    this.cachedScheduledEvents = this.vm.getOrderedScheduleEvents();
    this.cachedEventById.clear();
    this.cachedIndexById.clear();
    this.cachedVisibleIndexById.clear();
    this.cachedSearchTextById.clear();
    this.cachedScheduledEvents.forEach((event: EventEntity, index: number) => {
      this.cachedEventById.set(event.id, event);
      this.cachedIndexById.set(event.id, index);
      this.cachedSearchTextById.set(event.id, `${event.name}|${event.address || ''}`.toLowerCase());
    });
    this.cachedVisibleScheduledEvents = this.cachedScheduledEvents.filter((event: EventEntity) =>
      matchesCompanionFilter(event, this.companionFilterState)
    );
    this.cachedVisibleScheduledEvents.forEach((event: EventEntity, index: number) => {
      this.cachedVisibleIndexById.set(event.id, index);
    });
  }

  private ensureScheduleCacheUpToDate(): void {
    if (this.cachedScheduleVersion !== this.vm.getScheduleVersion()) {
      this.refreshScheduleCache();
    }
  }

  private getScheduledEvents(): EventEntity[] {
    this.ensureScheduleCacheUpToDate();
    return this.cachedScheduledEvents;
  }

  private getVisibleScheduledEvents(): EventEntity[] {
    this.ensureScheduleCacheUpToDate();
    return this.cachedVisibleScheduledEvents;
  }

  private getVisibleTimelineEvents(): EventEntity[] {
    return this.getVisibleScheduledEvents();
  }

  private getVisibleTimelineCount(): number {
    return this.getVisibleScheduledEvents().length;
  }

  private getVisibleFocusPosition(): number {
    this.ensureScheduleCacheUpToDate();
    return resolveCompanionVisibleFocusPosition(this.focusedEventId, this.cachedVisibleIndexById);
  }

  private ensureFocusVisible(): void {
    const visible = this.getVisibleScheduledEvents();
    const nextFocusId = resolveCompanionVisibleFocusId(visible, this.focusedEventId);
    if (nextFocusId <= 0 || nextFocusId === this.focusedEventId) {
      return;
    }
    this.applyFocusById(nextFocusId, 'tap');
  }

  private openFilterPage(): void {
    this.showFilterPage = true;
  }

  private closeFilterPage(): void {
    this.showFilterPage = false;
  }

  private applyFilter(state: CompanionFilterState): void {
    this.companionFilterState = state;
    this.refreshScheduleCache();
    this.showFilterPage = false;
    this.ensureFocusVisible();
    const visibleCount = this.cachedVisibleScheduledEvents.length;
    this.safeShowToast(`筛选：${getCompanionFilterLabel(this.companionFilterState)}（${visibleCount}）`);
    hilog.info(0x0000, 'CompanionView', `[COMPANION_FILTER][apply] state=${this.companionFilterState}, count=${visibleCount}`);
  }

  private refreshSearchResults(): void {
    this.searchResults = resolveCompanionSearchResults(
      this.getScheduledEvents(),
      this.searchKeyword,
      this.cachedSearchTextById
    );
  }

  private openSearchPage(): void {
    this.refreshScheduleCache();
    this.searchKeyword = '';
    this.refreshSearchResults();
    this.showSearchPage = true;
    hilog.info(0x0000, 'CompanionView', `[COMPANION_SEARCH][open] seed=${this.searchResults.length}`);
  }

  private closeSearchPage(): void {
    this.showSearchPage = false;
    this.searchKeyword = '';
    this.searchResults = [];
  }

  private pickSearchResult(event: EventEntity): void {
    this.applyFocusById(event.id, 'tap');
    this.closeSearchPage();
    hilog.info(0x0000, 'CompanionView', `[COMPANION_SEARCH][pick] id=${event.id}, name=${event.name}`);
  }

  private getEventById(id: number): EventEntity | null {
    this.ensureScheduleCacheUpToDate();
    const found = this.cachedEventById.get(id);
    return found ? found : null;
  }

  private getScheduleIndexById(id: number): number {
    this.ensureScheduleCacheUpToDate();
    const index = this.cachedIndexById.get(id);
    return index !== undefined ? index : -1;
  }

  private pickDefaultFocusId(): number {
    return resolveCompanionDefaultFocusId(
      this.getScheduledEvents(),
      this.context.currentEvent ? this.context.currentEvent.id : -1,
      this.context.nextEvent ? this.context.nextEvent.id : -1
    );
  }

  private ensureFocusReady(): void {
    const schedule = this.getScheduledEvents();
    if (schedule.length === 0) {
      this.focusedEventId = -1;
      this.focusedIndex = -1;
      this.cardDisplayEventId = -1;
      this.outgoingCardEventId = -1;
      this.incomingCardEventId = -1;
      this.isCardSwitching = false;
      this.cardSwitchProgress = 1;
      return;
    }

    if (!schedule.some(e => e.id === this.focusedEventId)) {
      this.focusedEventId = this.pickDefaultFocusId();
      this.focusedIndex = this.getScheduleIndexById(this.focusedEventId);
      this.cardDisplayEventId = this.focusedEventId;
      this.outgoingCardEventId = -1;
      this.incomingCardEventId = -1;
      this.isCardSwitching = false;
      this.cardSwitchProgress = 1;
      return;
    }

    this.focusedIndex = this.getScheduleIndexById(this.focusedEventId);
    if (this.cardDisplayEventId <= 0 || !schedule.some(e => e.id === this.cardDisplayEventId)) {
      this.cardDisplayEventId = this.focusedEventId;
    }
  }

  private getFocusedEvent(): EventEntity | null {
    if (this.focusedEventId <= 0) {
      return null;
    }
    return this.getEventById(this.focusedEventId);
  }

  private canRenderSwitchCards(): boolean {
    if (!this.isCardSwitching) {
      return false;
    }
    if (this.outgoingCardEventId <= 0 || this.incomingCardEventId <= 0) {
      return false;
    }
    return this.getEventById(this.outgoingCardEventId) !== null && this.getEventById(this.incomingCardEventId) !== null;
  }

  private getDisplayCardEvent(): EventEntity | null {
    if (this.cardDisplayEventId > 0) {
      const cardEvent = this.getEventById(this.cardDisplayEventId);
      if (cardEvent) {
        return cardEvent;
      }
    }
    return this.getFocusedEvent();
  }

  private applyFocusById(targetId: number, source: FocusSource): void {
    if (targetId <= 0) {
      return;
    }

    const targetIndex = this.getScheduleIndexById(targetId);
    if (targetIndex < 0) {
      return;
    }

    if (source === 'tap') {
      this.tapPriorityUntilTs = Date.now() + this.tapPriorityWindowMs;
    }

    this.focusSource = source;
    this.focusedEventId = targetId;
    this.focusedIndex = targetIndex;

    if (this.cardDisplayEventId <= 0) {
      this.cardDisplayEventId = targetId;
      return;
    }

    if (this.cardDisplayEventId === targetId && !this.isCardSwitching) {
      return;
    }

    if (this.isCardSwitching) {
      this.pendingFocusId = targetId;
      return;
    }

    this.startCardSwitch(targetId);
  }

  private startCardSwitch(targetId: number): void {
    if (this.cardDisplayEventId <= 0 || this.cardDisplayEventId === targetId) {
      this.cardDisplayEventId = targetId;
      return;
    }

    this.outgoingCardEventId = this.cardDisplayEventId;
    this.incomingCardEventId = targetId;
    this.isCardSwitching = true;
    this.cardSwitchProgress = 0;

    this.getUIContext().animateTo({ duration: 240, curve: Curve.EaseInOut }, () => {
      this.cardSwitchProgress = 1;
    });

    setTimeout(() => {
      this.cardDisplayEventId = this.incomingCardEventId;
      this.outgoingCardEventId = -1;
      this.incomingCardEventId = -1;
      this.isCardSwitching = false;
      this.cardSwitchProgress = 1;

      if (this.pendingFocusId > 0 && this.pendingFocusId !== this.cardDisplayEventId) {
        const nextFocusId = this.pendingFocusId;
        this.pendingFocusId = -1;
        this.applyFocusById(nextFocusId, 'scroll');
      } else {
        this.pendingFocusId = -1;
      }
    }, 255);
  }

  private handleTimelineScrollIndex(start: number, end: number, center: number): void {
    this.visibleStartIndex = start;
    this.visibleEndIndex = end;
    this.visibleCenterIndex = center;
  }

  private handleTimelineScrollStop(): void {
    // Intentionally keep scroll passive: focus changes only by tap/action/init.
  }

  private handleTimelineTap(event: EventEntity, index: number): void {
    this.applyFocusById(event.id, 'tap');
    this.timelineScroller.scrollToIndex(index, true, ScrollAlign.CENTER);
  }

  private showActiveConflictDialog(conflictName: string): void {
    const safeName = (conflictName || '').trim().length > 0 ? conflictName : '其他地点';
    this.getUIContext().showAlertDialog({
      title: '无法开始打卡',
      message: `当前已有进行中的地点【${safeName}】。\n请先结束该地点后再开始新的打卡。`,
      autoCancel: true,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '我知道了',
        action: () => {}
      }
    });
  }

  private async showGlobalActiveConflictDialog(excludeEventId: number): Promise<boolean> {
    const conflict = await this.vm.getStartConflictInfo(excludeEventId);
    if (!conflict) {
      return false;
    }
    this.showActiveConflictDialog(conflict.name);
    return true;
  }

  private async handleFocusedPrimaryAction(): Promise<void> {
    const focused = this.getFocusedEvent();
    if (!focused) {
      return;
    }

    if (this.context.actions.canResume) {
      const ok = this.vm.resumeCurrentExecution();
      if (!ok) {
        this.safeShowToast('继续失败，请稍后重试');
        return;
      }
      this.refreshContext();
      this.applyFocusById(focused.id, 'tap');
      return;
    }

    const state = getCompanionEventState(focused);
    const now = Date.now();
    if (state === 'PENDING') {
      if (!canCompanionStartFocused(focused, this.getScheduledEvents())) {
        const shown = await this.showGlobalActiveConflictDialog(focused.id);
        if (!shown) {
          this.safeShowToast('请先结束当前进行中的任务');
        }
        return;
      }
      const started = await this.vm.updateActualTime(focused.id, 'actual_start_time', now);
      if (!started) {
        const shown = await this.showGlobalActiveConflictDialog(focused.id);
        if (!shown) {
          this.safeShowToast('开始打卡失败，请稍后重试');
        }
        return;
      }
      hilog.info(0x0000, 'CompanionView', `[COMPANION][action_start] eventId=${focused.id}, name=${focused.name}`);
      this.refreshContext();
      this.applyFocusById(focused.id, 'tap');
      this.enterImmersiveMode();
      return;
    }

    if (state === 'ACTIVE') {
      if (!this.context.actions.canPause) {
        this.safeShowToast('当前状态不可暂停');
        return;
      }
      const paused = this.vm.pauseCurrentExecution();
      if (!paused) {
        this.safeShowToast('暂停失败，请稍后重试');
        return;
      }
      this.refreshContext();
    }
  }

  private async handleFocusedSkip(): Promise<void> {
    await handleCompanionFocusedSkip({
      focusedEvent: this.getFocusedEvent(),
      skipEvent: async (event: EventEntity): Promise<void> => this.vm.skipEvent(event),
      refreshContext: () => this.refreshContext(),
      getScheduledEvents: () => this.getScheduledEvents(),
      getScheduleIndexById: (id: number) => this.getScheduleIndexById(id),
      applyFocusById: (id: number) => this.applyFocusById(id, 'tap'),
      showToast: (message: string) => this.safeShowToast(message)
    });
  }

  private startNavigation(target?: EventEntity): void {
    const event = target || this.getFocusedEvent() || this.context.currentEvent || this.context.nextEvent;
    if (!event) {
      this.safeShowToast('暂无可导航目的地');
      return;
    }

    if (!event.latitude || !event.longitude || (event.latitude === 0 && event.longitude === 0)) {
      this.safeShowToast(`[${event.name}] 缺少有效坐标`);
      return;
    }

    const uiContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const wantParam: Record<string, Object> = {};
    wantParam['sceneType'] = Number(1);
    wantParam['destinationName'] = String(event.name);
    wantParam['destinationLatitude'] = Number(event.latitude);
    wantParam['destinationLongitude'] = Number(event.longitude);

    const callback: common.AbilityStartCallback = {
      onError: () => {
        this.safeShowToast('鎷夎捣瀵艰埅澶辫触');
      }
    };

    uiContext.startAbilityByType('navigation', wantParam, callback).catch((_error: Object) => {
      this.safeShowToast('当前设备不支持系统导航');
    });
  }

  private loadHistoryTimelineData(): void {
    this.historyTimelineSummary = this.vm.getCurrentPlanHistorySummary();
    this.historyTimelineItems = this.vm.getCurrentPlanHistoryTimelineItems(10);
  }

  private openHistoryList(): void {
    this.loadHistoryTimelineData();
    this.historyTimelineFilter = 'all';
    this.selectedHistoryTimelineItem = null;
    this.historySummary = null;
    this.selectedHistoryPlaceName = '';
    this.historyViewMode = 'timeline';
    this.showHistoryPage = true;
  }

  private openHistoryDetailFromTimeline(item: HistoryTimelineItem): void {
    this.selectedHistoryTimelineItem = item;
    this.historySummary = this.vm.getPlaceCheckinSummary(item.placeName);
    this.selectedHistoryPlaceName = item.placeName;
    this.historyViewMode = 'detail';
    this.showHistoryPage = true;
  }

  private handleFocusedAdjust(event?: EventEntity): void {
    const target = event || this.getFocusedEvent();
    if (!target) {
      this.safeShowToast('暂无可补打卡的地点');
      return;
    }
    this.openRecordCorrectionDialog(target);
  }

  private openRecordCorrectionDialog(event: EventEntity): void {
    const target = this.getEventById(event.id);
    if (!target) {
      this.safeShowToast('地点不存在或已删除');
      return;
    }
    this.correctionDialogController = new CustomDialogController({
      builder: RecordCorrectionDialog({
        event: target,
        onConfirm: (startTs: number, endTs: number) => {
          void this.applyCompanionCheckinBackfill(target.id, startTs, endTs);
        },
        onClear: () => {
          void this.applyCompanionCheckinBackfill(target.id, 0, 0);
        }
      }),
      alignment: DialogAlignment.Center,
      autoCancel: true
    });
    this.correctionDialogController.open();
  }

  private async applyCompanionCheckinBackfill(eventId: number, startTs: number, endTs: number): Promise<void> {
    const safeStart = Number.isFinite(startTs) ? Math.max(0, Math.floor(startTs)) : 0;
    const safeEnd = Number.isFinite(endTs) ? Math.max(0, Math.floor(endTs)) : 0;
    if (safeStart <= 0 && safeEnd > 0) {
      this.safeShowToast('请先设置开始时间');
      return;
    }
    if (safeStart > 0 && safeEnd > 0 && safeEnd < safeStart) {
      this.safeShowToast('结束时间不能早于开始时间');
      return;
    }
    const ok = await this.vm.backfillCheckinTime(eventId, safeStart, safeEnd);
    if (!ok) {
      this.safeShowToast('补打卡失败，请稍后重试');
      return;
    }
    this.safeShowToast(safeStart > 0 ? '补打卡已保存' : '打卡记录已清除');
    this.refreshContext();
  }

  private async handleFocusedReopen(): Promise<void> {
    await handleCompanionFocusedReopen({
      focusedEvent: this.getFocusedEvent(),
      getScheduledEvents: () => this.getScheduledEvents(),
      reopenSkippedEvent: async (eventId: number) => this.vm.reopenSkippedEvent(eventId),
      updateActualStart: async (eventId: number, nowTs: number) =>
        this.vm.updateActualTime(eventId, 'actual_start_time', nowTs),
      showGlobalActiveConflictDialog: async (excludeEventId: number) =>
        this.showGlobalActiveConflictDialog(excludeEventId),
      refreshContext: () => this.refreshContext(),
      applyFocusById: (id: number) => this.applyFocusById(id, 'tap'),
      enterImmersiveMode: () => this.enterImmersiveMode(),
      showToast: (message: string) => this.safeShowToast(message)
    });
  }

  private enterControlMode(): void {
    if (this.companionSubMode === 'control') {
      return;
    }
    this.refreshContext();
    this.immersiveDragOffsetY = 0;
    this.interactionMode = 'both';
    this.getUIContext().animateTo({ duration: 250, curve: Curve.EaseInOut }, () => {
      this.companionSubMode = 'control';
    });
    setTimeout(() => {
      this.interactionMode = 'control';
    }, 260);
  }

  private enterImmersiveMode(): void {
    if (this.companionSubMode === 'immersive') {
      return;
    }
    this.refreshContext();
    this.immersiveDragOffsetY = 0;
    this.interactionMode = 'both';
    this.getUIContext().animateTo({ duration: 240, curve: Curve.EaseInOut }, () => {
      this.companionSubMode = 'immersive';
      this.showHistoryPage = false;
      this.showSearchPage = false;
      this.showFilterPage = false;
    });
    setTimeout(() => {
      this.interactionMode = 'immersive';
    }, 250);
  }

  private exitCompanion(): void {
    this.showHistoryPage = false;
    this.showSearchPage = false;
    this.showFilterPage = false;
    this.immersiveDragOffsetY = 0;
    this.isShow = false;
  }

  private handleCompanionBackNavigation(): boolean {
    const action = resolveCompanionBackAction(
      this.showHistoryPage,
      this.showSearchPage,
      this.showFilterPage,
      this.companionSubMode
    );
    if (action === 'close_overlay') {
      this.showHistoryPage = false;
      this.showSearchPage = false;
      this.showFilterPage = false;
      this.historyViewMode = 'timeline';
      this.selectedHistoryTimelineItem = null;
      this.selectedHistoryPlaceName = '';
      this.historySummary = null;
      this.safeShowToast('已返回伴游上一级');
      hilog.info(0x0000, 'CompanionView', '[COMPANION][back_hierarchy] close_overlay');
      return true;
    }
    if (action === 'control_to_immersive') {
      this.enterImmersiveMode();
      this.safeShowToast('已返回沉浸模式');
      hilog.info(0x0000, 'CompanionView', '[COMPANION][back_hierarchy] control_to_immersive');
      return true;
    }
    this.exitCompanion();
    hilog.info(0x0000, 'CompanionView', '[COMPANION][back_hierarchy] exit_companion');
    return true;
  }

  private handleImmersiveSwipeStart(): void {
    const now = Date.now();
    this.swipeStartTs = now;
    this.swipeLastTs = now;
    this.swipePeakDistance = 0;
  }

  private handleImmersiveSwipeUpdate(event: GestureEvent): void {
    if (this.companionSubMode !== 'immersive') {
      return;
    }
    const nextState = getCompanionSwipeUpdate(event.offsetY, this.swipePeakDistance, Date.now());
    this.swipePeakDistance = nextState.peakDistance;
    this.swipeLastTs = nextState.lastTs;
    this.immersiveDragOffsetY = nextState.dragOffsetY;
  }

  private resetImmersiveSwipe(): void {
    if (this.immersiveDragOffsetY === 0) {
      return;
    }
    this.getUIContext().animateTo({ duration: 220, curve: Curve.Friction }, () => {
      this.immersiveDragOffsetY = 0;
    });
  }

  private handleImmersiveSwipeEnd(event: GestureEvent): void {
    const now = Date.now();
    const shouldEnterControl = shouldCompanionEnterControlMode(
      this.swipePeakDistance,
      event.offsetY,
      this.swipeStartTs,
      now,
      this.immersiveDistanceTrigger,
      this.immersiveVelocityTrigger
    );
    this.swipeStartTs = 0;
    this.swipeLastTs = 0;
    this.swipePeakDistance = 0;
    if (shouldEnterControl) {
      this.enterControlMode();
      return;
    }
    this.resetImmersiveSwipe();
  }

  // endregion

  // region builders

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Stack() {
        CompanionImmersiveView({
          context: this.context,
          immersiveText: this.immersiveText,
          immersiveDragOffsetY: this.immersiveDragOffsetY,
          safeTopInset: this.safeTopInset,
          safeBottomInset: this.safeBottomInset,
          getRuntimeLabel: () => getCompanionRuntimeLabel(this.context.runtimeState),
          getPlannedRange: (event: EventEntity) => getCompanionPlannedRange(event),
          getForecastStartText: (event: EventEntity) => getCompanionForecastStartText(event),
          isCurrentEventPending: () => isCompanionCurrentEventPending(this.context),
          isCurrentEventActive: () => isCompanionCurrentEventActive(this.context),
          canStartFocused: (event: EventEntity) => canCompanionStartFocused(event, this.getScheduledEvents()),
          canEndFocused: (event: EventEntity) => canCompanionEndFocused(event, this.context),
          onStartEvent: async (event: EventEntity) => {
            this.applyFocusById(event.id, 'tap');
            await this.handleFocusedPrimaryAction();
          },
          onEndEvent: async (event: EventEntity) => {
            await this.vm.updateActualTime(event.id, 'actual_end_time', Date.now());
            hilog.info(0x0000, 'CompanionView', `[COMPANION][action_end] eventId=${event.id}, name=${event.name}`);
            this.refreshContext();
          },
          onNavigate: (event?: EventEntity) => {
            this.startNavigation(event);
          },
          onSwipeGesture: (phase, event) => {
            if (phase === 'start') {
              this.handleImmersiveSwipeStart();
              return;
            }
            if (phase === 'update' && event) {
              this.handleImmersiveSwipeUpdate(event);
              return;
            }
            if (phase === 'end' && event) {
              this.handleImmersiveSwipeEnd(event);
            }
          }
        });
      }
      .zIndex(this.companionSubMode === 'immersive' ? 3 : 1)
      .enabled(getCompanionInteractiveEnabled('immersive', this.interactionMode))
      .opacity(this.companionSubMode === 'immersive' ? 1 : 0)
      .scale({
        x: this.companionSubMode === 'immersive' ? 1 : 0.988,
        y: this.companionSubMode === 'immersive' ? 1 : 0.988
      })
      .translate({
        x: 0,
        y: this.companionSubMode === 'immersive' ? this.immersiveDragOffsetY : -8
      });

      CompanionControlPage({
        context: this.context,
        safeTopInset: this.safeTopInset,
        safeBottomInset: this.safeBottomInset,
        companionFilterState: this.companionFilterState,
        isWeatherFeatureEnabled: this.vm.isWeatherFeatureEnabled(),
        weatherExpanded: this.weatherExpanded,
        showWeatherScorePopup: this.showWeatherScorePopup,
        showWeatherHintPopup: this.showWeatherHintPopup,
        showWeatherSuggestionPopup: this.showWeatherSuggestionPopup,
        weatherSuggestionPopupText: this.weatherSuggestionPopupText,
        executionWeatherCollabBadge: this.vm.executionWeatherCollabBadge,
        executionWeatherLoading: this.vm.executionWeatherLoading,
        executionWeatherHint: this.vm.executionWeatherHint,
        executionWeatherLevel: this.vm.executionWeatherLevel,
        executionWeatherCurrentText: this.vm.executionWeatherCurrentText,
        executionWeatherNextText: this.vm.executionWeatherNextText,
        executionWeatherScore: this.vm.executionWeatherScore,
        executionWeatherCollabSummary: this.vm.executionWeatherCollabSummary,
        executionWeatherAppliedSummary: this.vm.executionWeatherAppliedSummary,
        executionWeatherSuggestions: this.vm.executionWeatherSuggestions,
        weatherScoreLines: this.vm.buildWeatherScoreExplanation(this.vm.executionWeatherScore).split('\n'),
        weatherHintLines: this.vm.buildWeatherHintExplanation().split('\n'),
        canRenderSwitchCards: this.canRenderSwitchCards(),
        outgoingEvent: this.getEventById(this.outgoingCardEventId),
        incomingEvent: this.getEventById(this.incomingCardEventId),
        stableEvent: this.getDisplayCardEvent(),
        focusedEventId: this.focusedEventId,
        isCardSwitching: this.isCardSwitching,
        cardSwitchProgress: this.cardSwitchProgress,
        scheduledEvents: this.getScheduledEvents(),
        timelineEvents: this.getVisibleTimelineEvents(),
        focusPosition: this.getVisibleFocusPosition(),
        timelineCount: this.getVisibleTimelineCount(),
        timelineScroller: this.timelineScroller,
        onExit: () => {
          this.handleCompanionBackNavigation();
        },
        onRefreshWeather: () => {
          this.safeShowToast('正在刷新天气...');
          void this.vm.refreshExecutionWeather(true, 'MANUAL').then(() => {
            this.safeShowToast('天气已刷新');
          }).catch((_error: Object) => {
            this.safeShowToast('天气刷新失败，请稍后重试');
          });
        },
        onToggleExpanded: () => {
          this.weatherExpanded = !this.weatherExpanded;
        },
        onToggleScorePopup: () => {
          this.showWeatherScorePopup = !this.showWeatherScorePopup;
        },
        onToggleHintPopup: () => {
          this.showWeatherHintPopup = !this.showWeatherHintPopup;
        },
        onToggleSuggestionPopup: () => {
          this.showWeatherSuggestionPopup = !this.showWeatherSuggestionPopup;
        },
        onScorePopupStateChange: (visible: boolean) => {
          if (!visible) {
            this.showWeatherScorePopup = false;
          }
        },
        onHintPopupStateChange: (visible: boolean) => {
          if (!visible) {
            this.showWeatherHintPopup = false;
          }
        },
        onSuggestionPopupStateChange: (visible: boolean) => {
          if (!visible) {
            this.showWeatherSuggestionPopup = false;
          }
        },
        onOpenSuggestionGuide: () => {
          this.weatherSuggestionPopupText = getCompanionWeatherGuidePopupText();
          this.showWeatherSuggestionPopup = !this.showWeatherSuggestionPopup;
        },
        onOpenSuggestionDetail: (item: WeatherSuggestion) => {
          this.weatherSuggestionPopupText = getCompanionWeatherSuggestionDetailText(item);
          this.showWeatherSuggestionPopup = true;
        },
        onApplySuggestion: (item: WeatherSuggestion) => {
          applyCompanionWeatherSuggestion({
            vm: this.vm,
            item: item,
            showToast: (message: string) => {
              this.safeShowToast(message);
            },
            showApplyConfirm: (title: string, message: string, onConfirm: () => void) => {
              this.getUIContext().showAlertDialog({
                title: title,
                message: message,
                autoCancel: true,
                alignment: DialogAlignment.Center,
                primaryButton: {
                  value: '鍏堜笉搴旂敤',
                  action: () => {}
                },
                secondaryButton: {
                  value: '纭搴旂敤',
                  action: () => {
                    onConfirm();
                  }
                }
              });
            }
          });
        },
        onLaterSuggestion: (suggestionId: string) => {
          this.vm.dismissExecutionSuggestion(suggestionId);
          this.safeShowToast(getCompanionDismissSuggestionToast('later'));
        },
        onIgnoreSuggestion: (suggestionId: string) => {
          this.vm.dismissExecutionSuggestion(suggestionId);
          this.safeShowToast(getCompanionDismissSuggestionToast('ignore'));
        },
        onNavigate: (event: EventEntity) => {
          this.startNavigation(event);
        },
        onStartFocused: async () => {
          await this.handleFocusedPrimaryAction();
        },
        onSkipFocused: async () => {
          await this.handleFocusedSkip();
        },
        onEndFocused: async (event: EventEntity) => {
          await this.vm.updateActualTime(event.id, 'actual_end_time', Date.now());
          hilog.info(0x0000, 'CompanionView', `[COMPANION][action_end] eventId=${event.id}, name=${event.name}`);
          this.refreshContext();
        },
        onReopenFocused: async () => {
          await this.handleFocusedReopen();
        },
        onAdjustFocused: async (event: EventEntity) => {
          this.handleFocusedAdjust(event);
        },
        onSkipDisabledTap: () => {
          this.safeShowToast('已跳过任务不可再次跳过');
        },
        onEnterImmersive: () => {
          this.enterImmersiveMode();
        },
        onTimelineItemTap: (event: EventEntity, index: number) => {
          this.handleTimelineTap(event, index);
        },
        onTimelineScrollIndex: (start: number, end: number, center: number) => {
          this.handleTimelineScrollIndex(start, end, center);
        },
        onTimelineScrollStop: () => {
          this.handleTimelineScrollStop();
        },
        onHistory: () => {
          hilog.info(0x0000, 'CompanionView', '[COMPANION_NAV][tap] action=history');
          this.openHistoryList();
        },
        onImmersive: () => {
          hilog.info(0x0000, 'CompanionView', '[COMPANION_NAV][tap] action=immersive');
          this.enterImmersiveMode();
        },
        onSearch: () => {
          hilog.info(0x0000, 'CompanionView', '[COMPANION_NAV][tap] action=search');
          this.openSearchPage();
        },
        onFilter: () => {
          hilog.info(0x0000, 'CompanionView', '[COMPANION_NAV][tap] action=filter');
          this.openFilterPage();
        }
      })
      .zIndex(this.companionSubMode === 'control' ? 3 : 2)
      .enabled(this.companionSubMode === 'control' || getCompanionInteractiveEnabled('control', this.interactionMode))
      .opacity(this.companionSubMode === 'control' ? 1 : 0)
      .scale({
        x: this.companionSubMode === 'control' ? 1 : 0.992,
        y: this.companionSubMode === 'control' ? 1 : 0.992
      })
      .translate({ x: 0, y: this.companionSubMode === 'control' ? 0 : 10 });

      if (this.showHistoryPage || this.showSearchPage || this.showFilterPage) {
        CompanionOverlayPages({
          showHistoryPage: this.showHistoryPage,
          historyTimelineSummary: this.historyTimelineSummary,
          historyTimelineItems: this.historyTimelineItems,
          historyTimelineFilter: this.historyTimelineFilter,
          historyViewMode: this.historyViewMode,
          historySummary: this.historySummary,
          vm: this.vm,
          selectedHistoryTimelineItem: this.selectedHistoryTimelineItem,
          showSearchPage: this.showSearchPage,
          searchKeyword: this.searchKeyword,
          searchResults: this.searchResults,
          showFilterPage: this.showFilterPage,
          companionFilterState: this.companionFilterState,
          safeTopInset: this.safeTopInset,
          safeBottomInset: this.safeBottomInset,
          onHistoryClose: () => {
            this.showHistoryPage = false;
            this.historyViewMode = 'timeline';
            this.historyTimelineFilter = 'all';
            this.selectedHistoryTimelineItem = null;
            this.selectedHistoryPlaceName = '';
            this.historySummary = null;
          },
          onHistoryBack: () => {
            this.historyViewMode = 'timeline';
            this.selectedHistoryTimelineItem = null;
            this.selectedHistoryPlaceName = '';
            this.historySummary = null;
          },
          onHistoryFilterChange: (filter: HistoryTimelineFilter) => {
            this.historyTimelineFilter = filter;
          },
          onHistoryItemClick: (item: HistoryTimelineItem) => {
            this.openHistoryDetailFromTimeline(item);
          },
          onSearchClose: () => {
            this.closeSearchPage();
          },
          onSearch: (keyword: string) => {
            this.searchKeyword = keyword;
            this.refreshSearchResults();
          },
          onSearchResultClick: (item: EventEntity) => {
            this.pickSearchResult(item);
          },
          onFilterClose: () => {
            this.closeFilterPage();
          },
          onFilterSelect: (state: CompanionFilterState) => {
            this.applyFilter(state);
          }
        })
          .zIndex(40);
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.getThemePalette().pageBg)
    .ignoreLayoutSafeArea()
    .padding({ left: this.safeLeftInset, right: this.safeRightInset });
  }
  // endregion
}

