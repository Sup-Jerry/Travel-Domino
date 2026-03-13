import { EventEntity } from '../../../model/entity/EventEntity';
import {
  CompanionContext,
  PlaceCheckinSummary,
  HistoryTimelineFilter,
  HistoryTimelineItem,
  HistoryTimelineSummary,
  TimelineViewModel
} from '../../../viewmodel/TimelineViewModel';
import { DateUtil } from '../../../common/utils/DateUtil';
import { display, promptAction, window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { CompanionBottomActionBar } from './BottomNavBar';
import { ThemeCenter } from '../../../common/utils/ThemeCenter';
import { CompanionEventState, CompanionPresentationHelper } from './CompanionPresentationHelper';
import { TimelineExecutionState } from '../../../common/utils/TimelineExecutionState';

type CompanionSubMode = 'immersive' | 'control';
type CompanionInteractionMode = 'immersive' | 'control' | 'both';
type FocusSource = 'tap' | 'scroll' | 'init';
type TimelineEventState = CompanionEventState;
type CompanionFilterState = 'ALL' | TimelineEventState;
type HistoryViewMode = 'timeline' | 'detail';

interface HistoryTimelineGroup {
  key: string;
  title: string;
  items: HistoryTimelineItem[];
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
    this.searchKeyword = '';
    this.searchResults = [];
    this.companionFilterState = 'ALL';
    this.immersiveDragOffsetY = 0;
    this.swipeStartTs = 0;
    this.swipeLastTs = 0;
    this.swipePeakDistance = 0;
    this.bindImmersiveWindowContext();
    this.pickImmersiveText();
    this.ensureFocusReady();
  }

  aboutToDisappear() {
    this.unbindImmersiveWindowContext();
    this.setSystemBarVisible(true);
  }

  private pickImmersiveText(): void {
    const tips: string[] = [
      '一步一步来。',
      '按自己的节奏走，就是最好的节奏。',
      '先完成这一站，再去下一站。',
      '旅程正在此刻发生。'
    ];
    const idx = Math.floor(Math.random() * tips.length);
    this.immersiveText = tips[idx];
  }

  private getThemePalette() {
    return ThemeCenter.getPalette(this.effectiveTheme);
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
      this.safeTopInset = 0;
      this.safeBottomInset = 0;
      this.safeLeftInset = 0;
      this.safeRightInset = 0;
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
    const apply = (targetWindow: window.Window) => {
      targetWindow.setWindowSystemBarEnable(isVisible ? ['status', 'navigation'] : []).catch((_error: BusinessError) => {
        // Ignore recoverable UI chrome updates.
      });
    };
    if (this.immersiveWindow) {
      apply(this.immersiveWindow);
      return;
    }
    window.getLastWindow(this.getUIContext().getHostContext()).then((mainWindow: window.Window) => {
      this.immersiveWindow = mainWindow;
      apply(mainWindow);
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
      this.safeTopInset = 0;
      this.safeBottomInset = 0;
      this.safeLeftInset = 0;
      this.safeRightInset = 0;
    });
  }

  private updateSafeAreaInsetsFromWindow(mainWindow: window.Window): void {
    try {
      const sysArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      const navArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      const cutoutArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_CUTOUT);
      const displayInfo = display.getDefaultDisplaySync();

      const cutoutTopPx = cutoutArea.topRect.height > 0 ? cutoutArea.topRect.top + cutoutArea.topRect.height : 0;
      const cutoutBottomPx = cutoutArea.bottomRect.height > 0 ? displayInfo.height - cutoutArea.bottomRect.top : 0;
      const cutoutLeftPx = cutoutArea.leftRect.width > 0 ? cutoutArea.leftRect.left + cutoutArea.leftRect.width : 0;
      const cutoutRightPx = cutoutArea.rightRect.width > 0 ? displayInfo.width - cutoutArea.rightRect.left : 0;

      const safeTopPx = Math.max(sysArea.topRect.height, cutoutTopPx);
      const safeBottomPx = Math.max(navArea.bottomRect.height, cutoutBottomPx);
      const safeLeftPx = Math.max(sysArea.leftRect.width, cutoutLeftPx);
      const safeRightPx = Math.max(sysArea.rightRect.width, cutoutRightPx);

      this.safeTopInset = this.getUIContext().px2vp(safeTopPx);
      this.safeBottomInset = this.getUIContext().px2vp(safeBottomPx);
      this.safeLeftInset = this.getUIContext().px2vp(safeLeftPx);
      this.safeRightInset = this.getUIContext().px2vp(safeRightPx);
    } catch (_err) {
      this.safeTopInset = 0;
      this.safeBottomInset = 0;
      this.safeLeftInset = 0;
      this.safeRightInset = 0;
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
    this.cachedVisibleScheduledEvents = this.cachedScheduledEvents.filter((event: EventEntity) => this.matchesFilter(event));
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

  private matchesFilter(event: EventEntity): boolean {
    if (this.companionFilterState === 'ALL') {
      return true;
    }
    return this.getEventState(event) === this.companionFilterState;
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
    const index = this.cachedVisibleIndexById.get(this.focusedEventId);
    return index !== undefined ? index + 1 : 0;
  }

  private getFilterLabel(state: CompanionFilterState): string {
    if (state === 'ALL') {
      return '全部';
    }
    if (state === 'PENDING') {
      return '未开始';
    }
    if (state === 'ACTIVE') {
      return '进行中';
    }
    if (state === 'COMPLETED') {
      return '已完成';
    }
    return '已跳过';
  }

  private ensureFocusVisible(): void {
    const visible = this.getVisibleScheduledEvents();
    if (visible.length === 0) {
      return;
    }
    if (!visible.some((event: EventEntity) => event.id === this.focusedEventId)) {
      this.applyFocusById(visible[0].id, 'tap');
    }
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
    this.safeShowToast(`筛选：${this.getFilterLabel(this.companionFilterState)}（${visibleCount}）`);
    hilog.info(0x0000, 'CompanionView', `[COMPANION_FILTER][apply] state=${this.companionFilterState}, count=${visibleCount}`);
  }

  private getFilterOptions(): CompanionFilterState[] {
    return ['ALL', 'PENDING', 'ACTIVE', 'COMPLETED', 'SKIPPED'];
  }

  private refreshSearchResults(): void {
    const keyword = this.searchKeyword.trim().toLowerCase();
    const source = this.getScheduledEvents();
    if (keyword.length === 0) {
      this.searchResults = source.slice(0, 20);
      return;
    }
    this.searchResults = source.filter((event: EventEntity) => {
      const searchable = this.cachedSearchTextById.get(event.id) ?? `${event.name}|${event.address || ''}`.toLowerCase();
      return searchable.includes(keyword);
    });
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
    const schedule = this.getScheduledEvents();
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

    const currentEvent = this.context.currentEvent;
    if (currentEvent !== null && schedule.some(e => e.id === currentEvent.id)) {
      return currentEvent.id;
    }

    const nextEvent = this.context.nextEvent;
    if (nextEvent !== null && schedule.some(e => e.id === nextEvent.id)) {
      return nextEvent.id;
    }

    if (pendingId > 0) {
      return pendingId;
    }
    return schedule[0].id;
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

  private getSafeCardEvent(id: number): EventEntity {
    const direct = this.getEventById(id);
    if (direct) {
      return direct;
    }
    const focused = this.getFocusedEvent();
    if (focused) {
      return focused;
    }
    const schedule = this.getScheduledEvents();
    if (schedule.length > 0) {
      return schedule[0];
    }
    return new EventEntity();
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

  private formatTs(ts: number): string {
    return CompanionPresentationHelper.formatTs(ts);
  }

  private getPlannedRange(event: EventEntity): string {
    return CompanionPresentationHelper.getPlannedRange(event);
  }

  private getForecastStartText(event: EventEntity): string {
    return CompanionPresentationHelper.getForecastStartText(event);
  }

  private getMainCardTimeText(event: EventEntity): string {
    return CompanionPresentationHelper.getMainCardTimeText(event);
  }

  private getEventState(event: EventEntity): TimelineEventState {
    return CompanionPresentationHelper.getEventState(event);
  }

  private getEventStateLabel(event: EventEntity): string {
    return CompanionPresentationHelper.getEventStateLabel(event);
  }

  private getStateCoreColor(event: EventEntity): ResourceColor {
    const state = this.getEventState(event);
    const palette = this.getThemePalette();
    if (state === 'ACTIVE') {
      return palette.success;
    }
    if (state === 'COMPLETED') {
      return palette.statusCompleted;
    }
    if (state === 'SKIPPED') {
      return palette.statusSkipped;
    }
    return palette.statusPending;
  }

  private getStateTagBackgroundColor(event: EventEntity): ResourceColor {
    const state = this.getEventState(event);
    if (state === 'ACTIVE') {
      return '#E9F8F1';
    }
    if (state === 'COMPLETED') {
      return '#EAF7EE';
    }
    if (state === 'SKIPPED') {
      return '#FFF4E7';
    }
    return '#EAF2FF';
  }

  private getStateTagTextColor(event: EventEntity): ResourceColor {
    return this.getStateCoreColor(event);
  }

  private getStateBorderColor(event: EventEntity): ResourceColor {
    return this.getStateCoreColor(event);
  }

  private getStateDotColor(event: EventEntity): ResourceColor {
    return this.getStateCoreColor(event);
  }

  private getTimelineSupplement(event: EventEntity): string {
    return CompanionPresentationHelper.getTimelineSupplement(event);
  }

  private getRuntimeLabel(): string {
    switch (this.context.runtimeState) {
      case 'READY':
        return '可开始';
      case 'ACTIVE':
        return '进行中';
      case 'GAP':
        return '空档中';
      default:
        return '空闲';
    }
  }

  private getRuntimeDescription(): string {
    if (this.context.runtimeState === 'ACTIVE') {
      return '当前地点进行中。结束打卡后会自动重排后续行程。';
    }

    if (this.context.runtimeState === 'READY' && this.context.currentEvent) {
      const startTs = this.context.currentEvent.dynamic_start_time;
      if (startTs > 0 && startTs + 60000 < Date.now()) {
        const overdue = Math.max(1, Math.round((Date.now() - startTs) / 60000));
        return `已超出计划开始 ${overdue} 分钟，仍可立即开始。`;
      }
      return '当前任务可以立即开始。';
    }

    if (this.context.runtimeState === 'GAP' && this.context.nextEvent) {
      return `当前暂无可执行任务。下一站：${this.context.nextEvent.name}。`;
    }

    if (this.context.nextEvent) {
      return `下一站：${this.context.nextEvent.name}。`;
    }
    return '当前暂无进行中的任务。';
  }

  private hasOtherActiveEvent(excludeEventId: number): boolean {
    return this.getScheduledEvents().some((item: EventEntity) =>
      item.id !== excludeEventId && this.getEventState(item) === 'ACTIVE'
    );
  }

  private canStartFocused(event: EventEntity): boolean {
    if (this.getEventState(event) !== 'PENDING') {
      return false;
    }
    return !this.hasOtherActiveEvent(event.id);
  }

  private canEndFocused(event: EventEntity): boolean {
    if (this.getEventState(event) !== 'ACTIVE') {
      return false;
    }
    if (!this.context.actions.canEnd) {
      return false;
    }
    if (!this.context.currentEvent) {
      return false;
    }
    return this.context.currentEvent.id === event.id;
  }

  private isCurrentEventPending(): boolean {
    return !!this.context.currentEvent && this.getEventState(this.context.currentEvent) === 'PENDING';
  }

  private isCurrentEventActive(): boolean {
    return !!this.context.currentEvent && this.getEventState(this.context.currentEvent) === 'ACTIVE';
  }

  private async handleFocusedPrimaryAction(): Promise<void> {
    const focused = this.getFocusedEvent();
    if (!focused) {
      return;
    }

    const state = this.getEventState(focused);
    const now = Date.now();
    if (state === 'PENDING') {
      if (!this.canStartFocused(focused)) {
        this.safeShowToast('请先结束当前进行中的任务');
        return;
      }
      await this.vm.updateActualTime(focused.id, 'actual_start_time', now);
      this.refreshContext();
      this.applyFocusById(focused.id, 'tap');
      this.enterImmersiveMode();
      return;
    }

    if (state === 'ACTIVE') {
      if (!this.canEndFocused(focused)) {
        this.safeShowToast('仅当前进行中的任务可结束');
        return;
      }
      await this.vm.updateActualTime(focused.id, 'actual_end_time', now);
      this.refreshContext();
    }
  }

  private async handleFocusedSkip(): Promise<void> {
    const focused = this.getFocusedEvent();
    if (!focused) {
      return;
    }
    if (this.getEventState(focused) !== 'PENDING') {
      this.safeShowToast('仅“未开始”任务可跳过');
      return;
    }
    await this.vm.skipEvent(focused);
    this.refreshContext();
    setTimeout(() => {
      const schedule = this.getScheduledEvents();
      const startIndex = this.getScheduleIndexById(focused.id);
      let nextId = -1;
      if (startIndex >= 0) {
        for (let i = startIndex + 1; i < schedule.length; i++) {
          if (TimelineExecutionState.isStartable(schedule[i])) {
            nextId = schedule[i].id;
            break;
          }
        }
      }
      if (nextId <= 0) {
        for (let i = 0; i < schedule.length; i++) {
          if (TimelineExecutionState.isStartable(schedule[i])) {
            nextId = schedule[i].id;
            break;
          }
        }
      }
      if (nextId > 0) {
        this.applyFocusById(nextId, 'tap');
      }
    }, 120);
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
        this.safeShowToast('拉起导航失败');
      }
    };

    uiContext.startAbilityByType('navigation', wantParam, callback).catch((error: BusinessError) => {
      this.safeShowToast(`当前设备不支持系统导航（${error.code}）`);
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

  private handleFocusedAdjust(): void {
    this.safeShowToast('该地点暂不支持修正入口');
  }

  private async handleFocusedReopen(): Promise<void> {
    const focused = this.getFocusedEvent();
    if (!focused) {
      return;
    }
    if (this.getEventState(focused) !== 'SKIPPED') {
      this.safeShowToast('仅“已跳过”任务可重新开始');
      return;
    }
    if (this.hasOtherActiveEvent(focused.id)) {
      this.safeShowToast('请先结束当前进行中的任务');
      return;
    }

    const reopened = await this.vm.reopenSkippedEvent(focused.id);
    if (!reopened) {
      this.safeShowToast('重新开始失败');
      return;
    }

    await this.vm.updateActualTime(focused.id, 'actual_start_time', Date.now());
    this.refreshContext();
    this.applyFocusById(focused.id, 'tap');
    this.enterImmersiveMode();
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
    if (event.offsetY < 0) {
      const dragDistance = Math.abs(event.offsetY);
      if (dragDistance > this.swipePeakDistance) {
        this.swipePeakDistance = dragDistance;
      }
      this.swipeLastTs = Date.now();
      const dampedOffset = event.offsetY * 0.38;
      this.immersiveDragOffsetY = dampedOffset < -150 ? -150 : dampedOffset;
      return;
    }
    this.immersiveDragOffsetY = 0;
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
    const dragDistance = Math.max(this.swipePeakDistance, event.offsetY < 0 ? Math.abs(event.offsetY) : 0);
    const duration = Math.max(1, now - this.swipeStartTs);
    const upVelocity = dragDistance / duration;
    const shouldEnterControl = dragDistance >= this.immersiveDistanceTrigger || upVelocity >= this.immersiveVelocityTrigger;
    this.swipeStartTs = 0;
    this.swipeLastTs = 0;
    this.swipePeakDistance = 0;
    if (shouldEnterControl) {
      this.enterControlMode();
      return;
    }
    this.resetImmersiveSwipe();
  }

  private getInteractiveEnabled(mode: CompanionSubMode): boolean {
    if (this.interactionMode === 'both') {
      return true;
    }
    return this.interactionMode === mode;
  }

  private getCardTranslateX(phase: 'stable' | 'outgoing' | 'incoming'): number {
    if (!this.isCardSwitching) {
      return 0;
    }
    if (phase === 'outgoing') {
      return -24 * this.cardSwitchProgress;
    }
    if (phase === 'incoming') {
      return 24 * (1 - this.cardSwitchProgress);
    }
    return 0;
  }

  private getCardOpacity(phase: 'stable' | 'outgoing' | 'incoming'): number {
    if (!this.isCardSwitching) {
      return 1;
    }
    if (phase === 'outgoing') {
      return 1 - this.cardSwitchProgress;
    }
    if (phase === 'incoming') {
      return this.cardSwitchProgress;
    }
    return 1;
  }

  private getCardScale(phase: 'stable' | 'outgoing' | 'incoming'): number {
    if (!this.isCardSwitching) {
      return 1;
    }
    if (phase === 'outgoing') {
      return 1 - (0.015 * this.cardSwitchProgress);
    }
    if (phase === 'incoming') {
      return 0.992 + (0.008 * this.cardSwitchProgress);
    }
    return 1;
  }
  // endregion

  // region builders
  @Builder
  private ImmersiveView() {
    Column({ space: 18 }) {
      Blank().layoutWeight(1);

      if (this.context.currentEvent) {
        Text(this.context.currentEvent.name)
          .fontSize(42)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.getThemePalette().textPrimary)
          .maxLines(2)
          .textAlign(TextAlign.Center)
          .textOverflow({ overflow: TextOverflow.Ellipsis });

        Text(`${this.getRuntimeLabel()} | ${this.getPlannedRange(this.context.currentEvent)}`)
          .fontSize(14)
          .fontColor(this.getThemePalette().textSecondary)
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .backgroundColor(this.getThemePalette().cardBgSoft)
          .borderRadius(16);

        Row({ space: 10 }) {
          if (this.isCurrentEventPending()) {
            Button('开始打卡')
              .layoutWeight(2)
              .height(50)
              .enabled(this.context.currentEvent ? this.canStartFocused(this.context.currentEvent) : false)
              .backgroundColor(this.getThemePalette().success)
              .fontColor(Color.White)
              .onClick(async () => {
                this.applyFocusById(this.context.currentEvent ? this.context.currentEvent.id : -1, 'tap');
                await this.handleFocusedPrimaryAction();
              });
          }
          if (this.isCurrentEventActive()) {
            Button('结束打卡')
              .layoutWeight(2)
              .height(50)
              .enabled(this.context.currentEvent ? this.canEndFocused(this.context.currentEvent) : false)
              .backgroundColor(this.getThemePalette().success)
              .fontColor(Color.White)
              .onClick(async () => {
                this.applyFocusById(this.context.currentEvent ? this.context.currentEvent.id : -1, 'tap');
                await this.handleFocusedPrimaryAction();
              });
          }
          Button('导航')
            .layoutWeight(this.isCurrentEventPending() || this.isCurrentEventActive() ? 1 : 3)
            .height(50)
            .backgroundColor(this.getThemePalette().primary)
            .fontColor(Color.White)
            .onClick(() => this.startNavigation(this.context.currentEvent || undefined));
        }
        .width('78%');
      } else {
        Text('当前暂无进行中的地点')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.getThemePalette().textPrimary);
        Text(this.immersiveText)
          .fontSize(16)
          .fontColor(this.getThemePalette().textSecondary)
          .textAlign(TextAlign.Center)
          .padding({ left: 28, right: 28 });
        if (this.context.nextEvent) {
          Text(`下一站：${this.context.nextEvent.name}（${this.getForecastStartText(this.context.nextEvent)}）`)
            .fontSize(14)
            .fontColor(this.getThemePalette().textSecondary)
            .textAlign(TextAlign.Center)
            .padding({ left: 28, right: 28 });
        }
      }

      Text('上滑进入控制页')
        .fontSize(12)
        .fontColor(this.getThemePalette().textTertiary)
        .margin({ top: 10 });

      Blank().layoutWeight(1);
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({ top: this.safeTopInset + 12, bottom: this.safeBottomInset + 12 })
    .backgroundColor(this.getThemePalette().immersiveBg)
    .translate({ y: this.immersiveDragOffsetY })
    .priorityGesture(
      PanGesture({ direction: PanDirection.Vertical, distance: 64 })
        .onActionStart((_event: GestureEvent) => {
          this.handleImmersiveSwipeStart();
        })
        .onActionUpdate((event: GestureEvent) => {
          this.handleImmersiveSwipeUpdate(event);
        })
        .onActionEnd((event: GestureEvent) => {
          this.handleImmersiveSwipeEnd(event);
        })
    );
  }

  @Builder
  private ControlTopBar() {
    Row() {
      Column({ space: 2 }) {
        Text('伴游控制')
          .fontSize(18)
          .fontColor(this.getThemePalette().textPrimary)
          .fontWeight(FontWeight.Bold);
        Text(this.getRuntimeDescription())
          .fontSize(11)
          .fontColor(this.getThemePalette().textSecondary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1);
      Text('退出伴游')
        .fontSize(13)
        .fontColor(this.getThemePalette().textSecondary)
        .onClick(() => {
          this.exitCompanion();
        });
    }
    .width('100%')
    .padding({ top: this.safeTopInset + 10, left: 16, right: 16, bottom: 8 });
  }

  @Builder
  private FocusedCardBody(event: EventEntity, phase: 'stable' | 'outgoing' | 'incoming') {
    Column({ space: 10 }) {
      Text(event.name)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.getThemePalette().textPrimary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis });

      Row({ space: 8 }) {
        Text(this.getEventStateLabel(event))
          .fontSize(12)
          .fontColor(this.getStateTagTextColor(event))
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor(this.getStateTagBackgroundColor(event))
          .border({ width: 1, color: this.getStateBorderColor(event), radius: 10 })
          .borderRadius(10);
        Text(this.getMainCardTimeText(event))
          .fontSize(12)
          .fontColor(this.getThemePalette().textSecondary)
          .maxLines(1);
      }

      if (this.getEventState(event) !== 'PENDING') {
        Text(`计划 ${this.getPlannedRange(event)}`)
          .fontSize(12)
          .fontColor(this.getThemePalette().textTertiary)
          .maxLines(1);
      }

      Row({ space: 8 }) {
        Button('导航')
          .layoutWeight(1)
          .height(42)
          .backgroundColor(this.getThemePalette().primary)
          .fontColor(Color.White)
          .onClick(() => this.startNavigation(event));

        if (this.getEventState(event) === 'PENDING') {
          Button('开始')
            .layoutWeight(1)
            .height(42)
            .enabled(this.canStartFocused(event))
            .backgroundColor(this.getThemePalette().success)
            .fontColor(Color.White)
            .onClick(async () => {
              await this.handleFocusedPrimaryAction();
            });
          Button('跳过')
            .layoutWeight(1)
            .height(42)
            .backgroundColor(this.getThemePalette().warning)
            .fontColor(Color.White)
            .onClick(async () => {
              await this.handleFocusedSkip();
            });
        } else if (this.getEventState(event) === 'ACTIVE') {
          Button('结束')
            .layoutWeight(1)
            .height(42)
            .enabled(this.canEndFocused(event))
            .backgroundColor(this.getThemePalette().success)
            .fontColor(Color.White)
            .onClick(async () => {
              await this.handleFocusedPrimaryAction();
            });
          Button('跳过')
            .layoutWeight(1)
            .height(42)
            .backgroundColor(this.getThemePalette().warning)
            .fontColor(Color.White)
            .onClick(async () => {
              await this.handleFocusedSkip();
            });
        } else if (this.getEventState(event) === 'SKIPPED') {
          Button('重新开始')
            .layoutWeight(1)
            .height(42)
            .backgroundColor(this.getThemePalette().success)
            .fontColor(Color.White)
            .onClick(async () => {
              await this.handleFocusedReopen();
            });
          Button('跳过')
            .layoutWeight(1)
            .height(42)
            .enabled(false)
            .backgroundColor(this.getThemePalette().cardBgSoft)
            .fontColor(this.getThemePalette().textTertiary)
            .onClick(() => {
              this.safeShowToast('已跳过任务不可再次跳过');
            });
        } else {
          Button('结束')
            .layoutWeight(1)
            .height(42)
            .enabled(false)
            .backgroundColor(this.getThemePalette().cardBgSoft)
            .fontColor(this.getThemePalette().textTertiary);
          Button('跳过')
            .layoutWeight(1)
            .height(42)
            .enabled(false)
            .backgroundColor(this.getThemePalette().cardBgSoft)
            .fontColor(this.getThemePalette().textTertiary);
        }
      }
      .width('100%');
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(16)
    .backgroundColor(this.getThemePalette().companionCardBg)
    .border({ width: 1, color: this.getStateBorderColor(event), radius: 16 })
    .shadow({ radius: 14, color: '#24000000', offsetY: 5 })
    .borderRadius(16)
    .translate({ x: this.getCardTranslateX(phase), y: 0 })
    .opacity(this.getCardOpacity(phase))
    .scale({
      x: this.getCardScale(phase),
      y: this.getCardScale(phase)
    });
  }

  @Builder
  private FocusedCardHost() {
    Stack() {
      if (this.canRenderSwitchCards()) {
        this.FocusedCardBody(this.getSafeCardEvent(this.outgoingCardEventId), 'outgoing');
        this.FocusedCardBody(this.getSafeCardEvent(this.incomingCardEventId), 'incoming');
      } else if (this.getDisplayCardEvent()) {
        this.FocusedCardBody(this.getSafeCardEvent(this.cardDisplayEventId), 'stable');
      } else {
        Column({ space: 8 }) {
          Text('暂无焦点任务')
            .fontSize(20)
            .fontColor(this.getThemePalette().textPrimary)
            .fontWeight(FontWeight.Bold);
          Text('点击时间轴条目以聚焦')
            .fontSize(12)
            .fontColor(this.getThemePalette().textSecondary);
        }
        .width('100%')
        .padding(16)
        .backgroundColor(this.getThemePalette().companionCardBg)
        .borderRadius(16);
      }
    }
    .width('100%');
  }

  @Builder
  private TimelineFocusItem(item: EventEntity, index: number) {
    Row({ space: 10 }) {
      Column({ space: 0 }) {
        Column()
          .width(10)
          .height(10)
          .borderRadius(5)
          .backgroundColor(item.id === this.focusedEventId ? this.getStateDotColor(item) : this.getThemePalette().textTertiary);
      }
      .width(16)
      .alignItems(HorizontalAlign.Center)
      .justifyContent(FlexAlign.Start);

      Column({ space: 4 }) {
        Text(item.name)
          .fontSize(item.id === this.focusedEventId ? 16 : 14)
          .fontWeight(item.id === this.focusedEventId ? FontWeight.Bold : FontWeight.Medium)
          .fontColor(item.id === this.focusedEventId ? this.getThemePalette().textPrimary : this.getThemePalette().textSecondary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis });

        if (item.id === this.focusedEventId) {
          Row({ space: 6 }) {
            Text(this.getEventStateLabel(item))
              .fontSize(10)
              .fontColor(this.getStateTagTextColor(item))
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .backgroundColor(this.getStateTagBackgroundColor(item))
              .border({ width: 1, color: this.getStateBorderColor(item), radius: 8 })
              .borderRadius(8);
            Text(this.getTimelineSupplement(item))
              .fontSize(11)
              .fontColor(this.getThemePalette().textTertiary)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1);
          }
          .width('100%');
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);
    }
    .width('100%')
    .padding({
      left: 12,
      right: 12,
      top: item.id === this.focusedEventId ? 12 : 10,
      bottom: item.id === this.focusedEventId ? 12 : 10
    })
    .backgroundColor(item.id === this.focusedEventId ? this.getThemePalette().companionCardBg : this.getThemePalette().companionBg)
    .border({ width: item.id === this.focusedEventId ? 1 : 0, color: this.getStateBorderColor(item), radius: 12 })
    .borderRadius(12)
    .shadow({
      radius: item.id === this.focusedEventId ? 10 : 0,
      color: item.id === this.focusedEventId ? '#22000000' : '#00000000',
      offsetY: item.id === this.focusedEventId ? 4 : 0
    })
    .scale({ x: item.id === this.focusedEventId ? 1 : 0.995, y: item.id === this.focusedEventId ? 1 : 0.995 })
    .onClick(() => {
      this.handleTimelineTap(item, index);
    });
  }

  @Builder
  private TimelineSection() {
    Column({ space: 8 }) {
      Row() {
        Text('时间轴')
          .fontSize(13)
          .fontColor(this.getThemePalette().textSecondary);
        Blank();
        Text(`筛选 ${this.getFilterLabel(this.companionFilterState)}  ${this.getVisibleFocusPosition()}/${Math.max(1, this.getVisibleTimelineCount())}`)
          .fontSize(11)
          .fontColor(this.getThemePalette().textTertiary);
      }
      .width('100%');

      if (this.getVisibleTimelineCount() === 0) {
        Column({ space: 6 }) {
          Text('当前筛选下无可见日程')
            .fontSize(13)
            .fontColor(this.getThemePalette().textSecondary);
          Text('点击筛选按钮可切换状态')
            .fontSize(11)
            .fontColor(this.getThemePalette().textTertiary);
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center);
      } else {
        List({ space: 8, scroller: this.timelineScroller }) {
          ForEach(this.getVisibleTimelineEvents(), (item: EventEntity, index: number) => {
            ListItem() {
              this.TimelineFocusItem(item, index);
            };
          }, (item: EventEntity) => item.id.toString());
          ListItem().height(8);
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
        .onScrollIndex((start: number, end: number, center: number) => {
          this.handleTimelineScrollIndex(start, end, center);
        })
        .onScrollStop(() => {
          this.handleTimelineScrollStop();
        });
      }
    }
    .width('100%')
    .layoutWeight(1);
  }

  private closeHistoryPage(): void {
    this.showHistoryPage = false;
    this.historyViewMode = 'timeline';
    this.historyTimelineFilter = 'all';
    this.selectedHistoryTimelineItem = null;
    this.selectedHistoryPlaceName = '';
    this.historySummary = null;
  }

  private backToHistoryTimeline(): void {
    this.historyViewMode = 'timeline';
    this.selectedHistoryTimelineItem = null;
    this.selectedHistoryPlaceName = '';
    this.historySummary = null;
  }

  private formatDateTime(ts: number): string {
    return CompanionPresentationHelper.formatDateTime(ts);
  }

  private getHistoryAddress(placeName: string): string {
    return this.vm.getPlaceAddress(placeName);
  }

  private getLatestEventForPlace(placeName: string): EventEntity | null {
    return this.vm.getLatestEventForPlace(placeName);
  }

  private getCurrentHistoryLatestEvent(): EventEntity | null {
    if (!this.historySummary) {
      return null;
    }
    return this.getLatestEventForPlace(this.historySummary.placeName);
  }

  private getCurrentHistoryStatusText(): string {
    const latestEvent = this.getCurrentHistoryLatestEvent();
    if (!latestEvent) {
      return '--';
    }
    if (TimelineExecutionState.isSkipped(latestEvent)) {
      return '已跳过';
    }
    if (TimelineExecutionState.isActive(latestEvent)) {
      return '进行中';
    }
    if (TimelineExecutionState.isCompleted(latestEvent)) {
      return '已离开';
    }
    return '未开始';
  }

  private getCurrentHistoryPlannedStartText(): string {
    if (this.selectedHistoryTimelineItem && this.selectedHistoryTimelineItem.plannedStart > 0) {
      return this.formatTs(this.selectedHistoryTimelineItem.plannedStart);
    }
    const latestEvent = this.getCurrentHistoryLatestEvent();
    if (!latestEvent) {
      return '--:--';
    }
    if (latestEvent.dynamic_start_time > 0) {
      return this.formatTs(latestEvent.dynamic_start_time);
    }
    return latestEvent.computed_time || latestEvent.fixed_start_time || '--:--';
  }

  private getCurrentHistoryActualStartText(): string {
    const latestEvent = this.getCurrentHistoryLatestEvent();
    if (!latestEvent || latestEvent.actual_start_time <= 0) {
      return '--:--';
    }
    return this.formatTs(latestEvent.actual_start_time);
  }

  private getCurrentHistoryActualEndText(): string {
    const latestEvent = this.getCurrentHistoryLatestEvent();
    if (!latestEvent || latestEvent.actual_end_time <= 0) {
      return '--:--';
    }
    return this.formatTs(latestEvent.actual_end_time);
  }

  private getCurrentHistoryStayText(): string {
    const latestEvent = this.getCurrentHistoryLatestEvent();
    if (!latestEvent || latestEvent.actual_start_time <= 0 || latestEvent.actual_end_time <= latestEvent.actual_start_time) {
      return '0 分钟';
    }
    const stayMinutes = Math.round((latestEvent.actual_end_time - latestEvent.actual_start_time) / 60000);
    return `${stayMinutes} 分钟`;
  }

  private getCurrentHistoryDeviationText(): string {
    const latestEvent = this.getCurrentHistoryLatestEvent();
    if (!latestEvent || latestEvent.actual_start_time <= 0 || latestEvent.dynamic_start_time <= 0) {
      return '--';
    }
    const delta = Math.round((latestEvent.actual_start_time - latestEvent.dynamic_start_time) / 60000);
    if (delta > 0) {
      return `晚到 ${delta} 分钟`;
    }
    if (delta < 0) {
      return `早到 ${Math.abs(delta)} 分钟`;
    }
    return '准时';
  }

  private getCurrentHistoryNoteText(): string {
    const latestEvent = this.getCurrentHistoryLatestEvent();
    if (!latestEvent) {
      return '--';
    }
    const note = (latestEvent.note || '').trim();
    return note.length > 0 ? note : '--';
  }

  private applyHistoryTimelineFilter(filter: HistoryTimelineFilter): void {
    this.historyTimelineFilter = filter;
  }

  private cycleHistoryTimelineFilter(): void {
    if (this.historyTimelineFilter === 'all') {
      this.historyTimelineFilter = 'completed';
      return;
    }
    if (this.historyTimelineFilter === 'completed') {
      this.historyTimelineFilter = 'skipped';
      return;
    }
    if (this.historyTimelineFilter === 'skipped') {
      this.historyTimelineFilter = 'abnormal';
      return;
    }
    this.historyTimelineFilter = 'all';
  }

  private getHistoryTimelineFilterLabel(): string {
    if (this.historyTimelineFilter === 'completed') {
      return '只看完成';
    }
    if (this.historyTimelineFilter === 'skipped') {
      return '只看跳过';
    }
    if (this.historyTimelineFilter === 'abnormal') {
      return '只看异常';
    }
    return '全部';
  }

  private isTimelineItemVisible(item: HistoryTimelineItem): boolean {
    if (this.historyTimelineFilter === 'all') {
      return true;
    }
    if (this.historyTimelineFilter === 'completed') {
      return item.actionType === 'ARRIVE' || item.actionType === 'LEAVE';
    }
    if (this.historyTimelineFilter === 'skipped') {
      return item.actionType === 'SKIP';
    }
    return item.isAbnormal || item.actionType === 'SKIP';
  }

  private getFilteredHistoryTimelineItems(): HistoryTimelineItem[] {
    return this.historyTimelineItems.filter((item: HistoryTimelineItem) => this.isTimelineItemVisible(item));
  }

  private getHistoryDayTitle(groupKey: string): string {
    if (groupKey === '未定') {
      return '未定';
    }
    const todayKey = DateUtil.formatLocalDate(Date.now());
    if (groupKey === todayKey) {
      return '今天';
    }
    const date = new Date(groupKey);
    return DateUtil.formatDate(date, 'MM月dd日');
  }

  private getHistoryTimelineGroups(): HistoryTimelineGroup[] {
    const source = this.getFilteredHistoryTimelineItems();
    const grouped: Record<string, HistoryTimelineItem[]> = {};
    source.forEach((item: HistoryTimelineItem) => {
      const key = item.groupDateKey || '未定';
      if (!grouped[key]) {
        grouped[key] = [];
      }
      grouped[key].push(item);
    });
    const keys = Object.keys(grouped).sort((a: string, b: string) => a.localeCompare(b));
    return keys.map((key: string): HistoryTimelineGroup => {
      const items = grouped[key];
      items.sort((a: HistoryTimelineItem, b: HistoryTimelineItem) => {
        if (a.displayTs !== b.displayTs) {
          return a.displayTs - b.displayTs;
        }
        return a.id - b.id;
      });
      return {
        key: key,
        title: this.getHistoryDayTitle(key),
        items: items
      };
    });
  }

  private getTimelineActionText(item: HistoryTimelineItem): string {
    if (item.actionType === 'ARRIVE') {
      return `到达 ${item.placeName}`;
    }
    if (item.actionType === 'LEAVE') {
      return `离开 ${item.placeName}`;
    }
    if (item.actionType === 'SKIP') {
      return `跳过 ${item.placeName}`;
    }
    return `到达 ${item.placeName}`;
  }

  private getTimelineSkipReason(item: HistoryTimelineItem): string {
    const note = (item.note || '').trim();
    if (note.includes('时间不足')) {
      return '时间不足';
    }
    return '手动跳过';
  }

  private getTimelineSubText(item: HistoryTimelineItem): string {
    if (item.actionType === 'LEAVE') {
      return `停留 ${item.stayMinutes} 分钟`;
    }
    if (item.actionType === 'SKIP') {
      return `原因：${this.getTimelineSkipReason(item)}`;
    }
    if (item.actionType === 'ACTIVE') {
      return '当前进行中';
    }
    if (item.deviationMinutes > 0) {
      return `比计划晚 ${item.deviationMinutes} 分钟`;
    }
    if (item.deviationMinutes < 0) {
      return `比计划早 ${Math.abs(item.deviationMinutes)} 分钟`;
    }
    return '与计划一致';
  }

  private getTimelineSubTextColor(item: HistoryTimelineItem): ResourceColor {
    if (item.actionType === 'SKIP') {
      return this.getThemePalette().statusSkipped;
    }
    if (item.actionType === 'ACTIVE') {
      return this.getThemePalette().success;
    }
    if (item.isAbnormal) {
      return this.getThemePalette().danger;
    }
    return this.getThemePalette().textSecondary;
  }

  private getTimelineCardBgColorByIndex(index: number): ResourceColor {
    const palette: string[] = ['#EAF2FF', '#EAF7EE', '#F7F2EA', '#F8EEF2'];
    const safeIndex = index >= 0 ? index : 0;
    return palette[safeIndex % palette.length];
  }

  private getTimelineCardBgColor(item: HistoryTimelineItem): ResourceColor {
    const visibleItems = this.getFilteredHistoryTimelineItems();
    const placeColorIndex = new Map<string, number>();
    let nextIndex = 0;
    for (let i = 0; i < visibleItems.length; i++) {
      const placeName = (visibleItems[i].placeName || '').trim();
      if (!placeColorIndex.has(placeName)) {
        placeColorIndex.set(placeName, nextIndex % 4);
        nextIndex += 1;
      }
    }
    const key = (item.placeName || '').trim();
    const idx = placeColorIndex.get(key) ?? 0;
    return this.getTimelineCardBgColorByIndex(idx);
  }

  private getTimelineDotColor(item: HistoryTimelineItem): ResourceColor {
    return this.getThemePalette().primary;
  }

  @Builder
  private HistoryFullPage() {
    if (this.showHistoryPage) {
      Column({ space: 12 }) {
        Row() {
          Text(this.historyViewMode === 'timeline' ? '本次计划打卡历史' : '打卡详情')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.getThemePalette().textPrimary);
          Blank();
          if (this.historyViewMode === 'timeline') {
            Text(`筛选 ${this.getHistoryTimelineFilterLabel()}`)
              .fontSize(14)
              .fontColor(this.getThemePalette().textSecondary)
              .onClick(() => {
                this.cycleHistoryTimelineFilter();
              });
          } else {
            Text('返回')
              .fontSize(14)
              .fontColor(this.getThemePalette().textSecondary)
              .onClick(() => {
                this.backToHistoryTimeline();
              });
          }
          Text('关闭')
            .fontSize(14)
            .fontColor(this.getThemePalette().textSecondary)
            .margin({ left: 14 })
            .onClick(() => {
              this.closeHistoryPage();
            });
        }
        .width('100%')
        .padding({ top: this.safeTopInset + 8, bottom: 6 });

        if (this.historyViewMode === 'timeline') {
          if (this.historyTimelineSummary) {
            Column({ space: 6 }) {
              Text(`计划：${this.historyTimelineSummary.planName}`)
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.getThemePalette().textPrimary)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis });
              Text(`已完成 ${this.historyTimelineSummary.completedCount} / 跳过 ${this.historyTimelineSummary.skippedCount} / 进行中 ${this.historyTimelineSummary.activeCount}`)
                .fontSize(12)
                .fontColor(this.getThemePalette().textSecondary);
            }
            .width('100%')
            .padding(12)
            .backgroundColor(this.getThemePalette().companionCardBg)
            .borderRadius(12);
          }

          if (this.getHistoryTimelineGroups().length === 0) {
            Column({ space: 8 }) {
              Text('暂无打卡记录')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.getThemePalette().textSecondary);
              Text('开始或结束一个地点后会生成时间线记录。')
                .fontSize(12)
                .fontColor(this.getThemePalette().textTertiary);
            }
            .width('100%')
            .layoutWeight(1)
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center);
          } else {
            List({ space: 10 }) {
              ForEach(this.getHistoryTimelineGroups(), (group: HistoryTimelineGroup) => {
                ListItem() {
                  Column({ space: 8 }) {
                    Text(group.title)
                      .fontSize(13)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(this.getThemePalette().textSecondary);

                    Column({ space: 8 }) {
                      ForEach(group.items, (item: HistoryTimelineItem) => {
                        Row({ space: 10 }) {
                          Text(item.displayTs > 0 ? this.formatTs(item.displayTs) : '--:--')
                            .fontSize(12)
                            .fontColor(this.getThemePalette().textSecondary)
                            .width(52);

                          Text('●')
                            .fontSize(14)
                            .fontColor(this.getTimelineDotColor(item))
                            .width(14);

                          Column({ space: 4 }) {
                            Text(this.getTimelineActionText(item))
                              .fontSize(14)
                              .fontWeight(FontWeight.Medium)
                              .fontColor(this.getThemePalette().textPrimary)
                              .maxLines(1)
                              .textOverflow({ overflow: TextOverflow.Ellipsis });
                            Text(this.getTimelineSubText(item))
                              .fontSize(12)
                              .fontColor(this.getTimelineSubTextColor(item))
                              .maxLines(1)
                              .textOverflow({ overflow: TextOverflow.Ellipsis });
                          }
                          .layoutWeight(1)
                          .alignItems(HorizontalAlign.Start);
                        }
                        .width('100%')
                        .padding({ left: 10, right: 10, top: 8, bottom: 8 })
                        .backgroundColor(this.getTimelineCardBgColor(item))
                        .borderRadius(10)
                        .onClick(() => {
                          this.openHistoryDetailFromTimeline(item);
                        });
                      }, (item: HistoryTimelineItem) => item.id.toString());
                    }
                    .width('100%');
                  }
                  .width('100%')
                  .padding({ left: 12, right: 12, top: 12, bottom: 12 })
                  .backgroundColor(this.getThemePalette().companionCardBg)
                  .borderRadius(12);
                };
              }, (group: HistoryTimelineGroup) => group.key);
            }
            .width('100%')
            .layoutWeight(1);

            Row({ space: 8 }) {
              Button('只看完成')
                .type(ButtonType.Capsule)
                .fontSize(12)
                .fontColor(this.historyTimelineFilter === 'completed'
                  ? this.getThemePalette().primary
                  : this.getThemePalette().textSecondary)
                .backgroundColor(this.getThemePalette().companionCardBg)
                .layoutWeight(1)
                .onClick(() => {
                  this.applyHistoryTimelineFilter('completed');
                });
              Button('只看跳过')
                .type(ButtonType.Capsule)
                .fontSize(12)
                .fontColor(this.historyTimelineFilter === 'skipped'
                  ? this.getThemePalette().statusSkipped
                  : this.getThemePalette().textSecondary)
                .backgroundColor(this.getThemePalette().companionCardBg)
                .layoutWeight(1)
                .onClick(() => {
                  this.applyHistoryTimelineFilter('skipped');
                });
              Button('只看异常')
                .type(ButtonType.Capsule)
                .fontSize(12)
                .fontColor(this.historyTimelineFilter === 'abnormal'
                  ? this.getThemePalette().danger
                  : this.getThemePalette().textSecondary)
                .backgroundColor(this.getThemePalette().companionCardBg)
                .layoutWeight(1)
                .onClick(() => {
                  this.applyHistoryTimelineFilter('abnormal');
                });
            }
            .width('100%');
          }
        } else if (this.historySummary) {
          Column({ space: 10 }) {
            Column({ space: 4 }) {
              Text(this.historySummary.placeName)
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.getThemePalette().textPrimary)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis });
              Text(`状态：${this.getCurrentHistoryStatusText()}`)
                .fontSize(12)
                .fontColor(this.getThemePalette().textSecondary);
            }
            .width('100%')
            .padding(12)
            .backgroundColor(this.getThemePalette().companionCardBg)
            .borderRadius(12);

            Column({ space: 6 }) {
              Text(`计划开始：${this.getCurrentHistoryPlannedStartText()}`)
                .fontSize(12)
                .fontColor(this.getThemePalette().textSecondary);
              Text(`实际到达：${this.getCurrentHistoryActualStartText()}`)
                .fontSize(12)
                .fontColor(this.getThemePalette().textSecondary);
              Text(`实际离开：${this.getCurrentHistoryActualEndText()}`)
                .fontSize(12)
                .fontColor(this.getThemePalette().textSecondary);
              Text(`实际停留：${this.getCurrentHistoryStayText()}`)
                .fontSize(12)
                .fontColor(this.getThemePalette().textSecondary);
              Text(`执行偏差：${this.getCurrentHistoryDeviationText()}`)
                .fontSize(12)
                .fontColor(this.getThemePalette().textSecondary);
            }
            .width('100%')
            .padding(12)
            .backgroundColor(this.getThemePalette().companionCardBg)
            .borderRadius(12);

            Column({ space: 6 }) {
              Text(`地址：${this.getHistoryAddress(this.historySummary.placeName)}`)
                .fontSize(12)
                .fontColor(this.getThemePalette().textSecondary)
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis });
              Text(`备注：${this.getCurrentHistoryNoteText()}`)
                .fontSize(12)
                .fontColor(this.getThemePalette().textSecondary)
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis });
            }
            .width('100%')
            .padding(12)
            .backgroundColor(this.getThemePalette().companionCardBg)
            .borderRadius(12);
          }
          .width('100%')
          .layoutWeight(1);
        } else {
          Column() {
            Text('暂无历史详情')
              .fontSize(14)
              .fontColor(this.getThemePalette().textSecondary);
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center);
        }
      }
      .width('100%')
      .height('100%')
      .padding({ left: 16, right: 16, bottom: this.safeBottomInset + 14 })
      .backgroundColor(this.getThemePalette().companionBg)
      .zIndex(9)
      .transition({
        type: TransitionType.All,
        opacity: 0,
        translate: { y: 18 },
        scale: { x: 0.985, y: 0.985 }
      });
    }
  }

  @Builder
  private SearchFullPage() {
    if (this.showSearchPage) {
      Column({ space: 10 }) {
        Row() {
          Text('搜索日程')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.getThemePalette().textPrimary);
          Blank();
          Text('关闭')
            .fontSize(14)
            .fontColor(this.getThemePalette().textSecondary)
            .onClick(() => {
              this.closeSearchPage();
            });
        }
        .width('100%')
        .padding({ top: this.safeTopInset + 8, bottom: 8 });

        TextInput({ text: this.searchKeyword, placeholder: '输入地点名或地址' })
          .width('100%')
          .height(42)
          .borderRadius(10)
          .backgroundColor(this.getThemePalette().companionCardBg)
          .fontColor(this.getThemePalette().textPrimary)
          .placeholderColor(this.getThemePalette().textTertiary)
          .padding({ left: 12, right: 12 })
          .onChange((value: string) => {
            this.searchKeyword = value;
            this.refreshSearchResults();
          });

        if (this.searchResults.length === 0) {
          Column({ space: 8 }) {
            Text('没有匹配结果')
              .fontSize(15)
              .fontColor(this.getThemePalette().textSecondary);
            Text('可尝试更短关键词')
              .fontSize(12)
              .fontColor(this.getThemePalette().textTertiary);
          }
          .layoutWeight(1)
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center);
        } else {
          List({ space: 8 }) {
            ForEach(this.searchResults, (item: EventEntity) => {
              ListItem() {
                Row() {
                  Column({ space: 4 }) {
                    Text(item.name)
                      .fontSize(15)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(this.getThemePalette().textPrimary)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis });
                    Text(`${this.getEventStateLabel(item)} | ${this.getPlannedRange(item)}`)
                      .fontSize(12)
                      .fontColor(this.getThemePalette().textSecondary)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis });
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start);

                  Text('聚焦')
                    .fontSize(12)
                    .fontColor(this.getThemePalette().primary);
                }
                .width('100%')
                .padding({ left: 12, right: 12, top: 12, bottom: 12 })
                .backgroundColor(this.getThemePalette().companionCardBg)
                .borderRadius(10)
                .onClick(() => {
                  this.pickSearchResult(item);
                });
              };
            }, (item: EventEntity) => item.id.toString());
          }
          .width('100%')
          .layoutWeight(1);
        }
      }
      .width('100%')
      .height('100%')
      .padding({ left: 16, right: 16, bottom: this.safeBottomInset + 14 })
      .backgroundColor(this.getThemePalette().companionBg)
      .zIndex(10)
      .transition({
        type: TransitionType.All,
        opacity: 0,
        translate: { y: 18 },
        scale: { x: 0.985, y: 0.985 }
      });
    }
  }

  @Builder
  private FilterFullPage() {
    if (this.showFilterPage) {
      Column({ space: 10 }) {
        Row() {
          Text('选择筛选')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.getThemePalette().textPrimary);
          Blank();
          Text('关闭')
            .fontSize(14)
            .fontColor(this.getThemePalette().textSecondary)
            .onClick(() => {
              this.closeFilterPage();
            });
        }
        .width('100%')
        .padding({ top: this.safeTopInset + 8, bottom: 8 });

        Column({ space: 8 }) {
          ForEach(this.getFilterOptions(), (item: CompanionFilterState) => {
            Row() {
              Text(this.getFilterLabel(item))
                .fontSize(15)
                .fontWeight(item === this.companionFilterState ? FontWeight.Bold : FontWeight.Medium)
                .fontColor(item === this.companionFilterState
                  ? this.getThemePalette().textPrimary
                  : this.getThemePalette().textSecondary);
              Blank();
              if (item === this.companionFilterState) {
                Text('已选')
                  .fontSize(12)
                  .fontColor(this.getThemePalette().primary);
              }
            }
            .width('100%')
            .height(48)
            .padding({ left: 12, right: 12 })
            .backgroundColor(item === this.companionFilterState
              ? this.getThemePalette().cardBgSoft
              : this.getThemePalette().companionCardBg)
            .border({
              width: item === this.companionFilterState ? 1 : 0,
              color: item === 'PENDING'
                ? this.getThemePalette().statusPending
                : (item === 'SKIPPED'
                  ? this.getThemePalette().statusSkipped
                  : (item === 'COMPLETED'
                    ? this.getThemePalette().statusCompleted
                    : this.getThemePalette().border)),
              radius: 10
            })
            .borderRadius(10)
            .onClick(() => {
              this.applyFilter(item);
            });
          }, (item: CompanionFilterState) => item);
        }
        .width('100%');
      }
      .width('100%')
      .height('100%')
      .padding({ left: 16, right: 16, bottom: this.safeBottomInset + 14 })
      .backgroundColor(this.getThemePalette().companionBg)
      .zIndex(10)
      .transition({
        type: TransitionType.All,
        opacity: 0,
        translate: { y: 18 },
        scale: { x: 0.985, y: 0.985 }
      });
    }
  }

  @Builder
  private ControlView() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column({ space: 10 }) {
        this.ControlTopBar();
        this.FocusedCardHost();
        this.TimelineSection();
      }
      .width('100%')
      .height('100%')
      .padding({ left: 12, right: 12, bottom: this.safeBottomInset + 90 })
      .backgroundColor(this.getThemePalette().companionBg);

      CompanionBottomActionBar({
        onHistory: () => {
          this.openHistoryList();
        },
        onImmersive: () => {
          this.enterImmersiveMode();
        },
        onSearch: () => {
          this.openSearchPage();
        },
        onFilter: () => {
          this.openFilterPage();
        }
      });
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.getThemePalette().pageBg);
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Stack() {
        this.ImmersiveView();
      }
      .zIndex(this.companionSubMode === 'immersive' ? 3 : 1)
      .enabled(this.getInteractiveEnabled('immersive'))
      .opacity(this.companionSubMode === 'immersive' ? 1 : 0)
      .scale({
        x: this.companionSubMode === 'immersive' ? 1 : 0.988,
        y: this.companionSubMode === 'immersive' ? 1 : 0.988
      })
      .translate({
        x: 0,
        y: this.companionSubMode === 'immersive' ? this.immersiveDragOffsetY : -8
      });

      Stack() {
        this.ControlView();
      }
      .zIndex(this.companionSubMode === 'control' ? 3 : 2)
      .enabled(this.getInteractiveEnabled('control'))
      .opacity(this.companionSubMode === 'control' ? 1 : 0)
      .scale({
        x: this.companionSubMode === 'control' ? 1 : 0.992,
        y: this.companionSubMode === 'control' ? 1 : 0.992
      })
      .translate({ x: 0, y: this.companionSubMode === 'control' ? 0 : 10 });

      this.HistoryFullPage();
      this.SearchFullPage();
      this.FilterFullPage();
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.getThemePalette().pageBg)
    .ignoreLayoutSafeArea()
    .padding({ left: this.safeLeftInset, right: this.safeRightInset });
  }
  // endregion
}













