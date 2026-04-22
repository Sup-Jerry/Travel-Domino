import { describe, it, expect } from '@ohos/hypium';
import { ThemeCenter } from '../main/ets/common/utils/ThemeCenter';
import {
  CompanionView,
  isCompanionOverlayVisible,
  resolveCompanionBackAction,
  resolveCompanionBackLevel,
  resolveCompanionDefaultFocusId,
  resolveCompanionSearchResults,
  resolveCompanionVisibleFocusId,
  resolveCompanionVisibleFocusPosition
} from '../main/ets/pages/components/views/CompanionView';
import { IndexCompanionOverlay } from '../main/ets/pages/index/IndexCompanionOverlay';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import {
  CompanionContext,
  HistoryTimelineItem,
  HistoryTimelineSummary,
  PlaceCheckinSummary,
  TimelineViewModel
} from '../main/ets/viewmodel/TimelineViewModel';

function buildCompanionEvent(id: number, name: string, address: string = ''): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = name;
  event.address = address;
  event.status = 1;
  event.completion_status = EventEntity.STATE_PENDING;
  event.actual_start_time = 0;
  event.actual_end_time = 0;
  return event;
}

type CompanionRuntimeStateTest = 'PENDING' | 'ACTIVE' | 'COMPLETED';

interface CompanionViewParamsTest {
  vm?: TimelineViewModel;
  isShow?: boolean;
}

interface IndexCompanionOverlayParamsTest {
  vm?: TimelineViewModel;
  isVisible?: boolean;
  overlayZIndex?: number;
}

interface CompanionViewCtorParamsTest {
  vm: Object;
  isShow: Object;
}

interface IndexCompanionOverlayPrivateTest {
  __vm: Object;
  __isVisible: Object;
}

interface CompanionViewPaletteTest {
  pageBg?: Object;
  textPrimary?: Object;
}

interface CompanionGestureEventTest {
  offsetY: number;
}

interface CompanionConflictInfoTest {
  name: string;
}

interface CompanionBackfillCallTest {
  eventId: number;
  startTs: number;
  endTs: number;
}

interface CompanionAlertDialogButtonTest {
  value: string;
  action: () => void;
}

interface CompanionAlertDialogOptionsTest {
  title: string;
  message: string;
  autoCancel: boolean;
  primaryButton: CompanionAlertDialogButtonTest;
  secondaryButton?: CompanionAlertDialogButtonTest;
}

interface CompanionViewUiContextTest {
  animateTo(options: Object, action: () => void): void;
  showAlertDialog(options: CompanionAlertDialogOptionsTest): void;
  getHostContext(): Object;
}

interface CompanionViewScrollerTest {
  scrollToIndex(index: number, smooth: boolean, align: Object): void;
}

interface CompanionWindowLikeTest {
  off(type: string): void;
}

interface CompanionViewVmTest {
  scheduleVersion: number;
  orderedEvents: EventEntity[];
  companionContext: CompanionContext;
  historySummary: HistoryTimelineSummary | null;
  historyItems: HistoryTimelineItem[];
  placeSummary: PlaceCheckinSummary | null;
  getScheduleVersion(): number;
  getOrderedScheduleEvents(): EventEntity[];
  getCompanionContext(): CompanionContext;
  getCurrentPlanHistorySummary(): HistoryTimelineSummary | null;
  getCurrentPlanHistoryTimelineItems(limit: number): HistoryTimelineItem[];
  getPlaceCheckinSummary(placeName: string): PlaceCheckinSummary | null;
  resumeCurrentExecution(): boolean;
  pauseCurrentExecution(): boolean;
  updateActualTime(eventId: number, field: string, value: number): Promise<boolean>;
  skipEvent(event: EventEntity): Promise<void>;
  getStartConflictInfo(excludeEventId: number): Promise<CompanionConflictInfoTest | null>;
  backfillCheckinTime(eventId: number, startTs: number, endTs: number): Promise<boolean>;
  reopenSkippedEvent(eventId: number): Promise<boolean>;
}

interface CompanionViewPrivateTest {
  vm: TimelineViewModel;
  isShow: boolean;
  effectiveTheme: string;
  context: CompanionContext;
  companionSubMode: 'immersive' | 'control';
  interactionMode: 'immersive' | 'control' | 'both';
  immersiveText: string;
  immersiveDragOffsetY: number;
  showHistoryPage: boolean;
  historyTimelineSummary: HistoryTimelineSummary | null;
  historyTimelineItems: HistoryTimelineItem[];
  historyTimelineFilter: string;
  selectedHistoryTimelineItem: HistoryTimelineItem | null;
  historySummary: PlaceCheckinSummary | null;
  historyViewMode: string;
  selectedHistoryPlaceName: string;
  showSearchPage: boolean;
  showFilterPage: boolean;
  searchKeyword: string;
  searchResults: EventEntity[];
  companionFilterState: string;
  cachedScheduledEvents: EventEntity[];
  cachedVisibleScheduledEvents: EventEntity[];
  focusedEventId: number;
  focusedIndex: number;
  focusSource: string;
  tapPriorityUntilTs: number;
  visibleStartIndex: number;
  visibleEndIndex: number;
  visibleCenterIndex: number;
  cardDisplayEventId: number;
  outgoingCardEventId: number;
  incomingCardEventId: number;
  isCardSwitching: boolean;
  cardSwitchProgress: number;
  pendingFocusId: number;
  swipeStartTs: number;
  swipeLastTs: number;
  swipePeakDistance: number;
  safeTopInset: number;
  safeBottomInset: number;
  safeLeftInset: number;
  safeRightInset: number;
  weatherExpanded: boolean;
  showWeatherScorePopup: boolean;
  showWeatherHintPopup: boolean;
  showWeatherSuggestionPopup: boolean;
  weatherSuggestionPopupText: string;
  realtimeWatchTimer: number;
  observedScheduleVersion: number;
  observedRuntimeState: string;
  observedBackRequest: number;
  immersiveWindow?: CompanionWindowLikeTest;
  timelineScroller: CompanionViewScrollerTest;
  getUIContext: () => CompanionViewUiContextTest;
  initialRender(): void;
  aboutToAppear(): void;
  aboutToDisappear(): void;
  setInitiallyProvidedValue(params: CompanionViewParamsTest): void;
  updateStateVars(params: CompanionViewParamsTest): void;
  updateSafeAreaInsets(): void;
  safeShowToast(message: string): void;
  getThemePalette(): CompanionViewPaletteTest;
  refreshContext(): void;
  refreshScheduleCache(): void;
  ensureScheduleCacheUpToDate(): void;
  getScheduledEvents(): EventEntity[];
  getVisibleScheduledEvents(): EventEntity[];
  getVisibleTimelineEvents(): EventEntity[];
  getVisibleTimelineCount(): number;
  getVisibleFocusPosition(): number;
  ensureFocusVisible(): void;
  openFilterPage(): void;
  closeFilterPage(): void;
  applyFilter(state: string): void;
  refreshSearchResults(): void;
  openSearchPage(): void;
  closeSearchPage(): void;
  pickSearchResult(event: EventEntity): void;
  getEventById(id: number): EventEntity | null;
  getScheduleIndexById(id: number): number;
  pickDefaultFocusId(): number;
  ensureFocusReady(): void;
  getFocusedEvent(): EventEntity | null;
  canRenderSwitchCards(): boolean;
  getDisplayCardEvent(): EventEntity | null;
  applyFocusById(targetId: number, source: 'tap' | 'scroll' | 'init'): void;
  startCardSwitch(targetId: number): void;
  handleTimelineScrollIndex(start: number, end: number, center: number): void;
  handleTimelineScrollStop(): void;
  handleTimelineTap(event: EventEntity, index: number): void;
  showActiveConflictDialog(conflictName: string): void;
  showGlobalActiveConflictDialog(excludeEventId: number): Promise<boolean>;
  startNavigation(target?: EventEntity): void;
  loadHistoryTimelineData(): void;
  openHistoryList(): void;
  openHistoryDetailFromTimeline(item: HistoryTimelineItem): void;
  handleFocusedAdjust(event?: EventEntity): void;
  openRecordCorrectionDialog(event: EventEntity): void;
  handleFocusedPrimaryAction(): Promise<void>;
  handleFocusedSkip(): Promise<void>;
  applyCompanionCheckinBackfill(eventId: number, startTs: number, endTs: number): Promise<void>;
  handleFocusedReopen(): Promise<void>;
  enterControlMode(): void;
  enterImmersiveMode(): void;
  exitCompanion(): void;
  handleCompanionBackNavigation(): boolean;
  handleImmersiveSwipeStart(): void;
  handleImmersiveSwipeUpdate(event: CompanionGestureEventTest): void;
  resetImmersiveSwipe(): void;
  handleImmersiveSwipeEnd(event: CompanionGestureEventTest): void;
}

