import { describe, expect, it } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { CompanionView } from '../main/ets/pages/components/views/CompanionView';
import { IndexCompanionOverlay } from '../main/ets/pages/index/IndexCompanionOverlay';
import {
  CompanionContext,
  HistoryTimelineItem,
  HistoryTimelineSummary,
  PlaceCheckinSummary,
  TimelineViewModel
} from '../main/ets/viewmodel/TimelineViewModel';

interface CompanionViewCtorParamsFQ {
  vm: Object;
  isShow: Object;
}

interface IndexCompanionOverlayParamsFQ {
  vm?: TimelineViewModel;
  isVisible?: boolean;
  overlayZIndex?: number;
}

interface IndexCompanionOverlayPrivateFQ {
  __vm: Object;
  __isVisible: Object;
}

interface CompanionViewScrollerFQ {
  scrollToIndex(index: number, smooth: boolean, align: Object): void;
}

interface CompanionViewUiContextFQ {
  animateTo(options: Object, action: () => void): void;
  showAlertDialog(options: Object): void;
  getHostContext(): Object;
}

interface CompanionViewPrivateFQ {
  timelineScroller: CompanionViewScrollerFQ;
  focusedEventId: number;
  focusedIndex: number;
  visibleStartIndex: number;
  visibleEndIndex: number;
  visibleCenterIndex: number;
  showSearchPage: boolean;
  showFilterPage: boolean;
  showHistoryPage: boolean;
  searchKeyword: string;
  searchResults: EventEntity[];
  companionFilterState: string;
  cachedVisibleScheduledEvents: EventEntity[];
  historyTimelineFilter: string;
  selectedHistoryTimelineItem: HistoryTimelineItem | null;
  historySummary: PlaceCheckinSummary | null;
  historyViewMode: string;
  selectedHistoryPlaceName: string;
  historyTimelineSummary: HistoryTimelineSummary | null;
  historyTimelineItems: HistoryTimelineItem[];
  safeShowToast(message: string): void;
  refreshContext(): void;
  openSearchPage(): void;
  closeSearchPage(): void;
  pickSearchResult(event: EventEntity): void;
  openFilterPage(): void;
  closeFilterPage(): void;
  applyFilter(state: string): void;
  handleTimelineScrollIndex(start: number, end: number, center: number): void;
  handleTimelineScrollStop(): void;
  handleTimelineTap(event: EventEntity, index: number): void;
  openHistoryList(): void;
  openHistoryDetailFromTimeline(item: HistoryTimelineItem): void;
  handleFocusedAdjust(event?: EventEntity): void;
}

class CompanionViewHostContextMockFQ {}

class CompanionViewUiContextMockFQ implements CompanionViewUiContextFQ {
  private readonly hostContext: Object = new CompanionViewHostContextMockFQ() as Object;

  animateTo(_options: Object, action: () => void): void {
    action();
  }

  showAlertDialog(_options: Object): void {}

  getHostContext(): Object {
    return this.hostContext;
  }
}

class CompanionViewScrollerMockFQ implements CompanionViewScrollerFQ {
  indices: number[] = [];

  scrollToIndex(index: number, _smooth: boolean, _align: Object): void {
    this.indices.push(index);
  }
}

class CompanionViewVmMockFQ {
  scheduleVersion: number = 1;
  orderedEvents: EventEntity[] = [];
  companionContext: CompanionContext = buildCompanionContextFQ('IDLE', null, null);
  historySummary: HistoryTimelineSummary | null = null;
  historyItems: HistoryTimelineItem[] = [];
  placeSummary: PlaceCheckinSummary | null = null;

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
}

