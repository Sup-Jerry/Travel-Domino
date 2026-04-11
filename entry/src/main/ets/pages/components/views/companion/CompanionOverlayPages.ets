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

  onHistoryClose: () => void = () => {};
  onHistoryBack: () => void = () => {};
  onHistoryFilterChange: (filter: HistoryTimelineFilter) => void = (_filter: HistoryTimelineFilter) => {};
  onHistoryItemClick: (item: HistoryTimelineItem) => void = (_item: HistoryTimelineItem) => {};

  onSearchClose: () => void = () => {};
  onSearch: (keyword: string) => void = (_keyword: string) => {};
  onSearchResultClick: (item: EventEntity) => void = (_item: EventEntity) => {};

  onFilterClose: () => void = () => {};
  onFilterSelect: (state: CompanionDisplayFilterState) => void = (_state: CompanionDisplayFilterState) => {};

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
        onClose: () => {
          this.onHistoryClose();
        },
        onBack: () => {
          this.onHistoryBack();
        },
        onFilterChange: (filter: HistoryTimelineFilter) => {
          this.onHistoryFilterChange(filter);
        },
        onItemClick: (item: HistoryTimelineItem) => {
          this.onHistoryItemClick(item);
        }
      });

      CompanionSearchPage({
        showSearchPage: shouldShowCompanionSearchOverlay(this.showSearchPage),
        searchKeyword: this.searchKeyword,
        searchResults: this.searchResults,
        safeTopInset: this.safeTopInset,
        safeBottomInset: this.safeBottomInset,
        onClose: () => {
          this.onSearchClose();
        },
        onSearch: (keyword: string) => {
          this.onSearch(keyword);
        },
        onResultClick: (item: EventEntity) => {
          this.onSearchResultClick(item);
        },
        getEventStateLabel: (item: EventEntity) => getCompanionEventStateLabel(item),
        getPlannedRange: (item: EventEntity) => getCompanionPlannedRange(item)
      });

      CompanionFilterPage({
        showFilterPage: shouldShowCompanionFilterOverlay(this.showFilterPage),
        companionFilterState: this.companionFilterState,
        safeTopInset: this.safeTopInset,
        safeBottomInset: this.safeBottomInset,
        onClose: () => {
          this.onFilterClose();
        },
        onFilterSelect: (state: CompanionDisplayFilterState) => {
          this.onFilterSelect(state);
        },
        getFilterOptions: () => getCompanionFilterOptions(),
        getFilterLabel: (state: CompanionDisplayFilterState) => getCompanionFilterLabel(state)
      });
    }
    .width('100%')
    .height('100%');
  }
}