class CompanionViewUiContextMockTest implements CompanionViewUiContextTest {
  public alertCount: number = 0;
  public lastAlert?: CompanionAlertDialogOptionsTest;
  private readonly hostContext: Object = new CompanionViewHostContextMockTest() as Object;

  animateTo(_options: Object, action: () => void): void {
    action();
  }

  showAlertDialog(options: CompanionAlertDialogOptionsTest): void {
    this.alertCount += 1;
    this.lastAlert = options;
  }

  getHostContext(): Object {
    return this.hostContext;
  }
}

class CompanionViewHostContextMockTest {}

class CompanionViewScrollerMockTest implements CompanionViewScrollerTest {
  public indices: number[] = [];

  scrollToIndex(index: number, _smooth: boolean, _align: Object): void {
    this.indices.push(index);
  }
}

class CompanionWindowMockTest implements CompanionWindowLikeTest {
  public offCalls: string[] = [];

  off(type: string): void {
    this.offCalls.push(type);
  }
}

function createCompanionViewInstance(vm: TimelineViewModel, isShow: boolean = true): CompanionViewPrivateTest {
  const overlayParams: IndexCompanionOverlayParamsTest = {
    vm,
    isVisible: isShow,
    overlayZIndex: 10
  };
  const overlay = new IndexCompanionOverlay(
    undefined,
    overlayParams as Object as LocalStorage
  ) as Object as IndexCompanionOverlayPrivateTest;
  const companionParams: CompanionViewCtorParamsTest = {
    vm: overlay.__vm,
    isShow: overlay.__isVisible
  };
  return new CompanionView(
    overlay as Object,
    companionParams as Object as LocalStorage
  ) as Object as CompanionViewPrivateTest;
}

function setCompanionViewUiContextForTest(
  page: CompanionViewPrivateTest,
  uiContext: CompanionViewUiContextTest
): void {
  Reflect.set(page as Object, 'getUIContext', (): CompanionViewUiContextTest => uiContext);
}

class CompanionViewVmMockTest implements CompanionViewVmTest {
  public scheduleVersion: number = 1;
  public orderedEvents: EventEntity[] = [];
  public companionContext: CompanionContext = buildCompanionContext('IDLE', null, null);
  public historySummary: HistoryTimelineSummary | null = null;
  public historyItems: HistoryTimelineItem[] = [];
  public placeSummary: PlaceCheckinSummary | null = null;
  public executionWeatherCollabBadge: string = '';
  public executionWeatherLoading: boolean = false;
  public executionWeatherHint: string = '';
  public executionWeatherLevel: string = 'INFO';
  public executionWeatherCurrentText: string = '';
  public executionWeatherNextText: string = '';
  public executionWeatherScore: number = -1;
  public executionWeatherCollabSummary: string = '';
  public executionWeatherAppliedSummary: string = '';
  public executionWeatherSuggestions: Object[] = [];
  public resumeResult: boolean = true;
  public resumeCount: number = 0;
  public pauseResult: boolean = true;
  public pauseCount: number = 0;
  public updateActualTimeResult: boolean = true;
  public updateActualTimeCount: number = 0;
  public lastUpdateActualEventId: number = -1;
  public lastUpdateActualField: string = '';
  public lastUpdateActualValue: number = 0;
  public skippedEventIds: number[] = [];
  public conflictName: string = '';
  public backfillResult: boolean = true;
  public backfillCalls: CompanionBackfillCallTest[] = [];
  public reopenResult: boolean = true;
  public reopenedEventIds: number[] = [];

  getScheduleVersion(): number {
    return this.scheduleVersion;
  }

  getOrderedScheduleEvents(): EventEntity[] {
    return this.orderedEvents;
  }

  getCompanionContext(): CompanionContext {
    return this.companionContext;
  }

  getCurrentPlanHistorySummary(): HistoryTimelineSummary | null {
    return this.historySummary;
  }

  getCurrentPlanHistoryTimelineItems(limit: number): HistoryTimelineItem[] {
    return this.historyItems.slice(0, limit);
  }

  getPlaceCheckinSummary(_placeName: string): PlaceCheckinSummary | null {
    return this.placeSummary;
  }

  isWeatherFeatureEnabled(): boolean {
    return true;
  }

  buildWeatherScoreExplanation(_score: number): string {
    return 'score_line';
  }

  buildWeatherHintExplanation(): string {
    return 'hint_line';
  }

  resumeCurrentExecution(): boolean {
    this.resumeCount += 1;
    if (this.resumeResult) {
      this.companionContext.runtimeState = 'ACTIVE';
    }
    return this.resumeResult;
  }

  pauseCurrentExecution(): boolean {
    this.pauseCount += 1;
    if (this.pauseResult) {
      this.companionContext.runtimeState = 'PAUSED';
    }
    return this.pauseResult;
  }

  async updateActualTime(eventId: number, field: string, value: number): Promise<boolean> {
    this.updateActualTimeCount += 1;
    this.lastUpdateActualEventId = eventId;
    this.lastUpdateActualField = field;
    this.lastUpdateActualValue = value;
    const target = this.orderedEvents.find((item: EventEntity) => item.id === eventId);
    if (this.updateActualTimeResult && target && field === 'actual_start_time') {
      target.actual_start_time = value;
      target.actual_end_time = 0;
      target.completion_status = EventEntity.STATE_PENDING;
      this.companionContext.currentEvent = target;
      this.companionContext.runtimeState = 'ACTIVE';
    }
    return this.updateActualTimeResult;
  }

  async skipEvent(event: EventEntity): Promise<void> {
    this.skippedEventIds.push(event.id);
    event.completion_status = EventEntity.STATE_SKIPPED;
    event.actual_start_time = 0;
    event.actual_end_time = 0;
    if (this.companionContext.currentEvent && this.companionContext.currentEvent.id === event.id) {
      this.companionContext.currentEvent = null;
      this.companionContext.runtimeState = 'READY';
    }
  }

  async getStartConflictInfo(_excludeEventId: number): Promise<CompanionConflictInfoTest | null> {
    if (this.conflictName.length === 0) {
      return null;
    }
    return { name: this.conflictName };
  }

  async backfillCheckinTime(eventId: number, startTs: number, endTs: number): Promise<boolean> {
    this.backfillCalls.push({ eventId, startTs, endTs });
    return this.backfillResult;
  }

  async reopenSkippedEvent(eventId: number): Promise<boolean> {
    this.reopenedEventIds.push(eventId);
    if (!this.reopenResult) {
      return false;
    }
    const target = this.orderedEvents.find((item: EventEntity) => item.id === eventId);
    if (target) {
      target.completion_status = EventEntity.STATE_PENDING;
      target.actual_start_time = 0;
      target.actual_end_time = 0;
      this.companionContext.nextEvent = target;
      this.companionContext.runtimeState = 'READY';
    }
    return true;
  }

  async refreshExecutionWeather(_forceRefresh: boolean, _trigger: string): Promise<void> {
    return Promise.resolve();
  }

  dismissExecutionSuggestion(_suggestionId: string): void {}
}

class CompanionActionHostTest {
  vm: CompanionViewVmMockTest;
  context: CompanionContext;
  focusedEventId: number = -1;
  companionSubMode: 'immersive' | 'control' = 'control';
  toastMessages: string[] = [];
  uiContext: CompanionViewUiContextMockTest;

  constructor(vm: CompanionViewVmMockTest, focusedEvent: EventEntity | null, uiContext?: CompanionViewUiContextMockTest) {
    this.vm = vm;
    this.context = vm.getCompanionContext();
    this.focusedEventId = focusedEvent ? focusedEvent.id : -1;
    this.uiContext = uiContext ? uiContext : new CompanionViewUiContextMockTest();
  }

  async handleFocusedPrimaryAction(): Promise<void> {
    return invokeCompanionActionMethodTest(companionHandleFocusedPrimaryActionTest, this);
  }

  async applyCompanionCheckinBackfill(eventId: number, startTs: number, endTs: number): Promise<void> {
    return invokeCompanionActionMethodTest(companionApplyCheckinBackfillTest, this, eventId, startTs, endTs);
  }