function buildCompanionEventFQ(id: number, name: string, address: string = ''): EventEntity {
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

function buildCompanionContextFQ(
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

function buildHistorySummaryFQ(planName: string): HistoryTimelineSummary {
  const summary = {} as HistoryTimelineSummary;
  summary.planName = planName;
  summary.completedCount = 1;
  summary.skippedCount = 0;
  summary.activeCount = 1;
  return summary;
}

function buildHistoryItemFQ(id: number, placeName: string): HistoryTimelineItem {
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
  item.groupDateKey = '2026-04-23';
  item.address = `addr_${placeName}`;
  item.note = 'history';
  item.displayTs = 1713254700000;
  item.isAbnormal = false;
  return item;
}

function buildPlaceSummaryFQ(placeName: string): PlaceCheckinSummary {
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

function createCompanionViewInstanceFQ(vm: TimelineViewModel, isShow: boolean = true): CompanionViewPrivateFQ {
  const overlayParams: IndexCompanionOverlayParamsFQ = {
    vm,
    isVisible: isShow,
    overlayZIndex: 10
  };
  const overlay = new IndexCompanionOverlay(
    undefined,
    overlayParams as Object as LocalStorage
  ) as Object as IndexCompanionOverlayPrivateFQ;
  const companionParams: CompanionViewCtorParamsFQ = {
    vm: overlay.__vm,
    isShow: overlay.__isVisible
  };
  return new CompanionView(
    overlay as Object,
    companionParams as Object as LocalStorage
  ) as Object as CompanionViewPrivateFQ;
}

function setCompanionViewUiContextFQ(page: CompanionViewPrivateFQ, uiContext: CompanionViewUiContextFQ): void {
  Reflect.set(page as Object, 'getUIContext', (): CompanionViewUiContextFQ => uiContext);
}

export default function phase2BatchFQTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchFQ_companion_view_methods', () => {
    it('normal: companion_view_search_and_filter_methods_should_update_focus_and_visibility', 0, () => {
      const active = buildCompanionEventFQ(1, 'museum', 'center');
      active.actual_start_time = Date.now() - 1000;
      const pending = buildCompanionEventFQ(2, 'cafe', 'lake');
      const vm = new CompanionViewVmMockFQ();
      vm.orderedEvents = [active, pending];
      vm.companionContext = buildCompanionContextFQ('ACTIVE', active, pending);
      const page = createCompanionViewInstanceFQ(vm as Object as TimelineViewModel);
      setCompanionViewUiContextFQ(page, new CompanionViewUiContextMockFQ());
      const toasts: string[] = [];
      Reflect.set(page as Object, 'safeShowToast', (message: string): void => {
        toasts.push(message);
      });
      page.refreshContext();

      page.openSearchPage();
      const seededCount = page.searchResults.length;
      page.pickSearchResult(pending);
      page.openFilterPage();
      page.applyFilter('PENDING');
      page.closeFilterPage();

      expect(seededCount).assertEqual(2);
      expect(page.focusedEventId).assertEqual(pending.id);
      expect(page.showSearchPage).assertFalse();
      expect(page.searchKeyword).assertEqual('');
      expect(page.searchResults.length).assertEqual(0);
      expect(page.companionFilterState).assertEqual('PENDING');
      expect(page.showFilterPage).assertFalse();
      expect(page.cachedVisibleScheduledEvents.length).assertEqual(1);
      expect(toasts.length > 0).assertTrue();
    });

    it('boundary: companion_view_timeline_methods_should_sync_scroll_window_and_tap_focus', 0, () => {
      const active = buildCompanionEventFQ(11, 'active');
      active.actual_start_time = Date.now() - 1000;
      const pending = buildCompanionEventFQ(12, 'pending');
      const vm = new CompanionViewVmMockFQ();
      vm.orderedEvents = [active, pending];
      vm.companionContext = buildCompanionContextFQ('ACTIVE', active, pending);
      const scroller = new CompanionViewScrollerMockFQ();
      const page = createCompanionViewInstanceFQ(vm as Object as TimelineViewModel);
      setCompanionViewUiContextFQ(page, new CompanionViewUiContextMockFQ());
      page.timelineScroller = scroller;
      page.refreshContext();

      page.handleTimelineScrollIndex(3, 5, 4);
      page.handleTimelineScrollStop();
      page.handleTimelineTap(pending, 1);

      expect(page.visibleStartIndex).assertEqual(3);
      expect(page.visibleEndIndex).assertEqual(5);
      expect(page.visibleCenterIndex).assertEqual(4);
      expect(page.focusedEventId).assertEqual(pending.id);
      expect(page.focusedIndex).assertEqual(1);
      expect(scroller.indices.length).assertEqual(1);
      expect(scroller.indices[0]).assertEqual(1);
    });

    it('combined: companion_view_history_methods_should_switch_between_timeline_and_detail', 0, () => {
      const active = buildCompanionEventFQ(21, 'gallery');
      active.actual_start_time = Date.now() - 1000;
      const pending = buildCompanionEventFQ(22, 'station');
      const historyItem = buildHistoryItemFQ(1, pending.name);
      const vm = new CompanionViewVmMockFQ();
      vm.orderedEvents = [active, pending];
      vm.companionContext = buildCompanionContextFQ('ACTIVE', active, pending);
      vm.historySummary = buildHistorySummaryFQ('trip');
      vm.historyItems = [historyItem];
      vm.placeSummary = buildPlaceSummaryFQ(pending.name);
      const page = createCompanionViewInstanceFQ(vm as Object as TimelineViewModel);
      setCompanionViewUiContextFQ(page, new CompanionViewUiContextMockFQ());
      page.selectedHistoryTimelineItem = historyItem;
      page.historySummary = buildPlaceSummaryFQ('other');
      page.selectedHistoryPlaceName = 'other';
      page.historyViewMode = 'detail';

      page.openHistoryList();
      const summaryPlanName = page.historyTimelineSummary?.planName ?? '';
      const itemsCount = page.historyTimelineItems.length;
      page.openHistoryDetailFromTimeline(historyItem);

      expect(summaryPlanName).assertEqual('trip');
      expect(itemsCount).assertEqual(1);
      expect(page.showHistoryPage).assertTrue();
      expect(page.historyViewMode).assertEqual('detail');
      expect(page.selectedHistoryTimelineItem?.id).assertEqual(historyItem.id);
      expect(page.selectedHistoryPlaceName).assertEqual(pending.name);
      expect(page.historySummary?.placeName).assertEqual(pending.name);
    });

    it('invalid: companion_view_focused_adjust_should_toast_when_no_target_exists', 0, () => {
      const vm = new CompanionViewVmMockFQ();
      vm.orderedEvents = [];
      vm.companionContext = buildCompanionContextFQ('IDLE', null, null);
      const page = createCompanionViewInstanceFQ(vm as Object as TimelineViewModel);
      setCompanionViewUiContextFQ(page, new CompanionViewUiContextMockFQ());
      const toasts: string[] = [];
      Reflect.set(page as Object, 'safeShowToast', (message: string): void => {
        toasts.push(message);
      });
      page.focusedEventId = -1;

      page.handleFocusedAdjust();

      expect(toasts.length).assertEqual(1);
      expect(toasts[0].length > 0).assertTrue();
    });
  });
}


