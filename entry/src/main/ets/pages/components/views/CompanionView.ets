import { EventEntity } from '../../../model/entity/EventEntity';
import {
  CompanionContext,
  PlaceCheckinRecord,
  PlaceCheckinSummary,
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
type HistoryViewMode = 'list' | 'detail';

interface HistoryPlaceItem {
  placeName: string;
  latestTs: number;
  totalRecords: number;
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
  @State historySummary: PlaceCheckinSummary | null = null;
  @State historyViewMode: HistoryViewMode = 'list';
  @State historyPlaces: HistoryPlaceItem[] = [];
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
  private cachedHistoryVersion: number = -1;
  private cachedHistoryPlaces: HistoryPlaceItem[] = [];
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

      this.safeTopInset = px2vp(safeTopPx);
      this.safeBottomInset = px2vp(safeBottomPx);
      this.safeLeftInset = px2vp(safeLeftPx);
      this.safeRightInset = px2vp(safeRightPx);
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
    promptAction.showToast({ message: `筛选：${this.getFilterLabel(this.companionFilterState)}（${visibleCount}）` });
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

    animateTo({ duration: 240, curve: Curve.EaseInOut }, () => {
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
        promptAction.showToast({ message: '请先结束当前进行中的任务' });
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
        promptAction.showToast({ message: '仅当前进行中的任务可结束' });
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
      promptAction.showToast({ message: '仅“未开始”任务可跳过' });
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
      promptAction.showToast({ message: '暂无可导航目的地' });
      return;
    }

    if (!event.latitude || !event.longitude || (event.latitude === 0 && event.longitude === 0)) {
      promptAction.showToast({ message: `[${event.name}] 缺少有效坐标` });
      return;
    }

    const uiContext = getContext(this) as common.UIAbilityContext;
    const wantParam: Record<string, Object> = {};
    wantParam['sceneType'] = Number(1);
    wantParam['destinationName'] = String(event.name);
    wantParam['destinationLatitude'] = Number(event.latitude);
    wantParam['destinationLongitude'] = Number(event.longitude);

    const callback: common.AbilityStartCallback = {
      onError: () => {
        promptAction.showToast({ message: '拉起导航失败' });
      }
    };

    uiContext.startAbilityByType('navigation', wantParam, callback).catch((error: BusinessError) => {
      promptAction.showToast({ message: `当前设备不支持系统导航（${error.code}）` });
    });
  }

  private getHistoryPlaces(): HistoryPlaceItem[] {
    const scheduleVersion = this.vm.getScheduleVersion();
    if (this.cachedHistoryVersion === scheduleVersion) {
      return [...this.cachedHistoryPlaces];
    }
    const summaries = this.vm.getAllPlaceCheckinSummaries();
    const places = summaries.map((summary: PlaceCheckinSummary): HistoryPlaceItem => {
      return {
        placeName: summary.placeName,
        latestTs: summary.lastEndTime > 0 ? summary.lastEndTime : 0,
        totalRecords: summary.totalRecords
      };
    });
    places.sort((a: HistoryPlaceItem, b: HistoryPlaceItem) => {
      if (b.latestTs !== a.latestTs) {
        return b.latestTs - a.latestTs;
      }
      return a.placeName.localeCompare(b.placeName);
    });
    this.cachedHistoryVersion = scheduleVersion;
    this.cachedHistoryPlaces = [...places];
    return places;
  }

  private openHistoryList(): void {
    const places = this.getHistoryPlaces();
    this.historyPlaces = places;
    this.historySummary = null;
    this.selectedHistoryPlaceName = '';
    this.historyViewMode = 'list';
    this.showHistoryPage = true;
  }

  private openPlaceHistoryDetail(placeName: string): void {
    this.historySummary = this.vm.getPlaceCheckinSummary(placeName);
    this.selectedHistoryPlaceName = placeName;
    this.historyViewMode = 'detail';
    this.showHistoryPage = true;
  }

  private handleFocusedAdjust(): void {
    promptAction.showToast({ message: '该地点暂不支持修正入口' });
  }

  private async handleFocusedReopen(): Promise<void> {
    const focused = this.getFocusedEvent();
    if (!focused) {
      return;
    }
    if (this.getEventState(focused) !== 'SKIPPED') {
      promptAction.showToast({ message: '仅“已跳过”任务可重新开始' });
      return;
    }
    if (this.hasOtherActiveEvent(focused.id)) {
      promptAction.showToast({ message: '请先结束当前进行中的任务' });
      return;
    }

    const reopened = await this.vm.reopenSkippedEvent(focused.id);
    if (!reopened) {
      promptAction.showToast({ message: '重新开始失败' });
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
    animateTo({ duration: 250, curve: Curve.EaseInOut }, () => {
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
    animateTo({ duration: 240, curve: Curve.EaseInOut }, () => {
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
    animateTo({ duration: 220, curve: Curve.Friction }, () => {
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
              promptAction.showToast({ message: '已跳过任务不可再次跳过' });
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
    this.historyViewMode = 'list';
    this.selectedHistoryPlaceName = '';
    this.historySummary = null;
  }

  private backToHistoryList(): void {
    this.historyViewMode = 'list';
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

  private getLatestRecord(summary: PlaceCheckinSummary): PlaceCheckinRecord | null {
    if (!summary.records || summary.records.length === 0) {
      return null;
    }
    return summary.records[0];
  }

  private getCurrentHistoryLatestRecord(): PlaceCheckinRecord | null {
    if (!this.historySummary) {
      return null;
    }
    return this.getLatestRecord(this.historySummary);
  }

  private getCurrentHistoryLatestEvent(): EventEntity | null {
    if (!this.historySummary) {
      return null;
    }
    return this.getLatestEventForPlace(this.historySummary.placeName);
  }

  private getCurrentHistoryPlannedStartText(): string {
    const latestEvent = this.getCurrentHistoryLatestEvent();
    if (!latestEvent) {
      return '--:--';
    }
    return latestEvent.computed_time || latestEvent.fixed_start_time || '--:--';
  }

  private getCurrentHistoryActualStartText(): string {
    const latestRecord = this.getCurrentHistoryLatestRecord();
    if (!latestRecord) {
      return '--:--';
    }
    return this.formatTs(latestRecord.actualStart);
  }

  private getCurrentHistoryActualEndText(): string {
    const latestRecord = this.getCurrentHistoryLatestRecord();
    if (!latestRecord) {
      return '--:--';
    }
    return this.formatTs(latestRecord.actualEnd);
  }

  private getCurrentHistoryStayText(): string {
    const latestRecord = this.getCurrentHistoryLatestRecord();
    if (!latestRecord) {
      return '0 分钟';
    }
    return `${latestRecord.stayMinutes} 分钟`;
  }

  @Builder
  private HistoryFullPage() {
    if (this.showHistoryPage) {
      Column({ space: 12 }) {
        Row() {
          Text(this.historyViewMode === 'list' ? '历史地点' : '地点历史')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.getThemePalette().textPrimary);
          Blank();
          if (this.historyViewMode === 'detail') {
            Text('返回')
              .fontSize(14)
              .fontColor(this.getThemePalette().textSecondary)
              .onClick(() => {
                this.backToHistoryList();
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

        if (this.historyViewMode === 'list') {
          if (this.historyPlaces.length === 0) {
            Column({ space: 8 }) {
              Text('暂无打卡历史')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.getThemePalette().textSecondary);
              Text('开始或结束一个地点后会生成历史记录。')
                .fontSize(12)
                .fontColor(this.getThemePalette().textTertiary);
            }
            .width('100%')
            .layoutWeight(1)
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center);
          } else {
            List({ space: 8 }) {
              ForEach(this.historyPlaces, (item: HistoryPlaceItem) => {
                ListItem() {
                  Row() {
                    Column({ space: 4 }) {
                      Text(item.placeName)
                        .fontSize(16)
                        .fontWeight(FontWeight.Bold)
                        .fontColor(this.getThemePalette().textPrimary)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis });
                      Text(`记录 ${item.totalRecords} 条 | 最近 ${item.latestTs > 0 ? this.formatDateTime(item.latestTs) : '--:--'}`)
                        .fontSize(12)
                        .fontColor(this.getThemePalette().textSecondary)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis });
                    }
                    .layoutWeight(1)
                    .alignItems(HorizontalAlign.Start);

                    Text('>')
                      .fontSize(14)
                      .fontColor(this.getThemePalette().textTertiary);
                  }
                  .width('100%')
                  .padding({ left: 12, right: 12, top: 12, bottom: 12 })
                  .backgroundColor(this.getThemePalette().companionCardBg)
                  .borderRadius(12)
                  .onClick(() => {
                    this.openPlaceHistoryDetail(item.placeName);
                  });
                };
              }, (item: HistoryPlaceItem) => item.placeName);
            }
            .width('100%')
            .layoutWeight(1);
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
              Text(this.getHistoryAddress(this.historySummary.placeName))
                .fontSize(12)
                .fontColor(this.getThemePalette().textSecondary)
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis });
            }
            .width('100%')
            .padding(12)
            .backgroundColor(this.getThemePalette().companionCardBg)
            .borderRadius(12);

            Column({ space: 6 }) {
              Text('当前计划记录')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.getThemePalette().textPrimary);
              Text(`计划开始：${this.getCurrentHistoryPlannedStartText()}`)
                .fontSize(12)
                .fontColor(this.getThemePalette().textSecondary);
              Text(`实际开始：${this.getCurrentHistoryActualStartText()}`)
                .fontSize(12)
                .fontColor(this.getThemePalette().textSecondary);
              Text(`实际结束：${this.getCurrentHistoryActualEndText()}`)
                .fontSize(12)
                .fontColor(this.getThemePalette().textSecondary);
              Text(`停留：${this.getCurrentHistoryStayText()}`)
                .fontSize(12)
                .fontColor(this.getThemePalette().textSecondary);
            }
            .width('100%')
            .padding(12)
            .backgroundColor(this.getThemePalette().companionCardBg)
            .borderRadius(12);

            Column({ space: 6 }) {
              Text('历史记录')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.getThemePalette().textPrimary);
              List({ space: 6 }) {
                ForEach(this.historySummary.records, (record: PlaceCheckinRecord) => {
                  ListItem() {
                    Row() {
                      Text(this.formatDateTime(record.actualEnd > 0 ? record.actualEnd : record.actualStart))
                        .fontSize(12)
                        .fontColor(this.getThemePalette().textSecondary)
                        .layoutWeight(1);
                      Text(record.status === EventEntity.STATE_SKIPPED ? '已跳过' : `停留 ${record.stayMinutes} 分钟`)
                        .fontSize(12)
                        .fontColor(record.status === EventEntity.STATE_SKIPPED
                          ? this.getThemePalette().statusSkipped
                          : this.getThemePalette().statusCompleted);
                    }
                    .width('100%')
                    .padding({ left: 8, right: 8, top: 6, bottom: 6 })
                    .backgroundColor(this.getThemePalette().cardBgSoft)
                    .borderRadius(8);
                  };
                });
              }
              .width('100%')
              .constraintSize({ maxHeight: '38%' });
            }
            .width('100%')
            .padding(12)
            .backgroundColor(this.getThemePalette().companionCardBg)
            .borderRadius(12);

            Column({ space: 6 }) {
              Text('汇总')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.getThemePalette().textPrimary);
              Text(`平均停留：${this.historySummary.avgStayMinutes} 分钟`)
                .fontSize(12)
                .fontColor(this.getThemePalette().textSecondary);
              Text(`最近到访：${this.historySummary.lastEndTime > 0 ? this.formatDateTime(this.historySummary.lastEndTime) : '--:--'}`)
                .fontSize(12)
                .fontColor(this.getThemePalette().textSecondary);
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