  async handleFocusedSkip(): Promise<void> {
    return invokeCompanionActionMethodTest(companionHandleFocusedSkipTest, this);
  }

  async handleFocusedReopen(): Promise<void> {
    return invokeCompanionActionMethodTest(companionHandleFocusedReopenTest, this);
  }

  getFocusedEvent(): EventEntity | null {
    return this.vm.orderedEvents.find((item: EventEntity) => item.id === this.focusedEventId) ?? null;
  }

  getScheduledEvents(): EventEntity[] {
    return this.vm.orderedEvents;
  }

  getScheduleIndexById(id: number): number {
    return this.vm.orderedEvents.findIndex((item: EventEntity) => item.id === id);
  }

  async showGlobalActiveConflictDialog(excludeEventId: number): Promise<boolean> {
    const conflict = await this.vm.getStartConflictInfo(excludeEventId);
    if (!conflict) {
      return false;
    }
    this.uiContext.showAlertDialog({
      title: '无法开始打卡',
      message: `当前已有进行中的地点【${conflict.name}】。`,
      autoCancel: true,
      primaryButton: {
        value: '知道了',
        action: (): void => {}
      }
    });
    return true;
  }

  safeShowToast(message: string): void {
    this.toastMessages.push(message);
  }

  refreshContext(): void {
    this.context = this.vm.getCompanionContext();
  }

  applyFocusById(targetId: number, _source: 'tap' | 'scroll' | 'init'): void {
    this.focusedEventId = targetId;
  }

  enterImmersiveMode(): void {
    this.companionSubMode = 'immersive';
  }
}

function getCompanionActionMethodTest<T>(name: string): T {
  const prototype = Reflect.get(CompanionView as Object, 'prototype') as Object;
  return Reflect.get(prototype, name) as T;
}

function invokeCompanionActionMethodTest<THost, TResult, TArgs extends (Object | number | string | boolean)[]>(
  method: (this: THost, ...args: TArgs) => TResult,
  host: THost,
  ...args: TArgs
): TResult {
  const bound = method.bind(host) as (...boundArgs: TArgs) => TResult;
  return bound(...args);
}

const companionHandleFocusedPrimaryActionTest = getCompanionActionMethodTest<
  (this: CompanionActionHostTest) => Promise<void>
>('handleFocusedPrimaryAction');
const companionApplyCheckinBackfillTest = getCompanionActionMethodTest<
  (this: CompanionActionHostTest, eventId: number, startTs: number, endTs: number) => Promise<void>
>('applyCompanionCheckinBackfill');
const companionHandleFocusedSkipTest = getCompanionActionMethodTest<
  (this: CompanionActionHostTest) => Promise<void>
>('handleFocusedSkip');
const companionHandleFocusedReopenTest = getCompanionActionMethodTest<
  (this: CompanionActionHostTest) => Promise<void>
>('handleFocusedReopen');

function buildCompanionRuntimeEvent(id: number, name: string, runtime: CompanionRuntimeStateTest, address: string = ''): EventEntity {
  const event = buildCompanionEvent(id, name, address);
  event.status = 1;
  event.duration = 45;
  event.fixed_start_time = '09:00';
  event.computed_time = '09:00';
  event.dynamic_start_time = 1713254400000 + (id * 60000);
  if (runtime === 'ACTIVE') {
    event.actual_start_time = 1713254400000 + (id * 60000);
    event.completion_status = EventEntity.STATE_PENDING;
    return event;
  }
  if (runtime === 'COMPLETED') {
    event.actual_start_time = 1713254400000 + (id * 60000);
    event.actual_end_time = event.actual_start_time + (30 * 60000);
    event.completion_status = EventEntity.STATE_COMPLETED;
    return event;
  }
  event.completion_status = EventEntity.STATE_PENDING;
  return event;
}

function buildCompanionContext(
  runtimeState: 'IDLE' | 'READY' | 'ACTIVE' | 'PAUSED' | 'GAP',
  currentEvent: EventEntity | null,
  nextEvent: EventEntity | null
): CompanionContext {
  const context = {} as CompanionContext;
  context.runtimeState = runtimeState;
  context.currentEvent = currentEvent;
  context.nextEvent = nextEvent;
  context.hint = null;
  context.actions = {
    canStart: true,
    canPause: true,
    canResume: true,
    canEnd: true,
    canSkip: true,
    canNavigate: true,
    canViewDetail: true
  };
  return context;
}

function buildCompanionHistorySummary(planName: string): HistoryTimelineSummary {
  const summary = {} as HistoryTimelineSummary;
  summary.planName = planName;
  summary.completedCount = 1;
  summary.skippedCount = 0;
  summary.activeCount = 1;
  return summary;
}

function buildCompanionHistoryItem(id: number, placeName: string): HistoryTimelineItem {
  const item = {} as HistoryTimelineItem;
  item.id = id;
  item.eventId = 1000 + id;
  item.placeName = placeName;
  item.actionType = 'ARRIVE';
  item.plannedStart = 1713254400000;
  item.actualStart = 1713254700000;
  item.actualEnd = 1713256500000;
  item.stayMinutes = 30;
  item.deviationMinutes = 5;
  item.status = 1;
  item.groupDateKey = '2026-04-20';
  item.address = `addr_${placeName}`;
  item.note = 'history_note';
  item.displayTs = 1713254700000;
  item.isAbnormal = false;
  return item;
}

function buildCompanionPlaceSummary(placeName: string): PlaceCheckinSummary {
  const summary = {} as PlaceCheckinSummary;
  summary.placeName = placeName;
  summary.totalRecords = 1;
  summary.completedRecords = 1;
  summary.skippedRecords = 0;
  summary.avgStayMinutes = 30;
  summary.lastEndTime = 1713256500000;
  summary.records = [];
  return summary;
}

