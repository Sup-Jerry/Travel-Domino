import { EventEntity } from '../../../../model/entity/EventEntity';
import {
  HistoryTimelineFilter,
  HistoryTimelineItem,
  HistoryTimelineSummary,
  PlaceCheckinSummary,
  TimelineViewModel
} from '../../../../viewmodel/TimelineViewModel';
import { CompanionHistoryPage, HistoryViewMode } from './CompanionHistoryPage';
import { CompanionSearchPage } from './CompanionSearchPage';
import { CompanionFilterPage } from './CompanionFilterPage';
import {
  CompanionDisplayFilterState,
  getCompanionEventStateLabel,
  getCompanionFilterLabel,
  getCompanionFilterOptions,
  getCompanionPlannedRange
} from './CompanionDisplayHelper';

export function shouldShowCompanionHistoryOverlay(showHistoryPage: boolean): boolean {
  return showHistoryPage;
}

export function shouldShowCompanionSearchOverlay(showSearchPage: boolean): boolean {
  return showSearchPage;
}

export function shouldShowCompanionFilterOverlay(showFilterPage: boolean): boolean {
  return showFilterPage;
}

function noopOverlayVoid(): void {}

function noopOverlayHistoryFilter(_filter: HistoryTimelineFilter): void {}

function noopOverlayHistoryItem(_item: HistoryTimelineItem): void {}

function noopOverlaySearch(_keyword: string): void {}

function noopOverlaySearchResult(_item: EventEntity): void {}

function noopOverlayFilterSelect(_state: CompanionDisplayFilterState): void {}

@Component
export struct CompanionOverlayPages {
  @Prop showHistoryPage: boolean = false;
  @Prop historyTimelineSummary: HistoryTimelineSummary | null = null;
  @Prop historyTimelineItems: HistoryTimelineItem[] = [];
  @Prop historyTimelineFilter: HistoryTimelineFilter = 'all';
  @Prop historyViewMode: HistoryViewMode = 'timeline';
  @Prop historySummary: PlaceCheckinSummary | null = null;
  @Prop vm: TimelineViewModel | null = null;
  @Prop selectedHistoryTimelineItem: HistoryTimelineItem | null = null;

  @Prop showSearchPage: boolean = false;
  @Prop searchKeyword: string = '';
  @Prop searchResults: EventEntity[] = [];

  @Prop showFilterPage: boolean = false;
  @Prop companionFilterState: CompanionDisplayFilterState = 'ALL';

  @Prop safeTopInset: number = 0;
  @Prop safeBottomInset: number = 0;

  onHistoryClose = noopOverlayVoid;
  onHistoryBack = noopOverlayVoid;
  onHistoryFilterChange = noopOverlayHistoryFilter;
  onHistoryItemClick = noopOverlayHistoryItem;

  onSearchClose = noopOverlayVoid;
  onSearch = noopOverlaySearch;
  onSearchResultClick = noopOverlaySearchResult;

  onFilterClose = noopOverlayVoid;
  onFilterSelect = noopOverlayFilterSelect;

  build() {
    Column() {
      CompanionHistoryPage({
        showHistoryPage: shouldShowCompanionHistoryOverlay(this.showHistoryPage),
        historyTimelineSummary: this.historyTimelineSummary,
        historyTimelineItems: this.historyTimelineItems,
        historyTimelineFilter: this.historyTimelineFilter,
        historyViewMode: this.historyViewMode,
        historySummary: this.historySummary,
        vm: this.vm,
        selectedHistoryTimelineItem: this.selectedHistoryTimelineItem,
        safeTopInset: this.safeTopInset,
        safeBottomInset: this.safeBottomInset,
        onClose: this.onHistoryClose,
        onBack: this.onHistoryBack,
        onFilterChange: this.onHistoryFilterChange,
        onItemClick: this.onHistoryItemClick
      });

      CompanionSearchPage({
        showSearchPage: shouldShowCompanionSearchOverlay(this.showSearchPage),
        searchKeyword: this.searchKeyword,
        searchResults: this.searchResults,
        safeTopInset: this.safeTopInset,
        safeBottomInset: this.safeBottomInset,
        onClose: this.onSearchClose,
        onSearch: this.onSearch,
        onResultClick: this.onSearchResultClick,
        getEventStateLabel: getCompanionEventStateLabel,
        getPlannedRange: getCompanionPlannedRange
      });

      CompanionFilterPage({
        showFilterPage: shouldShowCompanionFilterOverlay(this.showFilterPage),
        companionFilterState: this.companionFilterState,
        safeTopInset: this.safeTopInset,
        safeBottomInset: this.safeBottomInset,
        onClose: this.onFilterClose,
        onFilterSelect: this.onFilterSelect,
        getFilterOptions: getCompanionFilterOptions,
        getFilterLabel: getCompanionFilterLabel
      });
    }
    .width('100%')
    .height('100%');
  }
}