export default function companionViewHelperTest() {
  describe('unit_test_case_generator_autofill_CompanionViewHelper', () => {
    it('normal: companion_back_level_should_be_overlay_when_any_overlay_visible', 0, () => {
      // Arrange
      const showHistoryPage = true;
      const showSearchPage = false;
      const showFilterPage = false;
      // Act
      const level = resolveCompanionBackLevel(showHistoryPage, showSearchPage, showFilterPage, 'immersive');
      // Assert
      expect(level).assertEqual('overlay');
    });

    it('boundary: companion_back_level_should_be_control_without_overlays_in_control_mode', 0, () => {
      // Arrange
      const showHistoryPage = false;
      const showSearchPage = false;
      const showFilterPage = false;
      // Act
      const level = resolveCompanionBackLevel(showHistoryPage, showSearchPage, showFilterPage, 'control');
      // Assert
      expect(level).assertEqual('control');
    });

    it('invalid: companion_overlay_visible_should_be_false_when_all_flags_false', 0, () => {
      // Arrange
      const showHistoryPage = false;
      const showSearchPage = false;
      const showFilterPage = false;
      // Act
      const visible = isCompanionOverlayVisible(showHistoryPage, showSearchPage, showFilterPage);
      // Assert
      expect(visible).assertFalse();
    });

    it('conflict: companion_overlay_visible_should_be_true_when_history_and_search_both_open', 0, () => {
      // Arrange
      const showHistoryPage = true;
      const showSearchPage = true;
      const showFilterPage = false;
      // Act
      const visible = isCompanionOverlayVisible(showHistoryPage, showSearchPage, showFilterPage);
      // Assert
      expect(visible).assertTrue();
    });

    it('regression: td-20260412-companion-back-level-immersive-default-should-stay', 0, () => {
      // Arrange
      const showHistoryPage = false;
      const showSearchPage = false;
      const showFilterPage = false;
      // Act
      const level = resolveCompanionBackLevel(showHistoryPage, showSearchPage, showFilterPage, 'immersive');
      // Assert
      expect(level).assertEqual('immersive');
    });

    it('combined: companion_overlay_and_back_level_should_be_consistent', 0, () => {
      // Arrange
      const showHistoryPage = false;
      const showSearchPage = false;
      const showFilterPage = true;
      // Act
      const visible = isCompanionOverlayVisible(showHistoryPage, showSearchPage, showFilterPage);
      const level = resolveCompanionBackLevel(showHistoryPage, showSearchPage, showFilterPage, 'control');
      // Assert
      expect(visible).assertTrue();
      expect(level).assertEqual('overlay');
    });
  });

  describe('unit_test_case_generator_autofill_CompanionViewHelperBranches', () => {
    it('normal: companion_back_action_should_return_overlay_close_when_any_overlay_open', 0, () => {
      // Arrange
      const showHistoryPage = false;
      const showSearchPage = true;
      const showFilterPage = false;
      // Act
      const action = resolveCompanionBackAction(showHistoryPage, showSearchPage, showFilterPage, 'immersive');
      // Assert
      expect(action).assertEqual('close_overlay');
    });

    it('boundary: companion_search_should_limit_empty_keyword_result_to_20_items', 0, () => {
      // Arrange
      const source: EventEntity[] = [];
      for (let i = 1; i <= 25; i++) {
        source.push(buildCompanionEvent(i, `event-${i}`));
      }
      // Act
      const results = resolveCompanionSearchResults(source, '   ');
      // Assert
      expect(results.length).assertEqual(20);
    });

    it('invalid: companion_visible_focus_position_should_return_zero_when_focus_not_mapped', 0, () => {
      // Arrange
      const focusedEventId = 999;
      const visibleIndexById: Map<number, number> = new Map<number, number>();
      visibleIndexById.set(1, 0);
      // Act
      const position = resolveCompanionVisibleFocusPosition(focusedEventId, visibleIndexById);
      // Assert
      expect(position).assertEqual(0);
    });

    it('conflict: companion_default_focus_should_prioritize_current_event_over_next_when_both_exist', 0, () => {
      // Arrange
      const schedule = [buildCompanionEvent(11, 'a'), buildCompanionEvent(12, 'b')];
      const currentEventId = 12;
      const nextEventId = 11;
      // Act
      const focused = resolveCompanionDefaultFocusId(schedule, currentEventId, nextEventId);
      // Assert
      expect(focused).assertEqual(12);
    });

    it('regression: td-20260418-companion-visible-focus-id-should-fallback-to-first-visible', 0, () => {
      // Arrange
      const visibleEvents = [buildCompanionEvent(5, 'first'), buildCompanionEvent(6, 'second')];
      const focusedEventId = 100;
      // Act
      const visibleFocusId = resolveCompanionVisibleFocusId(visibleEvents, focusedEventId);
      // Assert
      expect(visibleFocusId).assertEqual(5);
    });

    it('combined: companion_search_and_back_action_should_support_keyword_filter_and_control_mode_exit', 0, () => {
      // Arrange
      const source = [
        buildCompanionEvent(1, 'Museum', 'Center'),
        buildCompanionEvent(2, 'Cafe', 'Lake')
      ];
      // Act
      const results = resolveCompanionSearchResults(source, 'cafe');
      const action = resolveCompanionBackAction(false, false, false, 'control');
      // Assert
      expect(results.length).assertEqual(1);
      expect(results[0].id).assertEqual(2);
      expect(action).assertEqual('control_to_immersive');
    });
  });

  describe('unit_test_case_generator_autofill_CompanionViewHelperPriorityBranches', () => {
    it('normal: companion_default_focus_should_prioritize_active_event_over_current_and_next', 0, () => {
      // Arrange
      const active = buildCompanionEvent(21, 'active');
      active.actual_start_time = 1000;
      active.actual_end_time = 0;
      const pending = buildCompanionEvent(22, 'pending');
      const schedule = [pending, active];
      // Act
      const focused = resolveCompanionDefaultFocusId(schedule, 22, 21);
      // Assert
      expect(focused).assertEqual(21);
    });

    it('boundary: companion_default_focus_should_fallback_to_negative_one_when_schedule_empty', 0, () => {
      // Arrange
      const schedule: EventEntity[] = [];
      // Act
      const focused = resolveCompanionDefaultFocusId(schedule, 1, 2);
      // Assert
      expect(focused).assertEqual(-1);
    });

    it('invalid: companion_search_should_use_search_text_map_when_event_text_not_match', 0, () => {
      // Arrange
      const source = [buildCompanionEvent(31, 'A', 'B')];
      const searchTextById = new Map<number, string>();
      searchTextById.set(31, 'custom-keyword');
      // Act
      const results = resolveCompanionSearchResults(source, 'custom', searchTextById);
      // Assert
      expect(results.length).assertEqual(1);
      expect(results[0].id).assertEqual(31);
    });

    it('conflict: companion_back_action_should_exit_when_no_overlay_and_not_control_mode', 0, () => {
      // Arrange
      const showHistoryPage = false;
      const showSearchPage = false;
      const showFilterPage = false;
      // Act
      const action = resolveCompanionBackAction(showHistoryPage, showSearchPage, showFilterPage, 'immersive');
      // Assert
      expect(action).assertEqual('exit');
    });

    it('regression: td-20260418-companion_visible_focus_position_should_be_1_based', 0, () => {
      // Arrange
      const visibleIndexById: Map<number, number> = new Map<number, number>();
      visibleIndexById.set(41, 0);
      // Act
      const position = resolveCompanionVisibleFocusPosition(41, visibleIndexById);
      // Assert
      expect(position).assertEqual(1);
    });

    it('combined: companion_focus_resolution_should_support_startable_fallback_and_visible_focus', 0, () => {
      // Arrange
      const pending = buildCompanionEvent(51, 'pending');
      const done = buildCompanionEvent(52, 'done');
      done.completion_status = EventEntity.STATE_COMPLETED;
      const schedule = [done, pending];
      const visible = [pending];
      // Act
      const focused = resolveCompanionDefaultFocusId(schedule, -1, -1);
      const visibleFocused = resolveCompanionVisibleFocusId(visible, focused);
      // Assert
      expect(focused).assertEqual(51);
      expect(visibleFocused).assertEqual(51);
    });

    it('boundary: companion_visible_focus_should_return_negative_one_when_visible_list_empty', 0, () => {
      // Arrange
      const visibleEvents: EventEntity[] = [];
      // Act
      const visibleFocusId = resolveCompanionVisibleFocusId(visibleEvents, 88);
      // Assert
      expect(visibleFocusId).assertEqual(-1);
    });

    it('conflict: companion_default_focus_should_use_next_event_when_current_event_missing', 0, () => {
      // Arrange
      const first = buildCompanionEvent(61, 'first');
      first.completion_status = EventEntity.STATE_COMPLETED;
      const next = buildCompanionEvent(62, 'next');
      next.completion_status = EventEntity.STATE_COMPLETED;
      const schedule = [first, next];
      // Act
      const focused = resolveCompanionDefaultFocusId(schedule, 999, 62);
      // Assert
      expect(focused).assertEqual(62);
    });

    it('regression: td-20260419-companion_default_focus_should_fallback_to_first_when_no_candidate_matches', 0, () => {
      // Arrange
      const first = buildCompanionEvent(71, 'first');
      first.completion_status = EventEntity.STATE_COMPLETED;
      const second = buildCompanionEvent(72, 'second');
      second.completion_status = EventEntity.STATE_COMPLETED;
      const schedule = [first, second];
      // Act
      const focused = resolveCompanionDefaultFocusId(schedule, -1, -1);
      // Assert
      expect(focused).assertEqual(71);
    });
  });

  describe('unit_test_case_generator_autofill_CompanionViewInstanceStateAndFlow', () => {
    it('combined: companion_view_instance_should_sync_state_cache_search_history_and_back_flow', 0, () => {
      // Arrange
      const active = buildCompanionRuntimeEvent(101, 'active_spot', 'ACTIVE', 'West Lake');
      const pending = buildCompanionRuntimeEvent(102, 'pending_spot', 'PENDING', 'Lake Road');
      const completed = buildCompanionRuntimeEvent(103, 'completed_spot', 'COMPLETED', 'City Center');
      const historyItem = buildCompanionHistoryItem(1, pending.name);
      const historySummary = buildCompanionHistorySummary('trip_companion');
      const placeSummary = buildCompanionPlaceSummary(pending.name);
      const vm = new CompanionViewVmMockTest();
      vm.orderedEvents = [active, pending, completed];
      vm.companionContext = buildCompanionContext('ACTIVE', active, pending);
      vm.historySummary = historySummary;
      vm.historyItems = [historyItem];
      vm.placeSummary = placeSummary;
      const uiContext = new CompanionViewUiContextMockTest();
      const scroller = new CompanionViewScrollerMockTest();
      const page = createCompanionViewInstance(vm as Object as TimelineViewModel);

      setCompanionViewUiContextForTest(page, uiContext);
      page.timelineScroller = scroller;
      page.isShow = false;
      page.isShow = true;
      page.effectiveTheme = 'dark';
      page.immersiveText = 'assistant';
      page.immersiveDragOffsetY = 18;
      page.interactionMode = 'control';
      page.showHistoryPage = false;
      page.showSearchPage = true;
      page.showFilterPage = true;
      page.searchKeyword = 'museum';
      page.searchResults = [pending];
      page.weatherExpanded = true;
      page.showWeatherScorePopup = true;
      page.showWeatherHintPopup = false;
      page.showWeatherSuggestionPopup = true;
      page.weatherSuggestionPopupText = 'weather_detail';
      page.safeTopInset = 11;
      page.safeBottomInset = 22;
      page.safeLeftInset = 3;
      page.safeRightInset = 4;
      page.refreshContext();

      // Act
      const scheduledCount = page.getScheduledEvents().length;
      const visibleCount = page.getVisibleScheduledEvents().length;
      const visibleTimelineCount = page.getVisibleTimelineCount();
      const visibleTimelineEvents = page.getVisibleTimelineEvents();
      const defaultFocusId = page.pickDefaultFocusId();
      page.ensureFocusReady();
      const initFocusedId = page.getFocusedEvent()?.id ?? -1;
      const initDisplayId = page.getDisplayCardEvent()?.id ?? -1;

      page.focusedEventId = 999;
      page.cardDisplayEventId = pending.id;
      page.applyFilter('PENDING');
      page.ensureFocusVisible();
      const focusedIdAfterFilter = page.focusedEventId;
      const visibleFocusPosition = page.getVisibleFocusPosition();
      const pendingVisibleCount = page.cachedVisibleScheduledEvents.length;

      page.openFilterPage();
      const filterOpen = page.showFilterPage;
      page.closeFilterPage();
      page.openSearchPage();
      const seededSearchCount = page.searchResults.length;
      page.searchKeyword = 'lake';
      page.refreshSearchResults();
      const keywordSearchCount = page.searchResults.length;
      page.cardDisplayEventId = active.id;
      page.focusedEventId = active.id;
      page.pickSearchResult(active);
      const eventById = page.getEventById(pending.id);
      const missingEvent = page.getEventById(999);
      const scheduleIndex = page.getScheduleIndexById(completed.id);
      const missingIndex = page.getScheduleIndexById(999);
      page.handleTimelineScrollIndex(2, 4, 3);
      page.handleTimelineScrollStop();
      page.loadHistoryTimelineData();
      page.openHistoryList();
      page.openHistoryDetailFromTimeline(historyItem);
      const detailPlaceName = page.selectedHistoryPlaceName;
      page.showActiveConflictDialog('');
      page.focusedEventId = -1;
      page.startNavigation();
      page.startNavigation(pending);
      page.handleFocusedAdjust();
      const backHandled = page.handleCompanionBackNavigation();
      page.exitCompanion();
      const palette = page.getThemePalette();

      // Assert
      expect(scheduledCount).assertEqual(3);
      expect(visibleCount).assertEqual(3);
      expect(visibleTimelineCount).assertEqual(3);
      expect(visibleTimelineEvents.length).assertEqual(3);
      expect(defaultFocusId).assertEqual(active.id);
      expect(initFocusedId).assertEqual(active.id);
      expect(initDisplayId).assertEqual(active.id);
      expect(page.companionFilterState).assertEqual('PENDING');
      expect(focusedIdAfterFilter).assertEqual(pending.id);
      expect(visibleFocusPosition).assertEqual(1);
      expect(pendingVisibleCount).assertEqual(1);
      expect(filterOpen).assertTrue();
      expect(page.showFilterPage).assertFalse();
      expect(seededSearchCount).assertEqual(3);
      expect(keywordSearchCount).assertEqual(2);
      expect(page.showSearchPage).assertFalse();
      expect(page.searchKeyword).assertEqual('');
      expect(page.searchResults.length).assertEqual(0);
      expect(eventById?.id).assertEqual(pending.id);
      expect(missingEvent).assertNull();
      expect(scheduleIndex).assertEqual(2);
      expect(missingIndex).assertEqual(-1);
      expect(page.visibleStartIndex).assertEqual(2);
      expect(page.visibleEndIndex).assertEqual(4);
      expect(page.visibleCenterIndex).assertEqual(3);
      expect(page.historyTimelineSummary?.planName).assertEqual(historySummary.planName);
      expect(page.historyTimelineItems.length).assertEqual(1);
      expect(detailPlaceName).assertEqual(pending.name);
      expect(page.historyViewMode).assertEqual('timeline');
      expect(page.selectedHistoryPlaceName).assertEqual('');
      expect(page.historySummary).assertNull();
      expect(page.selectedHistoryTimelineItem).assertNull();
      expect(uiContext.alertCount).assertEqual(1);
      expect((uiContext.lastAlert?.title?.length ?? 0) > 0).assertTrue();
      expect((uiContext.lastAlert?.message?.length ?? 0) > 0).assertTrue();
      expect(backHandled).assertTrue();
      expect(page.isShow).assertFalse();
      expect(page.effectiveTheme).assertEqual('dark');
      expect(page.immersiveText).assertEqual('assistant');
      expect(page.immersiveDragOffsetY).assertEqual(0);
      expect(page.interactionMode).assertEqual('control');
      expect(page.weatherExpanded).assertTrue();
      expect(page.showWeatherScorePopup).assertTrue();
      expect(page.showWeatherHintPopup).assertFalse();
      expect(page.showWeatherSuggestionPopup).assertTrue();
      expect(page.weatherSuggestionPopupText).assertEqual('weather_detail');
      expect(page.safeTopInset).assertEqual(11);
      expect(page.safeBottomInset).assertEqual(22);
      expect(page.safeLeftInset).assertEqual(3);
      expect(page.safeRightInset).assertEqual(4);
      expect(palette.pageBg).assertEqual(ThemeCenter.getPalette('dark').pageBg);
      expect(palette.textPrimary).assertEqual(ThemeCenter.getPalette('dark').textPrimary);
    });
  });

  describe('unit_test_case_generator_autofill_CompanionViewInstanceSwitchAndSwipe', () => {
    it('combined: companion_view_instance_should_switch_cards_modes_and_swipe_with_pending_focus', 0, async () => {
      // Arrange
      const active = buildCompanionRuntimeEvent(201, 'active_node', 'ACTIVE', 'A Street');
      const pending = buildCompanionRuntimeEvent(202, 'pending_node', 'PENDING', 'B Street');
      const completed = buildCompanionRuntimeEvent(203, 'completed_node', 'COMPLETED', 'C Street');
      const vm = new CompanionViewVmMockTest();
      vm.orderedEvents = [active, pending, completed];
      vm.companionContext = buildCompanionContext('ACTIVE', active, pending);
      const uiContext = new CompanionViewUiContextMockTest();
      const scroller = new CompanionViewScrollerMockTest();
      const page = createCompanionViewInstance(vm as Object as TimelineViewModel);

      setCompanionViewUiContextForTest(page, uiContext);
      page.timelineScroller = scroller;
      page.refreshContext();

      // Act
      const initDisplayId = page.getDisplayCardEvent()?.id ?? -1;
      page.applyFocusById(pending.id, 'tap');
      const renderDuringSwitch = page.canRenderSwitchCards();
      const firstOutgoingId = page.outgoingCardEventId;
      const firstIncomingId = page.incomingCardEventId;
      page.applyFocusById(completed.id, 'scroll');
      const queuedPendingId = page.pendingFocusId;
      await new Promise<void>((resolve: () => void): void => {
        setTimeout((): void => {
          resolve();
        }, 330);
      });
      const switchingAfterFirstWait = page.isCardSwitching;
      await new Promise<void>((resolve: () => void): void => {
        setTimeout((): void => {
          resolve();
        }, 330);
      });
      const finalDisplayId = page.cardDisplayEventId;
      const finalFocusedId = page.focusedEventId;
      const renderAfterSwitch = page.canRenderSwitchCards();
      page.handleTimelineTap(active, 0);
      await new Promise<void>((resolve: () => void): void => {
        setTimeout((): void => {
          resolve();
        }, 330);
      });
      const postTapDisplayId = page.cardDisplayEventId;
      page.enterControlMode();
      await new Promise<void>((resolve: () => void): void => {
        setTimeout((): void => {
          resolve();
        }, 280);
      });
      const controlMode = page.companionSubMode;
      const controlInteraction = page.interactionMode;
      page.showHistoryPage = true;
      page.showSearchPage = true;
      page.showFilterPage = true;
      page.enterImmersiveMode();
      await new Promise<void>((resolve: () => void): void => {
        setTimeout((): void => {
          resolve();
        }, 270);
      });
      const immersiveMode = page.companionSubMode;
      page.handleImmersiveSwipeStart();
      const swipeStartTs = page.swipeStartTs;
      page.handleImmersiveSwipeUpdate({ offsetY: -60 });
      const dragOffsetAfterUpdate = page.immersiveDragOffsetY;
      page.swipeStartTs = Date.now() - 1000;
      page.handleImmersiveSwipeEnd({ offsetY: -20 });
      const modeAfterShortSwipe = page.companionSubMode;
      const dragOffsetAfterShortSwipe = page.immersiveDragOffsetY;
      page.handleImmersiveSwipeStart();
      page.swipeStartTs = Date.now() - 300;
      page.swipePeakDistance = 120;
      page.handleImmersiveSwipeEnd({ offsetY: -120 });
      await new Promise<void>((resolve: () => void): void => {
        setTimeout((): void => {
          resolve();
        }, 280);
      });
      const modeAfterLongSwipe = page.companionSubMode;
      page.showHistoryPage = false;
      page.showSearchPage = false;
      page.showFilterPage = false;
      page.handleCompanionBackNavigation();
      await new Promise<void>((resolve: () => void): void => {
        setTimeout((): void => {
          resolve();
        }, 270);
      });
      const modeAfterBack = page.companionSubMode;

      // Assert
      expect(initDisplayId).assertEqual(active.id);
      expect(renderDuringSwitch).assertTrue();
      expect(firstOutgoingId).assertEqual(active.id);
      expect(firstIncomingId).assertEqual(pending.id);
      expect(queuedPendingId).assertEqual(completed.id);
      expect(switchingAfterFirstWait).assertTrue();
      expect(finalDisplayId).assertEqual(completed.id);
      expect(finalFocusedId).assertEqual(completed.id);
      expect(renderAfterSwitch).assertFalse();
      expect(page.pendingFocusId).assertEqual(-1);
      expect(page.cardSwitchProgress).assertEqual(1);
      expect(postTapDisplayId).assertEqual(active.id);
      expect(scroller.indices[0]).assertEqual(0);
      expect(controlMode).assertEqual('control');
      expect(controlInteraction).assertEqual('control');
      expect(immersiveMode).assertEqual('immersive');
      expect(page.showHistoryPage).assertFalse();
      expect(page.showSearchPage).assertFalse();
      expect(page.showFilterPage).assertFalse();
      expect(swipeStartTs > 0).assertTrue();
      expect(dragOffsetAfterUpdate < 0).assertTrue();
      expect(modeAfterShortSwipe).assertEqual('immersive');
      expect(dragOffsetAfterShortSwipe).assertEqual(0);
      expect(modeAfterLongSwipe).assertEqual('control');
      expect(modeAfterBack).assertEqual('immersive');
    });
  });

  describe('unit_test_case_generator_autofill_CompanionViewLifecycle', () => {
    it('combined: companion_view_lifecycle_should_start_watch_refresh_back_level_and_stop_cleanly', 0, async () => {
      // Arrange
      const active = buildCompanionRuntimeEvent(501, 'lifecycle_active', 'ACTIVE', 'Alpha Street');
      const pending = buildCompanionRuntimeEvent(502, 'lifecycle_pending', 'PENDING', 'Beta Street');
      const vm = new CompanionViewVmMockTest();
      vm.orderedEvents = [active, pending];
      vm.companionContext = buildCompanionContext('ACTIVE', active, pending);
      const uiContext = new CompanionViewUiContextMockTest();
      const page = createCompanionViewInstance(vm as Object as TimelineViewModel);
      setCompanionViewUiContextForTest(page, uiContext);
      page.isShow = true;
      AppStorage.setOrCreate('COMPANION_BACK_LEVEL', '');
      AppStorage.setOrCreate('COMPANION_BACK_REQUEST', 0);

      // Act
      page.aboutToAppear();
      await new Promise<void>((resolve: () => void): void => {
        setTimeout((): void => {
          resolve();
        }, 360);
      });
      const backLevelAfterAppear = String(AppStorage.get('COMPANION_BACK_LEVEL') || '');
      const timerAfterAppear = page.realtimeWatchTimer;

      page.showHistoryPage = true;
      await new Promise<void>((resolve: () => void): void => {
        setTimeout((): void => {
          resolve();
        }, 360);
      });
      const backLevelWithOverlay = String(AppStorage.get('COMPANION_BACK_LEVEL') || '');

      page.showHistoryPage = false;
      vm.scheduleVersion = 2;
      vm.companionContext = buildCompanionContext('READY', null, pending);
      AppStorage.setOrCreate('COMPANION_BACK_REQUEST', 1);
      await new Promise<void>((resolve: () => void): void => {
        setTimeout((): void => {
          resolve();
        }, 360);
      });
      const backRequestAfterRefresh = page.observedBackRequest;

      page.aboutToDisappear();
      const backLevelAfterDisappear = String(AppStorage.get('COMPANION_BACK_LEVEL') || '');

      // Assert
      expect(page.companionSubMode).assertEqual('immersive');
      expect(page.interactionMode).assertEqual('immersive');
      expect(page.focusedEventId).assertEqual(active.id);
      expect(page.cardDisplayEventId).assertEqual(active.id);
      expect(page.searchKeyword).assertEqual('');
      expect(page.searchResults.length).assertEqual(0);
      expect(timerAfterAppear !== -1).assertTrue();
      expect(backLevelAfterAppear).assertEqual('immersive');
      expect(backLevelWithOverlay).assertEqual('overlay');
      expect(backRequestAfterRefresh).assertEqual(1);
      expect(page.isShow).assertFalse();
      expect(page.realtimeWatchTimer).assertEqual(-1);
      expect(backLevelAfterDisappear).assertEqual('none');
    });
  });

  describe('unit_test_case_generator_autofill_CompanionViewInitialRender', () => {
    it('normal: companion_view_initial_render_should_cover_control_and_immersive_branches', 0, () => {
      // Arrange
      const active = buildCompanionRuntimeEvent(551, 'render_active', 'ACTIVE', 'Render Road');
      const pending = buildCompanionRuntimeEvent(552, 'render_pending', 'PENDING', 'Render Lake');
      const vm = new CompanionViewVmMockTest();
      vm.orderedEvents = [active, pending];
      vm.companionContext = buildCompanionContext('ACTIVE', active, pending);
      vm.executionWeatherHint = 'rain later';
      vm.executionWeatherLevel = 'NOTICE';
      vm.executionWeatherCurrentText = 'cloudy';
      vm.executionWeatherNextText = 'rain';
      vm.executionWeatherScore = 78;
      vm.executionWeatherCollabBadge = 'SYNC';
      vm.executionWeatherCollabSummary = 'summary';
      vm.executionWeatherAppliedSummary = 'applied';
      vm.executionWeatherSuggestions = [];
      const page = createCompanionViewInstance(vm as Object as TimelineViewModel);
      page.companionSubMode = 'control';
      page.interactionMode = 'both';
      page.refreshContext();
      let threw = false;

      // Act
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
      expect(page.context.runtimeState).assertEqual('ACTIVE');
      expect(page.focusedEventId).assertEqual(active.id);
    });

    it('combined: companion_view_initial_render_should_cover_overlay_pages_branch', 0, () => {
      // Arrange
      const pending = buildCompanionRuntimeEvent(553, 'overlay_pending', 'PENDING', 'Overlay Road');
      const historyItem = buildCompanionHistoryItem(9, pending.name);
      const vm = new CompanionViewVmMockTest();
      vm.orderedEvents = [pending];
      vm.companionContext = buildCompanionContext('READY', null, pending);
      vm.historySummary = buildCompanionHistorySummary('overlay_plan');
      vm.historyItems = [historyItem];
      vm.placeSummary = buildCompanionPlaceSummary(pending.name);
      const page = createCompanionViewInstance(vm as Object as TimelineViewModel);
      page.companionSubMode = 'control';
      page.showHistoryPage = true;
      page.showSearchPage = true;
      page.showFilterPage = true;
      page.searchKeyword = 'overlay';
      page.searchResults = [pending];
      page.historyTimelineSummary = vm.historySummary;
      page.historyTimelineItems = vm.historyItems;
      page.historySummary = vm.placeSummary;
      let threw = false;

      // Act
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
      expect(page.showHistoryPage).assertTrue();
      expect(page.showSearchPage).assertTrue();
      expect(page.showFilterPage).assertTrue();
    });

  });

  describe('unit_test_case_generator_autofill_CompanionViewPrimaryActionAndBackfillBranches', () => {
    it('normal: focused_primary_action_should_resume_execution_and_keep_focus', 0, async () => {
      // Arrange
      const pending = buildCompanionRuntimeEvent(601, 'resume_pending', 'PENDING', 'Resume Road');
      const vm = new CompanionViewVmMockTest();
      vm.orderedEvents = [pending];
      vm.companionContext = buildCompanionContext('PAUSED', pending, pending);
      vm.companionContext.actions.canResume = true;
      const page = new CompanionActionHostTest(vm, pending);

      // Act
      await page.handleFocusedPrimaryAction();

      // Assert
      expect(vm.resumeCount).assertEqual(1);
      expect(page.focusedEventId).assertEqual(pending.id);
      expect(page.context.runtimeState).assertEqual('ACTIVE');
    });

    it('boundary: focused_primary_action_should_start_pending_event_when_startable', 0, async () => {
      // Arrange
      const pending = buildCompanionRuntimeEvent(602, 'start_pending', 'PENDING', 'Start Road');
      const vm = new CompanionViewVmMockTest();
      vm.orderedEvents = [pending];
      vm.companionContext = buildCompanionContext('READY', null, pending);
      vm.companionContext.actions.canResume = false;
      const page = new CompanionActionHostTest(vm, pending);

      // Act
      await page.handleFocusedPrimaryAction();

      // Assert
      expect(vm.updateActualTimeCount).assertEqual(1);
      expect(vm.lastUpdateActualEventId).assertEqual(pending.id);
      expect(vm.lastUpdateActualField).assertEqual('actual_start_time');
      expect(page.context.runtimeState).assertEqual('ACTIVE');
      expect(page.companionSubMode).assertEqual('immersive');
    });

    it('invalid: focused_primary_action_should_toast_when_resume_fails', 0, async () => {
      // Arrange
      const pending = buildCompanionRuntimeEvent(603, 'resume_fail', 'PENDING', 'Fail Road');
      const vm = new CompanionViewVmMockTest();
      vm.orderedEvents = [pending];
      vm.resumeResult = false;
      vm.companionContext = buildCompanionContext('PAUSED', pending, pending);
      vm.companionContext.actions.canResume = true;
      const page = new CompanionActionHostTest(vm, pending);

      // Act
      await page.handleFocusedPrimaryAction();

      // Assert
      expect(vm.resumeCount).assertEqual(1);
      expect(page.context.runtimeState).assertEqual('PAUSED');
    });

    it('conflict: focused_primary_action_should_show_conflict_when_pending_start_is_blocked', 0, async () => {
      // Arrange
      const active = buildCompanionRuntimeEvent(604, 'active_blocker', 'ACTIVE', 'Active Road');
      const pending = buildCompanionRuntimeEvent(605, 'blocked_pending', 'PENDING', 'Blocked Road');
      const vm = new CompanionViewVmMockTest();
      vm.orderedEvents = [active, pending];
      vm.conflictName = active.name;
      vm.companionContext = buildCompanionContext('READY', null, pending);
      vm.companionContext.actions.canResume = false;
      const uiContext = new CompanionViewUiContextMockTest();
      const page = new CompanionActionHostTest(vm, pending, uiContext);

      // Act
      await page.handleFocusedPrimaryAction();

      // Assert
      expect(vm.updateActualTimeCount).assertEqual(0);
      expect(uiContext.alertCount).assertEqual(1);
      expect(uiContext.lastAlert?.message.includes(active.name)).assertTrue();
    });

    it('regression: td-20260422-focused_primary_action_should_toast_when_active_pause_is_disabled', 0, async () => {
      // Arrange
      const active = buildCompanionRuntimeEvent(606, 'pause_disabled', 'ACTIVE', 'Pause Road');
      const vm = new CompanionViewVmMockTest();
      vm.orderedEvents = [active];
      vm.companionContext = buildCompanionContext('ACTIVE', active, null);
      vm.companionContext.actions.canResume = false;
      vm.companionContext.actions.canPause = false;
      const page = new CompanionActionHostTest(vm, active);

      // Act
      await page.handleFocusedPrimaryAction();

      // Assert
      expect(vm.pauseCount).assertEqual(0);
      expect(page.context.runtimeState).assertEqual('ACTIVE');
    });

    it('combined: focused_primary_action_should_cover_start_failure_without_conflict_and_pause_success', 0, async () => {
      // Arrange
      const pending = buildCompanionRuntimeEvent(607, 'start_fail', 'PENDING', 'Start Fail Road');
      const active = buildCompanionRuntimeEvent(608, 'pause_active', 'ACTIVE', 'Pause Active Road');
      const vm = new CompanionViewVmMockTest();
      vm.orderedEvents = [pending];
      vm.updateActualTimeResult = false;
      vm.companionContext = buildCompanionContext('READY', null, pending);
      vm.companionContext.actions.canResume = false;
      const page = new CompanionActionHostTest(vm, pending);

      // Act
      await page.handleFocusedPrimaryAction();
      vm.updateActualTimeResult = true;
      vm.scheduleVersion = 2;
      vm.orderedEvents = [active];
      vm.companionContext = buildCompanionContext('ACTIVE', active, null);
      vm.companionContext.actions.canResume = false;
      vm.companionContext.actions.canPause = true;
      page.refreshContext();
      page.applyFocusById(active.id, 'tap');
      await page.handleFocusedPrimaryAction();

      // Assert
      expect(vm.updateActualTimeCount).assertEqual(1);
      expect(vm.pauseCount).assertEqual(1);
      expect(page.context.runtimeState).assertEqual('PAUSED');
    });

    it('boundary: checkin_backfill_should_reject_end_without_start', 0, async () => {
      // Arrange
      const pending = buildCompanionRuntimeEvent(609, 'backfill_pending', 'PENDING', 'Backfill Road');
      const vm = new CompanionViewVmMockTest();
      vm.orderedEvents = [pending];
      vm.companionContext = buildCompanionContext('READY', null, pending);
      const page = new CompanionActionHostTest(vm, pending);

      // Act
      await page.applyCompanionCheckinBackfill(pending.id, 0, 2000);

      // Assert
      expect(vm.backfillCalls.length).assertEqual(0);
      expect(page.toastMessages[0]).assertEqual('请先设置开始时间');
      expect(page.context.runtimeState).assertEqual('READY');
    });

    it('invalid: checkin_backfill_should_reject_end_before_start', 0, async () => {
      // Arrange
      const pending = buildCompanionRuntimeEvent(610, 'backfill_invalid', 'PENDING', 'Invalid Road');
      const vm = new CompanionViewVmMockTest();
      vm.orderedEvents = [pending];
      vm.companionContext = buildCompanionContext('READY', null, pending);
      const page = new CompanionActionHostTest(vm, pending);

      // Act
      await page.applyCompanionCheckinBackfill(pending.id, 3000, 2000);

      // Assert
      expect(vm.backfillCalls.length).assertEqual(0);
      expect(page.toastMessages[0]).assertEqual('结束时间不能早于开始时间');
      expect(page.context.runtimeState).assertEqual('READY');
    });

    it('conflict: checkin_backfill_should_toast_when_repository_rejects_update', 0, async () => {
      // Arrange
      const pending = buildCompanionRuntimeEvent(611, 'backfill_fail', 'PENDING', 'Reject Road');
      const vm = new CompanionViewVmMockTest();
      vm.orderedEvents = [pending];
      vm.backfillResult = false;
      vm.companionContext = buildCompanionContext('READY', null, pending);
      const page = new CompanionActionHostTest(vm, pending);

      // Act
      await page.applyCompanionCheckinBackfill(pending.id, 1000.8, 2000.2);

      // Assert
      expect(vm.backfillCalls.length).assertEqual(1);
      expect(vm.backfillCalls[0].startTs).assertEqual(1000);
      expect(vm.backfillCalls[0].endTs).assertEqual(2000);
      expect(page.toastMessages[0]).assertEqual('补打卡失败，请稍后重试');
      expect(page.context.runtimeState).assertEqual('READY');
    });

    it('regression: td-20260422-checkin_backfill_should_clear_record_when_times_are_invalid_numbers', 0, async () => {
      // Arrange
      const pending = buildCompanionRuntimeEvent(612, 'backfill_clear', 'PENDING', 'Clear Road');
      const vm = new CompanionViewVmMockTest();
      vm.orderedEvents = [pending];
      vm.companionContext = buildCompanionContext('READY', null, pending);
      const page = new CompanionActionHostTest(vm, pending);

      // Act
      await page.applyCompanionCheckinBackfill(pending.id, Number.NaN, Number.POSITIVE_INFINITY);

      // Assert
      expect(vm.backfillCalls.length).assertEqual(1);
      expect(vm.backfillCalls[0].startTs).assertEqual(0);
      expect(vm.backfillCalls[0].endTs).assertEqual(0);
      expect(page.context.nextEvent?.id).assertEqual(pending.id);
    });

    it('combined: checkin_backfill_should_save_positive_time_and_refresh_context', 0, async () => {
      // Arrange
      const pending = buildCompanionRuntimeEvent(613, 'backfill_save', 'PENDING', 'Save Road');
      const vm = new CompanionViewVmMockTest();
      vm.orderedEvents = [pending];
      vm.companionContext = buildCompanionContext('READY', null, pending);
      const page = new CompanionActionHostTest(vm, pending);

      // Act
      await page.applyCompanionCheckinBackfill(pending.id, 1000, 2000);

      // Assert
      expect(vm.backfillCalls.length).assertEqual(1);
      expect(vm.backfillCalls[0].eventId).assertEqual(pending.id);
      expect(page.context.nextEvent?.id).assertEqual(pending.id);
    });
  });

  describe('unit_test_case_generator_autofill_CompanionViewSkipReopenAndDialogBranches', () => {
    it('normal: focused_skip_should_skip_pending_event_and_focus_next_startable', 0, async () => {
      // Arrange
      const first = buildCompanionRuntimeEvent(701, 'skip_first', 'PENDING', 'Skip First Road');
      const second = buildCompanionRuntimeEvent(702, 'skip_second', 'PENDING', 'Skip Second Road');
      const vm = new CompanionViewVmMockTest();
      vm.orderedEvents = [first, second];
      vm.companionContext = buildCompanionContext('READY', null, first);
      const page = new CompanionActionHostTest(vm, first);

      // Act
      await page.handleFocusedSkip();
      await new Promise<void>((resolve: () => void): void => {
        setTimeout((): void => {
          resolve();
        }, 150);
      });

      // Assert
      expect(vm.skippedEventIds.length).assertEqual(1);
      expect(vm.skippedEventIds[0]).assertEqual(first.id);
      expect(first.completion_status).assertEqual(EventEntity.STATE_SKIPPED);
      expect(page.focusedEventId).assertEqual(second.id);
    });

    it('boundary: focused_skip_should_noop_when_focus_missing', 0, async () => {
      // Arrange
      const pending = buildCompanionRuntimeEvent(703, 'skip_missing', 'PENDING', 'Missing Road');
      const vm = new CompanionViewVmMockTest();
      vm.orderedEvents = [pending];
      vm.companionContext = buildCompanionContext('READY', null, pending);
      const page = new CompanionActionHostTest(vm, null);

      // Act
      await page.handleFocusedSkip();

      // Assert
      expect(vm.skippedEventIds.length).assertEqual(0);
      expect(page.focusedEventId).assertEqual(-1);
    });

    it('invalid: focused_skip_should_toast_when_focused_event_is_active', 0, async () => {
      // Arrange
      const active = buildCompanionRuntimeEvent(704, 'skip_active', 'ACTIVE', 'Active Road');
      const vm = new CompanionViewVmMockTest();
      vm.orderedEvents = [active];
      vm.companionContext = buildCompanionContext('ACTIVE', active, null);
      const page = new CompanionActionHostTest(vm, active);

      // Act
      await page.handleFocusedSkip();

      // Assert
      expect(vm.skippedEventIds.length).assertEqual(0);
      expect(page.toastMessages[0]).assertEqual('仅“未开始”任务可跳过');
    });

    it('conflict: focused_reopen_should_block_when_other_event_is_active', 0, async () => {
      // Arrange
      const active = buildCompanionRuntimeEvent(705, 'reopen_blocker', 'ACTIVE', 'Blocker Road');
      const skipped = buildCompanionRuntimeEvent(706, 'reopen_skipped', 'PENDING', 'Skipped Road');
      skipped.completion_status = EventEntity.STATE_SKIPPED;
      const vm = new CompanionViewVmMockTest();
      vm.orderedEvents = [active, skipped];
      vm.companionContext = buildCompanionContext('ACTIVE', active, null);
      const page = new CompanionActionHostTest(vm, skipped);

      // Act
      await page.handleFocusedReopen();

      // Assert
      expect(vm.reopenedEventIds.length).assertEqual(0);
      expect(vm.updateActualTimeCount).assertEqual(0);
      expect(page.toastMessages[0]).assertEqual('请先结束当前进行中的任务');
    });

    it('regression: td-20260422-focused_reopen_should_toast_when_reopen_repository_fails', 0, async () => {
      // Arrange
      const skipped = buildCompanionRuntimeEvent(707, 'reopen_fail', 'PENDING', 'Fail Road');
      skipped.completion_status = EventEntity.STATE_SKIPPED;
      const vm = new CompanionViewVmMockTest();
      vm.orderedEvents = [skipped];
      vm.reopenResult = false;
      vm.companionContext = buildCompanionContext('READY', null, skipped);
      const page = new CompanionActionHostTest(vm, skipped);

      // Act
      await page.handleFocusedReopen();

      // Assert
      expect(vm.reopenedEventIds.length).assertEqual(1);
      expect(vm.updateActualTimeCount).assertEqual(0);
      expect(page.toastMessages[0]).assertEqual('重新开始失败');
    });

    it('combined: focused_reopen_and_dialog_helpers_should_cover_success_and_missing_target_paths', 0, async () => {
      // Arrange
      const skipped = buildCompanionRuntimeEvent(708, 'reopen_success', 'PENDING', 'Success Road');
      skipped.completion_status = EventEntity.STATE_SKIPPED;
      const vm = new CompanionViewVmMockTest();
      vm.orderedEvents = [skipped];
      vm.companionContext = buildCompanionContext('READY', null, skipped);
      const page = new CompanionActionHostTest(vm, skipped);

      const dialogVm = new CompanionViewVmMockTest();
      dialogVm.orderedEvents = [skipped];
      dialogVm.conflictName = 'running_spot';
      dialogVm.companionContext = buildCompanionContext('READY', null, skipped);
      const uiContext = new CompanionViewUiContextMockTest();
      const dialogPage = createCompanionViewInstance(dialogVm as Object as TimelineViewModel);
      setCompanionViewUiContextForTest(dialogPage, uiContext);
      dialogPage.refreshContext();
      const missing = buildCompanionRuntimeEvent(799, 'missing_dialog_target', 'PENDING', 'Missing Dialog Road');

      // Act
      await page.handleFocusedReopen();
      const conflictShown = await dialogPage.showGlobalActiveConflictDialog(skipped.id);
      dialogPage.openRecordCorrectionDialog(missing);

      // Assert
      expect(vm.reopenedEventIds[0]).assertEqual(skipped.id);
      expect(vm.updateActualTimeCount).assertEqual(1);
      expect(page.focusedEventId).assertEqual(skipped.id);
      expect(page.companionSubMode).assertEqual('immersive');
      expect(conflictShown).assertTrue();
      expect(uiContext.alertCount).assertEqual(1);
      expect(uiContext.lastAlert?.message.includes('running_spot')).assertTrue();
    });

    it('regression: companion_view_update_safe_area_insets_should_fallback_to_zero_when_window_resolution_fails', 0, () => {
      // Arrange
      const vm = new CompanionViewVmMockTest();
      const page = createCompanionViewInstance(vm as Object as TimelineViewModel);
      page.safeTopInset = 12;
      page.safeBottomInset = 18;
      page.safeLeftInset = 4;
      page.safeRightInset = 6;
      page.immersiveWindow = new CompanionWindowMockTest();
      let threw = false;

      // Act
      try {
        page.updateSafeAreaInsets();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
      expect(page.safeTopInset).assertEqual(0);
      expect(page.safeBottomInset).assertEqual(0);
      expect(page.safeLeftInset).assertEqual(0);
      expect(page.safeRightInset).assertEqual(0);
    });
  });

}
